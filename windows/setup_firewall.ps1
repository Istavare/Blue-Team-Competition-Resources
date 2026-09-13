# =========================
# Windows Firewall Control Script (with Logging + Backup/Restore + Temporary Block/Unblock)
# =========================

# Log file path
$logPath = "C:\FirewallScriptLog.txt"

# State paths for temporary block/unblock
$stateDir  = "C:\FirewallBackups"
$stateFile = Join-Path $stateDir "TEMP_BLOCK_LAST.wfw"
$stateFlag = Join-Path $stateDir "TEMP_BLOCK_ACTIVE.txt"

# Essential ports config: if this file exists, it is used; otherwise defaults in code are used
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$essentialPortsConfigPath = Join-Path $scriptDir "essential_ports.json"

# Optional: if you group your rules, set this (safe even if unused)
$RuleGroup = "CCDC-Lockdown"

# Default essential ports (used when essential_ports.json is not present)
function Get-DefaultEssentialPorts {
    @(
        @{Port=80;   Protocol="TCP"; Name="HTTP"},
        @{Port=443;  Protocol="TCP"; Name="HTTPS"},
        @{Port=53;   Protocol="TCP"; Name="DNS-TCP"},
        @{Port=53;   Protocol="UDP"; Name="DNS-UDP"},
        @{Port=123;  Protocol="UDP"; Name="NTP"},
        @{Port=25;   Protocol="TCP"; Name="SMTP"},
        @{Port=110;  Protocol="TCP"; Name="POP3"},
        @{Port=389;  Protocol="TCP"; Name="LDAP"},
        @{Port=389;  Protocol="UDP"; Name="LDAP-UDP"},
        @{Port=636;  Protocol="TCP"; Name="LDAPS"},
        @{Port=445;  Protocol="TCP"; Name="SMB"},
        @{Port=3389; Protocol="TCP"; Name="RDP"},
        @{Port=8000; Protocol="TCP"; Name="Splunk-Web"},
        @{Port=9997; Protocol="TCP"; Name="Splunk-Logs"}
    )
}

# Load essential ports: from config file if present, otherwise from default in code
function Get-EssentialPorts {
    if (Test-Path -LiteralPath $essentialPortsConfigPath) {
        try {
            $json = Get-Content -Path $essentialPortsConfigPath -Raw -Encoding UTF8
            $rows = $json | ConvertFrom-Json
            $list = @()
            foreach ($obj in $rows) {
                $portNum = [int]$obj.Port
                $proto = [string]$obj.Protocol
                $name = [string]$obj.Name
                if ($portNum -ge 1 -and $portNum -le 65535 -and $proto -match '^(TCP|UDP)$') {
                    $list += @{ Port = $portNum; Protocol = $proto; Name = $name }
                }
            }
            if ($list.Count -gt 0) {
                Write-Host "Using essential ports from config: $essentialPortsConfigPath" -ForegroundColor Cyan
                return $list
            }
        } catch {
            Write-Host "Could not parse config file, using defaults. Error: $_" -ForegroundColor Yellow
        }
    }
    Write-Host "Using default essential ports (no config file or invalid config)." -ForegroundColor Cyan
    return Get-DefaultEssentialPorts
}

# Function to log actions
function Log-Action {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "[$timestamp] $Message"
}

# Helper to format port display (handles "Any", empty, or specific ports)
function Format-PortDisplay {
    param ($PortValue)
    if ($null -eq $PortValue) { return "-" }
    $arr = @($PortValue)
    $unique = $arr | Select-Object -Unique
    $str = ($unique | Where-Object { $null -ne $_ -and $_ -ne 'Any' }) -join ","
    if ([string]::IsNullOrWhiteSpace($str)) { return "Any" }
    if ($str.Length -gt 16) { return $str.Substring(0, 13) + "..." }
    return $str
}

# Function to display all enabled firewall rules (with ports when available)
function Show-FirewallRules {
    $rules = Get-NetFirewallRule | Where-Object Enabled -eq 'True'

    Write-Host "`nCurrently Enabled Firewall Rules (ports shown when available):`n" -ForegroundColor Cyan
    Write-Host ("{0,-45} {1,-10} {2,-10} {3,-10} {4,-18} {5,-18}" -f "DisplayName", "Direction", "Action", "Profile", "LocalPort", "RemotePort")
    Write-Host ("-" * 120)

    foreach ($r in $rules) {
        $pf = $null
        try {
            $pf = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $r -ErrorAction Stop
        } catch {
            # Rule has no port filter (e.g. ICMP, or application-based with Any)
        }
        $localPorts  = Format-PortDisplay -PortValue $(if ($pf) { $pf.LocalPort } else { $null })
        $remotePorts = Format-PortDisplay -PortValue $(if ($pf) { $pf.RemotePort } else { $null })

        Write-Host ("{0,-45} {1,-10} {2,-10} {3,-10} {4,-18} {5,-18}" -f `
            $r.DisplayName, `
            $r.Direction, `
            $r.Action, `
            $r.Profile, `
            $localPorts, `
            $remotePorts)
    }
    Write-Host ""
}

