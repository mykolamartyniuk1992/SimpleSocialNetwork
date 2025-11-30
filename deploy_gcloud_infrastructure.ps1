# =============================================
# deploy_gcloud_infrastructure.ps1
# =============================================

Param(
  [string]$Project = "",
  [string]$Region = "us-central1",
  [string]$Zone = "us-central1-c",
  [string]$TemplateName = "webapp-windows-template",
  [string]$InstanceName = "webapp-windows",

  # network/disks/tags
  [string]$Network = "default",
  [string]$Subnetwork = "",                      # can be left empty for regional default
  [string]$MachineType = "n2-highcpu-16",
  [string]$BootDiskType = "pd-ssd",
  [string]$BootDiskSize = "200GB",
  [string]$Tags = "webapp,rdp-allow,https-allow,http-allow",

  # metadata for startup
  [string]$Domain = "simplesocialnetwork.mykolamartyniuk1992.dev",
  [string]$AcmeEmail = "mykola.martyniuk.1992@gmail.com",

  # Cloud DNS
  [string]$DnsZoneName = "mykolamartyniuk1992-dev",

  # Secret Manager: имя секрета для пароля почты
  [string]$MailSecretName = "resend-email-api-key",

  # Resend DNS values
  [string]$ResendDkimValue = "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDe1AbDloh5x0fNvf/ck6ClEHHl/VmUWtncczbn02M1SHcw5nKpRzvosRYXB6Iu2XNxvifnnFXAX63/aY+ccvG7bSLiPR5+LPvOWbbnwfeku06ofTc4mnfPw/SGc3E3vLNASviKSJiVhsqe5FNHc2PCL61Tr1/TpVaEEVQ5Uy/oTQIDAQAB",
  [string]$ResendSpfValue = "v=spf1 include:amazonses.com ~all",
  [string]$ResendDmarcValue = "v=DMARC1; p=none;",

  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'PlainText'

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $PSScriptRoot "create_webapp_${TemplateName}_$ts.log"
Start-Transcript -Path $logFile -Force | Out-Null

Write-Host "==== Create WebApp Windows Template & VM ===="
Write-Host "Project:     $Project"
Write-Host "Template:    $TemplateName"
Write-Host "Instance:    $InstanceName"
Write-Host "Region/Zone: $Region / $Zone"
Write-Host "Domain:      $Domain"
Write-Host "DNS zone:    $DnsZoneName  | DNS name: $($Domain + '.')"
Write-Host "Mail secret: $MailSecretName (Secret Manager)"
Write-Host "Log:         $logFile"
Write-Host ""

function Invoke-Gcloud {
  param(
    [Parameter(Mandatory)] [string]$GcloudArgs,
    [int]$SuccessCode = 0
  )
  Write-Host ">> gcloud $GcloudArgs"
  $flat = $GcloudArgs -replace "(`r|`n)+", " "
  $flat = $flat -replace "\s{2,}", " "

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c gcloud $flat"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if ($stdout) { Write-Host $stdout.TrimEnd() }
  if ($stderr) { Write-Warning $stderr.TrimEnd() }
  if ($p.ExitCode -ne $SuccessCode) {
    throw "gcloud exited with code $($p.ExitCode). Args: $GcloudArgs"
  }
  return $stdout
}

function Watch-RemoteLog {
    param(
        [string]$User,
        [string]$Ip,
        [string]$KeyPath,  # фактически не нужен, Invoke-SSH уже знает ключ
        [string]$RemoteLogPath,
        [string]$DoneMarker = "INSTALLATION SCRIPT COMPLETED",
        [int]$IntervalSeconds = 10
    )

    $lastLineCount = 0     # сколько строк мы уже показали
    $hadConnection = $false

    while ($true) {
        $timestamp = (Get-Date).ToString("HH:mm:ss")
        $remoteCmd = "powershell -NoProfile -Command `"if (Test-Path '$RemoteLogPath') { Get-Content '$RemoteLogPath' } else { '' }`""

        try {
            $output = Invoke-SSH $User $Ip $remoteCmd
            $exit   = $LASTEXITCODE
        }
        catch {
            $output = $null
            $exit   = 255
        }

        if ($exit -ne 0) {
            Write-Host "[$timestamp] SSH not ready for $RemoteLogPath yet. Retrying in $IntervalSeconds seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }

        if (-not $hadConnection) {
            Write-Host "[$timestamp] SSH reconnected successfully." -ForegroundColor Green
            $hadConnection = $true
        }

        if ([string]::IsNullOrEmpty($output)) {
            Write-Host "[$timestamp] $RemoteLogPath not created yet. Waiting..." -ForegroundColor DarkYellow
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }

        # приводим к массиву строк
        $lines = $output -split "`r?`n"

        # если лог «схлопнулся» (перезаписан) — начинаем сначала
        if ($lines.Length -lt $lastLineCount) {
            Write-Host "[$timestamp] Log shrank (rotation/rewrite). Resetting cursor." -ForegroundColor DarkGray
            $lastLineCount = 0
        }

        if ($lines.Length -gt $lastLineCount) {
            $newLines = $lines[$lastLineCount..($lines.Length - 1)]
            $newLines | ForEach-Object { Write-Host $_ }
            $lastLineCount = $lines.Length
        }
        else {
            Write-Host "[$timestamp] SSH OK, no new log lines yet. Next check in $IntervalSeconds sec..." -ForegroundColor DarkGray
        }

        if ($output -like "*$DoneMarker*") {
            Write-Host "[$timestamp] Done marker '$DoneMarker' found in $RemoteLogPath." -ForegroundColor Green
            break
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}


# ---------- SSH helpers ----------

# Глобальный Invoke-SSH: всегда используем один и тот же ключ и опции
function Invoke-SSH {
  param(
    [Parameter(Mandatory)] [string]$User,
    [Parameter(Mandatory)] [string]$IP,
    [Parameter(Mandatory)] [string]$Command
  )

  if (-not $script:SshPrivateKeyPath) {
    throw "SshPrivateKeyPath not set at script scope."
  }

  $knownHosts = Join-Path $env:USERPROFILE ".ssh\known_hosts"

  $sshArgs = @(
    "-i", $script:SshPrivateKeyPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=$knownHosts",
    "-o", "ConnectTimeout=20",
    "$User@$IP",
    $Command
  )

  & ssh @sshArgs
}

# Ожидание, пока sshd поднимется и startup-скрипт создаст marker
function Wait-ForSshAndPrep {
  param(
    [string]$InstanceName,
    [string]$Zone,
    [string]$SshPrivateKeyPath,
    [string]$ExternalIp,
    [int]$TimeoutMinutes = 30
  )

  Write-Host "`nWaiting for SSH (key auth) and prep marker on VM..."
  $start = Get-Date
  $ready = $false
  $attempt = 0

  while (-not $ready) {

    if (((Get-Date) - $start).TotalMinutes -gt $TimeoutMinutes) {
      throw "Timeout ($TimeoutMinutes min) waiting for SSH / prep marker on $InstanceName."
    }

    $attempt++

    try {
      $remoteCmd = "powershell -NoProfile -Command ""if (Test-Path 'C:\webapp\system_prep_complete.txt') { 'READY' } else { 'NOT_READY' }"""

      $sshArgs = @(
        "-i", $SshPrivateKeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=$($env:USERPROFILE)\.ssh\known_hosts",
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=10",
        "mykola@$ExternalIp",
        $remoteCmd
      )

      $output = & ssh @sshArgs 2>&1

      if ($output -match "READY") {
        Write-Host "`n✔ SSH по ключу работает, system_prep_complete.txt найден."
        $ready = $true
      }
      else {
        Write-Host "SSH откликнулся, но prep ещё не завершён (attempt #$attempt)..."
        Start-Sleep -Seconds 15
      }
    }
    catch {
      Write-Host -NoNewline "."
      Start-Sleep -Seconds 15
    }
  }
}

# ---------- cleanup old DNS transaction.yaml ----------

$possibleTxnLocations = @(
  (Join-Path $PSScriptRoot "transaction.yaml"),
  (Join-Path (Get-Location).Path "transaction.yaml"),
  "C:\Windows\System32\transaction.yaml"
)

foreach ($f in $possibleTxnLocations) {
  if (Test-Path $f) {
    Write-Host "Removing stale DNS transaction file: $f"
    Remove-Item $f -Force -ErrorAction SilentlyContinue
  }
}

# --- gcloud available? ---
try { Invoke-Gcloud "version" | Out-Null } catch {
  Stop-Transcript | Out-Null
  throw "gcloud not found or not running. Add it to PATH."
}

# --- config ---
Invoke-Gcloud "config set project $Project"       | Out-Null
Invoke-Gcloud "config set compute/region $Region" | Out-Null
Invoke-Gcloud "config set compute/zone $Zone"     | Out-Null

# --- Open port 445 (SMB) in Google Cloud Firewall ---
$firewallRuleName = "allow-smb-445"

$existingRules = Invoke-Gcloud "compute firewall-rules list --format=""value(name)"""
if ($existingRules -split "`r?`n" -contains $firewallRuleName) {
  Write-Host "Firewall rule '$firewallRuleName' for port 445 already exists."
}
else {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule '$firewallRuleName'..."
  }
  else {
    Write-Host "Creating firewall rule '$firewallRuleName'..."
    Invoke-Gcloud "compute firewall-rules create $firewallRuleName --allow=tcp:445 --direction=INGRESS --priority=1000 --network=$Network --target-tags=webapp --source-ranges=0.0.0.0/0 --description=Allow-SMB-TCP-445-for-deployment"
    Write-Host "✔ Firewall rule '$firewallRuleName' created."
  }
}

# --- enable Secret Manager API ---
$secretApi = "secretmanager.googleapis.com"
Write-Host "`nChecking Secret Manager API ($secretApi)…"

$enabledServicesRaw = Invoke-Gcloud "services list --enabled --format=""value(config.name)"" --filter=""config.name:$secretApi"""
$enabledServices = $enabledServicesRaw -split "`r?`n" | Where-Object { $_ -ne "" }

if ($enabledServices -contains $secretApi) {
  Write-Host "Secret Manager API already enabled for project $Project."
}
else {
  if ($WhatIf) {
    Write-Host "WhatIf: would enable Secret Manager API for project $Project."
  }
  else {
    Write-Host "Enabling Secret Manager API for project $Project…"
    Invoke-Gcloud "services enable $secretApi" | Out-Null
    Write-Host "✔ Secret Manager API enabled."
  }
}

# --- startup script path ---
$startup = Join-Path $PSScriptRoot "startup_webapp_windows.ps1"
if (-not (Test-Path $startup)) {
  Stop-Transcript | Out-Null
  throw "startup_webapp_windows.ps1 not found next to the script: $startup"
}
$sha = (Get-FileHash -Algorithm SHA256 $startup).Hash
Write-Host "Startup script: $startup"
Write-Host "SHA256: $sha"

# --- SSH key pair for user 'mykola' (passwordless SSH) ---
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

$sshKeyInfo = Ensure-SshKeyPair -KeyBasePath (Join-Path $PSScriptRoot "mykola_ssh")
$script:SshPrivateKeyPath = $sshKeyInfo.Private
$SshPublicKeyPath         = $sshKeyInfo.Public

# чтобы Invoke-SSH видел ключ
$script:SshPrivateKeyPath = $SshPrivateKeyPath

Write-Host "SSH key pair will be used for user 'mykola':"
Write-Host "  Private key: $SshPrivateKeyPath"
Write-Host "  Public key : $SshPublicKeyPath"

# --- recreate instance template if exists ---
$allTpl = Invoke-Gcloud 'compute instance-templates list --format="value(name)"'
if (($allTpl -split "`r?`n") -contains $TemplateName) {
  if ($WhatIf) { Write-Host "WhatIf: would delete template '$TemplateName' (skipped)." }
  else {
    Write-Host "Deleting existing template '$TemplateName'..."
    Invoke-Gcloud "compute instance-templates delete $TemplateName --quiet" | Out-Null
  }
}

# --- network/subnet args ---
$netArgs = @("--network=$Network")
if ($Subnetwork) { $netArgs += "--subnet=$Subnetwork" }

# --- metadata ---
$metadataInline = "domain=$Domain,email=$AcmeEmail"
$metadataFileKV = "windows-startup-script-ps1=""$startup"",ssh-public-key=""$SshPublicKeyPath"""

# --- create instance template ---
$argsList = @(
  "compute", "instance-templates", "create", $TemplateName,
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
}
else {
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
$addressName = "${InstanceName}-external-ip"

$globalList = Invoke-Gcloud 'compute addresses list --global --format="value(name)"'
if (($globalList -split "`r?`n") -contains $addressName) {
  if ($WhatIf) {
    Write-Host "WhatIf: would delete GLOBAL address '$addressName' (skipped)."
  }
  else {
    Write-Host "Deleting GLOBAL address '$addressName' (regional $Region needed)..."
    Invoke-Gcloud "compute addresses delete $addressName --global --quiet" | Out-Null
  }
}

$regionalList = Invoke-Gcloud "compute addresses list --regions=$Region --format=""value(name)"""
if (-not (($regionalList -split "`r?`n") -contains $addressName)) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create regional address '$addressName' in $Region (skipped)."
  }
  else {
    Invoke-Gcloud "compute addresses create $addressName --region=$Region" | Out-Null
    Write-Host "✔ Regional external address '$addressName' created in $Region."
  }
}
$externalIp = (Invoke-Gcloud "compute addresses describe $addressName --region=$Region --format=""value(address)""" | Select-Object -First 1).Trim()
Write-Host "Planned External IP (regional $Region): $externalIp"

