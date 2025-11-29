# C:\webapp\install_software_launcher.ps1
$ErrorActionPreference = 'Stop'

$logDir = "C:\webapp\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$Log = Join-Path $logDir "launcher.log"

function Write-Log {
    param([string]$Message)
    "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message |
        Tee-Object -FilePath $Log -Append
}

Write-Log "Launcher started. Creating scheduled task for install_software.ps1..."

Import-Module ScheduledTasks -ErrorAction SilentlyContinue

# Что на самом деле будет выполняться
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\webapp\install_software.ps1"

# Запуск один раз, через 5 секунд
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddSeconds(5))

# ВАЖНО: запускаем под mykola, без пароля, через S4U, c правами администратора
$principal = New-ScheduledTaskPrincipal `
    -UserId "mykola" `
    -LogonType S4U `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName "Install_WebApp_Software_Once" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Force | Out-Null

Start-ScheduledTask -TaskName "Install_WebApp_Software_Once"

Write-Log "Scheduled task 'Install_WebApp_Software_Once' created and started under user 'mykola'."
Write-Log "Launcher finished (install_software.ps1 will run under Task Scheduler)."