# Function to backup firewall rules
function Backup-FirewallRules {
    param (
        [string]$BackupDir = "C:\FirewallBackups"
    )
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    $BackupPath = "$BackupDir\FirewallRulesBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').wfw"
    netsh advfirewall export $BackupPath | Out-Null
    if (Test-Path $BackupPath) {
        Write-Host "Backup successful! Rules saved at $BackupPath"
        Log-Action -Message "Backup created at $BackupPath"
    } else {
        Write-Host "Backup failed!"
        Log-Action -Message "Backup failed!"
    }
    return $BackupPath
}

# Function to restore firewall rules
function Restore-FirewallRules {
    param (
        [string]$BackupDir = "C:\FirewallBackups"
    )
    $backupFiles = Get-ChildItem -Path $BackupDir -Filter "FirewallRulesBackup*.wfw" -ErrorAction SilentlyContinue
    if (-not $backupFiles -or $backupFiles.Count -eq 0) {
        Write-Host "No backups found in $BackupDir!"
        return
    }
    Write-Host "Available Backups:"
    $backupFiles | ForEach-Object { Write-Host "$($_.Name)" }
    $selectedBackup = Read-Host "Enter the full name of the backup file to restore (e.g., FirewallRulesBackup_20250117_123456.wfw)"
    $backupPath = "$BackupDir\$selectedBackup"
    if (Test-Path $backupPath) {
        netsh advfirewall import $backupPath
        Write-Host "Firewall rules restored from $backupPath!"
        Log-Action -Message "Firewall rules restored from $backupPath"
    } else {
        Write-Host "Backup file not found at $backupPath!"
        Log-Action -Message "Failed to restore backup: $backupPath not found"
    }
}

# Function to block all ports and allow specific ones
function Block-All-And-Allow-Specific-Ports {
    # Confirm action
    $confirmation = Read-Host "This will block all ports except the ones you specify. Do you want to continue? (Y/N)"
    if ($confirmation -notmatch "^[Yy]$") {
        Write-Host "Action cancelled."
        return
    }

    # Backup existing rules
    $backupPath = Backup-FirewallRules
    if (-not (Test-Path $backupPath)) {
        Write-Host "Backup failed! Exiting script to avoid losing existing rules." -ForegroundColor Red
        return
    }

    # Load allowed ports: from essential_ports.json if present, else defaults
    $allowedPorts = Get-EssentialPorts

    # Enable ICMP (Ping)
    Write-Host "Allowing ICMP traffic..."
    $icmpRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Allow-Inbound-ICMP" }
    if (-not $icmpRule) {
        New-NetFirewallRule -DisplayName "Allow-Inbound-ICMP" -Protocol ICMPv4 -Direction Inbound -Action Allow -Profile Any -Group $RuleGroup
        Log-Action -Message "Created ICMP allow rule"
    } else {
        Write-Host "ICMP rule already exists. Skipping creation." -ForegroundColor Yellow
    }

    # Block all inbound and outbound traffic by default
    Write-Host "Setting default inbound and outbound rules to block..."
    Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Block
    Log-Action -Message "Set default inbound/outbound rules to block"

    # Remove all existing rules not in our group (backup can recreate them on restore)
    Write-Host "Removing all firewall rules except those in group '$RuleGroup'..."
    $otherRules = Get-NetFirewallRule -All | Where-Object { $_.Group -ne $RuleGroup }
    $count = ($otherRules | Measure-Object).Count
    if ($count -gt 0) {
        $otherRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        Write-Host "Removed $count existing rule(s). Restore from backup to bring them back." -ForegroundColor Yellow
        Log-Action -Message "Removed $count firewall rules (non-$RuleGroup)"
    }

    # Create rules for allowed ports
    Write-Host "Creating rules for allowed ports..."
    foreach ($port in $allowedPorts) {
        $name = $port.Name
        $protocol = $port.Protocol
        $portNumber = $port.Port

        # Inbound: LocalPort
        $inboundRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Allow-Inbound-$name" }
        if (-not $inboundRule) {
            New-NetFirewallRule -DisplayName "Allow-Inbound-$name" -Direction Inbound -Protocol $protocol -LocalPort $portNumber -Action Allow -Profile Any -Group $RuleGroup
            Log-Action -Message "Created inbound rule for $name"
        } else {
            Write-Host "Inbound rule for $name already exists. Skipping creation." -ForegroundColor Yellow
        }

        # Outbound: RemotePort (correct for most outbound allow cases)
        $outboundRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Allow-Outbound-$name" }
        if (-not $outboundRule) {
            New-NetFirewallRule -DisplayName "Allow-Outbound-$name" -Direction Outbound -Protocol $protocol -RemotePort $portNumber -Action Allow -Profile Any -Group $RuleGroup
            Log-Action -Message "Created outbound rule for $name"
        } else {
            Write-Host "Outbound rule for $name already exists. Skipping creation." -ForegroundColor Yellow
        }
    }

    # Allow DNS resolver to reach external servers (outbound remote port 53)
    Write-Host "Allowing DNS resolver to reach external servers..."
    $dnsResolverRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Allow-Outbound-DNS-Resolver" }
    if (-not $dnsResolverRule) {
        New-NetFirewallRule -DisplayName "Allow-Outbound-DNS-Resolver" -Direction Outbound -Protocol UDP -RemotePort 53 -Action Allow -Profile Any -Group $RuleGroup
        Log-Action -Message "Created DNS resolver rule"
    } else {
        Write-Host "DNS resolver rule already exists. Skipping creation." -ForegroundColor Yellow
    }

    # Allow general outbound traffic for HTTP and HTTPS (remote ports)
    Write-Host "Allowing general outbound HTTP/HTTPS traffic..."
    $httpHttpsRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Allow-General-Outbound-HTTP-HTTPS" }
    if (-not $httpHttpsRule) {
        New-NetFirewallRule -DisplayName "Allow-General-Outbound-HTTP-HTTPS" -Direction Outbound -Protocol TCP -RemotePort @(80, 443) -Action Allow -Profile Any -Group $RuleGroup
        Log-Action -Message "Created general outbound HTTP/HTTPS rule"
    } else {
        Write-Host "General outbound HTTP/HTTPS rule already exists. Skipping creation." -ForegroundColor Yellow
    }

    Write-Host "Specified ports have been allowed. Use option 3 (Restore) to bring back removed rules from backup."
    Log-Action -Message "Completed 'Block all and allow essential ports'"
}

