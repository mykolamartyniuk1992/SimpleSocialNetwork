# ==============================================================================
# deploy.ps1
# Build -> Flexible Angular Config -> Stage -> Deploy
# ==============================================================================

param(
    [string]$ProjectId,
    [switch]$ResetDatabase  # по умолчанию $false, нужно вызвать -ResetDatabase
)

$ErrorActionPreference = 'Stop'

# --- НАСТРОЙКИ СЕРВЕРА ---
$ServerIP   = "34.172.236.103"
$ServerUser = "mykola"
$DomainName = "simplesocialnetwork.mykolamartyniuk1992.dev"
$AdminEmail = "mykola.martyniuk.1992@gmail.com"

# --- НАСТРОЙКИ ПРИЛОЖЕНИЯ ---
$ApiUrl = ""   # если нужно — можешь задать внешний API-URL

# --- ПУТИ ---
$RepoRoot   = Get-Location
$ApiFolder  = "SimpleSocialNetwork.Api"
$WebFolder  = "SimpleSocialNetwork.Angular"
$ApiExeName = "SimpleSocialNetwork.exe"

$StagingDir         = Join-Path $RepoRoot ".deploy_staging"
$ZipFile            = Join-Path $RepoRoot "deploy_package.zip"
$RemoteScriptFile   = Join-Path $StagingDir "remote_exec.ps1"
$RemoteLauncherFile = Join-Path $StagingDir "remote_launcher.ps1"

# путь к удалённому логу деплоя
$RemoteDeployLogPath = "C:\webapp\logs\remote_deploy.log"

# --- SSH KEYPAIR -------------------------------------------------------------

function Ensure-SshKeyPair {
    param(
        [string]$KeyBasePath
    )

    if ([string]::IsNullOrWhiteSpace($KeyBasePath)) {
        $KeyBasePath = Join-Path $PSScriptRoot "mykola_ssh"
    }

    $privateKeyPath = $KeyBasePath
    $publicKeyPath  = "${KeyBasePath}.pub"

    if ((Test-Path $privateKeyPath) -and (Test-Path $publicKeyPath)) {
        Write-Host "Using existing SSH key pair:"
        Write-Host "  Private: $privateKeyPath"
        Write-Host "  Public : $publicKeyPath"
        return @{
            Private = $privateKeyPath
            Public  = $publicKeyPath
        }
    }

    Write-Host "SSH key pair not found. Generating new key pair at: $KeyBasePath"
    $sshKeygen = "ssh-keygen"
    $args = @("-t", "ed25519", "-f", $privateKeyPath, "-N", "")
    & $sshKeygen @args | Out-Null

    if (-not (Test-Path $publicKeyPath)) {
        throw "Failed to generate SSH public key at $publicKeyPath"
    }

    Write-Host "✔ SSH keys generated:"
    Write-Host "  Private: $privateKeyPath"
    Write-Host "  Public : $publicKeyPath"

    return @{
        Private = $privateKeyPath
        Public  = $publicKeyPath
    }
}

$sshKeyInfo        = Ensure-SshKeyPair -KeyBasePath (Join-Path $PSScriptRoot "mykola_ssh")
$SshPrivateKeyPath = $sshKeyInfo.Private

$knownHosts = Join-Path $env:USERPROFILE ".ssh\known_hosts"
if (-not (Test-Path $knownHosts)) {
    New-Item -ItemType File -Path $knownHosts -Force | Out-Null
}

function Invoke-Ssh {
    param(
        [Parameter(Mandatory)] [string]$Command
    )

    $sshArgs = @(
        "-i", $SshPrivateKeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=$knownHosts",
        "-o", "BatchMode=yes",
        "$ServerUser@$ServerIP",
        $Command
    )

    & ssh @sshArgs
}

function Invoke-Scp {
    param(
        [Parameter(Mandatory)] [string]$LocalPath,
        [Parameter(Mandatory)] [string]$RemotePath
    )

    $remoteSpec = "{0}@{1}:{2}" -f $ServerUser, $ServerIP, $RemotePath

    $scpArgs = @(
        "-i", $SshPrivateKeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=$knownHosts",
        $LocalPath,
        $remoteSpec
    )

    & scp @scpArgs
}

