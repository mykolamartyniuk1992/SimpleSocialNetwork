# =============================================
# startup_webapp_windows.ps1
# - HTTPS-first on Caddy
# - ACME-safe: staging while DNS != external IP
# - NSSM service for Caddy
# - No here-strings inside here-strings (no parser errors)
# =============================================

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ---------- helpers ----------
function Get-Meta {
  param([string]$Path)
  try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers['Metadata-Flavor'] = 'Google'
    return $wc.DownloadString("http://metadata.google.internal/computeMetadata/v1/$Path")
  } catch { return $null }
}
function Get-ExternalIP { (Get-Meta "instance/network-interfaces/0/access-configs/0/external-ip") }
function Dns-A-Records($name) {
  try { (Resolve-DnsName -Type A -Name $name -ErrorAction Stop | Select-Object -ExpandProperty IPAddress) }
  catch {
    $out = nslookup $name 2>$null
    if ($out) { ($out -split "`r?`n" | Where-Object { $_ -match 'Address:\s+(\d+\.\d+\.\d+\.\d+)$' } | ForEach-Object { ($_ -replace '.*Address:\s+','').Trim() }) }
  }
}
function Write-Log($msg) { "[{0}] {1}" -f (Get-Date -Format s), $msg | Add-Content $global:logMain }

# ---------- metadata ----------
$Domain = Get-Meta "instance/attributes/domain"; if (-not $Domain) { $Domain = "webapp-windows.mykolamartyniuk1992.dev" }
$Email  = Get-Meta "instance/attributes/email";  if (-not $Email)  { $Email  = "mykola.martyniuk.1992@gmail.com" }

# ---------- paths / logs ----------
$AppRoot   = "C:\webapp"
$WwwRoot   = "C:\webapp\wwwroot"
$LogsRoot  = "C:\webapp\logs"
$WorkDir   = "C:\webapp"
$Caddyfile = "C:\webapp\Caddyfile"
$Kestrel   = "http://127.0.0.1:8080"

New-Item -Force -ItemType Directory $AppRoot,$WwwRoot,$LogsRoot | Out-Null
$global:logMain = Join-Path $LogsRoot "startup.log"
Write-Log "startup begin; domain=$Domain; email=$Email"

# ---------- enable long paths ----------
try {
  New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Force | Out-Null
  New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -PropertyType DWord -Value 1 -Force | Out-Null
  Write-Log "LongPathsEnabled=1"
} catch { Write-Log "WARN LongPathsEnabled: $_" }

# ---------- chocolatey ----------
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
  try {
    Write-Log "installing chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  } catch { Write-Log "ERROR choco install: $_"; throw }
}
$env:Path += ";C:\ProgramData\chocolatey\bin"
$chocoArgs = "-y --no-progress --limit-output"
$chocoOut  = Join-Path $LogsRoot "choco-stdout.log"
$chocoErr  = Join-Path $LogsRoot "choco-stderr.log"

try {
  Write-Log "installing git nssm caddy..."
  Start-Process choco -ArgumentList "install git nssm caddy $chocoArgs" -Wait -NoNewWindow `
    -RedirectStandardOutput $chocoOut -RedirectStandardError $chocoErr
  Write-Log "choco done"
} catch { Write-Log "ERROR choco packages: $_"; throw }

# ---------- placeholder static ----------
if (-not (Test-Path (Join-Path $WwwRoot 'index.html'))) {
@"
<!doctype html>
<html><head><meta charset="utf-8"><title>Webapp Windows</title></head>
<body>
  <h1>It works over HTTPS</h1>
  <p>Domain: $Domain</p>
  <p>Static files are served by Caddy from C:\webapp\wwwroot.</p>
  <p>Non-static requests under /app are proxied to $Kestrel.</p>
</body></html>
"@ | Set-Content -Path (Join-Path $WwwRoot "index.html") -Encoding UTF8
}

# ---------- Windows firewall ----------
try {
  netsh advfirewall firewall add rule name="Webapp HTTP 80"  dir=in action=allow protocol=TCP localport=80  | Out-Null
  netsh advfirewall firewall add rule name="Webapp HTTPS 443" dir=in action=allow protocol=TCP localport=443 | Out-Null
  Write-Log "firewall 80/443 opened"
} catch { Write-Log "WARN firewall: $_" }

# ---------- Enable Remote Desktop (RDP) ----------
try {
  # Разрешить RDP на уровне системы
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' `
                   -Name 'fDenyTSConnections' -Value 0 -Force

  # Включить RDP-правила в Windows Firewall
  netsh advfirewall firewall set rule group="remote desktop" new enable=Yes | Out-Null

  Write-Log "RDP enabled (Terminal Services + firewall group 'Remote Desktop')."
} catch {
  Write-Log "WARN enabling RDP: $_"
}

