# ==============================================================================
# deploy_gcloud_infrastructure.ps1
# Robust Idempotent Infrastructure Setup + Auto Google Key
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
  
  # --- Restored Parameters ---
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
Write-Host "Log:         $logFile"

# --- Helper Function ---
function Invoke-Gcloud {
  param([string]$Command, [int]$SuccessCode = 0)
  Write-Host ">> gcloud $Command"
  $flatArgs = $Command -replace "(`r|`n)+", " "
  $flatArgs = $flatArgs -replace "\s{2,}", " "
  
  if ([string]::IsNullOrWhiteSpace($flatArgs)) { throw "Empty command." }

  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c gcloud $flatArgs" -PassThru -Wait -NoNewWindow -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
  $out = Get-Content "stdout.txt" -ErrorAction SilentlyContinue
  $err = Get-Content "stderr.txt" -ErrorAction SilentlyContinue
  
  if ($err -and $err -match "ERROR:") { Write-Warning ($err -join "`n") } 
  if ($p.ExitCode -ne $SuccessCode) { throw "Gcloud failed ($($p.ExitCode)): $flatArgs`n$err" }
  return $out
}

# --- 1. CHECKS & AUTH ---
$startup = Join-Path $PSScriptRoot "startup_webapp_windows.ps1"
if (-not (Test-Path $startup)) { Stop-Transcript; throw "Startup script not found: $startup" }

# Auth Check
$active = (& gcloud auth list --filter=status:ACTIVE --format="value(account)") 2>$null
if (-not $active) { Write-Warning "Logging in..."; & gcloud auth login }

Invoke-Gcloud "config set project $Project" | Out-Null
Invoke-Gcloud "config set compute/region $Region" | Out-Null
Invoke-Gcloud "config set compute/zone $Zone" | Out-Null

# --- 2. KEY MANAGEMENT (NEW) ---
Write-Host "`nChecking Service Account Key..."
$KeyFile = Join-Path $PSScriptRoot "google_key.json"

if (-not (Test-Path $KeyFile)) {
    Write-Host "   Key file not found locally. Generating..."
    
    # 1. Get Project Number
    $ProjNum = Invoke-Gcloud "projects describe $Project --format=""value(projectNumber)"""
    $ProjNum = $ProjNum.Trim()
    
    # 2. Construct Default Compute SA Email
    $ServiceAccountEmail = "${ProjNum}-compute@developer.gserviceaccount.com"
    Write-Host "   Target Service Account: $ServiceAccountEmail"

    # 3. Create Key
    Invoke-Gcloud "iam service-accounts keys create ""$KeyFile"" --iam-account=$ServiceAccountEmail" | Out-Null
    Write-Host "   ✔ Key generated: $KeyFile" -ForegroundColor Green
} else {
    Write-Host "   ✔ Key file exists locally." -ForegroundColor Green
}

# --- 3. SSH KEYS ---
Write-Host "`nChecking SSH Keys..."
$SshKeyDir = Split-Path $SshPublicKeyPath
if (-not (Test-Path $SshKeyDir)) { New-Item -ItemType Directory -Force -Path $SshKeyDir | Out-Null }
if (-not (Test-Path $SshPublicKeyPath)) {
    ssh-keygen -t ed25519 -N "" -f ($SshPublicKeyPath.Substring(0, $SshPublicKeyPath.Length - 4)) -q
}

# --- 4. INFRASTRUCTURE ---

# Firewall
try { Invoke-Gcloud "compute firewall-rules describe allow-smb-445" | Out-Null } 
catch { if (-not $WhatIf) { Invoke-Gcloud "compute firewall-rules create allow-smb-445 --allow=tcp:445 --direction=INGRESS --priority=1000 --network=$Network --source-ranges=0.0.0.0/0" } }

# Instance Template
$allTpl = Invoke-Gcloud 'compute instance-templates list --format="value(name)"'
if (($allTpl) -contains $TemplateName) {
    if (-not $WhatIf) { Invoke-Gcloud "compute instance-templates delete $TemplateName --quiet" | Out-Null }
}

# METADATA: Pass key file content securely via metadata-from-file
$metadataInline = "domain=$Domain,email=$AcmeEmail"
# !!! ВАЖНО: Добавляем google-key-json в список файлов
$metadataFileKV = "windows-startup-script-ps1=""$startup"",ssh-public-key=""$SshPublicKeyPath"",google-key-json=""$KeyFile"""

$argsList = @(
  "compute","instance-templates","create",$TemplateName,
  "--machine-type=$MachineType",
  "--image-family=windows-2022",
  "--image-project=windows-cloud",
  "--boot-disk-type=$BootDiskType",
  "--boot-disk-size=$BootDiskSize",
  "--tags=$Tags",
  "--metadata=$metadataInline",
  "--metadata-from-file=$metadataFileKV", # <-- Key is injected here
  "--network=$Network"
)
if ($Subnetwork) { $argsList += "--subnet=$Subnetwork" }

if (-not $WhatIf) {
    Invoke-Gcloud ($argsList -join ' ') | Out-Null
    Write-Host "✔ Template created."
}

# VM Instance
$existsVm = Invoke-Gcloud 'compute instances list --format="value(name)"'
if (($existsVm) -contains $InstanceName) {
    if (-not $WhatIf) { Invoke-Gcloud "compute instances delete $InstanceName --quiet" | Out-Null }
}

# Static IP
$addrName = "${InstanceName}-external-ip"
$addrList = Invoke-Gcloud "compute addresses list --regions=$Region --format=""value(name)"""
if (-not ($addrList -contains $addrName)) {
    if (-not $WhatIf) { Invoke-Gcloud "compute addresses create $addrName --region=$Region" | Out-Null }
}

$extIpOut = Invoke-Gcloud "compute addresses describe $addrName --region=$Region --format=""value(address)"""
$externalIp = ($extIpOut | Where-Object { $_ -match '\d+\.\d+\.\d+\.\d+' } | Select-Object -First 1).Trim()

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

# --- 5. POST DEPLOY ---
Write-Host "`nWaiting for Windows VM to initialize..."
$maxRetries = 30; $retryCount = 0; $success = $false
while (-not $success -and $retryCount -lt $maxRetries) {
    $retryCount++
    Write-Host "Attempt $retryCount..." -NoNewline
    try {
        $passOutput = Invoke-Gcloud "compute reset-windows-password $InstanceName --zone=$Zone --user=mykola --quiet"
        Write-Host " Success!" -ForegroundColor Green
        Write-Host "`n===== RDP CREDENTIALS =====" -ForegroundColor Green
        $passOutput | ForEach-Object { Write-Host $_ }
        Write-Host "==========================="
        $success = $true
    } catch {
        Write-Host " VM not ready. Retrying in 20s..." -ForegroundColor Yellow
        Start-Sleep -Seconds 20
    }
}

Stop-Transcript | Out-Null
Write-Host "`nDONE." -ForegroundColor Green