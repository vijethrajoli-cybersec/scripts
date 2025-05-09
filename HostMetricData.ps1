$datasetPath = "C:\Data"
$logPath = "C:\Logs"
$iterations = 4
$logIntervalSeconds = 15

# Timing
$idleDuration = 5      # minutes
$readDuration = 5      # minutes
$writeDuration = 5     # minutes

# Setup
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

$allFiles = Get-ChildItem -Path $datasetPath -Recurse -File | Select-Object -ExpandProperty FullName
$metricLog = Join-Path $logPath "host_metrics.csv"
$fileLog = Join-Path $logPath "file_stats.csv"

# Add CSV headers if files don't exist
if (-not (Test-Path $metricLog)) {
    "Timestamp,CPU_Usage,Mem_Used_MB,Disk_KBps,FileIO_KBps" | Out-File -FilePath $metricLog -Encoding utf8
}
if (-not (Test-Path $fileLog)) {
    "Timestamp,FileName,Size,Extension,Entropy,LastAccess,LastWrite" | Out-File -FilePath $fileLog -Encoding utf8
}

function Collect-Metrics {
    param ($logFile)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
    $mem = Get-CimInstance Win32_OperatingSystem
    $diskIO = Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec'
    $fileIO = Get-Counter '\Process(_Total)\IO Data Bytes/sec'

    $usedMB = ($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1024
    $diskKBps = $diskIO.CounterSamples[0].CookedValue / 1024
    $fileKBps = $fileIO.CounterSamples[0].CookedValue / 1024

    $line = "$timestamp,{0:N2},{1:N2},{2:N2},{3:N2}" -f `
        $cpu.CounterSamples[0].CookedValue, `
        $usedMB, `
        $diskKBps, `
        $fileKBps

    $line | Out-File -Append -FilePath $logFile
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
                Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
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

# 🌀 Main Loop: Idle → Read → Idle → Write
for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "`n[Cycle $i] - Idle Phase (5 mins)"
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

    Write-Host "[Cycle $i] - Idle Phase (5 mins)"
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

Write-Host "`n✅ Monitoring complete. Logs saved to $logPath"