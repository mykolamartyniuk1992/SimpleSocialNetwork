# =============================================
# deploy_gcloud_infrastructure.ps1
# =============================================

Param(
  [Parameter(Mandatory=$true)] [string]$Project,
  [string]$Region       = "us-central1",
  [string]$Zone         = "us-central1-c",
  [string]$TemplateName = "webapp-windows-template",
  [string]$InstanceName = "webapp-windows",

  # network/disks/tags
  [string]$Network      = "default",
  [string]$Subnetwork   = "",                      # can be left empty for regional default
  [string]$MachineType  = "e2-standard-4",
  [string]$BootDiskType = "pd-balanced",
  [string]$BootDiskSize = "60GB",
  [string]$Tags         = "webapp,rdp-allow,https-allow,http-allow",

  # metadata for startup
  [string]$Domain       = "simplesocialnetwork.mykolamartyniuk1992.dev",
  [string]$AcmeEmail    = "mykola.martyniuk.1992@gmail.com",

  # Cloud DNS
  [string]$DnsZoneName  = "mykolamartyniuk1992-dev",

  # Secret Manager: имя секрета для пароля почты
  [string]$MailSecretName = "resend-email-api-key",

  # Resend DNS values (для отправки почты через mail.mykolamartyniuk1992.dev)
  [string]$ResendDkimValue  = "PASTE_DKIM_VALUE_FROM_RESEND",
  [string]$ResendSpfValue   = "v=spf1 include:amazonses.com ~all",
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

# --- gcloud available? ---
try { Invoke-Gcloud "version" | Out-Null } catch {
  Stop-Transcript | Out-Null
  throw "gcloud not found or not running. Add it to PATH."
}

# --- config ---
Invoke-Gcloud "config set project $Project"       | Out-Null
Invoke-Gcloud "config set compute/region $Region" | Out-Null
Invoke-Gcloud "config set compute/zone $Zone"     | Out-Null

# --- Открытие порта 445 (SMB) в Google Cloud Firewall ---
$firewallRuleName   = "allow-smb-445"
$firewallRuleExists = $false

try {
    Invoke-Gcloud "compute firewall-rules describe $firewallRuleName --format=""value(name)""" | Out-Null
    $firewallRuleExists = $true
} catch {
    $firewallRuleExists = $false
}

if ($firewallRuleExists) {
    Write-Host "Firewall rule '$firewallRuleName' for port 445 already exists."
} else {
    if ($WhatIf) {
        Write-Host "WhatIf: would create firewall rule '$firewallRuleName' to allow TCP:445 from any IP."
    } else {
        Write-Host "Creating firewall rule '$firewallRuleName' to allow TCP:445 from any IP..."
        Invoke-Gcloud "compute firewall-rules create $firewallRuleName --allow=tcp:445 --direction=INGRESS --priority=1000 --network=$Network --target-tags=webapp --source-ranges=0.0.0.0/0 --description=""Allow SMB (TCP 445) for deployment"""
        Write-Host "✔ Firewall rule '$firewallRuleName' created."
    }
}

# --- enable Secret Manager API ---
$secretApi = "secretmanager.googleapis.com"
Write-Host "`nChecking Secret Manager API ($secretApi)…"

$enabledServicesRaw = Invoke-Gcloud "services list --enabled --format=""value(config.name)"" --filter=""config.name:$secretApi"""
$enabledServices     = $enabledServicesRaw -split "`r?`n" | Where-Object { $_ -ne "" }

if ($enabledServices -contains $secretApi) {
  Write-Host "Secret Manager API already enabled for project $Project."
} else {
  if ($WhatIf) {
    Write-Host "WhatIf: would enable Secret Manager API for project $Project."
  } else {
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
$metadataFileKV = "windows-startup-script-ps1=""$startup"""

# --- create instance template ---
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
$addressName = "${InstanceName}-external-ip"

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
Write-Host "Current Internal IP: $internalIp"
Write-Host "External IP (pinned at create): $nowExternalIp"

# ---------- FIREWALL RULES (RDP + HTTP/HTTPS + SMTP relay) ----------
$fwListRaw = Invoke-Gcloud 'compute firewall-rules list --format="value(name)"'
$fwNames   = $fwListRaw -split "`r?`n"

# RDP
if (-not ($fwNames -contains "allow-rdp")) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule 'allow-rdp'."
  } else {
    Write-Host "Creating firewall rule 'allow-rdp' (tcp:3389)..."
    Invoke-Gcloud "compute firewall-rules create allow-rdp --network=$Network --direction=INGRESS --priority=1000 --action=ALLOW --rules=tcp:3389 --source-ranges=0.0.0.0/0 --target-tags=rdp-allow"
  }
} else {
  Write-Host "Firewall rule 'allow-rdp' already exists."
}

# HTTP/HTTPS
if (-not ($fwNames -contains "allow-webapp-http-https")) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule 'allow-webapp-http-https'."
  } else {
    Write-Host "Creating firewall rule 'allow-webapp-http-https' (tcp:80,443)..."
    Invoke-Gcloud "compute firewall-rules create allow-webapp-http-https --network=$Network --direction=INGRESS --priority=1000 --action=ALLOW --rules=tcp:80,tcp:443 --source-ranges=0.0.0.0/0 --target-tags=webapp"
  }
} else {
  Write-Host "Firewall rule 'allow-webapp-http-https' already exists."
}

