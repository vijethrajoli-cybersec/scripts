$datasetPath = "C:\Data"
$logPath = "C:\Logs"
$iterations = 4
$logIntervalSeconds = 10

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
$fileLog = Join-Path $logPath "file_stats.csv"

function Collect-Metrics {
    param ($logFile)

    try {
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
        $mem = Get-Counter '\Memory\Committed Bytes'
        $diskIO = Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec'
        $fileIO = Get-Counter '\Process(_Total)\IO Data Bytes/sec'

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $metrics = [PSCustomObject]@{
            Timestamp        = $timestamp
            CPU_Usage        = "{0:N2}" -f $cpu.CounterSamples[0].CookedValue
            Mem_Usage_MB     = "{0:N2}" -f ($mem.CounterSamples[0].CookedValue / 1MB)
            Disk_KBps        = "{0:N2}" -f ($diskIO.CounterSamples[0].CookedValue / 1KB)
            File_KBps        = "{0:N2}" -f ($fileIO.CounterSamples[0].CookedValue / 1KB)
        }
        $metrics | Export-Csv -Path $logFile -Append -NoTypeInformation
    } catch {
        Write-Warning "Failed to collect host metrics: $($_.Exception.Message)"
    }
}

function Get-Entropy {
    param ($filePath)

    $entPath = "C:\Tools\ent.exe"
    if (Test-Path $entPath) {
        try {
            $output = & $entPath $filePath 2>&1
            if ($output -match "Entropy\s+=\s+([0-9\.]+)") {
                return [Math]::Round([double]$matches[1], 3)
            }
        } catch {
            Write-Warning "ENT.exe failed for $filePath: $($_.Exception.Message)"
            return -1
        }
    }

    # Fallback if ENT.exe not found
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
            Write-Warning ("Failed to log stats for {0}: {1}" -f $file, $_)
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
        Log-File-Stats -files $sampleFiles -logFile $fileLog
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
        Log-File-Stats -files $sampleFiles -logFile $fileLog
        Collect-Metrics -logFile $metricLog
        Start-Sleep -Seconds $logIntervalSeconds
    }
}

Write-Host "`n✅ Monitoring complete. Logs saved to $logPath"
