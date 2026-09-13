#Requires -Version 5.1
#Requires -RunAsAdministrator
# Display recent events without changing audit policy or creating test tasks.
$since = (Get-Date).AddMinutes(-30)
$queries = @(
    @{ LogName = 'Security'; Id = @(4625,4688,4720,4724,4732,4698); StartTime = $since },
    @{ LogName = 'System'; Id = @(7045); StartTime = $since }
)
foreach ($query in $queries) {
    Write-Host "--- $($query.LogName): last 30 minutes ---" -ForegroundColor Cyan
    try {
        Get-WinEvent -FilterHashtable $query -MaxEvents 100 -ErrorAction Stop |
            Select-Object TimeCreated, Id, Message | Format-List
    } catch {
        Write-Warning "No matching events, or the log could not be read: $_"
    }
}
Write-Host 'No results do not prove a clean host. Required auditing may be disabled.'
