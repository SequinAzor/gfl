Clear-Host

# 1. URLs for your GitHub files
$configUrl = "https://raw.githubusercontent.com/SequinAzor/GFL-AD-Script/refs/heads/Production/conf.json"
$scriptUrl = "https://raw.githubusercontent.com/SequinAzor/GFL-AD-Script/refs/heads/Production/HB%20Toolbox.ps1"

# Load the JSON data into a local instantace
try {
    $conf = Invoke-RestMethod -Uri $configUrl | ConvertFrom-Json
} catch {
    $conf = $null
} 

# Pull values from the JSON (with fallbacks if the download failed)
$version = if ($conf.Version) { $conf.Version } else { "N/A" }
$state = if ($conf.State) { $conf.CustomMessage } else { "N/A" }

# Loading Screen
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "         HB TOOLBOX LAUNCHER                 " -ForegroundColor Green
Write-Host "            By Hugo Brito                    " -ForegroundColor Green 
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [+] Version: $version $($state.ToUpper())" -ForegroundColor DarkGreen
Write-Host "  [+] Please wait a moment..." -ForegroundColor DarkYellow
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan

# Add the delay before the load actually starts
Start-Sleep -Seconds 2

# Load the main script and start it
Invoke-RestMethod -Uri $scriptUrl | Invoke-Expression