# --- очистка старого host key для этого IP из known_hosts ---
$khPath = Join-Path $env:USERPROFILE ".ssh\known_hosts"
if (Test-Path $khPath) {
    Write-Host "Cleaning old SSH host key for $externalIp..."
    $oldLines = Get-Content $khPath

    # Строки в known_hosts обычно начинаются с "IP " или "IP,"
    $cleanLines = $oldLines | Where-Object {
        -not (($_ -like "$externalIp *") -or ($_ -like "$externalIp,*"))
    }

    Set-Content $khPath $cleanLines
}

# === CREATE VM with this IP ===
$niParts = @()
if ($Subnetwork) { $niParts += "subnet=$Subnetwork" } else { $niParts += "network=$Network" }
$niParts += "address=$externalIp"
$niArg = "--network-interface=" + ($niParts -join ",")

$createVmArgs = @(
  "compute", "instances", "create", $InstanceName,
  "--source-instance-template=$TemplateName",
  $niArg
)
$createVm = ($createVmArgs -join ' ')
if ($WhatIf) {
  Write-Host "WhatIf: would run -> gcloud $createVm"
}
else {
  Invoke-Gcloud $createVm | Out-Null
  Write-Host "✔ Instance '$InstanceName' created with static External IP $externalIp."
}

# --- get internal/external IPs ---
$internalIp = (Invoke-Gcloud "compute instances describe $InstanceName --zone=$Zone --format=""value(networkInterfaces[0].networkIP)""" | Select-Object -First 1).Trim()
$nowExternalIp = $externalIp
Write-Host "Current Internal IP: $internalIp"
Write-Host "External IP (pinned at create): $nowExternalIp"

