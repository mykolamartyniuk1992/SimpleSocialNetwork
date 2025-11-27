# =============================================
# redeploy_webapp_vm.ps1
# - пересоздать instance template и VM
# - привязать статический regional IP
# - запустить startup_webapp_windows.ps1
# - опционально: проверить, что вся нужная инфраструктура уже есть
# =============================================

Param(
  [Parameter(Mandatory=$true)] [string]$Project,
  [string]$Region       = "us-central1",
  [string]$Zone         = "us-central1-c",
  [string]$TemplateName = "webapp-windows-template",
  [string]$InstanceName = "webapp-windows",

  # network/disks/tags
  [string]$Network      = "default",
  [string]$Subnetwork   = "",
  [string]$MachineType  = "n2-standard-8",
  [string]$BootDiskType = "pd-balanced",
  [string]$BootDiskSize = "200GB",
  [string]$Tags         = "webapp,rdp-allow,https-allow,http-allow",

  # metadata for startup
  [string]$Domain       = "simplesocialnetwork.mykolamartyniuk1992.dev",
  [string]$AcmeEmail    = "mykola.martyniuk.1992@gmail.com",

  # доп. режим: только проверяем инфраструктуру и падаем, если чего-то нет
  [switch]$CheckRequiredInfrastructure,

  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'PlainText'

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $PSScriptRoot "redeploy_webapp_${TemplateName}_$ts.log"
Start-Transcript -Path $logFile -Force | Out-Null

Write-Host "==== Recreate WebApp Windows VM ===="
Write-Host "Project:     $Project"
Write-Host "Template:    $TemplateName"
Write-Host "Instance:    $InstanceName"
Write-Host "Region/Zone: $Region / $Zone"
Write-Host "Domain:      $Domain"
Write-Host "Log:         $logFile"
Write-Host ""

# --- startup script path + проверка синтаксиса ---
$startup = Join-Path $PSScriptRoot "startup_webapp_windows.ps1"
if (-not (Test-Path $startup)) {
  Stop-Transcript | Out-Null
  throw "startup_webapp_windows.ps1 not found next to the script: $startup"
}

$sha = (Get-FileHash -Algorithm SHA256 $startup).Hash
Write-Host "Startup script: $startup"
Write-Host "SHA256:        $sha"

try {
    Write-Host "Checking startup script PowerShell syntax..."
    $null = [System.Management.Automation.PSParser]::Tokenize(
        (Get-Content -LiteralPath $startup -Raw),
        [ref]$null
    )
    Write-Host "Startup script syntax OK."
}
catch {
    Write-Host "ERROR: startup script has syntax errors."
    Write-Host $_
    Stop-Transcript | Out-Null
    throw "Startup script 'startup_webapp_windows.ps1' contains syntax errors: $($_.Exception.Message)"
}

# --- helper для gcloud ---
function Invoke-Gcloud {
  param(
    [Parameter(Mandatory)] [string]$Args,
    [int]$SuccessCode = 0
  )
  Write-Host ">> gcloud $Args"
  $flat = $Args -replace "(`r|`n)+", " "
  $flat = $flat -replace "\s{2,}", " "

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c gcloud $flat"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if ($stdout) { Write-Host $stdout.TrimEnd() }
  if ($stderr) { Write-Warning $stderr.TrimEnd() }
  if ($p.ExitCode -ne $SuccessCode) {
    throw "gcloud exited with code $($p.ExitCode). Args: $Args"
  }
  return $stdout
}

# --- установка gcloud при необходимости ---
Write-Host "`nChecking for gcloud installation..."

function Install-GCloud {
    $installerDir = Join-Path $env:TEMP "gcloud-installer"
    New-Item -ItemType Directory -Force -Path $installerDir | Out-Null

    $installerUrl = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-481.0.0-windows-x86_64.exe"
    $installerExe = Join-Path $installerDir "google-cloud-sdk.exe"

    Write-Host "Downloading Google Cloud SDK..."
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($installerUrl, $installerExe)

    Write-Host "Installing Google Cloud SDK silently..."
    Start-Process -FilePath $installerExe -ArgumentList "/S" -Wait -NoNewWindow
    Write-Host "Google Cloud SDK installed."
}

$gcloudPath = (Get-Command gcloud -ErrorAction SilentlyContinue)
if (-not $gcloudPath) {
    Write-Warning "gcloud not found! Installing Google Cloud SDK..."
    Install-GCloud
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $gcloudPath = (Get-Command gcloud -ErrorAction SilentlyContinue)
    if (-not $gcloudPath) {
        Stop-Transcript | Out-Null
        throw "Google Cloud SDK installation failed — gcloud still not found."
    }
}
Write-Host "gcloud found at: $($gcloudPath.Source)"

# --- аутентификация ---
Write-Host "`nChecking gcloud authentication..."
$activeAccountRaw = (& gcloud auth list --filter=status:ACTIVE --format="value(account)") 2>$null
$activeAccount = $activeAccountRaw | Select-Object -First 1

if (-not $activeAccount) {
    Write-Warning "No active gcloud account. Starting login flow..."
    & gcloud auth login
    & gcloud auth application-default login
    $activeAccountRaw = (& gcloud auth list --filter=status:ACTIVE --format="value(account)") 2>$null
    $activeAccount = $activeAccountRaw | Select-Object -First 1
    if (-not $activeAccount) {
        Stop-Transcript | Out-Null
        throw "Authentication failed. Cannot continue."
    }
}
Write-Host "Authenticated as: $activeAccount"

# --- доступ к проекту ---
try {
    Write-Host "`nChecking access to project '$Project'..."
    & gcloud projects describe $Project | Out-Null
    Write-Host "Access to project '$Project' OK."
}
catch {
    Stop-Transcript | Out-Null
    throw "Cannot access project '$Project'. Error: $($_.Exception.Message)"
}

# --- config ---
Invoke-Gcloud "config set project $Project"        | Out-Null
Invoke-Gcloud "config set compute/region $Region" | Out-Null
Invoke-Gcloud "config set compute/zone $Zone"     | Out-Null

# имя адреса, нужен и для проверки, и для деплоя
$addressName = "${InstanceName}-external-ip"

# ============================================
# Проверка необходимой инфраструктуры (опция)
# ============================================
if ($CheckRequiredInfrastructure) {
    Write-Host "`nChecking required infrastructure (network, subnet, static IP)..."

    $problems = @()

    # network
    try {
        Invoke-Gcloud "compute networks describe $Network --format=""value(name)""" | Out-Null
    } catch {
        $problems += "Network '$Network' not found."
    }

    # subnet (если указан)
    if ($Subnetwork) {
        try {
            Invoke-Gcloud "compute networks subnets describe $Subnetwork --region=$Region --format=""value(name)""" | Out-Null
        } catch {
            $problems += "Subnetwork '$Subnetwork' not found in region '$Region'."
        }
    }

    # regional static IP
    try {
        $addr = Invoke-Gcloud "compute addresses describe $addressName --region=$Region --format=""value(address)""" | Select-Object -First 1
        if (-not $addr) { $problems += "Regional address '$addressName' in region '$Region' not found." }
    }
    catch {
        $problems += "Regional address '$addressName' in region '$Region' not found."
    }

    if ($problems.Count -gt 0) {
        Write-Host ""
        Write-Host "Required infrastructure check FAILED:" -ForegroundColor Red
        foreach ($p in $problems) {
            Write-Host "  - $p" -ForegroundColor Red
        }
        Stop-Transcript | Out-Null
        throw "Required infrastructure missing. See messages above."
    }
    else {
        Write-Host "All required infrastructure objects are present."
    }
}

# ============================================
# Дальше — собственно redeploy (template + VM)
# ============================================

# --- recreate instance template ---
$allTpl = Invoke-Gcloud 'compute instance-templates list --format="value(name)"'
if (($allTpl -split "`r?`n") -contains $TemplateName) {
  if ($WhatIf) { Write-Host "WhatIf: would delete template '$TemplateName' (skipped)." }
  else {
    Write-Host "Deleting existing template '$TemplateName'..."
    Invoke-Gcloud "compute instance-templates delete $TemplateName --quiet" | Out-Null
  }
}

$netArgs = @("--network=$Network")
if ($Subnetwork) { $netArgs += "--subnet=$Subnetwork" }

$metadataInline = "domain=$Domain,email=$AcmeEmail"
$metadataFileKV = "windows-startup-script-ps1=""$startup"""

$argsList = @(
  "compute","instance-templates","create",$TemplateName,
  "--machine-type=$MachineType",
  "--image-family=windows-2022",
  "--image-project=windows-cloud",
  "--boot-disk-type=$BootDiskType",
  "--boot-disk-size=$BootDiskSize",
  "--tags=$Tags",
  "--metadata=$metadataInline",
  "--metadata-from-file=$metadataFileKV"
)
$argsList += $netArgs
$createTpl = ($argsList -join ' ')

if ($WhatIf) {
  Write-Host "WhatIf: would run -> gcloud $createTpl"
} else {
  Invoke-Gcloud $createTpl | Out-Null
  Write-Host "✔ Template '$TemplateName' created."
}

# --- delete VM if exists ---
$existsVm = Invoke-Gcloud 'compute instances list --format="value(name)"'
if (($existsVm -split "`r?`n") -contains $InstanceName) {
  if ($WhatIf) { Write-Host "WhatIf: would delete instance '$InstanceName' (skipped)." }
  else {
    Write-Host "Deleting existing instance '$InstanceName'..."
    Invoke-Gcloud "compute instances delete $InstanceName --quiet" | Out-Null
  }
}

# === Regional static external IP ===
if ($CheckRequiredInfrastructure) {
    # В проверочном режиме IP считаем обязательным и не создаём/не трогаем его
    $externalIp = (Invoke-Gcloud "compute addresses describe $addressName --region=$Region --format=""value(address)""" | Select-Object -First 1).Trim()
    if (-not $externalIp) {
        Stop-Transcript | Out-Null
        throw "Required regional address '$addressName' not found in region $Region (but CheckRequiredInfrastructure is set)."
    }
    Write-Host "Using existing regional external address '$addressName' in ${Region}: $externalIp"
}
else {
    # обычный режим — аккуратно подчищаем global и создаём regional при необходимости
    # Delete GLOBAL address with same name (we need regional)
    $globalList = Invoke-Gcloud 'compute addresses list --global --format="value(name)"'
    if (($globalList -split "`r?`n") -contains $addressName) {
      if ($WhatIf) {
        Write-Host "WhatIf: would delete GLOBAL address '$addressName' (skipped)."
      } else {
        Write-Host "Deleting GLOBAL address '$addressName' (regional $Region needed)..."
        Invoke-Gcloud "compute addresses delete $addressName --global --quiet" | Out-Null
      }
    }

    # Create/reuse REGIONAL address
    $regionalList = Invoke-Gcloud "compute addresses list --regions=$Region --format=""value(name)"""
    if (-not (($regionalList -split "`r?`n") -contains $addressName)) {
      if ($WhatIf) {
        Write-Host "WhatIf: would create regional address '$addressName' in $Region (skipped)."
      } else {
        Invoke-Gcloud "compute addresses create $addressName --region=$Region" | Out-Null
        Write-Host "✔ Regional external address '$addressName' created in $Region."
      }
    }
    $externalIp = (Invoke-Gcloud "compute addresses describe $addressName --region=$Region --format=""value(address)""" | Select-Object -First 1).Trim()
}
Write-Host "Planned External IP (regional $Region): $externalIp"

# === CREATE VM with this IP ===
$niParts = @()
if ($Subnetwork) { $niParts += "subnet=$Subnetwork" } else { $niParts += "network=$Network" }
$niParts += "address=$externalIp"
$niArg = "--network-interface=" + ($niParts -join ",")

$createVmArgs = @(
  "compute","instances","create",$InstanceName,
  "--source-instance-template=$TemplateName",
  $niArg
)
$createVm = ($createVmArgs -join ' ')

if ($WhatIf) {
  Write-Host "WhatIf: would run -> gcloud $createVm"
} else {
  Invoke-Gcloud $createVm | Out-Null
  Write-Host "✔ Instance '$InstanceName' created with static External IP $externalIp."
}

# --- get internal/external IPs ---
$internalIp    = (Invoke-Gcloud "compute instances describe $InstanceName --zone=$Zone --format=""value(networkInterfaces[0].networkIP)""" | Select-Object -First 1).Trim()
$nowExternalIp = $externalIp

Write-Host ""
Write-Host "===== Summary ====="
Write-Host "Template:       $TemplateName"
Write-Host "Instance:       $InstanceName"
Write-Host "Internal IP:    $internalIp"
Write-Host "External IP:    $nowExternalIp"
Write-Host "Startup script: $startup (SHA256: $sha)"
Write-Host "Log file:       $logFile"

# --- Reset Windows password for user 'mykola' (опционально, но удобно) ---
Write-Host ""
Write-Host "Creating / resetting Windows user 'mykola' on instance '$InstanceName'..."
try {
    $resetOutput = Invoke-Gcloud "compute reset-windows-password $InstanceName --zone=$Zone --user=mykola --quiet"
    Write-Host ""
    Write-Host "===== Windows RDP credentials (user 'mykola') ====="
    Write-Host $resetOutput
    Write-Host "==================================================="
    Write-Host "Эти данные также есть в лог-файле: $logFile"
}
catch {
    Write-Warning "Не удалось создать/сбросить пароль для пользователя 'mykola': $_"
}

Stop-Transcript | Out-Null
