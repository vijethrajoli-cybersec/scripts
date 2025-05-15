<#
.SYNOPSIS
Simulates a 70% read and 30% write workload on a specified directory and logs CPU, Memory, and Disk IOPS using provided functions.

.DESCRIPTION
This script creates a mix of read and write operations on files within the specified directory to simulate a typical I/O workload.
It uses the provided functions to collect CPU usage, memory usage, and disk IOPS, logging the data to a CSV file.

.PARAMETER TargetDirectory
The directory where the read and write operations will be performed. Default is C:\Data\000.

.PARAMETER DurationMinutes
The duration in minutes for which the simulation will run. Default is 10.

.PARAMETER OutputCsvPath
The path to the CSV file where the performance statistics will be logged. Default is "IO_Simulation_Stats_Functions.csv".

.EXAMPLE
.\Simulate-IOWorkload-Functions.ps1 -TargetDirectory "D:\TestData" -DurationMinutes 15 -OutputCsvPath "FuncIOStats.csv"

.NOTES
- Ensure the target directory exists before running the script and contains some files for the read operations.
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
    [string]$OutputCsvPath = "IO_Simulation_Stats_Functions.csv"
)

# Define the log file path
$logFilePath = $OutputCsvPath

# Source the provided functions
function Get-CpuUsage {
    $cpu = Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 2
    return ($cpu.CounterSamples | Select-Object -ExpandProperty CookedValue | Measure-Object -Average).Average
}

function Get-MemoryUsage {
    $memory = Get-Counter -Counter "\Memory\Available MBytes", "\Memory\Committed Bytes"
    $available = ($memory | Where-Object {$_.CounterSetName -eq "Memory" -and $_.InstanceName -eq "Available MBytes"}).CookedValue
    $committed = ($memory | Where-Object {$_.CounterSetName -eq "Memory" -and $_.InstanceName -eq "Committed Bytes"}).CookedValue
    # Calculate total physical memory.  Handles cases where Available MBytes > Committed Bytes
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $totalMemoryGB = [Math]::Round($os.TotalVisibleMemorySize / 1024, 2) # in GB
    if ($totalMemoryGB -eq 0)
    {
       # If the above method fails, try this.
       $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
       $totalMemoryGB = [Math]::Round($computerSystem.TotalPhysicalMemory / (1024*1024*1024), 2)
    }
    # Calculate usage as a percentage.  Avoid divide by zero.
    if ($totalMemoryGB -gt 0) {
        $memoryUsedGB = ($committed / (1024*1024))
        $usage = ($memoryUsedGB / $totalMemoryGB) * 100
        return [Math]::Round($usage, 2)
    }
    else{
        return 0; # Return 0 if total memory is not available.
    }
}

function Get-DiskIOPS {
    $diskCounters = Get-Counter -Counter "\PhysicalDisk(*)\Disk Reads/sec", "\PhysicalDisk(*)\Disk Writes/sec" -SampleInterval 1 -MaxSamples 2
    $readIOPS = 0
    $writeIOPS = 0

    foreach ($counter in $diskCounters.CounterSamples) {
        if ($counter.Path -like "*Disk Reads/sec") {
            $readIOPS += $counter.CookedValue
        } elseif ($counter.Path -like "*Disk Writes/sec") {
            $writeIOPS += $counter.CookedValue
        }
    }
    return @{
        ReadIOPS  = [Math]::Round($readIOPS, 2)
        WriteIOPS = [Math]::Round($writeIOPS, 2)
    }
}

function Log-DataToCSV {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CPUUsage,
        [Parameter(Mandatory = $true)]
        [string]$MemoryUsage,
        [Parameter(Mandatory = $true)]
        [string]$ReadIOPS,
        [Parameter(Mandatory = $true)]
        [string]$WriteIOPS
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = [PSCustomObject]@{
        Timestamp     = $timestamp
        CPU_PercentUsed      = $CPUUsage
        Memory_PercentUsed   = $MemoryUsage
        Disk_ReadIOPS      = $ReadIOPS
        Disk_WriteIOPS     = $WriteIOPS
    }
    # Check if the log file exists.  If not, create it with the header.
    if (!(Test-Path -Path $logFilePath)) {
        $logEntry | Export-Csv -Path $logFilePath -NoTypeInformation
    } else {
        $logEntry | Export-Csv -Path $logFilePath -Append -NoTypeInformation
    }
}

# Check if the target directory exists
if (-not (Test-Path -Path $TargetDirectory -PathType Container)) {
    Write-Error "Target directory '$TargetDirectory' does not exist. Please create it or specify a valid directory."
    exit 1
}

# Calculate the end time for the simulation
$EndTime = (Get-Date).AddMinutes($DurationMinutes)

Write-Host "Starting I/O workload simulation on '$TargetDirectory' for $DurationMinutes minutes using provided functions..."

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
    $cpuUsage = Get-CpuUsage
    $memoryUsage = Get-MemoryUsage
    $diskIO = Get-DiskIOPS

    # Log the statistics to the CSV file
    Log-DataToCSV -CPUUsage $cpuUsage -MemoryUsage $memoryUsage -ReadIOPS $($diskIO.ReadIOPS) -WriteIOPS $($diskIO.WriteIOPS)

    # Wait for a short interval to avoid overwhelming the system
    Start-Sleep -Milliseconds 500
}

Write-Host "I/O workload simulation completed. Performance statistics logged to '$OutputCsvPath'."