# ---------- FIREWALL RULES (RDP + HTTP/HTTPS + SMTP relay) ----------
$fwListRaw = Invoke-Gcloud 'compute firewall-rules list --format="value(name)"'
$fwNames = $fwListRaw -split "`r?`n"

if (-not ($fwNames -contains "allow-rdp")) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule 'allow-rdp'."
  }
  else {
    Write-Host "Creating firewall rule 'allow-rdp' (tcp:3389)..."
    Invoke-Gcloud "compute firewall-rules create allow-rdp --network=$Network --direction=INGRESS --priority=1000 --action=ALLOW --rules=tcp:3389 --source-ranges=0.0.0.0/0 --target-tags=rdp-allow"
  }
}
else {
  Write-Host "Firewall rule 'allow-rdp' already exists."
}

if (-not ($fwNames -contains "allow-webapp-http-https")) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule 'allow-webapp-http-https'."
  }
  else {
    Write-Host "Creating firewall rule 'allow-webapp-http-https' (tcp:80,443)..."
    Invoke-Gcloud "compute firewall-rules create allow-webapp-http-https --network=$Network --direction=INGRESS --priority=1000 --action=ALLOW --rules=tcp:80,tcp:443 --source-ranges=0.0.0.0/0 --target-tags=webapp"
  }
}
else {
  Write-Host "Firewall rule 'allow-webapp-http-https' already exists."
}

