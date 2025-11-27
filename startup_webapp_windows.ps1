# ==============================================================================
# startup_webapp_windows.ps1
# FINAL VERSION: Visual Studio v18 + SQL 2022 + Dynamic Shortcuts
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

# --- Helpers ---
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
try {
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -PropertyType DWord -Value 1 -Force | Out-Null
} catch {}

# ============================================
# 1. OpenSSH Fix (System Profile Temp)
# ============================================
if (-not (Test-Path "C:\Windows\System32\config\systemprofile\AppData\Local\Temp")) {
    Write-Log "Fixing OpenSSH Temp folder permissions..."
    New-Item -Path "C:\Windows\System32\config\systemprofile\AppData\Local\Temp" -ItemType Directory -Force | Out-Null
}

# ============================================
# 2. Install GitHub Desktop
# ============================================
try {
    Write-Log "Installing GitHub Desktop..."
    $ghUrl = "https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi"
    $ghMsi = Join-Path $InstallersDir "GitHubDesktopSetup.msi"
    (New-Object System.Net.WebClient).DownloadFile($ghUrl, $ghMsi)
    
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$ghMsi`" /qn /norestart ALLUSERS=1" -Wait
    Write-Log "GitHub Desktop installed."
} catch { Write-Log "ERROR GitHub Desktop: $_" }

# ============================================
# 3. Chocolatey & Base Tools
# ============================================
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

try {
    Write-Log "Installing base packages..."
    choco install git nssm caddy vscode sql-server-management-studio nodejs-lts googlechrome -y --no-progress --limit-output
    Write-Log "Chocolatey packages installed."
} catch { Write-Log "ERROR Choco packages: $_" }

# ============================================
# 4. Visual Studio 2026 (v18 Stable Channel)
# ============================================
try {
    Write-Log "Downloading Visual Studio 2026 (v18)..."
    
    # Ссылка v18
    $vsUrl  = "https://aka.ms/vs/18/Stable/vs_community.exe"
    $vsPath = Join-Path $InstallersDir "vs_Community_2026.exe"
    (New-Object System.Net.WebClient).DownloadFile($vsUrl, $vsPath)

    Write-Log "Installing Visual Studio... (Using default path)"
    
    # УБРАН --installPath. Пусть установщик сам выберет путь по умолчанию.
    $vsArgs = "--quiet --wait --norestart --nocache `
    --add Microsoft.VisualStudio.Workload.NetWeb `
    --add Microsoft.VisualStudio.Workload.ManagedDesktop `
    --add Microsoft.VisualStudio.Workload.Azure `
    --includeRecommended --includeOptional"

    $p = Start-Process -FilePath $vsPath -ArgumentList $vsArgs -Wait -PassThru
    
    if ($p.ExitCode -ne 0) { Write-Log "WARN: VS Installer exit code: $($p.ExitCode)" }
    else { Write-Log "VS Installed Successfully." }
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
} catch {
    Log "ERROR installing SQL: $_"
}

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
    
    Write-Log "Stage 2 Task Registered."
} catch { Write-Log "ERROR Stage 2 Setup: $_" }

# ============================================
# 6. OpenSSH Config
# ============================================
try {
    Write-Log "Configuring OpenSSH..."
    $SshDir = "C:\Users\$SshUser\.ssh"
    if (-not (Test-Path $SshDir)) { New-Item -ItemType Directory -Force -Path $SshDir | Out-Null }
    
    $UserPublicKey = Get-Meta "instance/attributes/ssh-public-key"
    if (-not [string]::IsNullOrWhiteSpace($UserPublicKey)) {
        $UserPublicKey.Trim() | Set-Content -Path "$SshDir\authorized_keys" -Encoding Ascii -Force
        icacls "$SshDir\authorized_keys" /inheritance:r /grant "$($SshUser):F" /grant SYSTEM:F /grant Administrators:F | Out-Null
    }
    
    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd
    Write-Log "OpenSSH Configured."
} catch { Write-Log "WARN SSH: $_" }

# ============================================
# 7. Shortcuts (Robust Dynamic Search)
# ============================================
function New-Shortcut {
    param([string]$Target, [string]$Name)
    try {
        if (-not (Test-Path $Target)) { return }
        $desktop = Join-Path $Env:Public "Desktop"
        $shell   = New-Object -ComObject WScript.Shell
        $lnk     = $shell.CreateShortcut((Join-Path $desktop ($Name + ".lnk")))
        $lnk.TargetPath = $Target
        $lnk.Save()
    } catch {}
}

try {
    Write-Log "Creating Shortcuts..."
    # VS Code
    if ($e = (Get-Command "Code.exe" -ErrorAction SilentlyContinue).Source) { New-Shortcut -Target $e -Name "Visual Studio Code" }
    
    # 1. SSMS (Ищем в Program Files И Program Files (x86) - v22 ставится в x64)
    $paths64 = Resolve-Path "C:\Program Files\Microsoft SQL Server Management Studio*\Release\Common7\IDE\Ssms.exe" -ErrorAction SilentlyContinue
    $paths86 = Resolve-Path "C:\Program Files (x86)\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe" -ErrorAction SilentlyContinue
    $allSSMS = @($paths64, $paths86) | Where-Object { $_ } # Объединяем и фильтруем nulls
    
    if ($allSSMS.Count -gt 0) {
        $latestSSMS = $allSSMS | Sort-Object Path | Select-Object -Last 1
        New-Shortcut -Target $latestSSMS.Path -Name "SQL Server Management Studio"
    }

    # 2. VISUAL STUDIO (Ищем в Program Files, любая версия)
    $vsRoots = Resolve-Path "$env:ProgramFiles\Microsoft Visual Studio\*\*\Common7\IDE\devenv.exe" -ErrorAction SilentlyContinue
    if ($vsRoots) {
        $latestVS = $vsRoots | Sort-Object Path | Select-Object -Last 1
        Write-Log "Found Visual Studio at: $latestVS"
        New-Shortcut -Target $latestVS.Path -Name "Visual Studio"
    } else {
        Write-Log "WARN: Could not find devenv.exe automatically."
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
    Start-Service caddy
} catch { Write-Log "WARN Caddy: $_" }

# ============================================
# 🏁 FINALIZE STAGE 1
# ============================================
Write-Log "STAGE 1 DONE. Creating marker file and rebooting for Stage 2..."
New-Item -Path $MarkerFile -ItemType File -Force | Out-Null

Start-Sleep -Seconds 5
Restart-Computer -Force