# ==============================================================================
# deploy.ps1
# Build -> Stage -> Zip -> Deploy (Idempotent Service Install)
# ==============================================================================

$ErrorActionPreference = 'Stop'

# --- НАСТРОЙКИ ---
$ServerIP   = "34.172.236.103"
$ServerUser = "mykola" 

$RepoRoot   = Get-Location
$ApiFolder  = "SimpleSocialNetwork.Api"
$WebFolder  = "SimpleSocialNetwork.Angular"
$ApiExeName = "SimpleSocialNetwork.exe" 

# Временная папка
$StagingDir = Join-Path $RepoRoot ".deploy_staging"
$ZipFile    = Join-Path $RepoRoot "deploy_package.zip"

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

if (-not $PublishSource -or -not (Test-Path $PublishSource)) {
    Write-Error "Could not find publish output!"
    exit 1
}
Write-Host "   -> Artifacts: $($PublishSource.Path)" -ForegroundColor DarkGray

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
$json.AllowedOrigins = @("https://simplesocialnetwork.mykolamartyniuk1992.dev")

if ($json.Kestrel) { $json.PSObject.Properties.Remove('Kestrel') }

$json | ConvertTo-Json -Depth 10 | Set-Content $AppSettingsFile

# --- 4. СБОРКА ANGULAR ---
Write-Host "🎨 Building Angular..." -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot $WebFolder)

npx ng build --configuration=production

$DistRoot = Join-Path (Get-Location) "dist"
if (Test-Path "$DistRoot/$WebFolder/browser") {
    $DistSource = "$DistRoot/$WebFolder/browser"
} elseif (Test-Path "$DistRoot/browser") {
    $DistSource = "$DistRoot/browser"
} else {
    $DistSource = $DistRoot
}

Write-Host "   -> Artifacts: $DistSource" -ForegroundColor DarkGray
Copy-Item "$DistSource\*" "$StagingDir\wwwroot" -Recurse -Force
Pop-Location

# --- 5. АРХИВАЦИЯ ---
Write-Host "📦 Zipping..." -ForegroundColor Yellow
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipFile -CompressionLevel Optimal

# --- 6. ОТПРАВКА И ЗАПУСК ---
Write-Host "📤 Uploading..." -ForegroundColor Yellow

ssh "$ServerUser@$ServerIP" "powershell.exe -c New-Item -ItemType Directory -Force -Path C:/webapp_temp"
scp $ZipFile "${ServerUser}@${ServerIP}:C:/webapp_temp/deploy_package.zip"

Write-Host "🔄 Remote Update..." -ForegroundColor Cyan

# --- УДАЛЕННЫЙ СКРИПТ ---
$RemoteBlock = {
    $ErrorActionPreference = 'Stop'
    $ServiceName = "SimpleSocialApp"

    Write-Host "   [Remote] Stopping service..."
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep 2

    Write-Host "   [Remote] Unzipping..."
    if (Test-Path "C:/webapp_temp/extracted") { Remove-Item "C:/webapp_temp/extracted" -Recurse -Force }
    Expand-Archive -Path "C:/webapp_temp/deploy_package.zip" -DestinationPath "C:/webapp_temp/extracted" -Force

    Write-Host "   [Remote] Deploying..."
    if (Test-Path "C:/webapp/api") { Remove-Item "C:/webapp/api/*" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path "C:/webapp/wwwroot") { Remove-Item "C:/webapp/wwwroot/*" -Recurse -Force -ErrorAction SilentlyContinue }
    
    if (-not (Test-Path "C:/webapp/api")) { New-Item -ItemType Directory -Force -Path "C:/webapp/api" | Out-Null }
    if (-not (Test-Path "C:/webapp/wwwroot")) { New-Item -ItemType Directory -Force -Path "C:/webapp/wwwroot" | Out-Null }

    Copy-Item "C:/webapp_temp/extracted/api/*" "C:/webapp/api" -Recurse -Force
    Copy-Item "C:/webapp_temp/extracted/wwwroot/*" "C:/webapp/wwwroot" -Recurse -Force

    Write-Host "   [Remote] Migrations..."
    Set-Location "C:/webapp/api"
    & ".\efbundle.exe" --connection "Server=localhost;Database=SimpleSocialNetwork;Trusted_Connection=True;TrustServerCertificate=True;"

    Write-Host "   [Remote] Service Config..."
    $nssm = (Get-Command nssm).Source
    $AppExePath = "C:\webapp\api\$ExeName"
    
    # --- FIX: ПРОВЕРКА СУЩЕСТВОВАНИЯ СЕРВИСА ---
    if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "   [Remote] Service exists. Updating config..."
        & $nssm set $ServiceName Application "$AppExePath" 2>$null
    } else {
        Write-Host "   [Remote] Installing new service..."
        & $nssm install $ServiceName "$AppExePath" 2>$null
    }

    # Общие настройки (применяются всегда)
    & $nssm set $ServiceName AppDirectory "C:\webapp\api"
    & $nssm set $ServiceName AppParameters "--urls http://0.0.0.0:8080"
    & $nssm set $ServiceName AppStdout "C:\webapp\logs\service-stdout.log"
    & $nssm set $ServiceName AppStderr "C:\webapp\logs\service-stderr.log"
    & $nssm set $ServiceName Start SERVICE_AUTO_START
    & $nssm set $ServiceName AppRotateFiles 1
    & $nssm set $ServiceName AppRotateOnline 1

    Write-Host "   [Remote] Starting..."
    Start-Service $ServiceName
    
    Remove-Item "C:/webapp_temp" -Recurse -Force
}

# --- ПОДГОТОВКА PAYLOAD ---
$ScriptWithVar = "`$ExeName = '$ApiExeName'; " + $RemoteBlock.ToString()
$ScriptBytes = [System.Text.Encoding]::Unicode.GetBytes($ScriptWithVar)
$ScriptEncoded = [System.Convert]::ToBase64String($ScriptBytes)

ssh "$ServerUser@$ServerIP" "powershell.exe -NonInteractive -EncodedCommand $ScriptEncoded"

# --- ЛОКАЛЬНАЯ ОЧИСТКА ---
Remove-Item $ZipFile -Force
Remove-Item $StagingDir -Recurse -Force

Write-Host "✅ DEPLOYMENT COMPLETE!" -ForegroundColor Green