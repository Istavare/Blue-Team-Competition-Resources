#Requires -RunAsAdministrator

$script:protectedAccounts = @('Administrator')
$script:rotationLog = @()

function Generate-SecurePassword {
    param(
        [int]$Length = 15
    )
    
    $upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowerCase = 'abcdefghijklmnopqrstuvwxyz'
    $numbers = '0123456789'
    $specialChars = '!@#$%^&*()_-+={}[]|:;<>,.?/'
    
    $allChars = $upperCase + $lowerCase + $numbers + $specialChars
    
    $password = @(
        $upperCase[(Get-Random -Maximum $upperCase.Length)]
        $lowerCase[(Get-Random -Maximum $lowerCase.Length)]
        $numbers[(Get-Random -Maximum $numbers.Length)]
        $specialChars[(Get-Random -Maximum $specialChars.Length)]
    )
    
    for ($i = $password.Count; $i -lt $Length; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }
    
    $shuffledPassword = ($password | Get-Random -Count $password.Count) -join ''
    
    return $shuffledPassword
}

function XOR-String {
    param(
        [string]$InputString,
        [string]$Key
    )
    
    $result = New-Object System.Text.StringBuilder
    $keyIndex = 0
    
    foreach ($char in $InputString.ToCharArray()) {
        $xorChar = [char]([byte]$char -bxor [byte]$Key[$keyIndex % $Key.Length])
        [void]$result.Append($xorChar)
        $keyIndex++
    }
    
    return $result.ToString()
}

function ConvertTo-Base64 {
    param([string]$InputString)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    return [Convert]::ToBase64String($bytes)
}

