# ==============================================================================
# startup_webapp_windows.ps1
# FINAL: VS v18 + SQL 2022 + OpenSSH + Google Auth + GitHub Desktop (Choco)
# ==============================================================================

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ==============================================================================
# 🛑 CHECK: IF STAGE 1 DONE -> EXIT
# ==============================================================================
$MarkerFile = "C:\webapp\stage1_complete.txt"
if (Test-Path $MarkerFile) {
    Write-Host "Stage 1 marker found. Startup script finished."
    exit 0
}

# ==============================================================================
# 🚀 STAGE 1 START
# ==============================================================================

function Get-Meta {
    param([string]$Path)
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers['Metadata-Flavor'] = 'Google'
        return $wc.DownloadString("http://metadata.google.internal/computeMetadata/v1/$Path")
    } catch { return $null }
}

$LogsRoot = "C:\webapp\logs"
New-Item -Force -ItemType Directory $LogsRoot | Out-Null
$GlobalLog = Join-Path $LogsRoot "startup.log"

function Write-Log($msg) { 
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Tee-Object -FilePath $GlobalLog -Append 
}

# --- Config ---
$Domain = Get-Meta "instance/attributes/domain"; if (-not $Domain) { $Domain = "localhost" }
$Email  = Get-Meta "instance/attributes/email";  if (-not $Email)  { $Email  = "admin@example.com" }
$InstallersDir = "C:\Installers"
$SshUser = "mykola"

New-Item -Force -ItemType Directory "C:\webapp\wwwroot", $InstallersDir | Out-Null
Write-Log "STAGE 1 START. Domain=$Domain"

# --- Fix Long Paths ---
try { New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -PropertyType DWord -Value 1 -Force | Out-Null } catch {}

# ============================================
# 0. SETUP GOOGLE AUTH
# ============================================
try {
    Write-Log "Setting up Google Cloud Credentials..."
    
    # 1. Read key from Metadata
    $KeyContent = Get-Meta "instance/attributes/google-key-json"
    $KeyPath = "C:\webapp\google_key.json"
    
    if (-not [string]::IsNullOrWhiteSpace($KeyContent)) {
        # 2. Save Key File
        Set-Content -Path $KeyPath -Value $KeyContent -Encoding UTF8 -Force
        Write-Log "Google Key saved to $KeyPath"

        # 3. Set System Environment Variable (Persists after reboot for ALL users including mykola)
        [Environment]::SetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", $KeyPath, "Machine")
        Write-Log "Environment variable GOOGLE_APPLICATION_CREDENTIALS set."

        # 4. Authenticate gcloud (SYSTEM context)
        & gcloud auth activate-service-account --key-file=$KeyPath --quiet
        Write-Log "gcloud authenticated via service account."
    } else {
        Write-Log "WARN: No google-key-json found in metadata."
    }
} catch { Write-Log "ERROR Google Auth Setup: $_" }

# ============================================
# 1. OpenSSH Installation & Config
# ============================================
try {
    Write-Log "Installing OpenSSH Server..."
    $capName = 'OpenSSH.Server~~~~0.0.1.0'
    $cap = Get-WindowsCapability -Online -Name $capName -ErrorAction SilentlyContinue
    if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $capName -ErrorAction Stop | Out-Null }

    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd
    netsh advfirewall firewall add rule name="OpenSSH Server (sshd)" dir=in action=allow protocol=TCP localport=22 | Out-Null

    Write-Log "Configuring SSH Keys for user $SshUser..."
    $UserDir = "C:\Users\$SshUser"
    $SshDir  = "$UserDir\.ssh"
    $AuthKey = "$SshDir\authorized_keys"

    if (-not (Test-Path $SshDir)) { New-Item -ItemType Directory -Force -Path $SshDir | Out-Null }

    $UserPublicKey = Get-Meta "instance/attributes/ssh-public-key"
    if (-not [string]::IsNullOrWhiteSpace($UserPublicKey)) {
        $UserPublicKey = $UserPublicKey.Trim()
        Set-Content -Path $AuthKey -Value $UserPublicKey -Encoding Ascii -Force
        
        $acl = Get-Acl $SshDir
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }
        
        $rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        $type   = [System.Security.AccessControl.AccessControlType]::Allow
        
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($SshUser, $rights, $type)))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", $rights, $type)))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", $rights, $type)))
        
        Set-Acl -Path $SshDir -AclObject $acl
        Set-Acl -Path $AuthKey -AclObject $acl
    }

    $ConfigPath = "C:\ProgramData\ssh\sshd_config"
    if (Test-Path $ConfigPath) {
        $conf = Get-Content $ConfigPath -Raw
        $conf = $conf -replace 'Match Group administrators', '# Match Group administrators'
        $conf = $conf -replace 'AuthorizedKeysFile __PROGRAMDATA__', '# AuthorizedKeysFile __PROGRAMDATA__'
        $conf | Set-Content $ConfigPath -Encoding UTF8
        Restart-Service sshd -Force
    }
} catch { Write-Log "WARN SSH Setup: $_" }

