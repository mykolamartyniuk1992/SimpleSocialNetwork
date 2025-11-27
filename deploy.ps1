# ==============================================================================
# deploy.ps1
# Build (Default Paths) -> Stage -> Zip -> Deploy
# ==============================================================================

$ErrorActionPreference = 'Stop'

# --- НАСТРОЙКИ ---
$ServerIP   = "34.172.236.103"
$ServerUser = "mykola"

$RepoRoot   = Get-Location
$ApiFolder  = "SimpleSocialNetwork.Api"
$WebFolder  = "SimpleSocialNetwork.Angular"
$ApiExeName = "SimpleSocialNetwork.exe"

# Временная папка для подготовки архива (будет удалена после)
$StagingDir = Join-Path $RepoRoot ".deploy_staging"
$ZipFile    = Join-Path $RepoRoot "deploy_package.zip"

Write-Host "🚀 STARTING DEPLOYMENT to $ServerIP..." -ForegroundColor Green

# --- 1. ОЧИСТКА ---
# Чистим staging и zip, но НЕ трогаем bin/obj (dotnet сам разберется)
if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
if (Test-Path $ZipFile)    { Remove-Item $ZipFile -Force }

# Создаем структуру для архива
New-Item -ItemType Directory -Path "$StagingDir/api" | Out-Null
New-Item -ItemType Directory -Path "$StagingDir/wwwroot" | Out-Null

# --- 2. СБОРКА API (Standard Output) ---
Write-Host "🔨 Building .NET API (Default Output)..." -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot $ApiFolder)

# 1. Билд в стандартную папку (bin/Release/netX.X/publish)
# --self-contained false = Framework Dependent (легкий вес)
dotnet publish -c Release -r win-x64 --self-contained false

# 2. Ищем, куда dotnet положил файлы (обычно bin\Release\net10.0\win-x64\publish)
# Используем wildcard *, чтобы не хардкодить версию .NET
$PublishSource = Resolve-Path "bin\Release\*\win-x64\publish" | Select-Object -Last 1

if (-not $PublishSource -or -not (Test-Path $PublishSource)) {
    Write-Error "Could not find publish output in bin/Release!"
    exit 1
}
Write-Host "   -> Found artifacts in: $PublishSource" -ForegroundColor DarkGray

# 3. Создаем мигратор прямо в папку publish (чтобы скопировать всё вместе)
dotnet ef migrations bundle -o "$PublishSource\efbundle.exe" --force --self-contained -r win-x64

# 4. Копируем всё в Staging
Copy-Item "$PublishSource\*" "$StagingDir\api" -Recurse -Force

Pop-Location

# --- 3. НАСТРОЙКА API (В папке Staging) ---
Write-Host "⚙️ Configuring Staging API..." -ForegroundColor Yellow
$ApiStagePath = "$StagingDir/api"

# Удаляем лишние конфиги
Get-ChildItem "$ApiStagePath/appsettings.*.json" | Where-Object { $_.Name -ne "appsettings.json" } | Remove-Item -Force

# Патчим основной конфиг
$AppSettingsFile = "$ApiStagePath/appsettings.json"
$json = Get-Content $AppSettingsFile -Raw | ConvertFrom-Json
$json.ConnectionStrings.Default = "Server=localhost;Database=SimpleSocialNetwork;Trusted_Connection=True;TrustServerCertificate=True;"
$json.AllowedOrigins = @("https://simplesocialnetwork.mykolamartyniuk1992.dev")
if ($json.PSObject.Properties['Kestrel']) { $json.PSObject.Properties.Remove('Kestrel') }
$json | ConvertTo-Json -Depth 10 | Set-Content $AppSettingsFile

# --- 4. СБОРКА ANGULAR (Standard Output) ---
Write-Host "🎨 Building Angular..." -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot $WebFolder)

npx ng build --configuration=production

# Ищем dist (Angular 17+ = dist/Project/browser, старые = dist/Project)
$DistRoot = Join-Path (Get-Location) "dist"
if (Test-Path "$DistRoot/$WebFolder/browser") {
    $DistSource = "$DistRoot/$WebFolder/browser"
} elseif (Test-Path "$DistRoot/browser") {
    $DistSource = "$DistRoot/browser"
} else {
    $DistSource = $DistRoot # Fallback
}