# --- Watch-RemoteLog --------------------------------------------------------

function Watch-RemoteLog {
    param(
        [Parameter(Mandatory)] [string]$RemoteLogPath,
        [Parameter(Mandatory)] [string]$DoneMarker,
        [string]$ErrorMarker = "REMOTE_DEPLOY_ERROR",
        [int]$IntervalSeconds = 10
    )

    $lastLineCount = 0
    $hadConnection = $false

    while ($true) {
        $timestamp = (Get-Date).ToString("HH:mm:ss")

        $remoteCmd = "powershell -NoProfile -Command `"if (Test-Path '$RemoteLogPath') { Get-Content '$RemoteLogPath' -Raw } else { '' }`""
        $output = Invoke-Ssh -Command $remoteCmd
        $exit   = $LASTEXITCODE

        if ($exit -ne 0) {
            Write-Host "[$timestamp] SSH not ready for $RemoteLogPath yet. Retrying in $IntervalSeconds seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }

        if (-not $hadConnection) {
            Write-Host "[$timestamp] SSH reconnected successfully for remote log." -ForegroundColor Green
            $hadConnection = $true
        }

        if ([string]::IsNullOrEmpty($output)) {
            Write-Host "[$timestamp] $RemoteLogPath not created yet. Waiting..." -ForegroundColor DarkYellow
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }

        # Разбиваем лог на строки и выводим только новые
        $lines = $output -split "`r?`n"

        if ($lines.Count -gt $lastLineCount) {
            for ($i = $lastLineCount; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Host $line
                }
            }
            $lastLineCount = $lines.Count
        }
        else {
            Write-Host "[$timestamp] SSH OK, no new log lines yet. Next check in $IntervalSeconds sec..." -ForegroundColor DarkGray
        }

        # Проверяем маркеры по всему тексту
        if ($output -like "*$ErrorMarker*") {
            throw "Remote deploy failed. See $RemoteLogPath on server."
        }

        if ($output -like "*$DoneMarker*") {
            Write-Host "[$timestamp] Done marker '$DoneMarker' found in $RemoteLogPath." -ForegroundColor Green
            break
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}

if ($ResetDatabase) {
    Write-Host ""
    Write-Host "⚠️  WARNING: FULL DATABASE RESET ENABLED!" -ForegroundColor Yellow
    Write-Host "    Target DB: SimpleSocialNetwork on remote SQL Server (localhost)"
    Write-Host "    The database will be DROPPED and recreated on the remote server."
    Write-Host ""
    Write-Host "Press ANY key within 10 seconds to CANCEL database wipe..." -ForegroundColor Yellow

    $cancel = $false
    $seconds = 10

    for ($i = $seconds; $i -gt 0; $i--) {
        # если нажали любую клавишу — отменяем вайп
        if ([Console]::KeyAvailable) {
            [void][Console]::ReadKey($true)  # забираем нажатую клавишу из буфера
            $cancel = $true
            break
        }

        Write-Host ("`r  Wiping DB in {0} sec..." -f $i) -NoNewline
        Start-Sleep -Seconds 1
    }

    Write-Host ""  # перенос строки после `-NoNewline`

    if ($cancel) {
        Write-Host "⏹ Database wipe CANCELLED by user. Exiting script." -ForegroundColor Cyan
        $ResetDatabase = $false
        exit
    }
    else {
        Write-Host "✅ Proceeding with database RESET on remote server..." -ForegroundColor Red
    }
}

Write-Host "🚀 STARTING DEPLOYMENT to $ServerIP..." -ForegroundColor Green

# --- 1. ОЧИСТКА --------------------------------------------------------------
if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
if (Test-Path $ZipFile)    { Remove-Item $ZipFile -Force }

New-Item -ItemType Directory -Path "$StagingDir/api"      | Out-Null
New-Item -ItemType Directory -Path "$StagingDir/wwwroot"  | Out-Null

# --- 2. СБОРКА API -----------------------------------------------------------
Write-Host "🔨 Building .NET API..." -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot $ApiFolder)

dotnet publish -c Release -r win-x64 --self-contained false

$PublishSource = Resolve-Path "bin\Release\*\win-x64\publish" | Select-Object -Last 1
if (-not $PublishSource -or -not (Test-Path $PublishSource)) {
    Pop-Location
    throw "API publish failed!"
}

