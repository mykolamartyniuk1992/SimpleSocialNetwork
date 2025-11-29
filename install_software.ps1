# ==============================================================================
# install_software.ps1
# Runs via SSH as user 'mykola'. Installs Choco + Tools + VS.
# ==============================================================================
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Log = "C:\webapp\logs\user_install.log"
function Write-Log($m) { "[$(Get-Date -Format 'HH:mm:ss')] $m" | Tee-Object -FilePath $Log -Append }

Write-Log "STARTING SOFTWARE INSTALLATION (User: $env:USERNAME)..."

# 0. Install Chocolatey (User Context - Safe!)
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Chocolatey..."
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refreshenv workaround for current session
    $env:Path = $env:Path + ";C:\ProgramData\chocolatey\bin"
}

# 1. Base Tools & .NET SDKs
try {
    Write-Log "Installing base tools and .NET SDKs..."
    # Added dotnet-sdk (latest) + 8 and 9 specific
    $packages = @("git", "vscode", "sql-server-management-studio", "nodejs-lts", "googlechrome", "dotnet-8.0-sdk", "dotnet-9.0-sdk", "dotnet-sdk")
    choco install $packages -y --no-progress
} catch { Write-Log "Error Choco Base: $_" }

# 2. GitHub Desktop (Clean User Install)
try {
    Write-Log "Installing GitHub Desktop..."
    choco install github-desktop -y --no-progress
    Write-Log "GitHub Desktop installed."
} catch { Write-Log "Error GitHub: $_" }

# 3. Visual Studio 2026 (v18)
try {
    $vsPath = "C:\Installers\vs_community_2026.exe"
    if (-not (Test-Path "C:\Installers")) { New-Item -Type Directory "C:\Installers" | Out-Null }
    
    if (-not (Test-Path $vsPath)) {
        Write-Log "Downloading Visual Studio 2026 (v18)..."
        (New-Object System.Net.WebClient).DownloadFile("https://aka.ms/vs/18/Stable/vs_community.exe", $vsPath)
    }
    
    if ((Get-Item $vsPath).Length -gt 1000000) {
        Write-Log "Installing Visual Studio 2026 (Takes 20+ mins)..."
        $args = "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.Data --add Microsoft.VisualStudio.Workload.Node --includeRecommended --includeOptional"
        $p = Start-Process -FilePath $vsPath -ArgumentList $args -Wait -PassThru
        Write-Log "VS Install finished with code: $($p.ExitCode)"
    } else { Write-Log "ERROR: VS installer too small." }
} catch { Write-Log "Error VS: $_" }

# 4. Shortcuts
try {
    Write-Log "Creating Shortcuts..."
    $WshShell = New-Object -comObject WScript.Shell
    $Desktop = [Environment]::GetFolderPath("Desktop")

    # VS Code
    if (Get-Command "code" -ErrorAction SilentlyContinue) {
        $s = $WshShell.CreateShortcut("$Desktop\VS Code.lnk")
        $s.TargetPath = (Get-Command "code").Source
        $s.Save()
    }

    # SSMS
    $ssmsPath = "C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\SSMS.exe"
    if (Test-Path $ssmsPath) {
        Write-Log "Creating SSMS shortcut..."
        $ssmsShortcut = $WshShell.CreateShortcut("$Desktop\SSMS.lnk")
        $ssmsShortcut.TargetPath = $ssmsPath
        $ssmsShortcut.IconLocation = $ssmsPath
        $ssmsShortcut.Save()
    } else {
        Write-Log "SSMS path not found, skipping SSMS shortcut."
    }
} catch { }

Write-Log "Base software installation (without SQL Server 2022) COMPLETE."