function Show-SecurityDisclaimer {
    param([string]$ExportType)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "         SECURITY DISCLAIMER" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    
    if ($ExportType -eq "XOR") {
        Write-Host "WARNING: XOR ENCRYPTION LIMITATIONS" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "You are about to export credentials using XOR encryption." -ForegroundColor White
        Write-Host ""
        Write-Host "IMPORTANT SECURITY NOTICE:" -ForegroundColor Red
        Write-Host "- XOR encryption can be BRUTEFORCED with known-plaintext attacks" -ForegroundColor Yellow
        Write-Host "- It should ONLY be used as OBFUSCATION, not secure encryption" -ForegroundColor Yellow
        Write-Host "- Attackers with file structure knowledge can recover the key" -ForegroundColor Yellow
        Write-Host "- This provides protection against casual viewing ONLY" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "USE CASES:" -ForegroundColor Cyan
        Write-Host "- Preventing accidental exposure of credentials" -ForegroundColor White
        Write-Host "- Basic protection against casual file browsing" -ForegroundColor White
        Write-Host "- Obfuscation from automated scanning tools" -ForegroundColor White
        Write-Host ""
        Write-Host "DO NOT USE FOR:" -ForegroundColor Red
        Write-Host "- Protection against determined attackers" -ForegroundColor White
        Write-Host "- Compliance with encryption requirements" -ForegroundColor White
        Write-Host "- Long-term secure storage" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "WARNING: PLAINTEXT CREDENTIAL DISPLAY" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "You are about to view credentials in PLAINTEXT format." -ForegroundColor White
        Write-Host ""
        Write-Host "CRITICAL SECURITY RISKS:" -ForegroundColor Red
        Write-Host "- Passwords will be displayed on screen in plaintext" -ForegroundColor Yellow
        Write-Host "- PowerShell transcript logging WILL capture passwords" -ForegroundColor Yellow
        Write-Host "- Screen recording/sharing will expose credentials" -ForegroundColor Yellow
        Write-Host "- Shoulder surfing risk in shared environments" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan
        Write-Host "- Use encrypted export instead (no plaintext display)" -ForegroundColor White
        Write-Host "- Disable PowerShell transcript logging if possible" -ForegroundColor White
        Write-Host "- Ensure no screen recording/sharing is active" -ForegroundColor White
        Write-Host "- Verify you are in a secure, private location" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "Type Y to confirm you understand the risks and proceed:" -ForegroundColor Cyan
    $confirmation = Read-Host
    
    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Host ""
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

function Get-EncryptionKey {
    param([string]$Purpose = "encryption")
    
    Write-Host ""
    Write-Host "Enter $Purpose key (will be hidden):" -ForegroundColor Cyan
    $secureKey = Read-Host -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $key = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Host "Error: Encryption key cannot be empty." -ForegroundColor Red
        return $null
    }
    
    return $key
}

function Export-LogToTxtEncrypted {
    param(
        [string]$FilePath,
        [string]$Key
    )
    
    $output = New-Object System.Collections.ArrayList
    
    [void]$output.Add("=" * 80)
    [void]$output.Add("           ENCRYPTED PASSWORD ROTATION LOG (XOR)")
    [void]$output.Add("                 Session Date: $(Get-Date -Format 'yyyy-MM-dd')")
    [void]$output.Add("            Total Rotations: $($script:rotationLog.Count) Accounts")
    [void]$output.Add("=" * 80)
    [void]$output.Add("")
    [void]$output.Add("WARNING: This file is XOR encrypted for obfuscation only.")
    [void]$output.Add("It does NOT provide cryptographic security.")
    [void]$output.Add("")
    
    foreach ($entry in $script:rotationLog) {
        $encUser = ConvertTo-Base64 (XOR-String $entry.Username $Key)
        $encPass = ConvertTo-Base64 (XOR-String $entry.Password $Key)
        $encTime = ConvertTo-Base64 (XOR-String $entry.Timestamp $Key)
        
        [void]$output.Add("Username: $encUser")
        [void]$output.Add("Password: $encPass")
        [void]$output.Add("Rotated:  $encTime")
        [void]$output.Add("-" * 80)
        [void]$output.Add("")
    }
    
    [void]$output.Add("=" * 80)
    [void]$output.Add("                      END OF ENCRYPTED LOG")
    [void]$output.Add("           To decrypt: Use the same key with XOR decryption")
    [void]$output.Add("=" * 80)
    
    $output | Out-File -FilePath $FilePath -Encoding UTF8
    
    Write-Host ""
    Write-Host "Encrypted log exported to: $FilePath" -ForegroundColor Green
}

function Export-LogToCsvEncrypted {
    param(
        [string]$FilePath,
        [string]$Key
    )
    
    $encryptedData = @()
    
    foreach ($entry in $script:rotationLog) {
        $encryptedData += [PSCustomObject]@{
            Username = ConvertTo-Base64 (XOR-String $entry.Username $Key)
            Password = ConvertTo-Base64 (XOR-String $entry.Password $Key)
            Timestamp = ConvertTo-Base64 (XOR-String $entry.Timestamp $Key)
        }
    }
    
    $encryptedData | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host ""
    Write-Host "Encrypted log exported to: $FilePath" -ForegroundColor Green
}

function Export-LogToTxt {
    param(
        [string]$FilePath
    )
    
    $output = @()
    $output += "=" * 80
    $output += "                        PASSWORD ROTATION LOG"
    $output += "                      Session Date: $(Get-Date -Format 'yyyy-MM-dd')"
    $output += "                    Total Rotations: $($script:rotationLog.Count) Accounts"
    $output += "=" * 80
    $output += ""
    
    foreach ($entry in $script:rotationLog) {
        $output += "Username: $($entry.Username)"
        $output += "Password: $($entry.Password)"
        $output += "Rotated:  $($entry.Timestamp)"
        $output += "-" * 80
        $output += ""
    }
    
    $output += "=" * 80
    $output += "                            END OF ROTATION LOG"
    $output += "              All passwords are 15 characters, NIST compliant"
    $output += "           Store this file securely - passwords are highly sensitive"
    $output += "=" * 80
    
    $output | Out-File -FilePath $FilePath -Encoding UTF8
    
    Write-Host ""
    Write-Host "Log exported to: $FilePath" -ForegroundColor Green
}

function Export-LogToCsv {
    param(
        [string]$FilePath
    )
    
    $script:rotationLog | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host ""
    Write-Host "Log exported to: $FilePath" -ForegroundColor Green
}

function Confirm-ProtectedAccount {
    param(
        [string]$Username
    )
    
    if ($script:protectedAccounts -contains $Username.ToLower()) {
        Write-Host ""
        Write-Host "WARNING: '$Username' is a PROTECTED ACCOUNT!" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host "This account requires additional confirmation." -ForegroundColor Yellow
        Write-Host ""
        
        $confirmation = Read-Host "Type YES in all caps to confirm password rotation for $Username"
        
        if ($confirmation -cne 'YES') {
            Write-Host "Password rotation CANCELLED for '$Username'" -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "Secondary confirmation received. Proceeding with rotation..." -ForegroundColor Green
        Write-Host ""
    }
    
    return $true
}

function Rotate-UserPassword {
    param(
        [string]$Username,
        [switch]$SkipProtectedCheck,
        [switch]$Silent
    )
    
    try {
        $userExists = Get-LocalUser -Name $Username -ErrorAction Stop
        if (-not $Silent) {
            Write-Host "User found: $Username" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "ERROR: User '$Username' not found on this system!" -ForegroundColor Red
        return $null
    }
    
    if (-not $SkipProtectedCheck) {
        if (-not (Confirm-ProtectedAccount -Username $Username)) {
            return $null
        }
    }
    
    if (-not $Silent) {
        Write-Host "Generating secure password..." -ForegroundColor Yellow
    }
    
    $newPassword = Generate-SecurePassword -Length 15
    $securePassword = ConvertTo-SecureString -String $newPassword -AsPlainText -Force
    
    try {
        Set-LocalUser -Name $Username -Password $securePassword -ErrorAction Stop
        
        # Create log entry first (before any output)
        $logEntry = [PSCustomObject]@{
            Username = $Username
            Password = $newPassword
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $script:rotationLog += $logEntry
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  PASSWORD ROTATION SUCCESSFUL" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "User Account:    " -NoNewline -ForegroundColor Cyan
            Write-Host $Username -ForegroundColor White
            Write-Host "New Password:    " -NoNewline -ForegroundColor Cyan
            Write-Host $newPassword -ForegroundColor Yellow
            Write-Host "Password Length: " -NoNewline -ForegroundColor Cyan
            Write-Host "15 characters" -ForegroundColor White
            Write-Host "Rotation Date:   " -NoNewline -ForegroundColor Cyan
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -ForegroundColor White
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "[OK] Password rotated for: $Username" -ForegroundColor Green
            Write-Host "Credential stored in session log (use Option 6 to export)" -ForegroundColor Cyan
            Write-Host ""
        }
        
        return $logEntry
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Failed to rotate password for user '$Username'" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
        return $null
    }
}

function Get-NextLogFileName {
    param(
        [string]$Extension,
        [switch]$Encrypted
    )
    
    $scriptDirectory = Split-Path -Parent $MyInvocation.PSCommandPath
    if ([string]::IsNullOrEmpty($scriptDirectory)) {
        $scriptDirectory = Get-Location
    }
    
    $counter = 1
    $prefix = if ($Encrypted) { "PasswordRotation_Encrypted" } else { "PasswordRotation" }
    $fileName = "${prefix}_$counter.$Extension"
    $fullPath = Join-Path $scriptDirectory $fileName
    
    while (Test-Path $fullPath) {
        $counter++
        $fileName = "${prefix}_$counter.$Extension"
        $fullPath = Join-Path $scriptDirectory $fileName
    }
    
    return $fullPath
}

function Export-BulkRotationLog {
    param(
        [string]$EncryptionChoice
    )
    
    Write-Host ""
    Write-Host "Select file format:" -ForegroundColor Cyan
    Write-Host "1. TXT file" -ForegroundColor White
    Write-Host "2. CSV file" -ForegroundColor White
    Write-Host "3. Both TXT and CSV" -ForegroundColor White
    Write-Host ""
    
    $formatChoice = Read-Host "Enter your choice (1, 2, or 3)"
    
    if ($EncryptionChoice -eq "XOR") {
        if (-not (Show-SecurityDisclaimer -ExportType "XOR")) {
            return $false
        }
        
        $key = Get-EncryptionKey -Purpose "encryption"
        if ($null -eq $key) {
            return $false
        }
        
        switch ($formatChoice) {
            '1' {
                $txtPath = Get-NextLogFileName -Extension "txt" -Encrypted
                Export-LogToTxtEncrypted -FilePath $txtPath -Key $key
            }
            '2' {
                $csvPath = Get-NextLogFileName -Extension "csv" -Encrypted
                Export-LogToCsvEncrypted -FilePath $csvPath -Key $key
            }
            '3' {
                $txtPath = Get-NextLogFileName -Extension "txt" -Encrypted
                $csvPath = Get-NextLogFileName -Extension "csv" -Encrypted
                Export-LogToTxtEncrypted -FilePath $txtPath -Key $key
                Export-LogToCsvEncrypted -FilePath $csvPath -Key $key
            }
            default {
                Write-Host ""
                Write-Host "Invalid selection. Log not saved." -ForegroundColor Red
                $key = $null
                [System.GC]::Collect()
                return $false
            }
        }
        
        $key = $null
        [System.GC]::Collect()
        return $true
    }
    else {
        if (-not (Show-SecurityDisclaimer -ExportType "PLAINTEXT")) {
            return $false
        }
        
        switch ($formatChoice) {
            '1' {
                $txtPath = Get-NextLogFileName -Extension "txt"
                Export-LogToTxt -FilePath $txtPath
            }
            '2' {
                $csvPath = Get-NextLogFileName -Extension "csv"
                Export-LogToCsv -FilePath $csvPath
            }
            '3' {
                $txtPath = Get-NextLogFileName -Extension "txt"
                $csvPath = Get-NextLogFileName -Extension "csv"
                Export-LogToTxt -FilePath $txtPath
                Export-LogToCsv -FilePath $csvPath
            }
            default {
                Write-Host ""
                Write-Host "Invalid selection. Log not saved." -ForegroundColor Red
                return $false
            }
        }
        return $true
    }
}

function Export-SilentEncrypted {
    param(
        [string]$Format
    )
    
    if (-not (Show-SecurityDisclaimer -ExportType "XOR")) {
        return $false
    }
    
    $key = Get-EncryptionKey -Purpose "encryption"
    if ($null -eq $key) {
        return $false
    }
    
    if ($Format -eq "TXT") {
        $txtPath = Get-NextLogFileName -Extension "txt" -Encrypted
        Export-LogToTxtEncrypted -FilePath $txtPath -Key $key
    }
    elseif ($Format -eq "CSV") {
        $csvPath = Get-NextLogFileName -Extension "csv" -Encrypted
        Export-LogToCsvEncrypted -FilePath $csvPath -Key $key
    }
    elseif ($Format -eq "BOTH") {
        $txtPath = Get-NextLogFileName -Extension "txt" -Encrypted
        $csvPath = Get-NextLogFileName -Extension "csv" -Encrypted
        Export-LogToTxtEncrypted -FilePath $txtPath -Key $key
        Export-LogToCsvEncrypted -FilePath $csvPath -Key $key
    }
    
    $key = $null
    [System.GC]::Collect()
    
    return $true
}

function Export-PlaintextDirect {
    param(
        [string]$Format
    )
    
    if ($Format -eq "TXT") {
        $txtPath = Get-NextLogFileName -Extension "txt"
        Export-LogToTxt -FilePath $txtPath
    }
    elseif ($Format -eq "CSV") {
        $csvPath = Get-NextLogFileName -Extension "csv"
        Export-LogToCsv -FilePath $csvPath
    }
    elseif ($Format -eq "BOTH") {
        $txtPath = Get-NextLogFileName -Extension "txt"
        $csvPath = Get-NextLogFileName -Extension "csv"
        Export-LogToTxt -FilePath $txtPath
        Export-LogToCsv -FilePath $csvPath
    }
    
    return $true
}

function Export-WithEncryptionChoice {
    param(
        [string]$Format
    )
    
    Write-Host ""
    Write-Host "Select export option:" -ForegroundColor Cyan
    Write-Host "1. XOR Encrypted export (passwords never displayed)" -ForegroundColor White
    Write-Host "2. View plaintext then choose export format" -ForegroundColor White
    Write-Host ""
    
    $exportChoice = Read-Host "Enter your choice (1 or 2)"
    
    if ($exportChoice -eq '1') {
        return Export-SilentEncrypted -Format $Format
    }
    elseif ($exportChoice -eq '2') {
        if (-not (Show-SecurityDisclaimer -ExportType "PLAINTEXT")) {
            return $false
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  PASSWORD ROTATION LOG (PLAINTEXT)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Total rotations: $($script:rotationLog.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($entry in $script:rotationLog) {
            Write-Host "User: " -NoNewline -ForegroundColor Cyan
            Write-Host $entry.Username -ForegroundColor White
            Write-Host "Password: " -NoNewline -ForegroundColor Cyan
            Write-Host $entry.Password -ForegroundColor Yellow
            Write-Host "Time: " -NoNewline -ForegroundColor Cyan
            Write-Host $entry.Timestamp -ForegroundColor White
            Write-Host "----------------------------------------" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "Exporting to plaintext file..." -ForegroundColor Cyan
        Write-Host ""
        
        return Export-PlaintextDirect -Format $Format
    }
    else {
        Write-Host ""
        Write-Host "Invalid selection. Export cancelled." -ForegroundColor Red
        return $false
    }
}

function Rotate-SingleUser {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  SINGLE USER PASSWORD ROTATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $allUsers = Get-LocalUser | Sort-Object Name
    
    Write-Host "Available user accounts on this system:" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($user in $allUsers) {
        $status = if ($user.Enabled) { "Enabled" } else { "Disabled" }
        $statusColor = if ($user.Enabled) { "Green" } else { "Gray" }
        $isProtected = $script:protectedAccounts -contains $user.Name.ToLower()
        
        Write-Host "  - " -NoNewline
        Write-Host $user.Name -NoNewline -ForegroundColor White
        Write-Host " [$status]" -NoNewline -ForegroundColor $statusColor
        
        if ($isProtected) {
            Write-Host " [PROTECTED]" -ForegroundColor Yellow
        } else {
            Write-Host ""
        }
    }
    
    Write-Host ""
    $username = Read-Host "Enter the username for password rotation (or C to cancel)"
    
    if ($username -eq 'C' -or $username -eq 'c' -or [string]::IsNullOrWhiteSpace($username)) {
        return
    }
    
    Write-Host ""
    Write-Host "Select rotation mode:" -ForegroundColor Cyan
    Write-Host "1. Silent mode (password hidden - invisible to PowerShell logging)" -ForegroundColor White
    Write-Host "2. Verbose mode (show password - will be logged in PowerShell logging)" -ForegroundColor White
    Write-Host ""
    
    $modeChoice = Read-Host "Enter your choice (1 or 2)"
    $silentMode = ($modeChoice -eq '1')
    
    if (-not $silentMode) {
        Write-Host ""
        if (-not (Show-SecurityDisclaimer -ExportType "PLAINTEXT")) {
            return
        }
    }
    
    Rotate-UserPassword -Username $username -Silent:$silentMode
}

function Rotate-AllUsers {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  BULK PASSWORD ROTATION" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "Select user scope for bulk rotation:" -ForegroundColor Cyan
    Write-Host "1. Enabled users only" -ForegroundColor White
    Write-Host "2. All users (enabled and disabled)" -ForegroundColor White
    Write-Host "C. Cancel" -ForegroundColor White
    Write-Host ""
    
    $scopeChoice = Read-Host "Enter your choice (1, 2, or C)"
    
    if ($scopeChoice -eq 'C' -or $scopeChoice -eq 'c') {
        Write-Host "Bulk rotation cancelled." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    $allUsers = @()
    $scopeDescription = ""
    
    switch ($scopeChoice) {
        '1' {
            $allUsers = Get-LocalUser | Where-Object { $_.Enabled -eq $true }
            $scopeDescription = "Enabled users only"
        }
        '2' {
            $allUsers = Get-LocalUser
            $scopeDescription = "All users (enabled and disabled)"
        }
        default {
            Write-Host "Invalid selection. Operation cancelled." -ForegroundColor Red
            Write-Host ""
            Read-Host "Press Enter to continue"
            return
        }
    }
    
    Write-Host ""
    Write-Host "Scope: $scopeDescription" -ForegroundColor Magenta
    Write-Host ""
    
    $usersToRotate = $allUsers | Where-Object { 
        $script:protectedAccounts -notcontains $_.Name.ToLower() 
    }
    
    $enabledCount = ($usersToRotate | Where-Object { $_.Enabled -eq $true }).Count
    $disabledCount = ($usersToRotate | Where-Object { $_.Enabled -eq $false }).Count
    
    Write-Host "Total users in scope: $($allUsers.Count)" -ForegroundColor Cyan
    Write-Host "Protected users (will skip): $($script:protectedAccounts.Count)" -ForegroundColor Yellow
    Write-Host "Users to rotate: $($usersToRotate.Count)" -ForegroundColor Green
    
    if ($scopeChoice -eq '2') {
        Write-Host "  - Enabled: $enabledCount" -ForegroundColor Green
        Write-Host "  - Disabled: $disabledCount" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    if ($usersToRotate.Count -eq 0) {
        Write-Host "No users to rotate (all users are protected)." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host "The following users will have their passwords rotated:" -ForegroundColor Cyan
    foreach ($user in $usersToRotate) {
        $status = if ($user.Enabled) { "Enabled" } else { "Disabled" }
        $statusColor = if ($user.Enabled) { "Green" } else { "Gray" }
        Write-Host "  - " -NoNewline
        Write-Host $user.Name -NoNewline -ForegroundColor White
        Write-Host " [$status]" -ForegroundColor $statusColor
    }
    Write-Host ""
    
    $confirmation = Read-Host "Type ROTATE in all caps to proceed with bulk rotation"
    
    if ($confirmation -cne 'ROTATE') {
        Write-Host "Bulk rotation CANCELLED" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    Write-Host "Select rotation mode:" -ForegroundColor Cyan
    Write-Host "1. Silent mode (passwords hidden - invisible to PowerShell logging)" -ForegroundColor White
    Write-Host "2. Verbose mode (show passwords during rotation - Logged in PowerShell logging)" -ForegroundColor White
    Write-Host ""
    
    $displayChoice = Read-Host "Enter your choice (1 or 2)"
    $silentMode = ($displayChoice -eq '1')
    
    if ($silentMode) {
        Write-Host ""
        Write-Host "SECURITY MODE: Passwords will be hidden during rotation." -ForegroundColor Green
        Write-Host "No plaintext passwords will appear in logs or on screen." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        if (-not (Show-SecurityDisclaimer -ExportType "PLAINTEXT")) {
            Write-Host ""
            Read-Host "Press Enter to continue"
            return
        }
        Write-Host ""
    }
    
    Write-Host "Starting bulk password rotation..." -ForegroundColor Green
    Write-Host ""
    
    $bulkRotationLog = @()
    $successCount = 0
    $failCount = 0
    $successEnabled = 0
    $successDisabled = 0
    
    foreach ($user in $usersToRotate) {
        if (-not $silentMode) {
            Write-Host "----------------------------------------" -ForegroundColor Gray
        }
        
        $result = Rotate-UserPassword -Username $user.Name -SkipProtectedCheck -Silent:$silentMode
        
        if ($result) {
            $successCount++
            $bulkRotationLog += $result
            if ($user.Enabled) {
                $successEnabled++
            } else {
                $successDisabled++
            }
        } else {
            $failCount++
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  BULK ROTATION SUMMARY" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "Scope: $scopeDescription" -ForegroundColor Cyan
    Write-Host "Successful rotations: $successCount" -ForegroundColor Green
    
    if ($scopeChoice -eq '2') {
        Write-Host "  - Enabled users: $successEnabled" -ForegroundColor Green
        Write-Host "  - Disabled users: $successDisabled" -ForegroundColor Gray
    }
    
    Write-Host "Failed rotations: $failCount" -ForegroundColor Red
    Write-Host "Skipped (protected): $($script:protectedAccounts.Count)" -ForegroundColor Yellow
    Write-Host ""
    
    if ($bulkRotationLog.Count -gt 0) {
        Write-Host "Press L to save log to file, or press Enter to return to menu" -ForegroundColor Yellow
        $logChoice = Read-Host
        
        if ($logChoice -eq 'L' -or $logChoice -eq 'l') {
            Write-Host ""
            Write-Host "Select encryption type:" -ForegroundColor Cyan
            Write-Host "1. XOR Encrypted (obfuscation)" -ForegroundColor White
            Write-Host "2. Plaintext (no encryption)" -ForegroundColor White
            Write-Host ""
            
            $encryptionChoice = Read-Host "Enter your choice (1 or 2)"
            
            $tempLog = $script:rotationLog
            $script:rotationLog = $bulkRotationLog
            
            if ($encryptionChoice -eq '1') {
                Export-BulkRotationLog -EncryptionChoice "XOR"
            }
            elseif ($encryptionChoice -eq '2') {
                Export-BulkRotationLog -EncryptionChoice "PLAINTEXT"
            }
            else {
                Write-Host ""
                Write-Host "Invalid selection. Log not saved." -ForegroundColor Red
            }
            
            $script:rotationLog = $tempLog
            
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
    } else {
        Read-Host "Press Enter to continue"
    }
}

function Show-ProtectedAccounts {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  PROTECTED ACCOUNTS LIST" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($script:protectedAccounts.Count -eq 0) {
        Write-Host "No protected accounts configured." -ForegroundColor Yellow
    } else {
        Write-Host "Current protected accounts ($($script:protectedAccounts.Count)):" -ForegroundColor Cyan
        foreach ($account in $script:protectedAccounts) {
            Write-Host "  - $account" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Add-ProtectedAccount {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ADD PROTECTED ACCOUNT" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $allUsers = Get-LocalUser | Sort-Object Name
    
    Write-Host "Available user accounts on this system:" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($user in $allUsers) {
        $status = if ($user.Enabled) { "Enabled" } else { "Disabled" }
        $statusColor = if ($user.Enabled) { "Green" } else { "Gray" }
        $isProtected = $script:protectedAccounts -contains $user.Name.ToLower()
        
        Write-Host "  - " -NoNewline
        Write-Host $user.Name -NoNewline -ForegroundColor White
        Write-Host " [$status]" -NoNewline -ForegroundColor $statusColor
        
        if ($isProtected) {
            Write-Host " [PROTECTED]" -ForegroundColor Yellow
        } else {
            Write-Host ""
        }
    }
    
    Write-Host ""
    $username = Read-Host "Enter username to add to protected list (or C to cancel)"
    
    if ($username -eq 'C' -or $username -eq 'c' -or [string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    if ($script:protectedAccounts -contains $username.ToLower()) {
        Write-Host "User '$username' is already in the protected list." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    $userExists = $allUsers | Where-Object { $_.Name.ToLower() -eq $username.ToLower() }
    if (-not $userExists) {
        Write-Host "Warning: User '$username' does not exist on this system." -ForegroundColor Yellow
        Write-Host "Add anyway? (Y/N)" -ForegroundColor Yellow
        $confirm = Read-Host
        
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Press Enter to continue"
            return
        }
    }
    
    $script:protectedAccounts += $username.ToLower()
    Write-Host "User '$username' has been added to the protected accounts list." -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Remove-ProtectedAccount {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  REMOVE PROTECTED ACCOUNT" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    
    if ($script:protectedAccounts.Count -eq 0) {
        Write-Host "No protected accounts to remove." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    $allUsers = Get-LocalUser | Sort-Object Name
    
    Write-Host "Currently protected accounts:" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $script:protectedAccounts.Count; $i++) {
        $protectedUsername = $script:protectedAccounts[$i]
        $user = $allUsers | Where-Object { $_.Name.ToLower() -eq $protectedUsername }
        
        Write-Host "  [$($i + 1)] " -NoNewline -ForegroundColor White
        Write-Host $protectedUsername -NoNewline -ForegroundColor White
        
        if ($user) {
            $status = if ($user.Enabled) { "Enabled" } else { "Disabled" }
            $statusColor = if ($user.Enabled) { "Green" } else { "Gray" }
            Write-Host " [$status]" -ForegroundColor $statusColor
        } else {
            Write-Host " [User Not Found]" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    $selection = Read-Host "Enter number to remove (or C to cancel)"
    
    if ($selection -eq 'C' -or $selection -eq 'c') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    if ($selection -match '^\d+$') {
        $index = [int]$selection - 1
        
        if ($index -ge 0 -and $index -lt $script:protectedAccounts.Count) {
            $removedAccount = $script:protectedAccounts[$index]
            $script:protectedAccounts = $script:protectedAccounts | Where-Object { $_ -ne $removedAccount }
            Write-Host "User '$removedAccount' has been removed from the protected accounts list." -ForegroundColor Green
        } else {
            Write-Host "Invalid selection." -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid input." -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-RotationLog {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  PASSWORD ROTATION LOG" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($script:rotationLog.Count -eq 0) {
        Write-Host "No password rotations performed in this session." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host "Rotations in session: $($script:rotationLog.Count)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select action:" -ForegroundColor Cyan
    Write-Host "1. Export encrypted (passwords never displayed)" -ForegroundColor White
    Write-Host "2. View plaintext and export" -ForegroundColor White
    Write-Host "C. Cancel" -ForegroundColor White
    Write-Host ""
    
    $viewChoice = Read-Host "Enter your choice (1, 2, or C)"
    
    if ($viewChoice -eq 'C' -or $viewChoice -eq 'c') {
        return
    }
    
    if ($viewChoice -eq '1') {
        Write-Host ""
        Write-Host "Select log format:" -ForegroundColor Cyan
        Write-Host "1. TXT file" -ForegroundColor White
        Write-Host "2. CSV file" -ForegroundColor White
        Write-Host "3. Both TXT and CSV" -ForegroundColor White
        Write-Host ""
        
        $formatChoice = Read-Host "Enter your choice (1, 2, or 3)"
        
        switch ($formatChoice) {
            '1' { Export-SilentEncrypted -Format "TXT" }
            '2' { Export-SilentEncrypted -Format "CSV" }
            '3' { Export-SilentEncrypted -Format "BOTH" }
            default {
                Write-Host "Invalid selection." -ForegroundColor Red
            }
        }
    }
    elseif ($viewChoice -eq '2') {
        # Show security disclaimer first
        if (-not (Show-SecurityDisclaimer -ExportType "PLAINTEXT")) {
            Write-Host ""
            Read-Host "Press Enter to continue"
            return
        }
        
        # Display plaintext passwords
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  PASSWORD ROTATION LOG (PLAINTEXT)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Total rotations: $($script:rotationLog.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($entry in $script:rotationLog) {
            Write-Host "User: " -NoNewline -ForegroundColor Cyan
            Write-Host $entry.Username -ForegroundColor White
            Write-Host "Password: " -NoNewline -ForegroundColor Cyan
            Write-Host $entry.Password -ForegroundColor Yellow
            Write-Host "Time: " -NoNewline -ForegroundColor Cyan
            Write-Host $entry.Timestamp -ForegroundColor White
            Write-Host "----------------------------------------" -ForegroundColor Gray
        }
        
        # Prompt for export options
        Write-Host ""
        Write-Host "Select export option:" -ForegroundColor Cyan
        Write-Host "1. Export to TXT file (plaintext)" -ForegroundColor White
        Write-Host "2. Export to CSV file (plaintext)" -ForegroundColor White
        Write-Host "3. Export to both TXT and CSV (plaintext)" -ForegroundColor White
        Write-Host "4. Return to main menu (do not export)" -ForegroundColor White
        Write-Host ""
        
        $exportChoice = Read-Host "Enter your choice (1, 2, 3, or 4)"
        
        switch ($exportChoice) {
            '1' {
                $txtPath = Get-NextLogFileName -Extension "txt"
                Export-LogToTxt -FilePath $txtPath
            }
            '2' {
                $csvPath = Get-NextLogFileName -Extension "csv"
                Export-LogToCsv -FilePath $csvPath
            }
            '3' {
                $txtPath = Get-NextLogFileName -Extension "txt"
                $csvPath = Get-NextLogFileName -Extension "csv"
                Export-LogToTxt -FilePath $txtPath
                Export-LogToCsv -FilePath $csvPath
            }
            '4' {
                Write-Host ""
                Write-Host "Returning to main menu without export." -ForegroundColor Yellow
            }
            default {
                Write-Host ""
                Write-Host "Invalid selection. Returning to main menu." -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "Invalid selection." -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host " _____   ______      _        _       " -ForegroundColor Cyan
    Write-Host "|  ___|  | ___ \    | |      | |      " -ForegroundColor Cyan
    Write-Host "| |__ ___| |_/ /___ | |_ __ _| |_ ___ " -ForegroundColor Cyan
    Write-Host "|  __|_  /    // _ \| __/ _`` | __/ _ \" -ForegroundColor Cyan
    Write-Host "| |___/ /| |\ \ (_) | || (_| | ||  __/" -ForegroundColor Cyan
    Write-Host "\____/___\_| \_\___/ \__\__,_|\__\___|" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "A NIST SP 800-63B Compliant Password Rotation Script" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "1. Rotate single user password" -ForegroundColor White
    Write-Host "2. Rotate ALL users (except protected)" -ForegroundColor White
    Write-Host "3. View protected accounts" -ForegroundColor White
    Write-Host "4. Add protected account" -ForegroundColor White
    Write-Host "5. Remove protected account" -ForegroundColor White
    Write-Host "6. View/Export rotation log" -ForegroundColor White
    Write-Host "Q. Quit" -ForegroundColor White
    Write-Host ""
}

$running = $true

while ($running) {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        '1' {
            Rotate-SingleUser
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        '2' {
            Rotate-AllUsers
        }
        '3' {
            Show-ProtectedAccounts
        }
        '4' {
            Add-ProtectedAccount
        }
        '5' {
            Remove-ProtectedAccount
        }
        '6' {
            Show-RotationLog
        }
        'Q' {
            $running = $false
            Write-Host ""
            Write-Host "Exiting password rotation script..." -ForegroundColor Cyan
            Write-Host "Session rotations: $($script:rotationLog.Count)" -ForegroundColor Yellow
            Write-Host ""
        }
        'q' {
            $running = $false
            Write-Host ""
            Write-Host "Exiting password rotation script..." -ForegroundColor Cyan
            Write-Host "Session rotations: $($script:rotationLog.Count)" -ForegroundColor Yellow
            Write-Host ""
        }
        default {
            Write-Host ""
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}

$script:rotationLog = @()
[System.GC]::Collect()

Write-Host "Password rotation session completed." -ForegroundColor Cyan
Write-Host ""