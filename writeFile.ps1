# Specify the path to the directory you want to process
$directoryPath = "C:\Data\"

# Function to process a single file (open and close)
function Process-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Write-Host "Processing file: '$FilePath'"

    $fileStream = $null
    $streamWriter = $null

    try {
        # Open the file for writing.  This will OVERWRITE the file.
        $fileStream = [System.IO.FileStream]::new($FilePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $streamWriter = [System.IO.StreamWriter]::new($fileStream)

        Write-Host "  Opened for writing successfully."

        # --- Perform write operations on the file ---
        # Example: Write a line of text
        $streamWriter.WriteLine("This is some text written to the file.")

        # Example: Write multiple lines
        $streamWriter.WriteLine("Another line.")
        $streamWriter.WriteLine("A third line.")

        # You can add more write operations here.  For example, writing a formatted string:
        $streamWriter.WriteLine("The current date is: {0}", (Get-Date))

    }
    catch {
        Write-Error "  Error processing file '$FilePath': $($_.Exception.Message)"
    }
    finally {
        if ($streamWriter) {
            $streamWriter.Close()
            Write-Host "  StreamWriter closed."
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