if (-not ($fwNames -contains "allow-smtp-relay")) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule 'allow-smtp-relay'."
  }
  else {
    Write-Host "Creating firewall rule 'allow-smtp-relay' (tcp:587)..."
    Invoke-Gcloud "compute firewall-rules create allow-smtp-relay --network=$Network --direction=INGRESS --priority=1000 --action=ALLOW --rules=tcp:587 --source-ranges=0.0.0.0/0 --target-tags=webapp"
  }
}
else {
  Write-Host "Firewall rule 'allow-smtp-relay' already exists."
}

# ---------- Resend DNS records (DKIM, SPF, DMARC) ----------
Write-Host "`nConfiguring Resend DNS records…"

$zoneDnsName = (Invoke-Gcloud "dns managed-zones describe $DnsZoneName --format=""value(dnsName)"" --quiet" | Select-Object -First 1).Trim()
if ([string]::IsNullOrWhiteSpace($zoneDnsName)) {
  throw "DNS zone '$DnsZoneName' not found in project $Project."
}

$baseDomainRaw = $zoneDnsName.TrimEnd('.')
$mailHost = "mail.$baseDomainRaw"

$dkimName  = "resend._domainkey.$mailHost."
$spfName   = "send.$mailHost."
$dmarcName = "_dmarc.$mailHost."