# ---------- Enable PowerShell Remoting (WinRM) ----------
try {
    Write-Log "Enabling PowerShell remoting (WinRM)..."
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Log "PSRemoting enabled."
}
catch {
    Write-Log "WARN Enable-PSRemoting: $_"
}

# ---------- Caddyfile builders ----------
function New-CaddyfileProduction {
@"
{
  email $Email
}

http://$Domain {
  redir https://$Domain{uri}
}

$Domain {
  root * "$WwwRoot"

  @static {
    file {
      try_files {path} {path}/index.html
    }
  }

  handle @static {
    file_server
  }

  handle_path /app/* {
    reverse_proxy $Kestrel
  }

  log {
    output file "$LogsRoot\caddy-access.log"
  }
}
"@
}
function New-CaddyfileStaging {
@"
{
  email $Email
  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

http://$Domain {
  redir https://$Domain{uri}
}

$Domain {
  root * "$WwwRoot"

  file_server

  handle_path /app/* {
    reverse_proxy $Kestrel
  }

  log {
    output file "$LogsRoot\caddy-access.log"
  }
}
"@
}

# ---------- DNS==IP guard (avoid ACME rate limits) ----------
$extIP    = (Get-ExternalIP).Trim()
$deadline = (Get-Date).AddMinutes(10)
$dnsOK    = $false

Write-Log "external-ip=$extIP; checking DNS for $Domain"
while ((Get-Date) -lt $deadline) {
  $ips = @(Dns-A-Records $Domain) | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }
  if ($ips -and ($ips -contains $extIP)) { $dnsOK = $true; break }
  Write-Log "DNS not ready yet. A=$($ips -join ',') expected=$extIP; sleep 15s"
  Start-Sleep -Seconds 15
}

# ---------- select config and validate ----------
if ($dnsOK) {
  Write-Log "DNS OK; writing PRODUCTION Caddyfile"
  New-CaddyfileProduction | Set-Content -Path $Caddyfile -Encoding UTF8
} else {
  Write-Log "DNS not OK; writing STAGING Caddyfile"
  New-CaddyfileStaging | Set-Content -Path $Caddyfile -Encoding UTF8
}

$caddyExe = (Get-Command caddy.exe -ErrorAction Stop).Source
$valOut   = Join-Path $LogsRoot 'caddy-validate.out.log'
$valErr   = Join-Path $LogsRoot 'caddy-validate.err.log'
try {
  Write-Log "validating Caddyfile..."
  Start-Process $caddyExe -ArgumentList "validate --config `"$Caddyfile`" --adapter caddyfile" `
    -Wait -NoNewWindow -RedirectStandardOutput $valOut -RedirectStandardError $valErr
  Write-Log "Caddyfile validate OK"
} catch {
  Write-Log "ERROR Caddyfile validate: $_ (see $valOut / $valErr)"
  throw
}

# ---------- Install/run Caddy via NSSM ----------
$nssmLog = Join-Path $LogsRoot 'nssm-install.log'
try {
  Write-Log "recreating caddy service via NSSM"
  Stop-Service caddy -ErrorAction SilentlyContinue
  sc.exe delete caddy | Out-Null
  Start-Sleep -Seconds 1

  & nssm install caddy $caddyExe 'run' '--config' $Caddyfile '--adapter' 'caddyfile' *> $nssmLog
  & nssm set caddy AppDirectory $WorkDir
  & nssm set caddy Start SERVICE_AUTO_START
  & nssm set caddy AppStdout "$LogsRoot\caddy-service.out.log"
  & nssm set caddy AppStderr "$LogsRoot\caddy-service.err.log"
  & nssm set caddy AppThrottle 1500
  & nssm set caddy AppStopMethodConsole 1500
  & nssm set caddy AppStopMethodWindow 1500
  & nssm set caddy AppStopMethodThreads 1500
  & nssm set caddy AppExit Default Restart

  Start-Service caddy
  Write-Log "caddy service started"
} catch {
  Write-Log "ERROR caddy service: $_ (see $nssmLog and caddy-service.*.log)"
  throw
}

# ---------- auto-switch STAGING -> PRODUCTION (without here-string!) ----------
if (-not $dnsOK) {
  $switchScript = "C:\webapp\switch-caddy-to-prod.ps1"

  $L = @()
  $L += '$ErrorActionPreference = ''Stop'''
  $L += 'function Get-Meta { param([string]$Path) try { $wc = New-Object System.Net.WebClient; $wc.Headers[''Metadata-Flavor'']=''Google''; return $wc.DownloadString(''http://metadata.google.internal/computeMetadata/v1/'' + $Path) } catch { return $null } }'
  $L += 'function Dns-A-Records($name){ try{ (Resolve-DnsName -Type A -Name $name -ErrorAction Stop | Select-Object -ExpandProperty IPAddress) } catch { $out = nslookup $name 2>$null; if ($out){ ($out -split "`r?`n" | ? { $_ -match ''Address:\s+(\d+\.\d+\.\d+\.\d+)$'' } | % { ($_ -replace ''.*Address:\s+'''','''').Trim() }) } }'

  $L += ("`$Domain    = '{0}'" -f $Domain)
  $L += ("`$Email     = '{0}'" -f $Email)
  $L += ("`$Kestrel   = '{0}'" -f $Kestrel)
  $L += ("`$LogsRoot  = '{0}'" -f $LogsRoot)
  $L += ("`$Caddyfile = '{0}'" -f $Caddyfile)

  $L += '$extIP = (Get-Meta ''instance/network-interfaces/0/access-configs/0/external-ip'').Trim()'
  $L += '$ips  = @(Dns-A-Records $Domain)'
  $L += 'if ($ips -and ($ips -contains $extIP)) {'

  $L += '$c = @()'
  $L += '$c += ''{'''
  $L += '$c += ''  email '' + $Email'
  $L += '$c += ''}'''
  $L += '$c += '''''
  $L += '$c += ''http://'' + $Domain + '' {'''
  $L += '$c += ''  redir https://'' + $Domain + ''{uri}'''
  $L += '$c += ''}'''
  $L += '$c += '''''
  $L += '$c += $Domain + '' {'''
  $L += '$c += ''  root * "C:\webapp\wwwroot"'''
  $L += '$c += '''''
  $L += '$c += ''  @static {'''
  $L += '$c += ''    file {'''
  $L += '$c += ''      try_files {path} {path}/index.html'''
  $L += '$c += ''    }'''
  $L += '$c += ''  }'''
  $L += '$c += '''''
  $L += '$c += ''  handle @static {'''
  $L += '$c += ''    file_server'''
  $L += '$c += ''  }'''
  $L += '$c += '''''
  $L += '$c += ''  handle_path /app/* {'''
  $L += '$c += ''    reverse_proxy '' + $Kestrel'
  $L += '$c += ''  }'''
  $L += '$c += '''''
  $L += '$c += ''  log {'''
  $L += '$c += ''    output file "'' + $LogsRoot + ''\caddy-access.log"'''
  $L += '$c += ''  }'''
  $L += '$c += ''}'''

  $L += '$c -join "`r`n" | Set-Content -Path $Caddyfile -Encoding UTF8'
  $L += '& (Get-Command caddy.exe).Source reload --config "$Caddyfile" --adapter caddyfile'
  $L += '}'

  $L -join "`r`n" | Set-Content -Path $switchScript -Encoding UTF8

  $tsName = 'CaddySwitchToProduction'
  $time   = (Get-Date).AddMinutes(2).ToString('HH:mm')
  schtasks /Create /TN $tsName /TR "powershell -ExecutionPolicy Bypass -File `"$switchScript`"" /SC ONCE /ST $time /RL HIGHEST /F | Out-Null
  schtasks /Run /TN $tsName | Out-Null
  Write-Log "scheduled one-shot DNS re-check to switch Caddy to production"
}

# ---------- health check ----------
try {
  Start-Sleep -Seconds 3
  Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1" -Headers @{ Host = $Domain } -TimeoutSec 5 -MaximumRedirection 0 | Out-Null
  Write-Log "local HTTP ok (expected redirect to HTTPS)"
} catch { Write-Log "WARN local HTTP: $_" }

Write-Log "startup completed"