# 5. Scheduled Task: install SQL Server 2022 after reboot
try {
    Write-Log "Creating scheduled task to install SQL Server 2022 after reboot..."

    $chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
    if (-not (Test-Path $chocoPath)) {
        Write-Log "WARNING: $chocoPath not found; skipping scheduled task for SQL Server."
    }
    else {
        $sqlScriptPath = "C:\webapp\install_sql2022.ps1"
        if (-not (Test-Path "C:\webapp")) {
            New-Item -ItemType Directory -Path "C:\webapp" -Force | Out-Null
        }
        if (-not (Test-Path "C:\webapp\logs")) {
            New-Item -ItemType Directory -Path "C:\webapp\logs" -Force | Out-Null
        }

        # ВАЖНО: @' ... '@  → всё внутри попадает в файл как есть
        $sqlScriptContent = @'
$ErrorActionPreference = 'Stop'

$Log = 'C:\webapp\logs\sql_install.log'
function Write-Log {
    param([string]$Message)
    "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message | Tee-Object -FilePath $Log -Append
}

Write-Log "=== STARTING SQL SERVER 2022 INSTALL ==="

# 1) Install SQL Server 2022
$choco = "C:\ProgramData\chocolatey\bin\choco.exe"
Write-Log "Running: $choco install sql-server-2022 ..."
& $choco install sql-server-2022 -y --no-progress --params "'/IgnorePendingReboot'"
Write-Log "Choco install finished with exit code $LASTEXITCODE"

# 2) Wait for SQL service
$svcName = 'MSSQLSERVER'
try {
    Write-Log "Waiting for SQL Server service '$svcName'..."
    $svc = Get-Service -Name $svcName -ErrorAction Stop
    if ($svc.Status -ne 'Running') {
        Start-Service $svcName
        $svc.WaitForStatus('Running','00:02:00')
    }
    Write-Log "SQL Server service '$svcName' is running."
}
catch {
    Write-Log "ERROR: SQL Server service '$svcName' not found or cannot be started: $_"
}

# 3) Grant sysadmin to COMPUTERNAME\mykola
try {
    $comp  = $env:COMPUTERNAME
    $login = "$comp\mykola"
    Write-Log "Granting sysadmin to login [$login]..."

    $tsql = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$login')
    CREATE LOGIN [$login] FROM WINDOWS;
IF NOT EXISTS (
    SELECT 1 FROM sys.server_role_members rm
    JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
    WHERE r.name = N'sysadmin' AND m.name = N'$login'
)
    ALTER SERVER ROLE [sysadmin] ADD MEMBER [$login];
"@

    $possibleSqlcmd = @(
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe",
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe",
        "sqlcmd.exe"
    )
    $sqlcmd = $possibleSqlcmd | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $sqlcmd) { throw "sqlcmd.exe not found" }

    & $sqlcmd -E -S "localhost" -Q $tsql
    Write-Log "sysadmin granted to [$login]."
}
catch {
    Write-Log "ERROR granting sysadmin rights: $_"
}

Write-Log "=== SQL install completed ==="
'@

        Set-Content -Path $sqlScriptPath -Value $sqlScriptContent -Encoding UTF8

        Import-Module ScheduledTasks -ErrorAction SilentlyContinue

        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
                  -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$sqlScriptPath`""

        $trigger   = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount

        Register-ScheduledTask -TaskName "Install_SQLServer2022" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

        Write-Log "Scheduled task 'Install_SQLServer2022' created."
    }
}
catch {
    Write-Log "Error creating SQL Server 2022 scheduled task: $_"
    throw "Error while creating SQL Server 2022 scheduled task: $_"
}

# 6. Перед перезагрузкой гарантируем marker для стартап-скрипта
try {
    Write-Log "Ensuring C:\webapp\system_prep_complete.txt exists before reboot..."
    if (-not (Test-Path "C:\webapp")) {
        New-Item -ItemType Directory -Path "C:\webapp" -Force | Out-Null
    }
    New-Item -Path "C:\webapp\system_prep_complete.txt" -ItemType File -Force | Out-Null
    Write-Log "Marker file C:\webapp\system_prep_complete.txt is present."
} catch {
    Write-Log "Error creating system_prep_complete marker: $_"
    throw "Error while creating system_prep_complete marker: $_"
    exit -1
}

# 7. Планируем перезагрузку
try {
    Write-Log "Scheduling reboot in 60 seconds..."
    Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 60 /c `"Reboot after base software install`"" -WindowStyle Hidden
} catch {
    Write-Log "Error scheduling reboot: $_"
}

Write-Log "INSTALLATION SCRIPT COMPLETED (reboot scheduled)."