# SSH (tcp:22)
if (-not ($fwNames -contains "allow-webapp-ssh")) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule 'allow-webapp-ssh'."
  } else {
    Write-Host "Creating firewall rule 'allow-webapp-ssh' (tcp:22)..."
    Invoke-Gcloud "compute firewall-rules create allow-webapp-ssh --network=$Network --direction=INGRESS --priority=1000 --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0 --target-tags=webapp"
  }
} else {
  Write-Host "Firewall rule 'allow-webapp-ssh' already exists."
}

# SMTP relay (tcp:587)
if (-not ($fwNames -contains "allow-smtp-relay")) {
  if ($WhatIf) {
    Write-Host "WhatIf: would create firewall rule 'allow-smtp-relay'."
  } else {
    Write-Host "Creating firewall rule 'allow-smtp-relay' (tcp:587)..."
    Invoke-Gcloud "compute firewall-rules create allow-smtp-relay --network=$Network --direction=INGRESS --priority=1000 --action=ALLOW --rules=tcp:587 --source-ranges=0.0.0.0/0 --target-tags=webapp"
  }
} else {
  Write-Host "Firewall rule 'allow-smtp-relay' already exists."
}

# ---------- Cloud DNS A-record ----------
$zoneDnsName = (Invoke-Gcloud "dns managed-zones describe $DnsZoneName --format=""value(dnsName)""" | Select-Object -First 1)
if (-not $zoneDnsName) {
  throw "DNS managed zone '$DnsZoneName' not found in project $Project."
}
$fqdn = if ($Domain.EndsWith('.')) { $Domain } else { "$Domain." }

$currentDnsIp = (Invoke-Gcloud "dns record-sets list --zone=$DnsZoneName --name=$fqdn --type=A --format=""value(rrdatas[0])""" | Select-Object -First 1)
$currentDnsIp = if ($null -ne $currentDnsIp) { $currentDnsIp.Trim() } else { "" }

if ($currentDnsIp -and $currentDnsIp -eq $nowExternalIp) {
  Write-Host "DNS A-record already points to $nowExternalIp ($fqdn)."
} else {
  if ($currentDnsIp) {
    Write-Host "Updating DNS: $fqdn $currentDnsIp -> $nowExternalIp"
    if (-not $WhatIf) {
      Invoke-Gcloud "dns record-sets transaction start --zone=$DnsZoneName" | Out-Null
      Invoke-Gcloud "dns record-sets transaction remove --zone=$DnsZoneName --name=$fqdn --type=A --ttl=300 $currentDnsIp" | Out-Null
      Invoke-Gcloud "dns record-sets transaction add    --zone=$DnsZoneName --name=$fqdn --type=A --ttl=300 $nowExternalIp" | Out-Null
      Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
      Write-Host "✔ DNS updated."
    } else {
      Write-Host "WhatIf: would replace A-record $fqdn $currentDnsIp -> $nowExternalIp"
    }
  } else {
    Write-Host "Creating DNS A-record: $fqdn -> $nowExternalIp"
    if (-not $WhatIf) {
      Invoke-Gcloud "dns record-sets transaction start --zone=$DnsZoneName" | Out-Null
      Invoke-Gcloud "dns record-sets transaction add --zone=$DnsZoneName --name=$fqdn --type=A --ttl=300 $nowExternalIp" | Out-Null
      Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
      Write-Host "✔ DNS created."
    } else {
      Write-Host "WhatIf: would create A-record $fqdn -> $nowExternalIp"
    }
  }
}

