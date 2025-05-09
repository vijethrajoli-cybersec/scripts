$datasetPath = "C:\Data"
$logPath = "C:\Logs"
$entPath = "C:\Tools\ent.exe"

$iterations = 4
$logIntervalSeconds = 10

# Phase Durations (in minutes)
$idleDuration = 5
$readDuration = 5
$writeDuration = 5

# Setup log directories
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

$allFiles = Get-ChildItem -Path $datasetPath -Recurse -File | Select-Object -ExpandProperty FullName
$metricLog = Join-Path $logPath "host_metrics.csv"
$fileLog = Join-Path $logPath "file_stats.csv"

# Header for logs (run once)
if (-not (Test-Path $metricLog)) {
    "Timestamp,CPU_Usage,Mem_Usage_MB,Disk_KBps,FileIO_KBps" | Out-File -Encoding utf8 $metricLog
}
if (-not (Test-Path $fileLog)) {
    "Timestamp,FileName,Size,Extension,Entropy,LastAccess,LastWrite" | Out-File -Encoding utf8 $fileLog
}

function Collect-Metrics {
    param ($logFile)

    $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
    $memUsed = Get-Counter '\Memory\Committed Bytes'
    $diskIO = Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec'
    $fileIO = Get-Counter '\Process(_Total)\IO Data Bytes/sec'

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $metrics = [PSCustomObject]@{
        Timestamp       = $timestamp
        CPU_Usage       = "{0:N2}" -f $cpu.CounterSamples[0].CookedValue
        Mem_Usage_MB    = "{0:N2}" -f ($memUsed.CounterSamples[0].CookedValue / 1MB)
        Disk_KBps       = "{0:N2}" -f ($diskIO.CounterSamples[0].CookedValue / 1KB)
        FileIO_KBps     = "{0:N2}" -f ($fileIO.CounterSamples[0].CookedValue / 1KB)
    }
    $metrics | Export-Csv -Path $logFile -Append -NoTypeInformation
}

function Get-Entropy {
    param ($filePath)

    try {
        $output = & $entPath $filePath 2>&1
        foreach ($line in $output) {
            if ($line -match "^Entropy\s+=\s+([\d\.]+)") {
                return [Math]::Round([double]$matches[1], 3)
            }
        }
        return -1  # Entropy not found
    } catch {
        Write-Warning "Failed to compute entropy for $filePath using ent.exe: $_"
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
            Write-Warning "Failed to log stats for $file: $_"
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
            Write-Warning "Failed to modify $file: $_"
        }
    }
}

# Main Monitoring Loop
for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "`n[Cycle $i] - Idle Phase ($idleDuration mins)"
    $phaseEnd = (Get-Date).AddMinutes($idleDuration)
    while ((Get-Date) -lt $phaseEnd) {
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] - Read Phase ($readDuration mins)"
    $phaseEnd = (Get-Date).AddMinutes($readDuration)
    while ((Get-Date) -lt $phaseEnd) {
        $sampleFiles = Get-Random -InputObject $allFiles -Count ([Math]::Min(50, $allFiles.Count))
        Log-File-Stats -files $sampleFiles -logFile $fileLog
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] - Idle Phase ($idleDuration mins)"
    $phaseEnd = (Get-Date).AddMinutes($idleDuration)
    while ((Get-Date) -lt $phaseEnd) {
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }

    Write-Host "[Cycle $i] - Write Phase ($writeDuration mins)"
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