# Function to allow a specific port
function Open-Port {
    param (
        [int]$PortNumber,
        [string]$Protocol = "TCP"
    )

    if ($PortNumber -lt 1 -or $PortNumber -gt 65535) {
        Write-Host "Invalid port number! Port must be between 1 and 65535." -ForegroundColor Red
        return
    }

    if ($Protocol -notin @("TCP", "UDP")) {
        Write-Host "Invalid protocol! Protocol must be TCP or UDP." -ForegroundColor Red
        return
    }

    Write-Host "Opening port $PortNumber for $Protocol traffic..."

    $existingAllowRule = Get-NetFirewallRule | Where-Object {
        ($_.DisplayName -eq "Allow-Inbound-Port-$PortNumber" -and $_.Direction -eq "Inbound") -or
        ($_.DisplayName -eq "Allow-Outbound-Port-$PortNumber" -and $_.Direction -eq "Outbound")
    }

    if ($existingAllowRule) {
        Write-Host "Allow rules already exist for port $PortNumber. Skipping creation." -ForegroundColor Yellow
    } else {
        New-NetFirewallRule -DisplayName "Allow-Inbound-Port-$PortNumber" -Direction Inbound -Protocol $Protocol -LocalPort $PortNumber -Action Allow -Profile Any -Group $RuleGroup
        # For outbound, remote port is typically what you want
        New-NetFirewallRule -DisplayName "Allow-Outbound-Port-$PortNumber" -Direction Outbound -Protocol $Protocol -RemotePort $PortNumber -Action Allow -Profile Any -Group $RuleGroup

        Write-Host "Port $PortNumber has been opened."
        Log-Action -Message "Opened port $PortNumber for $Protocol traffic"
    }
}

# Function to block a specific port
function Block-Port {
    param (
        [int]$PortNumber,
        [string]$Protocol = "TCP"
    )

    if ($PortNumber -lt 1 -or $PortNumber -gt 65535) {
        Write-Host "Invalid port number! Port must be between 1 and 65535." -ForegroundColor Red
        return
    }

    if ($Protocol -notin @("TCP", "UDP")) {
        Write-Host "Invalid protocol! Protocol must be TCP or UDP." -ForegroundColor Red
        return
    }

    Write-Host "Blocking port $PortNumber for $Protocol traffic..."

    $existingBlockRule = Get-NetFirewallRule | Where-Object {
        ($_.DisplayName -eq "Block-Inbound-Port-$PortNumber" -and $_.Direction -eq "Inbound") -or
        ($_.DisplayName -eq "Block-Outbound-Port-$PortNumber" -and $_.Direction -eq "Outbound")
    }

    if ($existingBlockRule) {
        Write-Host "Block rules already exist for port $PortNumber. Skipping creation." -ForegroundColor Yellow
    } else {
        New-NetFirewallRule -DisplayName "Block-Inbound-Port-$PortNumber" -Direction Inbound -Protocol $Protocol -LocalPort $PortNumber -Action Block -Profile Any -Group $RuleGroup
        # For outbound, remote port is typically what you want
        New-NetFirewallRule -DisplayName "Block-Outbound-Port-$PortNumber" -Direction Outbound -Protocol $Protocol -RemotePort $PortNumber -Action Block -Profile Any -Group $RuleGroup

        Write-Host "Port $PortNumber has been blocked."
        Log-Action -Message "Blocked port $PortNumber for $Protocol traffic"
    }
}

