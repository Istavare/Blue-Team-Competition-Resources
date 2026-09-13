<#
.SYNOPSIS
    Active Directory User Management Script
.DESCRIPTION
    Menu-driven script for managing AD users including password changes, 
    enable/disable operations, and backup/restore functionality.
    Automatically installs ActiveDirectory module if not present.
.NOTES
    Author: AD Management Script
    Version: 1.1
    Requires: Administrator privileges for installation
#>

function Write-Status {
    param(
        [string]$Message,
        [string]$Status,
        [string]$Color = "White"
    )
    $symbol = switch ($Status) {
        "SUCCESS" { "[OK]" }
        "ERROR" { "[X]" }
        "WARNING" { "[!]" }
        "INFO" { "[i]" }
        default { "[?]" }
    }
    Write-Host "$symbol " -NoNewline -ForegroundColor $Color
    Write-Host $Message
}

function Show-Menu {
    Clear-Host
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "ACTIVE DIRECTORY USER MANAGEMENT" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    
    # Show Current User Context
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Running as: $currentUser" -ForegroundColor Green
    Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
    
    # Show All Users Always
    try {
        $allUsers = Get-AllADUsers -Properties "DisplayName", "Enabled", "EmailAddress"
        Write-Host "Current AD Users:" -ForegroundColor White
        $allUsers | Format-Table -Property SamAccountName, DisplayName, Enabled, EmailAddress -AutoSize | Out-String | Write-Host
    }
    catch {
        Write-Status "Could not fetch user list" "WARNING" "Yellow"
    }

    Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "1. Change Individual User Password" -ForegroundColor Yellow
    Write-Host "2. Enable/Disable User(s)" -ForegroundColor Yellow
    Write-Host "3. Backup All Users" -ForegroundColor Yellow
    Write-Host "4. Restore Users from Backup" -ForegroundColor Yellow
    Write-Host "5. Export & Bulk Update via CSV" -ForegroundColor Yellow
    Write-Host "6. Exit" -ForegroundColor Yellow
    Write-Host ""
}

function Get-AllADUsers {
    param(
        [string[]]$Properties = @("DisplayName", "EmailAddress", "Title", "Department", "Enabled")
    )

    try {
        Write-Status "Fetching users..." "INFO" "Cyan"
        # Only fetch specified properties to optimize performance
        $users = Get-ADUser -Filter * -Properties $Properties
        Write-Status "Found $($users.Count) users" "SUCCESS" "Green"
        return $users
    }
    catch {
        Write-Status "Error fetching users: $($_.Exception.Message)" "ERROR" "Red"
        return @()
    }
}

