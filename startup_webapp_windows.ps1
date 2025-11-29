# ==============================================================================
# startup_webapp_windows.ps1
# STAGE 1: Minimal Prep (User + SSH + Keys)
# ==============================================================================
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (Test-Path "C:\webapp\system_prep_complete.txt") { exit 0 }

New-Item -Force -ItemType Directory "C:\webapp\logs" | Out-Null
function Write-Log($msg) { 
    "[$(Get-Date -Format 'HH:mm:ss')] $msg" | Tee-Object -FilePath "C:\webapp\logs\startup.log" -Append 
}

try {
    Write-Log "STARTING PREP..."

    # SSH Setup
    $SshUser = "mykola"
    $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
    if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null }
    
    Stop-Service sshd -ErrorAction SilentlyContinue

    if (-not (Get-LocalUser -Name $SshUser -ErrorAction SilentlyContinue)) {
        $p = ConvertTo-SecureString "TempPass123!" -AsPlainText -Force
        New-LocalUser -Name $SshUser -Password $p -PasswordNeverExpires | Out-Null
        Add-LocalGroupMember -Group "Administrators" -Member $SshUser
    }

    # Paths
    $UserDir = "C:\Users\$SshUser"; $SshDir = "$UserDir\.ssh"; $AuthKey = "$SshDir\authorized_keys"
    $AdminKeyPath = "C:\ProgramData\ssh\administrators_authorized_keys"
    
    if (-not (Test-Path $SshDir)) { New-Item -ItemType Directory -Force -Path $SshDir | Out-Null }

    # Fetch Key
    $wc = New-Object System.Net.WebClient; $wc.Headers['Metadata-Flavor'] = 'Google'
    $UserPublicKey = $wc.DownloadString("http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh-public-key")

    if (-not [string]::IsNullOrWhiteSpace($UserPublicKey)) {
        $UserPublicKey = $UserPublicKey.Trim()
        
        # Key in User Folder (Standard)
        Set-Content $AuthKey $UserPublicKey -Encoding Ascii -Force
        
        # Permissions (Standard)
        $acl = Get-Acl $SshDir
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }
        $rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        $type = [System.Security.AccessControl.AccessControlType]::Allow
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($SshUser, $rights, $type)))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", $rights, $type)))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", $rights, $type)))
        Set-Acl $SshDir $acl
        Set-Acl $AuthKey $acl

        # Key in Admin Folder (Windows Requirement)
        if (-not (Test-Path (Split-Path $AdminKeyPath))) { New-Item -Type Directory (Split-Path $AdminKeyPath) -Force | Out-Null }
        Set-Content $AdminKeyPath $UserPublicKey -Encoding Ascii -Force
        
        # Permissions (Admin Strict)
        $cmd = "icacls ""$AdminKeyPath"" /inheritance:r /grant ""Administrators:F"" /grant ""SYSTEM:F"""
        Invoke-Expression $cmd | Out-Null
    }

    # Config
    $ConfigPath = "C:\ProgramData\ssh\sshd_config"
    if (Test-Path $ConfigPath) {
        $conf = Get-Content $ConfigPath -Raw
        # Fix: Ensure we comment out default admin match
        $conf = $conf -replace 'Match Group administrators', '# Match Group administrators'
        $conf = $conf -replace 'AuthorizedKeysFile __PROGRAMDATA__', '# AuthorizedKeysFile __PROGRAMDATA__'
        
        # Append robust settings
        $extra = "`nPubkeyAuthentication yes`nPasswordAuthentication no`nStrictModes no`nAuthorizedKeysFile .ssh/authorized_keys"
        if ($conf -notmatch "StrictModes no") { Set-Content $ConfigPath ($conf + $extra) -Encoding UTF8 }
    }

    # Restart Service (Critical) + автозапуск на будущих перезагрузках
    $svc = Get-Service sshd -ErrorAction SilentlyContinue
    if ($svc) {
        # Важно: чтобы при каждом ребуте sshd стартовал сам
        if ($svc.StartType -ne 'Automatic') {
            Set-Service sshd -StartupType Automatic
        }

        Restart-Service sshd -Force
    }

    netsh advfirewall firewall add rule name="SSH" dir=in action=allow protocol=TCP localport=22 | Out-Null

    # 3. Marker
    New-Item -Path "C:\webapp\system_prep_complete.txt" -ItemType File -Force | Out-Null
    Write-Log "PREP DONE."

} catch { Write-Log "ERROR: $_" }