# ============================================
# 3. Chocolatey & Tools (Inc. GitHub Desktop)
# ============================================
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

try {
    Write-Log "Installing packages via Chocolatey..."
    # Добавлен github-desktop. 
    # Пакет github-desktop использует MSI установщик, который корректно ставится в Program Files 
    # при запуске от SYSTEM, что делает его доступным для mykola.
    $packages = @(
        "git",
        "nssm",
        "caddy",
        "vscode",
        "sql-server-management-studio",
        "nodejs-lts",
        "googlechrome",
        "github-desktop" 
    )
    
    choco install $packages -y --no-progress --limit-output
} catch { Write-Log "ERROR Choco packages: $_" }

# ============================================
# 4. Visual Studio 2026 (v18 Stable Channel)
# ============================================
try {
    Write-Log "Downloading Visual Studio 2026 (v18)..."
    $vsUrl  = "https://aka.ms/vs/18/Stable/vs_community.exe"
    $vsPath = Join-Path $InstallersDir "vs_Community_2026.exe"
    (New-Object System.Net.WebClient).DownloadFile($vsUrl, $vsPath)

    Write-Log "Installing Visual Studio..."
    $vsArgs = "--quiet --wait --norestart --nocache `
    --add Microsoft.VisualStudio.Workload.NetWeb `
    --add Microsoft.VisualStudio.Workload.ManagedDesktop `
    --add Microsoft.VisualStudio.Workload.Azure `
    --includeRecommended --includeOptional"

    $p = Start-Process -FilePath $vsPath -ArgumentList $vsArgs -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Log "WARN: VS Installer exit code: $($p.ExitCode)" }
} catch { Write-Log "ERROR VS Install: $_" }

# ============================================
# 5. PREPARE STAGE 2 (SQL SERVER)
# ============================================
try {
    Write-Log "Preparing Stage 2 (SQL Server) Task..."
    $Stage2Path = Join-Path $InstallersDir "install_sql_stage2.ps1"
    
    $Stage2Script = @'
$ErrorActionPreference = 'Stop'
$LogFile = 'C:\webapp\logs\stage2_sql.log'
function Log($m) { "[{0}] {1}" -f (Get-Date -Format s), $m | Add-Content $LogFile }
Log "STAGE 2 START: Waiting for network..."
Start-Sleep -Seconds 30
try {
    Log "Installing SQL Server 2022..."
    $p = "/ACTION=Install /IACCEPTSQLSERVERLICENSETERMS=True /SECURITYMODE=SQL /SAPWD=`"P@ssw0rd!ChangeMe`" /TCPENABLED=1 /SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`""
    choco install sql-server-2022 -y --no-progress --execution-timeout=3600 --params="'$p'" | Out-String | Add-Content $LogFile
    Log "SQL Server installed."
} catch { Log "ERROR installing SQL: $_" }
Unregister-ScheduledTask -TaskName "InstallSQL" -Confirm:$false -ErrorAction SilentlyContinue
Log "STAGE 2 COMPLETE. Rebooting."
Start-Sleep -Seconds 5
Restart-Computer -Force
'@
    $Stage2Script | Set-Content -Path $Stage2Path -Encoding UTF8

    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$Stage2Path`""
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "InstallSQL" -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
} catch { Write-Log "ERROR Stage 2 Setup: $_" }