$dkimTxtValue   = '"' + $ResendDkimValue + '"'
$spfTxtValue    = '"' + $ResendSpfValue + '"'
$dmarcTxtValue  = '"' + $ResendDmarcValue + '"'
$spfMxRrData    = "10 feedback-smtp.eu-west-1.amazonses.com."

Write-Host "DEBUG: Base Domain: '$baseDomainRaw'"
Write-Host "DEBUG: Mail Host:   '$mailHost'"
Write-Host "DEBUG: DKIM Name:   '$dkimName'"

function Ensure-DnsRecord {
  param (
    [string]$Name,
    [string]$Type,
    [string]$Value
  )

  Write-Host "Checking $Type record: $Name"
    
  try {
    $current = (Invoke-Gcloud "dns record-sets list --zone=$DnsZoneName --name=""$Name"" --type=$Type --format=""value(rrdatas[0])""")
    if ($null -ne $current) { $current = $current.Trim() }
  }
  catch { $current = $null }

  if ($current -eq $Value) {
    Write-Host "  ✔ Record up to date."
  }
  else {
    if ($WhatIf) {
      Write-Host "  WhatIf: Would update $Name ($Type) -> $Value"
    }
    else {
      Invoke-Gcloud "dns record-sets transaction start --zone=$DnsZoneName" | Out-Null
      if ($current) {
        Invoke-Gcloud "dns record-sets transaction remove --zone=$DnsZoneName --name=""$Name"" --type=$Type --ttl=300 ""$current""" | Out-Null
      }
      Invoke-Gcloud "dns record-sets transaction add --zone=$DnsZoneName --name=""$Name"" --type=$Type --ttl=300 $Value" | Out-Null
      Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
      Write-Host "  ✔ Record updated."
    }
  }
}

Ensure-DnsRecord -Name $dkimName  -Type "TXT" -Value $dkimTxtValue
Ensure-DnsRecord -Name $spfName   -Type "TXT" -Value $spfTxtValue
Ensure-DnsRecord -Name $spfName   -Type "MX"  -Value """$spfMxRrData"""
Ensure-DnsRecord -Name $dmarcName -Type "TXT" -Value $dmarcTxtValue

# ---------- Secret Manager ----------
Write-Host "`nConfiguring Secret Manager secret '$MailSecretName'…"

$secretListRaw = Invoke-Gcloud "secrets list --format=""value(name)"""
$secretNames = $secretListRaw -split "`r?`n"

if ($secretNames -contains $MailSecretName) {
  Write-Host "Secret '$MailSecretName' already exists in project $Project."
}
else {
  if ($WhatIf) {
    Write-Host "WhatIf: would create secret '$MailSecretName' in Secret Manager."
  }
  else {
    Write-Host "Creating secret '$MailSecretName' in Secret Manager (automatic replication)…"
    Invoke-Gcloud "secrets create $MailSecretName --replication-policy=automatic" | Out-Null
    Write-Host "✔ Secret '$MailSecretName' created."
  }
}