# ---------- Resend DNS records (DKIM, SPF, DMARC) ----------
Write-Host "`nConfiguring Resend DNS records…"

# Чистим возможный transaction.yaml, чтобы не ломать transaction start
try {
    $txnPath = Join-Path (Get-Location) "transaction.yaml"
    if (Test-Path $txnPath) {
        Remove-Item $txnPath -Force -ErrorAction SilentlyContinue
        Write-Host "Old DNS transaction file 'transaction.yaml' removed."
    }
} catch { }

$baseDomain = $zoneDnsName.TrimEnd('.')      # mykolamartyniuk1992.dev
$mailHost   = "mail.$baseDomain"             # mail.mykolamartyniuk1992.dev

# Формируем имена БЕЗ точки в конце, затем вычищаем пробелы/переводы строк
$dkimNameRaw  = "resend._domainkey.$mailHost"
$spfNameRaw   = "send.$mailHost"
$dmarcNameRaw = "_dmarc.$mailHost"

$dkimName  = ($dkimNameRaw  -replace '\s+', '').Trim()
$spfName   = ($spfNameRaw   -replace '\s+', '').Trim()
$dmarcName = ($dmarcNameRaw -replace '\s+', '').Trim()

# Значения TXT – заворачиваем в кавычки для gcloud
$dkimTxtValue  = '"' + $ResendDkimValue  + '"'
$spfTxtValue   = '"' + $ResendSpfValue   + '"'
$dmarcTxtValue = '"' + $ResendDmarcValue + '"'

# MX для отправки (из Resend): send.mail -> feedback-smtp.eu-west-1.amazonses.com, priority 10
$spfMxRrData = "10 feedback-smtp.eu-west-1.amazonses.com."

# ----- DKIM TXT -----
$currentDkim = (
  Invoke-Gcloud "dns record-sets list --zone=$DnsZoneName --name=""$dkimName"" --type=TXT --format=""value(rrdatas[0])""" |
  Select-Object -First 1
)
$currentDkim = if ($null -ne $currentDkim) { $currentDkim.Trim() } else { "" }

if ($currentDkim) {
  Write-Host "Updating DKIM TXT record: $dkimName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    Invoke-Gcloud "dns record-sets transaction remove  --zone=$DnsZoneName --name=""$dkimName"" --type=TXT --ttl=300 $currentDkim" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$dkimName"" --type=TXT --ttl=300 $dkimTxtValue" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ DKIM TXT updated."
  } else {
    Write-Host "WhatIf: would update DKIM TXT record."
  }
} else {
  Write-Host "Creating DKIM TXT record: $dkimName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$dkimName"" --type=TXT --ttl=300 $dkimTxtValue" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ DKIM TXT record created."
  } else {
    Write-Host "WhatIf: would create DKIM TXT record."
  }
}

# ----- SPF TXT -----
$currentSpfTxt = (
  Invoke-Gcloud "dns record-sets list --zone=$DnsZoneName --name=""$spfName"" --type=TXT --format=""value(rrdatas[0])""" |
  Select-Object -First 1
)
$currentSpfTxt = if ($null -ne $currentSpfTxt) { $currentSpfTxt.Trim() } else { "" }

if ($currentSpfTxt) {
  Write-Host "Updating SPF TXT record: $spfName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    Invoke-Gcloud "dns record-sets transaction remove  --zone=$DnsZoneName --name=""$spfName"" --type=TXT --ttl=300 $currentSpfTxt" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$spfName"" --type=TXT --ttl=300 $spfTxtValue" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ SPF TXT updated."
  } else {
    Write-Host "WhatIf: would update SPF TXT record."
  }
} else {
  Write-Host "Creating SPF TXT record: $spfName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$spfName"" --type=TXT --ttl=300 $spfTxtValue" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ SPF TXT record created."
  } else {
    Write-Host "WhatIf: would create SPF TXT record."
  }
}

# ----- SPF MX (send.mail.mykolamartyniuk1992.dev) -----
$currentSpfMx = (
  Invoke-Gcloud "dns record-sets list --zone=$DnsZoneName --name=""$spfName"" --type=MX --format=""value(rrdatas[0])""" |
  Select-Object -First 1
)
$currentSpfMx = if ($null -ne $currentSpfMx) { $currentSpfMx.Trim() } else { "" }

