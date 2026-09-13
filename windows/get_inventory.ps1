#Requires -Version 5.1
#Requires -RunAsAdministrator
# Collect evidence without changing host configuration. No software installs.
$outputDir = Join-Path $env:ProgramData ("CCDC\inventory_" + $env:COMPUTERNAME + "_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $outputDir -ErrorAction Stop | Out-Null

function Save-Report {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action 2>&1 | Out-File (Join-Path $outputDir $Name) -Width 240
    } catch {
        $_ | Out-File (Join-Path $outputDir $Name) -Append
        Write-Warning "$Name could not be completed: $_"
    }
}

Save-Report 'system.txt' {
    Get-CimInstance Win32_ComputerSystem | Format-List Name, Domain, DomainRole
    Get-CimInstance Win32_OperatingSystem | Format-List Caption, Version, LastBootUpTime
    ipconfig /all
}
Save-Report 'services.txt' {
    Get-CimInstance Win32_Service | Format-List Name, State, StartMode, StartName, PathName
}
Save-Report 'processes.txt' {
    Get-CimInstance Win32_Process | Format-List ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine
}
Save-Report 'connections.txt' {
    Get-NetTCPConnection | Format-Table -AutoSize
    Get-NetUDPEndpoint | Format-Table -AutoSize
}
Save-Report 'users.txt' {
    $role = (Get-CimInstance Win32_ComputerSystem).DomainRole
    if ($role -ge 4) {
        Import-Module ActiveDirectory -ErrorAction Stop
        Get-ADUser -Filter * -Properties PasswordLastSet | Format-Table SamAccountName, Enabled, PasswordLastSet
    } else {
        Get-LocalUser | Format-Table Name, Enabled, LastLogon, PasswordLastSet
        Get-LocalGroupMember -SID 'S-1-5-32-544' | Format-Table Name, ObjectClass
    }
}
Save-Report 'tasks.txt' { Get-ScheduledTask | Format-List TaskPath, TaskName, State, Actions, Principal }
Save-Report 'startup.txt' { Get-CimInstance Win32_StartupCommand | Format-List Name, Command, Location, User }
Save-Report 'firewall.txt' { Get-NetFirewallProfile | Format-List * }
Save-Report 'audit.txt' { auditpol /get /category:* }

netsh advfirewall export (Join-Path $outputDir 'firewall_before.wfw')
if ($LASTEXITCODE -ne 0) { Write-Warning 'Firewall backup failed. Back up using setup_firewall.ps1 before changing rules.' }
foreach ($log in @('Security', 'System')) {
    wevtutil epl $log (Join-Path $outputDir "$log.evtx")
    if ($LASTEXITCODE -ne 0) { Write-Warning "$log event export failed." }
}
Write-Host "Reports saved to $outputDir" -ForegroundColor Cyan
Write-Host 'Check reports for errors. Keep evidence in the restricted team location, outside the repository.'
