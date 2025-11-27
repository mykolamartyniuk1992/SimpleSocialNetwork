# ==============================================================================
# deploy.ps1
# Build -> Flexible Angular Config -> Stage -> Deploy
# ==============================================================================

$ErrorActionPreference = 'Stop'

# --- НАСТРОЙКИ СЕРВЕРА ---
$ServerIP   = "34.172.236.103"
$ServerUser = "mykola"
$DomainName = "simplesocialnetwork.mykolamartyniuk1992.dev"
$AdminEmail = "mykola.martyniuk.1992@gmail.com"

# --- НАСТРОЙКИ ПРИЛОЖЕНИЯ ---
# Оставьте пустым (""), если API и Сайт на одном сервере (через Caddy proxy)
# Укажите полный URL ("https://api.example.com"), если API на другом сервере
$ApiUrl = "" 

# --- ПУТИ ---
$RepoRoot   = Get-Location
$ApiFolder  = "SimpleSocialNetwork.Api"
$WebFolder  = "SimpleSocialNetwork.Angular"
$ApiExeName = "SimpleSocialNetwork.exe"

# Временные пути
$StagingDir = Join-Path $RepoRoot ".deploy_staging"
$ZipFile    = Join-Path $RepoRoot "deploy_package.zip"
$RemoteScriptFile = Join-Path $StagingDir "remote_exec.ps1"

Write-Host "🚀 STARTING DEPLOYMENT to $ServerIP..." -ForegroundColor Green

# --- 1. ОЧИСТКА ---
if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
if (Test-Path $ZipFile)    { Remove-Item $ZipFile -Force }

New-Item -ItemType Directory -Path "$StagingDir/api" | Out-Null
New-Item -ItemType Directory -Path "$StagingDir/wwwroot" | Out-Null

# --- 2. СБОРКА API ---
Write-Host "🔨 Building .NET API..." -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot $ApiFolder)

dotnet publish -c Release -r win-x64 --self-contained false

$PublishSource = Resolve-Path "bin\Release\*\win-x64\publish" | Select-Object -Last 1
if (-not $PublishSource -or -not (Test-Path $PublishSource)) { Write-Error "Build failed!"; exit 1 }

# Мигратор
dotnet ef migrations bundle -o "$($PublishSource.Path)\efbundle.exe" --force --self-contained -r win-x64

# Копирование
Copy-Item "$($PublishSource.Path)\*" "$StagingDir\api" -Recurse -Force
Pop-Location

# --- 3. КОНФИГУРАЦИЯ API ---
Write-Host "⚙️ Configuring Staging API..." -ForegroundColor Yellow
$ApiStagePath = "$StagingDir/api"
Get-ChildItem "$ApiStagePath/appsettings.*.json" | Where-Object { $_.Name -ne "appsettings.json" } | Remove-Item -Force

$AppSettingsFile = "$ApiStagePath/appsettings.json"
$json = Get-Content $AppSettingsFile -Raw | ConvertFrom-Json
$json.ConnectionStrings.Default = "Server=localhost;Database=SimpleSocialNetwork;Trusted_Connection=True;TrustServerCertificate=True;"
# Разрешаем запросы с: Самого домена, Локалхоста (для Caddy), и если задан внешний API - то и с него
$corsOrigins = @("https://$DomainName", "http://localhost:8080", "http://127.0.0.1:8080")
if ($ApiUrl -ne "") { $corsOrigins += $ApiUrl }
$json.AllowedOrigins = $corsOrigins

if ($json.Kestrel) { $json.PSObject.Properties.Remove('Kestrel') }
$json | ConvertTo-Json -Depth 10 | Set-Content $AppSettingsFile

# FIX: Создаем пустую папку wwwroot внутри API
New-Item -ItemType Directory -Path "$ApiStagePath/wwwroot" -Force | Out-Null

# --- 4. СБОРКА ANGULAR (С ГИБКИМ URL) ---
Write-Host "🎨 Building Angular..." -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot $WebFolder)

# !!! SMART PATCH: Заменяем localhost на $ApiUrl (или относительный путь) !!!
Write-Host "   -> Configuring API URL for Production..." -ForegroundColor DarkGray

# Если $ApiUrl пустой, используем HTTPS домен для абсолютной корректности, 
# либо пустую строку для относительного пути. 
# Для Caddy лучше всего работает относительный путь "" (пустая строка), 
# но Angular иногда требует полный URL.
# Используем безопасный вариант: если ApiUrl не задан, подставляем текущий домен + /api
$TargetApiUrl = if ($ApiUrl) { $ApiUrl } else { "https://$DomainName" }

$EnvFiles = Get-ChildItem -Path "src/environments" -Filter "*.ts" -Recurse
foreach ($file in $EnvFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "localhost:5003") {
        # Заменяем локальный адрес на целевой
        $newContent = $content -replace "http://localhost:5003", $TargetApiUrl
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        Write-Host "      Patched $($file.Name) -> API: $TargetApiUrl" -ForegroundColor Green
    }
}

npx ng build --configuration=production

