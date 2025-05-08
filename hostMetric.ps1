$datasetPath = "C:\Data"
$logPath = "C:\Logs"
$durationMinutes = 15
$intervalSeconds = 10
$endTime = (Get-Date).AddMinutes($durationMinutes)

if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath
}

function Modify-Files {
    param ($files)
    foreach ($file in $files) {
        try {
            # Touch metadata
            (Get-Item $file).LastAccessTime = Get-Date
            (Get-Item $file).LastWriteTime = Get-Date

            # Append dummy data
            Add-Content -Path $file -Value "`n# Modified on $(Get-Date)"
        } catch {
            Write-Warning "Failed to modify $file: $_"
        }
    }
}

function Collect-Metrics {
    param ($logFile)

    $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
    $mem = Get-Counter '\Memory\Available MBytes'
    $diskIO = Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec'
    $fileIO = Get-Counter '\Process(_Total)\IO Data Bytes/sec'

    $timestamp = Get-Date -Format o
    $metrics = [PSCustomObject]@{
        Timestamp = $timestamp
        CPU_Usage = "{0:N2}" -f $cpu.CounterSamples[0].CookedValue
        Mem_Avail_MB = "{0:N2}" -f $mem.CounterSamples[0].CookedValue
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
                Timestamp = Get-Date -Format o
                FileName = $info.Name
                Size = $info.Length
                Extension = $info.Extension
                Entropy = $entropy
                LastAccess = $info.LastAccessTime
                LastWrite = $info.LastWriteTime
            }
            $stat | Export-Csv -Path $logFile -Append -NoTypeInformation
        } catch {
            continue
        }
    }
}

# Main Loop
$allFiles = Get-ChildItem -Path $datasetPath -Recurse -File | Select-Object -ExpandProperty FullName
$metricLog = Join-Path $logPath "host_metrics.csv"
$fileLog = Join-Path $logPath "file_stats.csv"

while ((Get-Date) -lt $endTime) {
    $sampleFiles = Get-Random -InputObject $allFiles -Count ([Math]::Min(50, $allFiles.Count))
    Modify-Files -files $sampleFiles
    Collect-Metrics -logFile $metricLog
    Log-File-Stats -files $sampleFiles -logFile $fileLog
    Start-Sleep -Seconds $intervalSeconds
}

Write-Host "Monitoring complete. Logs saved to $logPath"
