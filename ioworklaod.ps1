# --- Configuration ---
$readFileScriptPath = "C:\Users\Administrator\Documents\readFile.ps1"
$writeFileScriptPath = "C:\Users\Administrator\Documents\writeFile.ps1"

# --- Run repeatedly ---
while ($true) {
    # --- Run readFile.ps1 ---
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Running readFile.ps1"
    try {
        Invoke-Expression "& '$readFileScriptPath'"
    }
    catch {
        Write-Error "Error running readFile.ps1: $($_.Exception.Message)"
    }

    # --- Wait for 3 minutes ---
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Waiting 3 minutes before next readFile..."
    Start-Sleep -Seconds 180

    # --- Check if it's time to run writeFile.ps1 (approximately every 10 minutes) ---
    $currentTimeMinute = (Get-Date).Minute
    if (($currentTimeMinute % 10) -eq 0) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Running writeFile.ps1"
        try {
            Invoke-Expression "& '$writeFileScriptPath'"
        }
        catch {
            Write-Error "Error running writeFile.ps1: $($_.Exception.Message)"
        }
        # --- Wait for another 7 minutes to roughly complete the 10-minute cycle ---
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Waiting 7 minutes before next readFile..."
        Start-Sleep -Seconds 420
    } else {
        # If it's not time for writeFile, just wait the remaining time for the next readFile
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Waiting until next readFile (approx. 7 more minutes)..."
        Start-Sleep -Seconds 420
    }
}