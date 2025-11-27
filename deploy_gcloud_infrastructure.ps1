# ==============================================================================
# deploy_gcloud_infrastructure.ps1
# Robust Idempotent Infrastructure Setup
# ==============================================================================

Param(
  [string]$Project      = "",
  [string]$Region       = "us-central1",
  [string]$Zone         = "us-central1-c",
  [string]$TemplateName = "webapp-windows-template",
  [string]$InstanceName = "webapp-windows",
  [string]$Network      = "default",
  [string]$Subnetwork   = "",
  [string]$MachineType  = "n2-standard-8",
  [string]$BootDiskType = "pd-balanced",
  [string]$BootDiskSize = "200GB",
  [string]$Tags         = "webapp,rdp-allow,https-allow,http-allow",
  [string]$Domain       = "simplesocialnetwork.mykolamartyniuk1992.dev",
  [string]$AcmeEmail    = "mykola.martyniuk.1992@gmail.com",
  [string]$SshPublicKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub",
  [string]$DnsZoneName  = "mykolamartyniuk1992-dev",
  [string]$MailSecretName = "resend-email-api-key",
  [string]$ResendDkimPrefix = "v=DKIM1; k=rsa;",
  [string]$ResendDkimKey    = "",
  [string]$ResendDkimValue  = "$ResendDkimPrefix $ResendDkimKey",
  [string]$ResendSpfValue   = "v=spf1 include:amazonses.com ~all",
  [string]$ResendDmarcValue = "v=DMARC1; p=none;",
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'PlainText'

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $PSScriptRoot "create_webapp_${TemplateName}_$ts.log"
Start-Transcript -Path $logFile -Force | Out-Null

Write-Host "==== Create WebApp Windows Template & VM (Idempotent) ===="
Write-Host "Project:     $Project"
Write-Host "Instance:    $InstanceName"
Write-Host "Log:         $logFile"
Write-Host ""

# --- Helper Function (Hardened) ---
function Invoke-Gcloud {
  # CHANGED: Renamed $Args to $Command to avoid conflict with PowerShell reserved variable
  param([string]$Command, [int]$SuccessCode = 0)
  
  Write-Host ">> gcloud $Command"
  
  # Clean up args (remove newlines and extra spaces)
  $flatArgs = $Command -replace "(`r|`n)+", " "
  $flatArgs = $flatArgs -replace "\s{2,}", " "

  # Check if command is empty to prevent "Command name argument expected" error
  if ([string]::IsNullOrWhiteSpace($flatArgs)) {
      throw "Invoke-Gcloud was called with an empty command string."
  }

  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c gcloud $flatArgs" -PassThru -Wait -NoNewWindow -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
  
  $out = Get-Content "stdout.txt" -ErrorAction SilentlyContinue
  $err = Get-Content "stderr.txt" -ErrorAction SilentlyContinue
  
  if ($err) { 
      # Convert stderr to string
      $errStr = $err -join "`n"
      # Only warn if it looks like a real error
      if ($errStr -match "ERROR:") { Write-Warning $errStr } 
  }

  if ($p.ExitCode -ne $SuccessCode) {
      throw "Gcloud command failed with exit code $($p.ExitCode).`nArgs: $flatArgs`nError: $err"
  }
  
  return $out
}

# --- 1. CHECKS ---
$startup = Join-Path $PSScriptRoot "startup_webapp_windows.ps1"
if (-not (Test-Path $startup)) { Stop-Transcript; throw "Startup script not found: $startup" }

# Auth Check
$active = (& gcloud auth list --filter=status:ACTIVE --format="value(account)") 2>$null
if (-not $active) {
    Write-Warning "Logging in..."
    & gcloud auth login
}

# Config
Invoke-Gcloud "config set project $Project" | Out-Null
Invoke-Gcloud "config set compute/region $Region" | Out-Null
Invoke-Gcloud "config set compute/zone $Zone" | Out-Null

# --- 2. SSH KEYS ---
Write-Host "`nChecking SSH Keys..."
$SshKeyDir = Split-Path $SshPublicKeyPath
$SshPrivateKeyPath = $SshPublicKeyPath.Substring(0, $SshPublicKeyPath.Length - 4)

if (-not (Test-Path $SshKeyDir)) { New-Item -ItemType Directory -Force -Path $SshKeyDir | Out-Null }

if (-not (Test-Path $SshPublicKeyPath)) {
    Write-Host "Generating SSH Key..."
    ssh-keygen -t ed25519 -N "" -f "$SshPrivateKeyPath" -q
} else {
    Write-Host "SSH Key exists."
}

# --- 3. INFRASTRUCTURE ---

# Firewall 445
try { Invoke-Gcloud "compute firewall-rules describe allow-smb-445" | Out-Null } 
catch { 
    if (-not $WhatIf) { Invoke-Gcloud "compute firewall-rules create allow-smb-445 --allow=tcp:445 --direction=INGRESS --priority=1000 --network=$Network --source-ranges=0.0.0.0/0" } 
}

# Instance Template
$allTpl = Invoke-Gcloud 'compute instance-templates list --format="value(name)"'
if (($allTpl) -contains $TemplateName) {
    if (-not $WhatIf) { Invoke-Gcloud "compute instance-templates delete $TemplateName --quiet" | Out-Null }
}

$metadataInline = "domain=$Domain,email=$AcmeEmail"
# Properly escaped for metadata-from-file
$metadataFileKV = "windows-startup-script-ps1=""$startup"",ssh-public-key=""$SshPublicKeyPath"""

$argsList = @(
  "compute","instance-templates","create",$TemplateName,
  "--machine-type=$MachineType",
  "--image-family=windows-2022",
  "--image-project=windows-cloud",
  "--boot-disk-type=$BootDiskType",
  "--boot-disk-size=$BootDiskSize",
  "--tags=$Tags",
  "--metadata=$metadataInline",
  "--metadata-from-file=$metadataFileKV",
  "--network=$Network"
)
if ($Subnetwork) { $argsList += "--subnet=$Subnetwork" }

if (-not $WhatIf) {
    Invoke-Gcloud ($argsList -join ' ') | Out-Null
    Write-Host "✔ Template created."
}

# VM Instance (Recreate Logic)
$existsVm = Invoke-Gcloud 'compute instances list --format="value(name)"'
if (($existsVm) -contains $InstanceName) {
    if (-not $WhatIf) {
        Write-Host "Deleting existing VM '$InstanceName'..."
        Invoke-Gcloud "compute instances delete $InstanceName --quiet" | Out-Null
    }
}

# Static IP
$addrName = "${InstanceName}-external-ip"
$addrList = Invoke-Gcloud "compute addresses list --regions=$Region --format=""value(name)"""
if (-not ($addrList -contains $addrName)) {
    if (-not $WhatIf) { Invoke-Gcloud "compute addresses create $addrName --region=$Region" | Out-Null }
}

# Retrieve IP Safely
Write-Host "Retrieving External IP..."
$extIpOut = Invoke-Gcloud "compute addresses describe $addrName --region=$Region --format=""value(address)"""
# Ensure we get a clean IP string
$externalIp = ($extIpOut | Where-Object { $_ -match '\d+\.\d+\.\d+\.\d+' } | Select-Object -First 1).Trim()

if ([string]::IsNullOrWhiteSpace($externalIp)) { 
    throw "Failed to retrieve valid IP address. Got: '$extIpOut'" 
}
Write-Host "Using IP: $externalIp"

# Create VM
$niArg = "--network-interface=network=$Network,address=$externalIp"
if ($Subnetwork) { $niArg = "--network-interface=subnet=$Subnetwork,address=$externalIp" }

if (-not $WhatIf) {
    Invoke-Gcloud "compute instances create $InstanceName --source-instance-template=$TemplateName $niArg --zone=$Zone" | Out-Null
    Write-Host "✔ VM created at $externalIp"
}

# Firewall Rules
$fwList = Invoke-Gcloud 'compute firewall-rules list --format="value(name)"'
$rules = @{ "allow-rdp"="tcp:3389"; "allow-webapp-http-https"="tcp:80,tcp:443"; "allow-webapp-ssh"="tcp:22" }

foreach ($r in $rules.GetEnumerator()) {
    if (-not ($fwList -contains $r.Key)) {
        if (-not $WhatIf) { Invoke-Gcloud "compute firewall-rules create $($r.Key) --direction=INGRESS --action=ALLOW --rules=$($r.Value) --source-ranges=0.0.0.0/0 --target-tags=webapp,rdp-allow" | Out-Null }
    }
}

# --- 4. POST DEPLOY ---
Write-Host "`nWaiting for Windows VM to initialize (this takes a few minutes)..."

$maxRetries = 30
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    $retryCount++
    Write-Host "Attempt $retryCount of $maxRetries to reset password..." -NoNewline
    
    try {
        # Try to reset the password
        $passOutput = Invoke-Gcloud "compute reset-windows-password $InstanceName --zone=$Zone --user=mykola --quiet"
        
        # If successful, print result and break loop
        Write-Host " Success!" -ForegroundColor Green
        Write-Host "`n===== RDP CREDENTIALS =====" -ForegroundColor Green
        # The output from gcloud often contains warnings, we just want the block with the password
        $passOutput | ForEach-Object { Write-Host $_ }
        Write-Host "==========================="
        $success = $true
    }
    catch {
        # If it fails (VM not ready), wait and loop again
        Write-Host " VM not ready. Retrying in 20s..." -ForegroundColor Yellow
        Start-Sleep -Seconds 20
    }
}

if (-not $success) {
    Write-Warning "Could not retrieve password automatically after multiple attempts."
    Write-Warning "Please wait a few more minutes and run:"
    Write-Warning "gcloud compute reset-windows-password $InstanceName --zone=$Zone --user=mykola"
}

Stop-Transcript | Out-Null
Write-Host "`nDONE." -ForegroundColor Green