dotnet ef migrations bundle -o "$($PublishSource.Path)\efbundle.exe" --force --self-contained -r win-x64

Copy-Item "$($PublishSource.Path)\*" "$StagingDir\api" -Recurse -Force
Pop-Location

# --- 3. КОНФИГ API -----------------------------------------------------------
Write-Host "⚙️ Configuring Staging API..." -ForegroundColor Yellow
$ApiStagePath = "$StagingDir/api"

Get-ChildItem "$ApiStagePath/appsettings.*.json" |
    Where-Object { $_.Name -ne "appsettings.json" } |
    Remove-Item -Force

$AppSettingsFile = "$ApiStagePath/appsettings.json"
$json = Get-Content $AppSettingsFile -Raw | ConvertFrom-Json

$json.ConnectionStrings.Default = "Server=localhost;Database=SimpleSocialNetwork;Trusted_Connection=True;TrustServerCertificate=True;"

$corsOrigins = @("https://$DomainName", "http://localhost:8080", "http://127.0.0.1:8080")
if ($ApiUrl -ne "") { $corsOrigins += $ApiUrl }
$json.AllowedOrigins = $corsOrigins

$json.Email.ProjectId = $ProjectId
Write-Host "   -> Set Email.ProjectId to $ProjectId" -ForegroundColor Green

if ($json.Kestrel) { $json.PSObject.Properties.Remove('Kestrel') }

$json | ConvertTo-Json -Depth 10 | Set-Content $AppSettingsFile -Encoding UTF8

New-Item -ItemType Directory -Path "$ApiStagePath/wwwroot" -Force | Out-Null

# --- 4. СБОРКА ANGULAR -------------------------------------------------------
Write-Host "🎨 Building Angular..." -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot $WebFolder)

Write-Host "   -> Configuring API URL for Production..." -ForegroundColor DarkGray
$TargetApiUrl = if ($ApiUrl) { $ApiUrl } else { "https://$DomainName" }

$EnvFiles = Get-ChildItem -Path "src/environments" -Filter "*.ts" -Recurse
foreach ($file in $EnvFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "localhost:5003") {
        $newContent = $content -replace "http://localhost:5003", $TargetApiUrl
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        Write-Host "      Patched $($file.Name) -> API: $TargetApiUrl" -ForegroundColor Green
    }
}

npx ng build --configuration=production

