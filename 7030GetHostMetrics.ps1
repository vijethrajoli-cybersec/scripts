<#
.SYNOPSIS
Simulates a 70% read and 30% write workload on a specified directory and logs CPU, Memory, and Disk IOPS to a CSV file.

.DESCRIPTION
This script creates a mix of read and write operations on files within the C:\Data\000 directory to simulate a typical I/O workload.
It monitors CPU utilization, memory usage, disk read IOPS, and disk write IOPS for a specified duration (default: 10 minutes) and logs these
statistics to a CSV file.

.PARAMETER TargetDirectory
The directory where the read and write operations will be performed. Default is C:\Data\000.

.PARAMETER DurationMinutes
The duration in minutes for which the simulation will run. Default is 10.

.PARAMETER OutputCsvPath
The path to the CSV file where the performance statistics will be logged. Default is "IO_Simulation_Stats.csv".

.EXAMPLE
.\Simulate-IOWorkload.ps1 -TargetDirectory "C:\MyTestData" -DurationMinutes 5 -OutputCsvPath "MyIOStats.csv"

.NOTES
- Ensure the target directory exists before running the script.
- The script creates and deletes temporary files during the write operations.
- Running this script might impact system performance. Use with caution in production environments.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TargetDirectory = "C:\Data\000",

    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 10,

    [Parameter(Mandatory=$false)]
    [string]$OutputCsvPath = "IO_Simulation_Stats.csv"
)

# Check if the target directory exists
if (-not (Test-Path -Path $TargetDirectory -PathType Container)) {
    Write-Error "Target directory '$TargetDirectory' does not exist. Please create it or specify a valid directory."
    exit 1
}

# Calculate the end time for the simulation
$EndTime = (Get-Date).AddMinutes($DurationMinutes)

# Create the output CSV file and write the header
"Timestamp,CPU_PercentUsed,Memory_PercentUsed,Disk_ReadIOPS,Disk_WriteIOPS" | Out-File -Path $OutputCsvPath

Write-Host "Starting I/O workload simulation on '$TargetDirectory' for $DurationMinutes minutes..."

while ((Get-Date) -lt $EndTime) {
    # Determine if it's a read or write operation (70% read, 30% write)
    $OperationType = Get-Random -Maximum 100
    if ($OperationType -lt 70) {
        # Perform a read operation
        $Files = Get-ChildItem -Path $TargetDirectory -File
        if ($Files) {
            $RandomFile = Get-Random -InputObject $Files
            try {
                # Attempt to read a small portion of the file
                $BytesRead = Get-Content -Path $RandomFile.FullName -TotalCount 1KB -AsByteStream -ErrorAction SilentlyContinue
                # No further action needed with the read data for simulation purposes
            } catch {
                Write-Warning "Error reading file '$($RandomFile.FullName)': $($_.Exception.Message)"
            }
        }
    } else {
        # Perform a write operation (create and delete a temporary file)
        $TempFileName = Join-Path -Path $TargetDirectory -ChildPath "TempFile_$(Get-Random).tmp"
        try {
            "This is some temporary data." | Out-File -Path $TempFileName
            Remove-Item -Path $TempFileName -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Error writing/deleting temporary file '$TempFileName': $($_.Exception.Message)"
        }
    }

    # Collect performance statistics
    $CPU = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $Memory = [int](((Get-Counter '\Memory\% Committed Bytes In Use').CounterSamples.CookedValue) -as [double])

    # Get Disk IOPS (adjust the disk counter name if needed - this is for the C: drive)
    $DiskReadIOPS = (Get-Counter '\PhysicalDisk(C:)\Disk Reads/sec').CounterSamples.CookedValue
    $DiskWriteIOPS = (Get-Counter '\PhysicalDisk(C:)\Disk Writes/sec').CounterSamples.CookedValue

    # Format the output string
    $LogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$CPU,$Memory,$DiskReadIOPS,$DiskWriteIOPS"

    # Append the statistics to the CSV file
    $LogEntry | Out-File -Append -Path $OutputCsvPath

    # Wait for a short interval to avoid overwhelming the system
    Start-Sleep -Milliseconds 500
}

Write-Host "I/O workload simulation completed. Performance statistics logged to '$OutputCsvPath'."