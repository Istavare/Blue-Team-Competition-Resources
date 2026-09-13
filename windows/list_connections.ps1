# Function to scan active ports in real-time (display only)
function RealTime-PortScan {
    Write-Host "Starting real-time port scan. Press Ctrl+C to stop the script." -ForegroundColor Cyan

    while ($true) {
        # Clear the screen for real-time updates
        Clear-Host

        # Get active TCP connections
        $tcpConnections = Get-NetTCPConnection | Select-Object LocalPort, RemoteAddress, State, @{Name="Protocol"; Expression={"TCP"}}, OwningProcess

        # Get UDP endpoints
        $udpEndpoints = Get-NetUDPEndpoint | Select-Object LocalPort, @{Name="RemoteAddress"; Expression={"N/A"}}, @{Name="State"; Expression={"Listening"}}, @{Name="Protocol"; Expression={"UDP"}}, OwningProcess

        # Combine TCP and UDP data
        $activePorts = $tcpConnections + $udpEndpoints

        # Display the results
        Write-Host "`nReal-Time Active Ports with Traffic:`n" -ForegroundColor Cyan
        Write-Host ("{0,-10} {1,-10} {2,-15} {3,-20} {4,-12} {5}" -f "Protocol", "Port", "State", "Remote IP", "Process ID", "Process Name")
        Write-Host "---------------------------------------------------------------------------------------------"

        foreach ($port in $activePorts) {
            # Resolve State and Remote Address to avoid inline 'if' issues
            $state = if ($port.State -ne $null) { $port.State } else { "Listening" }
            $remoteAddress = if ($port.RemoteAddress -notin @("0.0.0.0", "::")) { $port.RemoteAddress } else { "N/A" }
            $processName = (Get-Process -Id $port.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            if (-not $processName) {
                $processName = "Unknown"
            }

            # Output details for each connection
            Write-Host ("{0,-10} {1,-10} {2,-15} {3,-20} {4,-12} {5}" -f `
                $port.Protocol, `
                $port.LocalPort, `
                $state, `
                $remoteAddress, `
                $port.OwningProcess, `
                $processName)
        }

        $choice = Read-Host 'Press Enter to refresh, or type exit to quit'
        if ($choice -eq 'exit') { break }

        # Pause before the next scan
        Start-Sleep -Seconds 2
    }
}

# Run the function to start real-time port scanning
RealTime-PortScan
