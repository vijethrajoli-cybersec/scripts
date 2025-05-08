$datasetPath = "C:\Dataset"
$logPath = "C:\Logs"
$iterations = 2
$logIntervalSeconds = 15

$idleDuration = 5      # minutes
$readDuration = 5      # minutes
$writeDuration = 5     # minutes

if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

$allFiles = Get-ChildItem -Path $datasetPath -Recurse -File | Select-Object -ExpandProperty FullName
$metricLog = Join-Path $logPath "host_metrics.csv"
$fileLog = Join-Path $logPath "file_stats.csv"

function Collect-Metrics {
    param ($logFile)

    $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
    $diskIO = Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec'
    $fileIO = Get-Counter '\Process(_Total)\IO Data Bytes/sec'
    
    $totalMemKB = (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize
    $freeMemKB  = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
    $usedMemMB  = ($totalMemKB - $freeMemKB) / 1024
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $metrics = [PSCustomObject]@{
        Timestamp        = $timestamp
        CPU_Usage        = "{0:N2}" -f $cpu.CounterSamples[0].CookedValue
        Mem_Used_MB      = "{0:N2}" -f $usedMemMB
        Disk_BytesPerSec = "{0:N2}" -f $diskIO.CounterSamples[0].CookedValue
        FileIO_BytesPerSec = "{0:N2}" -f $fileIO.CounterSamples[0].CookedValue
    }
    $metrics | Export-Csv -Path $logFile -Append -NoTypeInformation
}

function Get-Entropy {
    param ($filePath)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $length = $bytes.Length
        if ($length -eq 0) { return 0 }

        $freqs = @{}
        foreach ($b in $bytes) { $freqs[$b] = $freqs.GetValueOrDefault($b, 0) + 1 }

        $entropy = 0
        foreach ($v in $freqs.Values) {
            $p = $v / $length
            $entropy -= $p * [Math]::Log($p, 2)
        }
        return [Math]::Round($entropy, 3)
    } catch {
        return -1
    }
}

function Log-File-Stats {
    param ($files, $logFile)
    foreach ($file in $files) {
        try {
            $info = Get-Item $file
            $entropy = Get-Entropy $file
            $stat = [PSCustomObject]@{
                Timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
                FileName    = $info.Name
                Size        = $info.Length
                Extension   = $info.Extension
                Entropy     = $entropy
                LastAccess  = $info.LastAccessTime
                LastWrite   = $info.LastWriteTime
            }
            $stat | Export-Csv -Path $logFile -Append -NoTypeInformation
        } catch {
            continue
        }
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
            Write-Warning "Failed to modify ${file}: $_"
        }
    }
}

for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "`n[Cycle $i] - Idle Phase 1 (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($idleDuration)
    while ((Get-Date) -lt $phaseEnd) {
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] - Read Phase (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($readDuration)
    while ((Get-Date) -lt $phaseEnd) {
        $sampleFiles = Get-Random -InputObject $allFiles -Count ([Math]::Min(50, $allFiles.Count))
        Log-File-Stats -files $sampleFiles -logFile $fileLog
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] - Idle Phase 2 (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($idleDuration)
    while ((Get-Date) -lt $phaseEnd) {
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] - Write Phase (5 mins)"
    $phaseEnd = (Get-Date).AddMinutes($writeDuration)
    while ((Get-Date) -lt $phaseEnd) {
        $sampleFiles = Get-Random -InputObject $allFiles -Count ([Math]::Min(30, $allFiles.Count))
        Modify-Files -files $sampleFiles
        Log-File-Stats -files $sampleFiles -logFile $fileLog
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }
}

Write-Host "`n✅ Completed all $iterations cycles. Logs are in $logPath"
