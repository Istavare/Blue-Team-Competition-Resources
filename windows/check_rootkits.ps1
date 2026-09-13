# ===============================
# Windows Rootkit Hunt
# ===============================

$findings = @()

# -------------------------------
# 1. Loaded drivers not on disk
# -------------------------------
$diskDrivers = Get-ChildItem C:\Windows\System32\drivers -Filter *.sys |
    Select-Object -ExpandProperty Name

$loadedDrivers = Get-CimInstance Win32_SystemDriver

foreach ($drv in $loadedDrivers) {
    if ($drv.PathName -and !(Test-Path $drv.PathName)) {
        $findings += @{
            Type = "HiddenDriver"
            Name = $drv.Name
            Path = $drv.PathName
        }
    }
}

# -------------------------------
# 2. Unsigned drivers
# -------------------------------
foreach ($drv in $loadedDrivers) {
    if ($drv.PathName) {
        $sig = Get-AuthenticodeSignature $drv.PathName
        if ($sig.Status -ne "Valid") {
            $findings += @{
                Type = "UnsignedDriver"
                Name = $drv.Name
                Path = $drv.PathName
                SignatureStatus = $sig.Status
            }
        }
    }
}

# -------------------------------
# 3. Known vulnerable drivers
# -------------------------------
$vulnDrivers = @(
    "asrdrv.sys",
    "gdrv.sys",
    "dbutil_2_3.sys",
    "rtcore64.sys"
)

foreach ($drv in $loadedDrivers) {
    if ($vulnDrivers -contains (Split-Path $drv.PathName -Leaf)) {
        $findings += @{
            Type = "KnownVulnerableDriver"
            Name = $drv.Name
            Path = $drv.PathName
        }
    }
}

# -------------------------------
# 4. Suspicious boot config
# -------------------------------
$bcd = bcdedit /enum all
if ($bcd -match "debug\s+Yes") {
    $findings += @{
        Type = "BootDebugEnabled"
        Indicator = "Debug mode enabled"
    }
}

# -------------------------------
# Output
# -------------------------------
$findings | ConvertTo-Json -Depth 4 |
    Out-File "rootkit_findings.json"

Write-Host "[+] Rootkit hunt complete → rootkit_findings.json"
