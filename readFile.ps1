# Specify the path to the directory you want to process
$directoryPath = "C:\Data"

# Function to process a single file (open and close)
function Process-File {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    Write-Host "Processing file: '$FilePath'"

    $fileStream = $null
    $streamReader = $null

    try {
        $fileStream = [System.IO.FileStream]::new($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $streamReader = [System.IO.StreamReader]::new($fileStream)

        Write-Host "  Opened successfully."

        # --- Perform operations on the file (e.g., read its contents) ---
        # Example: Read the first line
        $firstLine = $streamReader.ReadLine()
        if ($firstLine -ne $null) {
            Write-Host "  First line: '$firstLine'"
        }
        # You can add more read operations here if needed

    }
    catch {
        Write-Error "  Error processing file '$FilePath': $($_.Exception.Message)"
    }
    finally {
        if ($streamReader) {
            $streamReader.Close()
            Write-Host "  StreamReader closed."
        }
        if ($fileStream) {
            $fileStream.Close()
            Write-Host "  FileStream closed."
        }
    }
}

# Get all files recursively within the specified directory
Get-ChildItem -Path $directoryPath -Recurse -File | ForEach-Object {
    Process-File -FilePath $_.FullName
}

Write-Host "Recursive file processing complete."