# =========================
# Temporary Block / Unblock 
# =========================

function Temporary-Block-All-Traffic {
    $confirmation = Read-Host "This will temporarily DISABLE all firewall rules and block ALL inbound/outbound traffic. You may lose remote access. Continue? (Y/N)"
    if ($confirmation -notmatch "^[Yy]$") {
        Write-Host "Action cancelled." -ForegroundColor Yellow
        return
    }

    # Ensure state dir exists
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    # Save current firewall policy so we can revert exactly (remove existing file first so export always overwrites)
    Write-Host "Saving current firewall rules so we can revert later..." -ForegroundColor Cyan
    if (Test-Path $stateFile) { Remove-Item $stateFile -Force -ErrorAction SilentlyContinue }
    netsh advfirewall export $stateFile | Out-Null
    if (-not (Test-Path $stateFile)) {
        Write-Host "Failed to save firewall state. Not blocking traffic." -ForegroundColor Red
        Log-Action "Temporary block FAILED: could not export to $stateFile"
        return
    }

    Write-Host "Disabling ALL firewall rules..." -ForegroundColor Yellow
    Get-NetFirewallRule -All | Set-NetFirewallRule -Enabled False -ErrorAction SilentlyContinue

    Write-Host "Turning firewall ON and setting default inbound/outbound to BLOCK (all profiles)..." -ForegroundColor Red
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Block

    # Mark active
    Set-Content -Path $stateFlag -Value (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") -Force

    Write-Host "Temporary block is ACTIVE. Everything should be blocked in/out." -ForegroundColor Red
    Log-Action "Temporary block ENABLED: exported $stateFile, disabled ALL rules, default inbound/outbound BLOCK, firewall ON"
}

function Temporary-Unblock-And-Revert {
    if (-not (Test-Path $stateFile)) {
        Write-Host "No saved firewall state found at $stateFile. Cannot revert." -ForegroundColor Red
        Log-Action "Temporary unblock FAILED: missing state file $stateFile"
        return
    }

    Write-Host "Reverting firewall rules to the saved state..." -ForegroundColor Cyan
    netsh advfirewall import $stateFile

    # Cleanup marker
    if (Test-Path $stateFlag) { Remove-Item $stateFlag -Force -ErrorAction SilentlyContinue }

    Write-Host "Temporary block is OFF. Firewall rules reverted." -ForegroundColor Green
    Log-Action "Temporary block DISABLED: imported state from $stateFile"
}

function Temporary-Block-Menu {
    if (Test-Path $stateFlag) {
        Temporary-Unblock-And-Revert
    } else {
        Write-Host "Temporary block will start in 5 seconds... Ctrl+C to abort." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        Temporary-Block-All-Traffic
    }
}


# Main menu
function Main-Menu {
    while ($true) {
        Show-FirewallRules

        Write-Host "Select an option:"
        Write-Host "1) Block all and allow essential ports"
        Write-Host "2) Backup Only"
        Write-Host "3) Restore to a saved backup"
        Write-Host "4) Open a rule for allowing a port"
        Write-Host "5) Open a rule for blocking a port"
        Write-Host "6) Temporary block/unblock all traffic (reverts to previous rules)"
        Write-Host "7) Exit"
        $choice = Read-Host "Enter your choice"

        switch ($choice) {
            1 { Block-All-And-Allow-Specific-Ports }
            2 { Backup-FirewallRules }
            3 { Restore-FirewallRules }
            4 {
                $portNumber = Read-Host "Enter the port number to allow"
                $protocol = Read-Host "Enter the protocol (TCP/UDP)"
                Open-Port -PortNumber $portNumber -Protocol $protocol
            }
            5 {
                $portNumber = Read-Host "Enter the port number to block"
                $protocol = Read-Host "Enter the protocol (TCP/UDP)"
                Block-Port -PortNumber $portNumber -Protocol $protocol
            }
            6 { Temporary-Block-Menu }
            7 {
                Write-Host "Exiting... Goodbye!" -ForegroundColor Green
                exit
            }
            default {
                Write-Host "Invalid choice! Please select a valid option." -ForegroundColor Red
            }
        }
    }
}

# Run the main menu
Main-Menu