Write-Host "   -> Reverting environment files..." -ForegroundColor DarkGray
git checkout src/environments/*.ts 2>$null

$DistRoot = Join-Path (Get-Location) "dist"
if     (Test-Path "$DistRoot/$WebFolder/browser") { $DistSource = "$DistRoot/$WebFolder/browser" }
elseif (Test-Path "$DistRoot/browser")            { $DistSource = "$DistRoot/browser" }
else                                              { $DistSource = $DistRoot }

Copy-Item "$DistSource\*" "$StagingDir\wwwroot" -Recurse -Force
Pop-Location

# --- 5. ZIP ------------------------------------------------------------------
Write-Host "📦 Zipping..." -ForegroundColor Yellow
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipFile -CompressionLevel Optimal

# --- 6. УДАЛЁННЫЙ СКРИПТ (remote_exec.ps1) ----------------------------------

$RemoteBlock = {
    $ErrorActionPreference = 'Stop'

    $ServiceName    = "SimpleSocialApp"
    $CaddyService   = "caddy"
    $WebRoot        = "C:\webapp\wwwroot"
    $ApiRoot        = "C:\webapp\api"
    $TempRoot       = "C:\webapp_temp"
    $CaddyfilePath  = "C:\webapp\Caddyfile"
    $LogPath        = $RemoteLogPath

    function Write-Log {
        param([string]$Message)
        $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
        $dir  = Split-Path $LogPath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $line | Tee-Object -FilePath $LogPath -Append
    }

    Write-Log "REMOTE_DEPLOY_START"

    try {
        Write-Log "   [Remote] Ensuring base directories..."
        foreach ($dir in @("C:\webapp", "C:\webapp\logs", $TempRoot)) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir | Out-Null
            }
        }

        Write-Log "   [Remote] Ensuring Firewall Rules..."
        netsh advfirewall firewall add rule name="Caddy Web Server" dir=in action=allow protocol=TCP localport=80,443 2>$null | Out-Null

        Write-Log "   [Remote] Stopping API service (if exists)..."
        Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue

        # --- Unzip package ---------------------------------------------------
        Write-Log "   [Remote] Unzipping..."
        $extractPath = Join-Path $TempRoot "extracted"
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
        Expand-Archive -Path (Join-Path $TempRoot "deploy_package.zip") -DestinationPath $extractPath -Force

        # --- Deploy files ----------------------------------------------------
        Write-Log "   [Remote] Deploying files to $ApiRoot and $WebRoot..."

        if (Test-Path $ApiRoot) {
            # Robustly preserve uploads/profiles directory and its contents
            $profilesDir = Join-Path $ApiRoot "uploads\profiles"
            $preserveRoot = Join-Path $TempRoot "preserve_profiles_temp"
            if (Test-Path $profilesDir) {
                if (-not (Test-Path $preserveRoot)) {
                    New-Item -ItemType Directory -Path $preserveRoot | Out-Null
                }
                Move-Item $profilesDir (Join-Path $preserveRoot "profiles") -Force
            }
            Remove-Item "$ApiRoot\*" -Recurse -Force -ErrorAction SilentlyContinue
            $uploadsDir = Join-Path $ApiRoot "uploads"
            if (Test-Path (Join-Path $preserveRoot "profiles")) {
                if (-not (Test-Path $uploadsDir)) {
                    New-Item -ItemType Directory -Path $uploadsDir | Out-Null
                }
                Move-Item (Join-Path $preserveRoot "profiles") (Join-Path $uploadsDir "profiles") -Force
                Remove-Item $preserveRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        } else {
            New-Item -ItemType Directory -Path $ApiRoot | Out-Null
        }

        if (Test-Path $WebRoot) {
            Remove-Item "$WebRoot\*" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            New-Item -ItemType Directory -Path $WebRoot | Out-Null
        }

        Copy-Item "$extractPath\api\*"     $ApiRoot -Recurse -Force
        Copy-Item "$extractPath\wwwroot\*" $WebRoot -Recurse -Force

        # --- Caddy config ----------------------------------------------------
        Write-Log "   [Remote] Updating Caddy configuration..."
        $caddyConfig = @'
{
    email {{ADMIN_EMAIL}}
}

{{DOMAIN_NAME}} {
    root * "C:\webapp\wwwroot"
    encode gzip

    handle /api/* {
        reverse_proxy localhost:8080
    }

    handle /hubs/* {
        reverse_proxy localhost:8080
    }

    handle {
        try_files {path} {path}/ /index.html
        file_server
    }
}
'@

        $caddyConfig = $caddyConfig.Replace("{{ADMIN_EMAIL}}", $AdminEmail)
        $caddyConfig = $caddyConfig.Replace("{{DOMAIN_NAME}}", $DomainName)

        $rewriteNeeded = $true
        if (Test-Path $CaddyfilePath) {
            $existing = Get-Content $CaddyfilePath -Raw
            if ($existing -eq $caddyConfig) {
                $rewriteNeeded = $false
            }
        }

        if ($rewriteNeeded) {
            $caddyConfig | Set-Content -Path $CaddyfilePath -Encoding UTF8
            Write-Log "   [Remote] Caddyfile written/updated."
        } else {
            Write-Log "   [Remote] Caddyfile already up-to-date. TLS data will be reused."
        }

        # --- nssm detection --------------------------------------------------
        $nssmPath = "C:\ProgramData\chocolatey\bin\nssm.exe"
        if (-not (Test-Path $nssmPath)) {
            Write-Log "   [Remote] WARNING: nssm.exe not found at $nssmPath. Starting processes without services."

            $caddyCmd = Get-Command caddy -ErrorAction SilentlyContinue
            if ($caddyCmd) {
                $caddyExe = $caddyCmd.Source
                Start-Process $caddyExe -ArgumentList @("run","--config",$CaddyfilePath,"--adapter","caddyfile") -WindowStyle Hidden
                Write-Log "   [Remote] Caddy started as background process."
            } else {
                Write-Log "   [Remote] ERROR: caddy not found, cannot start web server."
            }

            $appExePath = Join-Path $ApiRoot $ExeName
            if (Test-Path $appExePath) {
                Start-Process $appExePath -ArgumentList "--urls http://0.0.0.0:8080" -WorkingDirectory $ApiRoot -WindowStyle Hidden
                Write-Log "   [Remote] API started as background process."
            } else {
                Write-Log "   [Remote] ERROR: API exe not found at $appExePath"
            }

            Write-Log "REMOTE_DEPLOY_DONE"
            return
        }

        # --- Ensure Caddy service -------------------------------------------
        Write-Log "   [Remote] Ensuring Caddy service..."
        $caddyCmd = Get-Command caddy -ErrorAction Stop
        $caddyExe = $caddyCmd.Source

        $caddySvc = Get-Service $CaddyService -ErrorAction SilentlyContinue
        if (-not $caddySvc) {
            Write-Log "   [Remote] Caddy service not found, installing via nssm..."
            & $nssmPath install $CaddyService $caddyExe "run" "--config" $CaddyfilePath "--adapter" "caddyfile" 2>$null
        }

        # перечитаем состояние после возможной установки
        $caddySvc = Get-Service $CaddyService -ErrorAction SilentlyContinue

        if ($caddySvc -and $caddySvc.Status -ne 'Running') {
            Write-Log "   [Remote] Caddy service is '$($caddySvc.Status)'. Starting..."
            & $nssmPath start $CaddyService 2>$null
        }
        else {
            Write-Log "   [Remote] Caddy service already running, restarting..."
            & $nssmPath restart $CaddyService 2>$null
        }

        $caddySvc = Get-Service $CaddyService -ErrorAction SilentlyContinue
        Write-Log "   [Remote] Caddy service status after ensure: $($caddySvc.Status)"

        if ($ResetDatabase) {
            Write-Log "   [Remote] ResetDatabase flag = TRUE. Dropping and recreating database 'SimpleSocialNetwork'..."
            try {
                $tsql = @"
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'SimpleSocialNetwork')
BEGIN
    ALTER DATABASE [SimpleSocialNetwork] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [SimpleSocialNetwork];
END;
CREATE DATABASE [SimpleSocialNetwork];
"@

                $possibleSqlcmd = @(
                    "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe",
                    "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe",
                    "sqlcmd.exe"
                )

                $sqlcmd = $possibleSqlcmd | Where-Object { Test-Path $_ } | Select-Object -First 1
                if (-not $sqlcmd) { throw "sqlcmd.exe not found" }

                & $sqlcmd -E -S "localhost" -d "master" -Q $tsql
                Write-Log "   [Remote] Database 'SimpleSocialNetwork' dropped and recreated."
            }
            catch {
                Write-Log "   [Remote] ERROR while resetting database: $_"
                throw
            }
        }

        # --- DB migrations ---------------------------------------------------
        Write-Log "   [Remote] Running EF migrations..."
        Set-Location $ApiRoot
        & ".\efbundle.exe" --connection "Server=localhost;Database=SimpleSocialNetwork;Trusted_Connection=True;TrustServerCertificate=True;"
        $efCode = $LASTEXITCODE
        if ($efCode -ne 0) {
            throw "efbundle.exe failed with exit code $efCode"
        }

        # --- API Windows service ---------------------------------------------
        Write-Log "   [Remote] Configuring API Windows service..."
        $appExePath = Join-Path $ApiRoot $ExeName

        if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
            & $nssmPath set $ServiceName Application  $appExePath 2>$null
        } else {
            & $nssmPath install $ServiceName $appExePath 2>$null
        }

        & $nssmPath set $ServiceName AppDirectory     $ApiRoot 2>$null
        & $nssmPath set $ServiceName AppParameters   "--urls http://0.0.0.0:8080" 2>$null
        & $nssmPath set $ServiceName AppStdout       "C:\webapp\logs\service-stdout.log" 2>$null
        & $nssmPath set $ServiceName AppStderr       "C:\webapp\logs\service-stderr.log" 2>$null
        & $nssmPath set $ServiceName Start           SERVICE_AUTO_START 2>$null
        & $nssmPath set $ServiceName AppRotateFiles  1 2>$null

        Start-Service $ServiceName

        Write-Log "   [Remote] Cleaning temp..."
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TempRoot "deploy_package.zip") -Force -ErrorAction SilentlyContinue

        Write-Log "REMOTE_DEPLOY_DONE"
    }
    catch {
        Write-Log "REMOTE_DEPLOY_ERROR: $_"
        throw
    }
}

$resetDbLiteral = if ($ResetDatabase) { '$true' } else { '$false' }

$ScriptContent = @"
`$ExeName        = '$ApiExeName'
`$DomainName     = '$DomainName'
`$AdminEmail     = '$AdminEmail'
`$RemoteLogPath  = '$RemoteDeployLogPath'
`$ResetDatabase  = $resetDbLiteral

$($RemoteBlock.ToString())
"@

Set-Content -Path $RemoteScriptFile -Value $ScriptContent -Encoding UTF8

# --- 6a. Лаунчер для Task Scheduler (remote_launcher.ps1) --------------------

$LauncherContent = @"
`$ErrorActionPreference = 'Stop'

`$LogPath = '$RemoteDeployLogPath'
function Write-Log {
    param([string]`$Message)
    `$line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), `$Message
    `$dir  = Split-Path `$LogPath -Parent
    if (-not (Test-Path `$dir)) {
        New-Item -ItemType Directory -Path `$dir -Force | Out-Null
    }
    `$line | Tee-Object -FilePath `$LogPath -Append
}

# Очищаем лог перед новым запуском, чтобы не путаться в старых строках
if (Test-Path `$LogPath) {
    Remove-Item `$LogPath -Force
}

Write-Log 'REMOTE_LAUNCHER_START'

`$taskName   = 'WebApp_Deploy_Once'
`$psExe      = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
`$scriptPath = 'C:\webapp_temp\remote_exec.ps1'

Import-Module ScheduledTasks -ErrorAction SilentlyContinue

try {
    `$action    = New-ScheduledTaskAction  -Execute `$psExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `$scriptPath"
    `$trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(10)
    `$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount

    Register-ScheduledTask -TaskName `$taskName -Action `$action -Trigger `$trigger -Principal `$principal -Force | Out-Null
    Write-Log 'REMOTE_LAUNCHER_TASK_CREATED'

    Start-ScheduledTask -TaskName `$taskName
    Write-Log 'REMOTE_LAUNCHER_TASK_STARTED'
}
catch {
    Write-Log "REMOTE_LAUNCHER_ERROR: `$_"
}

Write-Log 'REMOTE_LAUNCHER_DONE'
"@

Set-Content -Path $RemoteLauncherFile -Value $LauncherContent -Encoding UTF8

# --- 7. ОТПРАВКА И ЗАПУСК ----------------------------------------------------

Write-Host "📤 Uploading Files..." -ForegroundColor Yellow

Invoke-Ssh -Command "powershell -NoProfile -Command `"New-Item -ItemType Directory -Force -Path 'C:\webapp_temp' | Out-Null`""

Invoke-Scp -LocalPath $ZipFile            -RemotePath "C:\webapp_temp\deploy_package.zip"
Invoke-Scp -LocalPath $RemoteScriptFile   -RemotePath "C:\webapp_temp\remote_exec.ps1"
Invoke-Scp -LocalPath $RemoteLauncherFile -RemotePath "C:\webapp_temp\remote_launcher.ps1"

Write-Host "🔄 Executing Remote Launcher (Task Scheduler)..." -ForegroundColor Cyan
Invoke-Ssh -Command "powershell -NoProfile -ExecutionPolicy Bypass -File C:\webapp_temp\remote_launcher.ps1"

Write-Host "📡 Watching remote deploy log..." -ForegroundColor Cyan
Watch-RemoteLog -RemoteLogPath $RemoteDeployLogPath -DoneMarker "REMOTE_DEPLOY_DONE" -ErrorMarker "REMOTE_DEPLOY_ERROR"

Remove-Item $ZipFile    -Force
Remove-Item $StagingDir -Recurse -Force

Write-Host "✅ DEPLOYMENT COMPLETE!" -ForegroundColor Green
