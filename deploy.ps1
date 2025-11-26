# === Параметры подключения ===
$VmIp = ""
$VmUser = ""
$VmPassword = ""

# === Доверяемся целевой VM для WinRM (локальная машина) ===
try {
    $trustedPath = 'WSMan:\localhost\Client\TrustedHosts'

    # текущие значения (может быть пусто)
    $existing = (Get-Item $trustedPath -ErrorAction SilentlyContinue).Value

    if ([string]::IsNullOrEmpty($existing)) {
        $new = $VmIp
    }
    elseif ($existing -notlike "*$VmIp*") {
        $new = "$existing,$VmIp"
    }
    else {
        $new = $existing
    }

    Set-Item $trustedPath -Value $new -Force
    Write-Host "TrustedHosts set to: $new"
}
catch {
    Write-Warning "Не удалось обновить TrustedHosts (запусти PowerShell от администратора): $_"
}

# === Пути к проектам ===
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$AngularProjectPath = Join-Path $repoRoot "SimpleSocialNetwork.Angular"
$ApiProjectPath = Join-Path $repoRoot "SimpleSocialNetwork.Api"


# === 1. Сборка Angular production ===
Write-Host "Building Angular production..."
Push-Location $AngularProjectPath
npm install
ng build --configuration=production
Pop-Location

# === 2. Сборка .NET API ===
Write-Host "Publishing .NET API..."
dotnet publish $ApiProjectPath -c Release

# Определяем путь к publish-папке (ищем net* в bin/Release)
$publishFolder = Get-ChildItem -Path "$ApiProjectPath\bin\Release" -Directory | Where-Object { $_.Name -like "net*" } | Sort-Object Name -Descending | Select-Object -First 1
if ($null -eq $publishFolder) { throw "Не найдена папка bin/Release/net*/ в $ApiProjectPath" }
$publishPath = Join-Path $publishFolder.FullName "publish"
if (-not (Test-Path $publishPath)) { throw "Не найдена publish-папка: $publishPath" }

# === 3. Копирование файлов на VM ===
$remoteRoot = "\\$VmIp\c$"

$secpass = ConvertTo-SecureString $VmPassword -AsPlainText -Force
$cred    = New-Object PSCredential($VmUser, $secpass)

# Монтируем админский share как временный диск
$driveName = "WEBDEPLOY"

Write-Host "Creating temporary PSDrive $driveName: -> $remoteRoot ..."
New-PSDrive -Name $driveName -PSProvider FileSystem -Root $remoteRoot -Credential $cred -Scope Script -ErrorAction Stop | Out-Null

try {
    $remoteAngular = "$driveName`:\webapp\wwwroot"
    $remoteApi     = "$driveName`:\webapp\api"

    # на всякий случай создадим директории
    New-Item -ItemType Directory -Force -Path $remoteAngular, $remoteApi | Out-Null

    Write-Host "Copying Angular dist to VM..."
    Copy-Item "$AngularProjectPath\dist\SimpleSocialNetwork.Angular\*" $remoteAngular -Recurse -Force

    Write-Host "Copying .NET API to VM..."
    Copy-Item "$publishPath\*" $remoteApi -Recurse -Force
}
finally {
    Write-Host "Removing PSDrive $driveName ..."
    Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
}

# === 4. Перезапуск служб на VM ===
Write-Host "Restarting API and Caddy services on VM..."
Invoke-Command -ComputerName $VmIp -Credential $cred -ScriptBlock {
    Restart-Service -Name "caddy" -ErrorAction SilentlyContinue
    # Если есть отдельный сервис для .NET API, раскомментируйте строку ниже и укажите имя сервиса:
    # Restart-Service -Name "kestrel-simplesocialnetwork" -ErrorAction SilentlyContinue
}

Write-Host "Deployment complete! Проверьте https://simplesocialnetwork.mykolamartyniuk1992.dev"