if ($currentSpfMx -and $currentSpfMx -eq $spfMxRrData) {
  # Уже нужное значение — ничего не делаем
  Write-Host "SPF MX already correct: $spfName -> $currentSpfMx"
}
elseif ($currentSpfMx) {
  Write-Host "Updating SPF MX record: $spfName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    # ВАЖНО: завернуть rrdata в кавычки, чтобы это был один аргумент
    Invoke-Gcloud "dns record-sets transaction remove  --zone=$DnsZoneName --name=""$spfName"" --type=MX --ttl=300 ""$currentSpfMx""" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$spfName"" --type=MX --ttl=300 ""$spfMxRrData""" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ SPF MX updated."
  } else {
    Write-Host "WhatIf: would update SPF MX record."
  }
}
else {
  Write-Host "Creating SPF MX record: $spfName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$spfName"" --type=MX --ttl=300 ""$spfMxRrData""" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ SPF MX record created."
  } else {
    Write-Host "WhatIf: would create SPF MX record."
  }
}

# ----- DMARC TXT -----
$currentDmarc = (
  Invoke-Gcloud "dns record-sets list --zone=$DnsZoneName --name=""$dmarcName"" --type=TXT --format=""value(rrdatas[0])""" |
  Select-Object -First 1
)
$currentDmarc = if ($null -ne $currentDmarc) { $currentDmarc.Trim() } else { "" }

if ($currentDmarc) {
  Write-Host "Updating DMARC TXT record: $dmarcName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    Invoke-Gcloud "dns record-sets transaction remove  --zone=$DnsZoneName --name=""$dmarcName"" --type=TXT --ttl=300 $currentDmarc" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$dmarcName"" --type=TXT --ttl=300 $dmarcTxtValue" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ DMARC TXT updated."
  } else {
    Write-Host "WhatIf: would update DMARC TXT record."
  }
} else {
  Write-Host "Creating DMARC TXT record: $dmarcName"
  if (-not $WhatIf) {
    Invoke-Gcloud "dns record-sets transaction start   --zone=$DnsZoneName" | Out-Null
    Invoke-Gcloud "dns record-sets transaction add     --zone=$DnsZoneName --name=""$dmarcName"" --type=TXT --ttl=300 $dmarcTxtValue" | Out-Null
    Invoke-Gcloud "dns record-sets transaction execute --zone=$DnsZoneName" | Out-Null
    Write-Host "✔ DMARC TXT record created."
  } else {
    Write-Host "WhatIf: would create DMARC TXT record."
  }
}

# ---------- Secret Manager: secret for SMTP password ----------
Write-Host "`nConfiguring Secret Manager secret '$MailSecretName'…"

$secretListRaw = Invoke-Gcloud "secrets list --format=""value(name)"""
$secretNames   = $secretListRaw -split "`r?`n"

if ($secretNames -contains $MailSecretName) {
  Write-Host "Secret '$MailSecretName' already exists in project $Project."
} else {
  if ($WhatIf) {
    Write-Host "WhatIf: would create secret '$MailSecretName' in Secret Manager."
  } else {
    Write-Host "Creating secret '$MailSecretName' in Secret Manager (automatic replication)…"
    Invoke-Gcloud "secrets create $MailSecretName --replication-policy=automatic" | Out-Null
    Write-Host "✔ Secret '$MailSecretName' created."
  }
}

Write-Host ""
Write-Host "To put your SMTP password into this secret, run locally:"
Write-Host "  echo -n 'YOUR_PASSWORD_HERE' | gcloud secrets versions add $MailSecretName --data-file=-"
Write-Host "To read it from VM (with proper IAM):"
Write-Host "  gcloud secrets versions access latest --secret=$MailSecretName"
Write-Host ""

# ---------- Summary ----------
Write-Host ""
Write-Host "===== Summary ====="
Write-Host "Template:        $TemplateName"
Write-Host "Instance:        $InstanceName"
Write-Host "External IP:     $nowExternalIp"
Write-Host "Internal IP:     $internalIp"
Write-Host "DNS A-record:    $fqdn -> $nowExternalIp"
Write-Host "SPF TXT:         $spfName  $ResendSpfValue"
Write-Host "Mail secret:     $MailSecretName (Secret Manager)"
Write-Host "Startup script:  $startup (SHA256: $sha)"
Write-Host "Log file:        $logFile"

Stop-Transcript | Out-Null