function Show-AllUsers {
    $users = Get-AllADUsers
    if ($users.Count -eq 0) {
        Write-Status "No users found or error occurred" "WARNING" "Yellow"
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "ALL ACTIVE DIRECTORY USERS" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $userTable = $users | Select-Object -Property @(
        @{Name = "Username"; Expression = { $_.SamAccountName } },
        @{Name = "Display Name"; Expression = { $_.DisplayName } },
        @{Name = "Status"; Expression = { if ($_.Enabled) { "ENABLED" } else { "DISABLED" } } },
        @{Name = "Email"; Expression = { $_.EmailAddress } },
        @{Name = "Department"; Expression = { $_.Department } },
        @{Name = "Title"; Expression = { $_.Title } }
    )
    
    $userTable | Format-Table -AutoSize | Out-String | Write-Host
    
    Write-Host "Total Users: $($users.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    Read-Host "Press Enter to continue"
}

function Change-IndividualPassword {
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "CHANGE INDIVIDUAL USER PASSWORD" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Show user list first
    Write-Host "Available Users:" -ForegroundColor Yellow
    Write-Host ""
    $users = Get-AllADUsers
    if ($users.Count -eq 0) {
        Write-Status "No users found" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    $userTable = @()
    for ($i = 0; $i -lt $users.Count; $i++) {
        $userTable += [PSCustomObject]@{
            "#"            = $i + 1
            "Username"     = $users[$i].SamAccountName
            "Display Name" = $users[$i].DisplayName
            "Status"       = if ($users[$i].Enabled) { "ENABLED" } else { "DISABLED" }
            "Email"        = $users[$i].EmailAddress
        }
    }
    
    $userTable | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host ""
    
    $username = Read-Host "Enter username (SamAccountName) or number from list"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Status "Username cannot be empty" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    # Check if user entered a number
    $selectedUser = $null
    if ($username -match '^\d+$') {
        $index = [int]$username - 1
        if ($index -ge 0 -and $index -lt $users.Count) {
            $selectedUser = $users[$index]
            $username = $selectedUser.SamAccountName
        }
        else {
            Write-Status "Invalid number selected" "ERROR" "Red"
            Start-Sleep -Seconds 2
            return
        }
    }
    
    try {
        if ($null -eq $selectedUser) {
            $user = Get-ADUser -Identity $username -ErrorAction Stop
        }
        else {
            $user = $selectedUser
        }
        Write-Status "User found: $($user.DisplayName)" "SUCCESS" "Green"
    }
    catch {
        Write-Status "User not found: $username" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    $newPassword = Read-Host "Enter new password" -AsSecureString
    if ($newPassword.Length -eq 0) {
        Write-Status "Password cannot be empty" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    try {
        Set-ADAccountPassword -Identity $username -NewPassword $newPassword -Reset
        Set-ADUser -Identity $username -ChangePasswordAtLogon $false
        Write-Status "Password changed successfully for $username" "SUCCESS" "Green"
    }
    catch {
        Write-Status "Error changing password: $($_.Exception.Message)" "ERROR" "Red"
    }
    
    Start-Sleep -Seconds 2
}

function Enable-DisableUsers {
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "ENABLE/DISABLE USER(S)" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter username(s) separated by commas, or 'all' for all users" -ForegroundColor Yellow
    Write-Host "Examples: 'john.doe' or 'john.doe,jane.smith' or 'all'" -ForegroundColor Gray
    Write-Host ""
    
    $userInput = Read-Host "Enter username(s) or 'all'"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        Write-Status "Input cannot be empty" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host ""
    Write-Host "1. Enable" -ForegroundColor Green
    Write-Host "2. Disable" -ForegroundColor Red
    Write-Host ""
    $action = Read-Host "Select action (1 or 2)"
    
    if ($action -ne "1" -and $action -ne "2") {
        Write-Status "Invalid action selected" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    $enable = $action -eq "1"
    $actionText = if ($enable) { "Enable" } else { "Disable" }
    
    $usersToProcess = @()
    
    if ($userInput -eq "all") {
        $usersToProcess = Get-AllADUsers -Properties "Enabled"
        Write-Status "Processing ALL $($usersToProcess.Count) users" "INFO" "Cyan"
    }
    else {
        $usernames = $userInput -split ',' | ForEach-Object { $_.Trim() }
        foreach ($username in $usernames) {
            try {
                $user = Get-ADUser -Identity $username -ErrorAction Stop
                $usersToProcess += $user
            }
            catch {
                Write-Status "User not found: $username" "WARNING" "Yellow"
            }
        }
    }
    
    if ($usersToProcess.Count -eq 0) {
        Write-Status "No valid users to process" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host ""
    Write-Host "Users to ${actionText}:" -ForegroundColor Cyan
    $usersToProcess | ForEach-Object {
        Write-Host "  - $($_.SamAccountName) ($($_.DisplayName))" -ForegroundColor White
    }
    Write-Host ""
    
    $confirm = Read-Host "Confirm $actionText these users? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Status "Operation cancelled" "INFO" "Yellow"
        Start-Sleep -Seconds 2
        return
    }
    
    $successCount = 0
    $failCount = 0
    
    foreach ($user in $usersToProcess) {
        try {
            if ($enable) {
                Enable-ADAccount -Identity $user.SamAccountName
            }
            else {
                Disable-ADAccount -Identity $user.SamAccountName
            }
            Write-Status "$actionText`d: $($user.SamAccountName)" "SUCCESS" "Green"
            $successCount++
        }
        catch {
            Write-Status "Failed to $actionText`: $($user.SamAccountName) - $($_.Exception.Message)" "ERROR" "Red"
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Status "Completed: $successCount succeeded, $failCount failed" "INFO" "Cyan"
    Start-Sleep -Seconds 3
}

function Backup-ADUsers {
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "BACKUP ALL AD USERS" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NOTE: Passwords cannot be retrieved from AD (they are hashed)." -ForegroundColor Yellow
    Write-Host "This backup will save all user properties for restoration." -ForegroundColor Yellow
    Write-Host ""
    
    # Ask user for backup location
    Write-Host "Default backup location: .\AD-Backups" -ForegroundColor Gray
    $backupPath = Read-Host "Enter backup directory path (press Enter for default)"
    
    if ([string]::IsNullOrWhiteSpace($backupPath)) {
        $backupDir = ".\AD-Backups"
    }
    else {
        $backupDir = $backupPath.Trim()
    }
    
    # Validate and create directory
    try {
        if (-not (Test-Path $backupDir)) {
            Write-Status "Creating backup directory: $backupDir" "INFO" "Cyan"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        
        # Verify the path is valid
        if (-not (Test-Path $backupDir)) {
            throw "Could not create or access backup directory"
        }
        
        $backupDir = Resolve-Path $backupDir
        Write-Status "Backup directory: $backupDir" "SUCCESS" "Green"
    }
    catch {
        Write-Status "Invalid backup path: $($_.Exception.Message)" "ERROR" "Red"
        Write-Host "Using default location: .\AD-Backups" -ForegroundColor Yellow
        $backupDir = ".\AD-Backups"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = Join-Path $backupDir "AD-Users-Backup-$timestamp.json"
    
    Write-Status "Fetching all users (including extended properties)..." "INFO" "Cyan"
    $users = Get-AllADUsers -Properties *
    
    if ($users.Count -eq 0) {
        Write-Status "No users found to backup" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Status "Backing up $($users.Count) users..." "INFO" "Cyan"
    
    $backupData = @()
    foreach ($user in $users) {
        $userData = @{
            SamAccountName        = $user.SamAccountName
            DisplayName           = $user.DisplayName
            GivenName             = $user.GivenName
            Surname               = $user.Surname
            EmailAddress          = $user.EmailAddress
            UserPrincipalName     = $user.UserPrincipalName
            Enabled               = $user.Enabled
            DistinguishedName     = $user.DistinguishedName
            Description           = $user.Description
            Department            = $user.Department
            Title                 = $user.Title
            Office                = $user.Office
            TelephoneNumber       = $user.TelephoneNumber
            MobilePhone           = $user.MobilePhone
            StreetAddress         = $user.StreetAddress
            City                  = $user.City
            State                 = $user.State
            PostalCode            = $user.PostalCode
            Country               = $user.Country
            Company               = $user.Company
            Manager               = $user.Manager
            MemberOf              = $user.MemberOf
            PasswordExpired       = $user.PasswordExpired
            PasswordNeverExpires  = $user.PasswordNeverExpires
            PasswordLastSet       = $user.PasswordLastSet
            LastLogonDate         = $user.LastLogonDate
            AccountExpirationDate = $user.AccountExpirationDate
            CannotChangePassword  = $user.CannotChangePassword
            PasswordNotRequired   = $user.PasswordNotRequired
            BackupDate            = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $backupData += $userData
    }
    
    try {
        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Status "Backup completed successfully!" "SUCCESS" "Green"
        Write-Host "Backup file: $backupFile" -ForegroundColor Cyan
        Write-Host "Users backed up: $($users.Count)" -ForegroundColor Cyan
    }
    catch {
        Write-Status "Error creating backup: $($_.Exception.Message)" "ERROR" "Red"
    }
    
    Start-Sleep -Seconds 3
}

function Restore-ADUsers {
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "RESTORE USERS FROM BACKUP" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $backupDir = ".\AD-Backups"
    if (-not (Test-Path $backupDir)) {
        Write-Status "Backup directory not found: $backupDir" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    $backupFiles = Get-ChildItem -Path $backupDir -Filter "AD-Users-Backup-*.json" | Sort-Object LastWriteTime -Descending
    
    if ($backupFiles.Count -eq 0) {
        Write-Status "No backup files found" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host "Available backups:" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $backupFiles.Count; $i++) {
        Write-Host "$($i + 1). $($backupFiles[$i].Name)" -ForegroundColor Yellow
        Write-Host "   Created: $($backupFiles[$i].LastWriteTime)" -ForegroundColor Gray
    }
    Write-Host ""
    
    $selection = Read-Host "Select backup to restore (1-$($backupFiles.Count))"
    try {
        $index = [int]$selection - 1
        if ($index -lt 0 -or $index -ge $backupFiles.Count) {
            Write-Status "Invalid selection" "ERROR" "Red"
            Start-Sleep -Seconds 2
            return
        }
        $selectedBackup = $backupFiles[$index]
    }
    catch {
        Write-Status "Invalid selection" "ERROR" "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host ""
    Write-Host "WARNING: This will restore user properties from backup." -ForegroundColor Red
    Write-Host "NOTE: Passwords cannot be restored. You will need to set new passwords." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Continue with restore? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Status "Restore cancelled" "INFO" "Yellow"
        Start-Sleep -Seconds 2
        return
    }
    
    try {
        $backupData = Get-Content -Path $selectedBackup.FullName -Raw | ConvertFrom-Json
        Write-Status "Loaded backup with $($backupData.Count) users" "INFO" "Cyan"
        
        $successCount = 0
        $failCount = 0
        $skipCount = 0
        
        foreach ($userData in $backupData) {
            try {
                $user = Get-ADUser -Identity $userData.SamAccountName -ErrorAction SilentlyContinue
                if (-not $user) {
                    Write-Status "User not found, skipping: $($userData.SamAccountName)" "WARNING" "Yellow"
                    $skipCount++
                    continue
                }
                
                # Restore user properties
                $updateParams = @{}
                if ($userData.DisplayName) { $updateParams.DisplayName = $userData.DisplayName }
                if ($userData.GivenName) { $updateParams.GivenName = $userData.GivenName }
                if ($userData.Surname) { $updateParams.Surname = $userData.Surname }
                if ($userData.EmailAddress) { $updateParams.EmailAddress = $userData.EmailAddress }
                if ($userData.UserPrincipalName) { $updateParams.UserPrincipalName = $userData.UserPrincipalName }
                if ($userData.Description) { $updateParams.Description = $userData.Description }
                if ($userData.Department) { $updateParams.Department = $userData.Department }
                if ($userData.Title) { $updateParams.Title = $userData.Title }
                if ($userData.Office) { $updateParams.Office = $userData.Office }
                if ($userData.TelephoneNumber) { $updateParams.TelephoneNumber = $userData.TelephoneNumber }
                if ($userData.MobilePhone) { $updateParams.MobilePhone = $userData.MobilePhone }
                if ($userData.StreetAddress) { $updateParams.StreetAddress = $userData.StreetAddress }
                if ($userData.City) { $updateParams.City = $userData.City }
                if ($userData.State) { $updateParams.State = $userData.State }
                if ($userData.PostalCode) { $updateParams.PostalCode = $userData.PostalCode }
                if ($userData.Country) { $updateParams.Country = $userData.Country }
                if ($userData.Company) { $updateParams.Company = $userData.Company }
                
                if ($updateParams.Count -gt 0) {
                    Set-ADUser -Identity $userData.SamAccountName @updateParams
                }
                
                # Restore account status
                if ($userData.Enabled -ne $user.Enabled) {
                    if ($userData.Enabled) {
                        Enable-ADAccount -Identity $userData.SamAccountName
                    }
                    else {
                        Disable-ADAccount -Identity $userData.SamAccountName
                    }
                }
                
                Write-Status "Restored: $($userData.SamAccountName)" "SUCCESS" "Green"
                $successCount++
            }
            catch {
                Write-Status "Failed to restore: $($userData.SamAccountName) - $($_.Exception.Message)" "ERROR" "Red"
                $failCount++
            }
        }
        
        Write-Host ""
        Write-Status "Restore completed: $successCount succeeded, $failCount failed, $skipCount skipped" "INFO" "Cyan"
        Write-Host "NOTE: Passwords were not restored. Set new passwords manually." -ForegroundColor Yellow
    }
    catch {
        Write-Status "Error reading backup file: $($_.Exception.Message)" "ERROR" "Red"
    }
    
    Start-Sleep -Seconds 3
}

function Generate-RandomPassword {
    param([int]$Length = 16)
    
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = ""
    $random = New-Object System.Random
    
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $chars[$random.Next(0, $chars.Length)]
    }
    
    return $password
}





function Manage-UsersCSV {
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "EXPORT & BULK UPDATE USERS VIA CSV" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Step 1: Exporting current user list to CSV..." -ForegroundColor Yellow
    
    $users = Get-AllADUsers -Properties "SamAccountName", "DisplayName", "Enabled", "EmailAddress", "LastLogonDate"
    if ($users.Count -eq 0) {
        Write-Status "No users found" "ERROR" "Red"
        return
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvFile = ".\AD-UserManagement-$timestamp.csv"
    
    # Prepare data for export, adding 'NewPassword' column
    $exportData = @()
    foreach ($user in $users) {
        $exportData += [PSCustomObject]@{
            SamAccountName = $user.SamAccountName
            DisplayName    = $user.DisplayName
            CurrentStatus  = if ($user.Enabled) { "Enabled" } else { "Disabled" }
            Email          = $user.EmailAddress
            LastLogon      = $user.LastLogonDate
            NewPassword    = "" # Empty column for user input
        }
    }
    
    $exportData | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
    Write-Status "Users exported to: $csvFile" "SUCCESS" "Green"
    
    Write-Host ""
    Write-Host "Step 2: Please open the CSV file and enter new passwords in the 'NewPassword' column." -ForegroundColor Yellow
    Write-Host "        Save and close the file when done." -ForegroundColor Yellow
    
    # Attempt to open the file
    try {
        Invoke-Item $csvFile
    }
    catch {
        Write-Host "Could not automatically open file. Please open it manually." -ForegroundColor Gray
    }
    
    Write-Host ""
    Read-Host "Step 3: Press Enter AFTER you have saved changes to the CSV to apply updates..."
    
    Write-Host ""
    Write-Host "Step 4: Processing updates..." -ForegroundColor Cyan
    
    if (-not (Test-Path $csvFile)) {
        Write-Status "File not found: $csvFile" "ERROR" "Red"
        return
    }
    
    try {
        $importData = Import-Csv -Path $csvFile
        $updateCount = 0
        
        foreach ($row in $importData) {
            if (-not [string]::IsNullOrWhiteSpace($row.NewPassword)) {
                try {
                    $username = $row.SamAccountName
                    $newPass = $row.NewPassword
                    
                    # Convert plain text to secure string
                    $securePass = ConvertTo-SecureString $newPass -AsPlainText -Force
                    Set-ADAccountPassword -Identity $username -NewPassword $securePass -Reset
                    Set-ADUser -Identity $username -ChangePasswordAtLogon $false
                    
                    Write-Status "Password updated: $username" "SUCCESS" "Green"
                    $updateCount++
                }
                catch {
                    Write-Status "Failed to update $username : $($_.Exception.Message)" "ERROR" "Red"
                }
            }
        }
        
        if ($updateCount -eq 0) {
            Write-Status "No password changes detected in CSV." "INFO" "Yellow"
        }
        else {
            Write-Status "Completed: $updateCount passwords updated." "SUCCESS" "Green"
        }
        
    }
    catch {
        Write-Status "Error reading CSV: $($_.Exception.Message)" "ERROR" "Red"
    }
    
    Start-Sleep -Seconds 3
}

function Install-ActiveDirectoryModule {
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host "INSTALLING ACTIVE DIRECTORY MODULE" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Status "Administrator privileges required to install module" "ERROR" "Red"
        Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
        return $false
    }
    
    # Try installing via PowerShell Gallery first
    Write-Status "Attempting to install ActiveDirectory module from PowerShell Gallery..." "INFO" "Cyan"
    try {
        Install-Module -Name ActiveDirectory -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        Write-Status "Module installed from PowerShell Gallery" "SUCCESS" "Green"
        return $true
    }
    catch {
        Write-Status "PowerShell Gallery installation failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Try installing via Windows Capabilities (Windows 10/11)
    Write-Status "Attempting to install RSAT Active Directory tools via Windows Capabilities..." "INFO" "Cyan"
    try {
        $capabilityName = "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
        $capability = Get-WindowsCapability -Online -Name $capabilityName -ErrorAction SilentlyContinue
        
        if ($capability -and $capability.State -ne "Installed") {
            Write-Status "Installing Windows Capability: $capabilityName" "INFO" "Cyan"
            Add-WindowsCapability -Online -Name $capabilityName -ErrorAction Stop
            Write-Status "Windows Capability installed successfully" "SUCCESS" "Green"
            Start-Sleep -Seconds 2
            return $true
        }
        elseif ($capability -and $capability.State -eq "Installed") {
            Write-Status "Windows Capability already installed" "SUCCESS" "Green"
            return $true
        }
    }
    catch {
        Write-Status "Windows Capability installation failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Try installing via Windows Features (Windows Server)
    Write-Status "Attempting to install via Windows Features (Server)..." "INFO" "Cyan"
    try {
        $feature = Get-WindowsFeature -Name RSAT-AD-PowerShell -ErrorAction SilentlyContinue
        if ($feature -and -not $feature.Installed) {
            Write-Status "Installing Windows Feature: RSAT-AD-PowerShell" "INFO" "Cyan"
            Install-WindowsFeature -Name RSAT-AD-PowerShell -ErrorAction Stop
            Write-Status "Windows Feature installed successfully" "SUCCESS" "Green"
            Start-Sleep -Seconds 2
            return $true
        }
        elseif ($feature -and $feature.Installed) {
            Write-Status "Windows Feature already installed" "SUCCESS" "Green"
            return $true
        }
    }
    catch {
        Write-Status "Windows Feature installation failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    Write-Status "Could not automatically install ActiveDirectory module" "ERROR" "Red"
    Write-Host ""
    Write-Host "Manual installation options:" -ForegroundColor Yellow
    Write-Host "1. Windows 10/11: Install RSAT via Settings > Apps > Optional Features" -ForegroundColor Gray
    Write-Host "2. Windows Server: Install-WindowsFeature RSAT-AD-PowerShell" -ForegroundColor Gray
    Write-Host "3. PowerShell Gallery: Install-Module -Name ActiveDirectory -Force" -ForegroundColor Gray
    Write-Host ""
    return $false
}

# Main script execution
function Main {
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "WARNING: This script should be run as Administrator for full functionality" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Check if ActiveDirectory module is available
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Status "ActiveDirectory module loaded" "SUCCESS" "Green"
    }
    catch {
        Write-Host ""
        Write-Status "ActiveDirectory module not found" "WARNING" "Yellow"
        Write-Host "Attempting to install automatically..." -ForegroundColor Cyan
        Write-Host ""
        
        if (Install-ActiveDirectoryModule) {
            # Try importing again after installation
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
                Write-Status "ActiveDirectory module loaded successfully" "SUCCESS" "Green"
            }
            catch {
                Write-Status "Module installed but failed to import: $($_.Exception.Message)" "ERROR" "Red"
                Write-Host "You may need to restart PowerShell and run the script again" -ForegroundColor Yellow
                Write-Host ""
                Read-Host "Press Enter to exit"
                exit 1
            }
        }
        else {
            Write-Host ""
            Write-Host "ERROR: Could not install ActiveDirectory module automatically" -ForegroundColor Red
            Write-Host "Please install RSAT (Remote Server Administration Tools) manually" -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
    
    # Main menu loop
    while ($true) {
        Show-Menu
        $choice = Read-Host "Select option (1-6)"
        
        switch ($choice) {
            "1" { Change-IndividualPassword }
            "2" { Enable-DisableUsers }
            "3" { Backup-ADUsers }
            "4" { Restore-ADUsers }
            "5" { Manage-UsersCSV }
            "6" {
                Write-Host ""
                Write-Status "Exiting..." "INFO" "Cyan"
                exit 0
            }
            default {
                Write-Status "Invalid option. Please select 1-6." "ERROR" "Red"
                Start-Sleep -Seconds 2
            }
        }
    }
}

# Run main function
Main
