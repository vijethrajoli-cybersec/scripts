# PowerShell script to collect system statistics and log to CSV

# Configuration
$logFilePath = ".\SystemStats.csv"  # Path to the CSV log file
$sampleIntervalSeconds = 5         # Interval between samples in seconds
$dataSetPath = "C:\DataSets"      # Path to the directory containing files
$stringToAppend = " - This is appended text." # String to append to files
$concurrentFilesToRead = 5 # Number of files to read concurrently

# Ensure the directory exists
if (!(Test-Path -Path $dataSetPath -PathType Container)) {
    try {
        New-Item -Path $dataSetPath -ItemType Directory -Force | Out-Null
        Write-Host "Created directory: $dataSetPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create directory: $dataSetPath. Please create it manually and ensure you have permissions."
        return  # Stop script execution if directory creation fails
    }
}

# Function to get CPU usage
function Get-CpuUsage {
    $cpu = Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 2
    return ($cpu.CounterSamples | Select-Object -ExpandProperty CookedValue | Measure-Object -Average).Average
}

# Function to get memory usage
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

# Function to get disk IOPS
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

# Function to log data to CSV
function Log-DataToCSV {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CPUUsage,
        [Parameter(Mandatory = $true)]
        [string]$MemoryUsage,
        [Parameter(Mandatory = $true)]
        [string]$ReadIOPS,
        [Parameter(Mandatory = $true)]
        [string]$WriteIOPS,
        [Parameter(Mandatory = $true)]
        [string]$Action
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = [PSCustomObject]@{
        Timestamp   = $timestamp
        CPUUsage    = $CPUUsage
        MemoryUsage = $MemoryUsage
        ReadIOPS    = $ReadIOPS
        WriteIOPS   = $WriteIOPS
        Action      = $Action
    }
    # Check if the log file exists.  If not, create it with the header.
    if (!(Test-Path -Path $logFilePath)) {
        $logEntry | Export-Csv -Path $logFilePath -NoTypeInformation
    } else {
        $logEntry | Export-Csv -Path $logFilePath -Append -NoTypeInformation
    }
}

# Function to perform file read operations
function Read-Files {
    param([int]$durationSeconds)
    $startTime = Get-Date
    $endActionTime = $startTime.AddSeconds($durationSeconds)
    Write-Host "Reading files from $dataSetPath for $($durationSeconds) seconds..." -ForegroundColor Green
    while ((Get-Date) -lt $endActionTime) {
        # Get a list of files in the directory
        $files = Get-ChildItem -Path $dataSetPath -File
        $fileCount = $files.Count
        if ($fileCount -gt 0) {
            # Determine the number of files to read, up to the number of available files
            $numFilesToRead = [Math]::Min($concurrentFilesToRead, $fileCount)

            # Select random files
            $randomFiles = Get-Random -InputObject $files -Count $numFilesToRead

            # Create an array to store the job objects
            $jobs = @()

            # Start a job for each file to be read
            foreach ($randomFile in $randomFiles) {
                $filePath = Join-Path -Path $dataSetPath -ChildPath $randomFile.Name
                # Use Start-Job to read the file in a separate runspace
                $job = Start-Job -ScriptBlock {
                    param($filePath)  # Declare the parameter
                    try {
                        # Read the content of the file
                        $content = Get-Content -Path $filePath -ErrorAction SilentlyContinue
                        if ($content) {
                            #  Do nothing with the content
                        }
                        # Return the filename
                        return $MyInvocation.MyCommand.Name  # Changed this line
                    } catch {
                        #error reading.  Return Error
                        return "Error Reading File: $($MyInvocation.MyCommand.Name)"
                    }
                } -ArgumentList $filePath -Name $randomFile.Name # Pass the file path and use filename as jobname
                $jobs += $job  # Add the job to the array
            }

            # Wait for all jobs to complete and get the results
            foreach ($job in $jobs) {
                Wait-Job $job | Out-Null # Wait for the job to finish.
                $result = Receive-Job $job # Get the result
                if ($result -like "Error Reading File:*")
                {
                     Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action $result
                     Write-Host $result -ForegroundColor Red
                }
                else
                {
                    Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action "Read File: $($job.Name)"
                    Write-Host "Read file: $($job.Name)" -ForegroundColor Cyan
                }
                Remove-Job $job # Clean up the job
            }
        }
        else{
             Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action "No Files to Read"
             Write-Host "No Files to Read" -ForegroundColor Yellow
        }
        Start-Sleep -Seconds $sampleIntervalSeconds
    }
}

# Function to perform file append operations
function Append-Files {
    param([int]$durationSeconds)
    $startTime = Get-Date
    $endActionTime = $startTime.AddSeconds($durationSeconds)
    Write-Host "Appending to files in $dataSetPath for $($durationSeconds) seconds..." -ForegroundColor Green

    while ((Get-Date) -lt $endActionTime) {
        # Get a list of files in the directory
        $files = Get-ChildItem -Path $dataSetPath -File
        if ($files.Count -gt 0) {
            # Pick a random file
            $randomIndex = Get-Random -Maximum $files.Count
            $randomFile = $files[$randomIndex]
            $filePath = Join-Path -Path $dataSetPath -ChildPath $randomFile.Name
            try {
                # Append the string to the file
                Add-Content -Path $filePath -Value $stringToAppend -ErrorAction SilentlyContinue
                # Log
                Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action "Append File: $($randomFile.Name)"
                Write-Host "Appended to file: $($randomFile.Name)" -ForegroundColor Cyan
            } catch {
                 Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action "Error Appending File: $($randomFile.Name)"
                Write-Host "Error appending to file: $($randomFile.Name)" -ForegroundColor Red
            }
        }
        else
        {
            Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action "No Files to Append"
            Write-Host "No Files to Append" -ForegroundColor Yellow
        }
        Start-Sleep -Seconds $sampleIntervalSeconds
    }
}

# Main script execution

# 1. Collect stats for 1 minute (idle)
$idleDuration1 = 60
$endTime1 = (Get-Date).AddSeconds($idleDuration1)
Write-Host "Collecting stats (idle) for $idleDuration1 seconds..." -ForegroundColor Green
while ((Get-Date) -lt $endTime1) {
    Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action "Idle 1"
    Start-Sleep -Seconds $sampleIntervalSeconds
}

# 2. Read random files for 5 minutes
$readDuration = 300
Read-Files -durationSeconds $readDuration

# 3. Stay idle for 1 minute
$idleDuration2 = 60
$endTime2 = (Get-Date).AddSeconds($idleDuration2)
Write-Host "Collecting stats (idle) for $idleDuration2 seconds..." -ForegroundColor Green
while ((Get-Date) -lt $endTime2) {
    Log-DataToCSV -CPUUsage (Get-CpuUsage) -MemoryUsage (Get-MemoryUsage) -ReadIOPS (Get-DiskIOPS).ReadIOPS -WriteIOPS (Get-DiskIOPS).WriteIOPS -Action "Idle 2"
    Start-Sleep -Seconds $sampleIntervalSeconds
}

# 4. Append to random files for 5 minutes
$appendDuration = 300
Append-Files -durationSeconds $appendDuration

Write-Host "Script completed.  Check the log file: $logFilePath" -ForegroundColor Green
