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



function Modify-Files {
    param ($files)
    foreach ($file in $files) {
        try {
            (Get-Item $file).LastAccessTime = Get-Date
            (Get-Item $file).LastWriteTime = Get-Date
            if ($file -match "\.(txt|log|cfg|csv|ini|json|xml)$") {
                Add-Content -Path $file -Value "`n# Modified on $(Get-Date)"
            }
        } catch {
            Write-Warning ("Failed to modify {0}: {1}" -f $file, $_)
        }
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
        $sampleFiles = Get-Random -InputObject $allFiles -Count ([Math]::Min(50, $allFiles.Count))
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
        $sampleFiles = Get-Random -InputObject $allFiles -Count ([Math]::Min(30, $allFiles.Count))
        Modify-Files -files $sampleFiles
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }
}

Write-Host "`n✅ Monitoring complete. Logs saved to $logPath"