# ---------- SERVICE ACCOUNT + JSON KEY FOR SECRET MANAGER (ADC via GOOGLE_APPLICATION_CREDENTIALS) ----------
# создаём сервис-аккаунт, выдаём роль Secret Manager Secret Accessor и генерируем JSON-ключ
$SaId       = "simple-social-email-sa"
$SaEmail    = "$SaId@$Project.iam.gserviceaccount.com"
$SaKeyLocal = Join-Path $PSScriptRoot "gcp-email-sa-key.json"

Write-Host "`nConfiguring service account '$SaEmail' for Secret Manager…"

# 1) сервис-аккаунт
$saListRaw = Invoke-Gcloud "iam service-accounts list --project=$Project --format=""value(email)"""
$saEmails  = $saListRaw -split "`r?`n" | Where-Object { $_ -ne "" }

if ($saEmails -contains $SaEmail) {
    Write-Host "Service account '$SaEmail' already exists."
} else {
    if ($WhatIf) {
        Write-Host "WhatIf: would create service account '$SaEmail'."
    } else {
        Write-Host "Creating service account '$SaEmail'…"
        Invoke-Gcloud "iam service-accounts create $SaId --project=$Project --display-name=""Simple Social Email SA""" | Out-Null
        Write-Host "✔ Service account '$SaEmail' created."
    }
}

# 2) выдаём роль Secret Manager Secret Accessor на проект
if ($WhatIf) {
    Write-Host "WhatIf: would bind roles/secretmanager.secretAccessor for $SaEmail."
} else {
    Write-Host "Binding roles/secretmanager.secretAccessor for $SaEmail on project $Project…"
    Invoke-Gcloud "projects add-iam-policy-binding $Project --member=""serviceAccount:$SaEmail"" --role=""roles/secretmanager.secretAccessor""" | Out-Null
    Write-Host "✔ IAM binding applied."
}