Write-Host "   -> Found artifacts in: $DistSource" -ForegroundColor DarkGray

# Копируем в Staging
Copy-Item "$DistSource\*" "$StagingDir\wwwroot" -Recurse -Force

Pop-Location

# --- 5. АРХИВАЦИЯ STAGING ---
Write-Host "📦 Zipping Staging folder..." -ForegroundColor Yellow
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipFile -CompressionLevel Optimal

# --- 6. ОТПРАВКА И ЗАПУСК ---
Write-Host "📤 Uploading..." -ForegroundColor Yellow
ssh "$ServerUser@$ServerIP" "powershell -c New-Item -ItemType Directory -Force -Path C:/webapp_temp"
scp $ZipFile "${ServerUser}@${ServerIP}:C:/webapp_temp/deploy_package.zip"

Write-Host "🔄 Remote Update..." -ForegroundColor Cyan
$RemoteBlock = {
    param($ExeName)
    $ErrorActionPreference = 'Stop'
    
    Write-Host "   [Remote] Stopping..."
    Stop-Service "SimpleSocialApp" -Force -ErrorAction SilentlyContinue
    Start-Sleep 2

    Write-Host "   [Remote] Unzipping..."
    if (Test-Path "C:/webapp_temp/extracted") { Remove-Item "C:/webapp_temp/extracted" -Recurse -Force }
    Expand-Archive -Path "C:/webapp_temp/deploy_package.zip" -DestinationPath "C:/webapp_temp/extracted" -Force

    Write-Host "   [Remote] Deploying..."
    # Чистим целевые
    if (Test-Path "C:/webapp/api") { Remove-Item "C:/webapp/api/*" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path "C:/webapp/wwwroot") { Remove-Item "C:/webapp/wwwroot/*" -Recurse -Force -ErrorAction SilentlyContinue }
    
    # Создаем если нет
    if (-not (Test-Path "C:/webapp/api")) { New-Item -ItemType Directory -Force -Path "C:/webapp/api" | Out-Null }
    if (-not (Test-Path "C:/webapp/wwwroot")) { New-Item -ItemType Directory -Force -Path "C:/webapp/wwwroot" | Out-Null }

    # Копируем из распакованного
    Copy-Item "C:/webapp_temp/extracted/api/*" "C:/webapp/api" -Recurse -Force
    Copy-Item "C:/webapp_temp/extracted/wwwroot/*" "C:/webapp/wwwroot" -Recurse -Force

    Write-Host "   [Remote] Migrations..."
    Set-Location "C:/webapp/api"
    & ".\efbundle.exe" --connection "Server=localhost;Database=SimpleSocialNetwork;Trusted_Connection=True;TrustServerCertificate=True;"

    Write-Host "   [Remote] Service Config..."
    $nssm = (Get-Command nssm).Source
    $AppExePath = "C:\webapp\api\$ExeName"
    
    # NSSM
    & $nssm install SimpleSocialApp "$AppExePath" 2>$null
    & $nssm set SimpleSocialApp AppDirectory "C:\webapp\api"
    & $nssm set SimpleSocialApp AppParameters "--urls http://0.0.0.0:8080"
    & $nssm set SimpleSocialApp AppStdout "C:\webapp\logs\service-stdout.log"
    & $nssm set SimpleSocialApp AppStderr "C:\webapp\logs\service-stderr.log"
    & $nssm set SimpleSocialApp Start SERVICE_AUTO_START
    & $nssm set SimpleSocialApp AppRotateFiles 1
    & $nssm set SimpleSocialApp AppRotateOnline 1

    Write-Host "   [Remote] Starting..."
    Start-Service "SimpleSocialApp"
    
    Remove-Item "C:/webapp_temp" -Recurse -Force
}

$ScriptBody = $RemoteBlock.ToString()
ssh "$ServerUser@$ServerIP" "powershell -Command `"$ScriptBody`" -args '$ApiExeName'"

# Убираем мусор за собой локально
Remove-Item $ZipFile -Force
Remove-Item $StagingDir -Recurse -Force

Write-Host "✅ DEPLOYMENT COMPLETE!" -ForegroundColor Green