# ============================================
# 7. Shortcuts (For ALL Users)
# ============================================
function New-Shortcut {
    param([string]$Target, [string]$Name)
    try {
        if (-not (Test-Path $Target)) { return }
        # Используем Public Desktop, чтобы ярлыки появились у mykola
        $desktop = Join-Path $Env:Public "Desktop"
        $shell   = New-Object -ComObject WScript.Shell
        $lnk     = $shell.CreateShortcut((Join-Path $desktop ($Name + ".lnk")))
        $lnk.TargetPath = $Target
        $lnk.Save()
    } catch {}
}

try {
    Write-Log "Creating Shortcuts..."
    if ($e = (Get-Command "Code.exe" -ErrorAction SilentlyContinue).Source) { New-Shortcut -Target $e -Name "Visual Studio Code" }
    
    # SQL Management Studio
    $paths64 = Resolve-Path "C:\Program Files\Microsoft SQL Server Management Studio*\Release\Common7\IDE\Ssms.exe" -ErrorAction SilentlyContinue
    $paths86 = Resolve-Path "C:\Program Files (x86)\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe" -ErrorAction SilentlyContinue
    $allSSMS = @($paths64, $paths86) | Where-Object { $_ } 
    if ($allSSMS.Count -gt 0) {
        $latestSSMS = $allSSMS | Sort-Object Path | Select-Object -Last 1
        New-Shortcut -Target $latestSSMS.Path -Name "SQL Server Management Studio"
    }

    # Visual Studio
    $vsRoots = Resolve-Path "$env:ProgramFiles\Microsoft Visual Studio\*\*\Common7\IDE\devenv.exe" -ErrorAction SilentlyContinue
    if ($vsRoots) {
        $latestVS = $vsRoots | Sort-Object Path | Select-Object -Last 1
        New-Shortcut -Target $latestVS.Path -Name "Visual Studio"
    }

    # GitHub Desktop
    # При установке через choco как SYSTEM он падает в Program Files
    $ghPath = Resolve-Path "C:\Program Files\GitHub Desktop\GitHubDesktop.exe" -ErrorAction SilentlyContinue
    if ($ghPath) {
        New-Shortcut -Target $ghPath.Path -Name "GitHub Desktop"
    }
} catch { Write-Log "WARN Shortcuts: $_" }

# ============================================
# 8. Caddy Setup
# ============================================
try {
    Write-Log "Configuring Caddy..."
    $Caddyfile = "C:\webapp\Caddyfile"
    $CaddyContent = @"
{ email $Email }
http://$Domain { redir https://$Domain{uri} }
$Domain {
  root * "C:\webapp\wwwroot"
  file_server
}
"@
    $CaddyContent | Set-Content -Path $Caddyfile -Encoding UTF8
    
    $caddyExe = (Get-Command caddy.exe).Source
    Stop-Service caddy -ErrorAction SilentlyContinue
    & nssm install caddy $caddyExe 'run' '--config' $Caddyfile '--adapter' 'caddyfile' 2>$null
    & nssm set caddy AppDirectory "C:\webapp" 2>$null
    & nssm set caddy Start SERVICE_AUTO_START 2>$null
    netsh advfirewall firewall add rule name="Caddy Web Server" dir=in action=allow protocol=TCP localport=80,443 2>$null | Out-Null
    Start-Service caddy
} catch { Write-Log "WARN Caddy: $_" }

# ============================================
# 🏁 FINALIZE STAGE 1
# ============================================
Write-Log "STAGE 1 DONE. Creating marker file and rebooting for Stage 2..."
New-Item -Path $MarkerFile -ItemType File -Force | Out-Null
Start-Sleep -Seconds 5
Restart-Computer -Force