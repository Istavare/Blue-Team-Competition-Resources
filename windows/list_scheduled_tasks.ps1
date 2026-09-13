<#
.SYNOPSIS
    This script lists all scheduled tasks and highlights those that are not
    default Windows tasks, helping to identify potential persistence mechanisms.
#>

# --- Check for Administrator Privileges ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script should be run as Administrator for best results."
}

Write-Host "--- Listing Non-Default Scheduled Tasks ---"

# Get all scheduled tasks from all paths
$allTasks = Get-ScheduledTask

# Filter for tasks that are NOT in the \Microsoft\ path
$nonDefaultTasks = $allTasks | Where-Object { $_.TaskPath -notlike "\Microsoft\*" }

if ($nonDefaultTasks) {
    Write-Host "[+] Found the following non-default scheduled tasks:"
    $nonDefaultTasks | Select-Object TaskPath, TaskName, State, Author | Format-Table -AutoSize
    
    Write-Host "`n[*] Details of non-default tasks:"
    $nonDefaultTasks | ForEach-Object {
        Get-ScheduledTaskInfo -InputObject $_ | Select-Object *
    }
} else {
    Write-Host "[+] No scheduled tasks found outside of the default \Microsoft\ path."
}

Write-Host "`n--- Full Scheduled Task List (for reference) ---"
$allTasks | Select-Object TaskPath, TaskName, State | Format-Table -AutoSize