# 3) JSON-ключ (локальный файл)
if ($WhatIf) {
    Write-Host "WhatIf: would create key file $SaKeyLocal."
} else {
    if (Test-Path $SaKeyLocal) {
        Write-Host "Key file $SaKeyLocal already exists locally, keeping it."
    } else {
        Write-Host "Creating new JSON key for $SaEmail -> $SaKeyLocal…"
        Invoke-Gcloud "iam service-accounts keys create `"$SaKeyLocal`" --iam-account=$SaEmail" | Out-Null
        Write-Host "✔ Key file created."
    }
}

# --- 5. POST DEPLOY: WAIT FOR WINDOWS CREDENTIALS ---
Write-Host "`n------------------------------------------------------"
Write-Host "Waiting for Windows to boot (polling credentials)..."
Write-Host "------------------------------------------------------"

$credsReceived = $false
$password = ""
$startTime = Get-Date

while (-not $credsReceived) {
  if (((Get-Date) - $startTime).TotalMinutes -gt 20) { 
    Write-Error "Timeout waiting for VM boot (reset-windows-password)."
    break 
  }
  try {
    $jsonOutput = Invoke-Gcloud "compute reset-windows-password $InstanceName --zone=$Zone --user=mykola --quiet --format=json"
    $creds = ($jsonOutput -join "`n") | ConvertFrom-Json
    $password = $creds.password
    $credsReceived = $true
        
    Write-Host "`n===== CREDENTIALS =====" -ForegroundColor Cyan
    Write-Host "User:     mykola"
    Write-Host "Password: $password"
    Write-Host "IP:       $externalIp"
    Write-Host "=======================" -ForegroundColor Cyan
  }
  catch {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 20
  }
}

if ($credsReceived) {
    # Ждём, пока стартовый скрипт поднимет sshd и создаст marker
    Wait-ForSshAndPrep -InstanceName $InstanceName -Zone $Zone -SshPrivateKeyPath $SshPrivateKeyPath -ExternalIp $externalIp

    Write-Host "`nStarting Software Installation..."
    $InstallScriptLocal = Join-Path $PSScriptRoot "install_software.ps1"
    $InstallScriptLauncherLocal = Join-Path $PSScriptRoot "install_software_launcher.ps1"
    
    if (Test-Path $InstallScriptLocal) {

        # 1) Копируем скрипт install_software.ps1 на ВМ в C:\webapp
        $scpArgs = @(
            "-i", $SshPrivateKeyPath,
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=30",
            $InstallScriptLocal,
            "mykola@${externalIp}:C:\webapp\install_software.ps1"
        )
        & scp @scpArgs

        # 1b) Копируем скрипт install_software_launcher.ps1 на ВМ в C:\webapp
        $scpArgs = @(
            "-i", $SshPrivateKeyPath,
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=30",
            $InstallScriptLauncherLocal,
            "mykola@${externalIp}:C:\webapp\install_software_launcher.ps1"
        )
        & scp @scpArgs

        # 1c) Копируем JSON-ключ сервис-аккаунта на ВМ и выставляем GOOGLE_APPLICATION_CREDENTIALS
        if (Test-Path $SaKeyLocal) {
            Write-Host "Copying service account key to VM..."
            $scpArgs = @(
                "-i", $SshPrivateKeyPath,
                "-o", "StrictHostKeyChecking=no",
                "-o", "ConnectTimeout=30",
                $SaKeyLocal,
                "mykola@${externalIp}:C:\webapp\gcp-email-sa.json"
            )
            & scp @scpArgs

            $ServerUser = "mykola"
            $ServerIP   = $externalIp

            Write-Host "Setting system-wide GOOGLE_APPLICATION_CREDENTIALS on VM..."
            $remoteEnvCmd = 'powershell -NoProfile -Command "setx GOOGLE_APPLICATION_CREDENTIALS ''C:\webapp\gcp-email-sa.json'' /M"'
            Invoke-SSH $ServerUser $ServerIP $remoteEnvCmd
            Write-Host "GOOGLE_APPLICATION_CREDENTIALS configured."
        }

        Write-Host "Installing VS 2026, GitHub, etc (Remote Exec)..." -ForegroundColor Yellow

        # 2) Запускаем install_software.ps1 в фоне (через Start-Process)
        # Одинарные кавычки с двойными внутри — ничего не трогается при передаче в ssh.
        $remoteCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\webapp\install_software_launcher.ps1'

        Write-Host "DEBUG remoteCmd: $remoteCmd"  # чтобы видеть в логах, что реально шлём

        $ServerUser = "mykola"
        $ServerIP   = $externalIp
        Invoke-SSH $ServerUser $ServerIP $remoteCmd
        Write-Host "DEBUG ssh exit code (install_software): $LASTEXITCODE"

        Write-Host "NOTE: Base software will install now, SQL Server after reboot." -ForegroundColor Yellow
        Write-Host "Logs will be polled from the VM (user_install.log, then sql_install.log)." -ForegroundColor DarkGray

        # =====================================================================
        # PHASE 1: user_install.log (до ребута)
        # =====================================================================
        Write-Host "----- user_install.log -----" -ForegroundColor Cyan

        Watch-RemoteLog `
          -User        $ServerUser `
          -Ip          $ServerIP `
          -KeyPath     $SshPrivateKeyPath `
          -RemoteLogPath "C:\webapp\logs\user_install.log" `
          -DoneMarker  "INSTALLATION SCRIPT COMPLETED" `
          -IntervalSeconds 10

        # =====================================================================
        # Ждём, пока ВМ перезагрузится и снова примет SSH
        # =====================================================================
        Write-Host "Waiting for VM to come back after reboot..." -ForegroundColor Yellow
        while ($true) {
            try {
                Invoke-SSH $ServerUser $ServerIP "echo ok" 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { break }
            } catch { }

            Write-Host "SSH still not ready after reboot. Waiting 20 seconds..." -ForegroundColor DarkGray
            Start-Sleep 10
        }

        Write-Host "SSH is back. Switching to SQL installation log..." -ForegroundColor Green

        # =====================================================================
        # PHASE 2: sql_install.log (ждём 'SQL install completed')
        # =====================================================================
        Write-Host "----- sql_install.log -----" -ForegroundColor Cyan

        Watch-RemoteLog `
          -User        $ServerUser `
          -Ip          $ServerIP `
          -KeyPath     $SshPrivateKeyPath `
          -RemoteLogPath "C:\webapp\logs\sql_install.log" `
          -DoneMarker  "SQL install completed" `
          -IntervalSeconds 10

        Write-Host "SQL installation completed (marker found in sql_install.log). Finishing deploy..." -ForegroundColor Green
        Write-Host "DONE." -ForegroundColor Green
    }
}

Stop-Transcript | Out-Null
Write-Host "`nDONE." -ForegroundColor Green