# Откат изменений в файлах environment (чтобы git не считал их измененными)
# (Если вы хотите оставить файлы измененными, закомментируйте блок ниже)
Write-Host "   -> Reverting environment files (git checkout)..." -ForegroundColor DarkGray
git checkout src/environments/*.ts 2>$null

$DistRoot = Join-Path (Get-Location) "dist"
if (Test-Path "$DistRoot/$WebFolder/browser") { $DistSource = "$DistRoot/$WebFolder/browser" }
elseif (Test-Path "$DistRoot/browser") { $DistSource = "$DistRoot/browser" }
else { $DistSource = $DistRoot }
Copy-Item "$DistSource\*" "$StagingDir\wwwroot" -Recurse -Force
Pop-Location

# --- 5. АРХИВАЦИЯ ---
Write-Host "📦 Zipping..." -ForegroundColor Yellow
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipFile -CompressionLevel Optimal

# --- 6. ПОДГОТОВКА УДАЛЕННОГО СКРИПТА ---
$RemoteBlock = {
    $ErrorActionPreference = 'Stop'
    $ServiceName = "SimpleSocialApp"
    
    Write-Host "   [Remote] Ensuring Firewall Rules..."
    netsh advfirewall firewall add rule name="Caddy Web Server" dir=in action=allow protocol=TCP localport=80,443 2>$null | Out-Null

    Write-Host "   [Remote] Stopping services..."
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    
    Write-Host "   [Remote] Unzipping..."
    if (Test-Path "C:/webapp_temp/extracted") { Remove-Item "C:/webapp_temp/extracted" -Recurse -Force }
    Expand-Archive -Path "C:/webapp_temp/deploy_package.zip" -DestinationPath "C:/webapp_temp/extracted" -Force

    Write-Host "   [Remote] Deploying files..."
    if (Test-Path "C:/webapp/api") { Remove-Item "C:/webapp/api/*" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path "C:/webapp/wwwroot") { Remove-Item "C:/webapp/wwwroot/*" -Recurse -Force -ErrorAction SilentlyContinue }
    
    if (-not (Test-Path "C:/webapp/api")) { New-Item -ItemType Directory -Force -Path "C:/webapp/api" | Out-Null }
    if (-not (Test-Path "C:/webapp/wwwroot")) { New-Item -ItemType Directory -Force -Path "C:/webapp/wwwroot" | Out-Null }

    Copy-Item "C:/webapp_temp/extracted/api/*" "C:/webapp/api" -Recurse -Force
    Copy-Item "C:/webapp_temp/extracted/wwwroot/*" "C:/webapp/wwwroot" -Recurse -Force

    Write-Host "   [Remote] Updating Caddy Configuration..."
    $CaddyConfig = @"
{
    email $AdminEmail
}

$DomainName {
    root * "C:\webapp\wwwroot"
    encode gzip

    # 1. Блок для API: перенаправляем на .NET и НЕ трогаем try_files
    handle /api/* {
        reverse_proxy localhost:8080
    }

    # 2. Блок для SignalR
    handle /hubs/* {
        reverse_proxy localhost:8080
    }

    # 3. Блок для Angular (SPA): срабатывает только если это не API
    handle {
        try_files {path} {path}/ /index.html
        file_server
    }
}
"@
    $CaddyConfig | Set-Content -Path "C:\webapp\Caddyfile" -Encoding UTF8
    
    $nssm = (Get-Command nssm).Source
    & $nssm restart caddy 2>$null

    Write-Host "   [Remote] DB Migrations..."
    Set-Location "C:/webapp/api"
    & ".\efbundle.exe" --connection "Server=localhost;Database=SimpleSocialNetwork;Trusted_Connection=True;TrustServerCertificate=True;"

    Write-Host "   [Remote] Service Config..."
    $AppExePath = "C:\webapp\api\$ExeName"
    
    if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "   [Remote] Updating existing service..."
        & $nssm set $ServiceName Application "$AppExePath" 2>$null
    } else {
        Write-Host "   [Remote] Installing new service..."
        & $nssm install $ServiceName "$AppExePath" 2>$null
    }

    & $nssm set $ServiceName AppDirectory "C:\webapp\api"
    & $nssm set $ServiceName AppParameters "--urls http://0.0.0.0:8080"
    & $nssm set $ServiceName AppStdout "C:\webapp\logs\service-stdout.log"
    & $nssm set $ServiceName AppStderr "C:\webapp\logs\service-stderr.log"
    & $nssm set $ServiceName Start SERVICE_AUTO_START
    & $nssm set $ServiceName AppRotateFiles 1
    
    Write-Host "   [Remote] Starting API..."
    Start-Service $ServiceName
    
    Remove-Item "C:/webapp_temp" -Recurse -Force
}

$ScriptContent = "
`$ExeName = '$ApiExeName'
`$DomainName = '$DomainName'
`$AdminEmail = '$AdminEmail'
" + $RemoteBlock.ToString()

Set-Content -Path $RemoteScriptFile -Value $ScriptContent -Encoding UTF8

# --- 7. ОТПРАВКА И ЗАПУСК ---
Write-Host "📤 Uploading Files..." -ForegroundColor Yellow
ssh "$ServerUser@$ServerIP" "powershell.exe -c New-Item -ItemType Directory -Force -Path C:/webapp_temp"
scp $ZipFile "${ServerUser}@${ServerIP}:C:/webapp_temp/deploy_package.zip"
scp $RemoteScriptFile "${ServerUser}@${ServerIP}:C:/webapp_temp/remote_exec.ps1"

Write-Host "🔄 Executing Remote Script..." -ForegroundColor Cyan
ssh "$ServerUser@$ServerIP" "powershell.exe -ExecutionPolicy Bypass -File C:/webapp_temp/remote_exec.ps1"

Remove-Item $ZipFile -Force
Remove-Item $StagingDir -Recurse -Force

Write-Host "✅ DEPLOYMENT COMPLETE!" -ForegroundColor Green