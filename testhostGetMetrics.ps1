$datasetPath = "C:\Data"
$logPath = "C:\Logs"
$iterations = 2
$logIntervalSeconds = 5

# Timing (in minutes)
$idleDuration = 5
$readDuration = 5
$writeDuration = 5

# Setup
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

$allFiles = Get-ChildItem -Path $datasetPath -Recurse -File | Select-Object -ExpandProperty FullName
$metricLog = Join-Path $logPath "host_metrics.csv"
"Timestamp,CPU_Usage_Percent,Memory_Usage_Percent,Disk_Reads_per_sec,Disk_Writes_per_sec" | Out-File -FilePath $metricLog -Encoding UTF8


function Collect-Metrics {
    param ($logFile)

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # CPU usage
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $cpu = [math]::Round($cpu, 2)
     
        # Memory usage
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $memFree = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $memUsed = $memTotal - $memFree
        $memUsage = [math]::Round(($memUsed / $memTotal) * 100, 2)
     
        # Disk IOPS
        $readIOPS = (Get-Counter '\PhysicalDisk(_Total)\Disk Reads/sec').CounterSamples[0].CookedValue
        $writeIOPS = (Get-Counter '\PhysicalDisk(_Total)\Disk Writes/sec').CounterSamples[0].CookedValue
        $readIOPS = [math]::Round($readIOPS, 2)
        $writeIOPS = [math]::Round($writeIOPS, 2)
        "$timestamp,$cpu,$memUsage,$readIOPS,$writeIOPS" | Out-File -FilePath $metricLog -Append -Encoding UTF8
    } catch {
        Write-Warning "Failed to collect host metrics: $($_.Exception.Message)"
    }
}


# Main Monitoring Loop
for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "`n[Cycle $i] Idle Phase (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($idleDuration)
    while ((Get-Date) -lt $phaseEnd) {
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] Read Phase (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($readDuration)
    while ((Get-Date) -lt $phaseEnd) {
        $files = Get-ChildItem -Path $datasetPath -Recurse -File
        $files | ForEach-Object -Parallel {
            param($filePath)
            try {
                $null = Get-Content -Path $filePath -Raw
            } catch {
                Write-Warning "Read failed for $filePath"
            }
        } -ArgumentList { $_.FullName } -ThrottleLimit 5
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] Idle Phase (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($idleDuration)
    while ((Get-Date) -lt $phaseEnd) {
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] Write Phase (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($writeDuration)
    while ((Get-Date) -lt $phaseEnd) {
        $files = Get-ChildItem -Path $datasetPath -Recurse -File
        $files | ForEach-Object -Parallel {
            param($filePath)
            try {
                $rand = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
                Add-Content -Path $filePath -Value "`n# Random: $rand"
            } catch {
                Write-Warning "Write failed for $filePath"
            }
        } -ArgumentList { $_.FullName } -ThrottleLimit 5
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }
}

Write-Host "`n✅ Monitoring complete. Logs saved to $logPath"
