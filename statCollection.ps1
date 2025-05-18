$outputFile = "SystemStats.csv"
 
if (-not (Test-Path $outputFile)) {
    "Timestamp,CPU_Usage_Percent,Memory_Used_GB,Memory_Total_GB,Memory_Usage_Percent,Disk_Reads_per_sec,Disk_Writes_per_sec" | Out-File -FilePath $outputFile -Encoding UTF8
}
 
# Sampling loop configuration
$intervalSeconds = 5     # <<<< Update this as per requirement
$durationMinutes = 2      # <<<< Specify Total duration to run (in minutes)
$endTime = (Get-Date).AddMinutes($durationMinutes)
 
Write-Host "Collecting system stats every $intervalSeconds seconds for $durationMinutes minutes..."
Write-Host "Output CSV: $outputFile"
 
# Start loop
while ((Get-Date) -lt $endTime) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
 
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
 
    # Write to CSV
    "$timestamp,$cpu,$memUsed,$memTotal,$memUsage,$readIOPS,$writeIOPS" | Out-File -FilePath $outputFile -Append -Encoding UTF8
 
    Start-Sleep -Seconds $intervalSeconds
}
 
Write-Host "Data collection complete."