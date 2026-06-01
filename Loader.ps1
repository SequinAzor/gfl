# Run-MyTools.ps1
# This fetches and runs the latest tools from GitHub without saving a file locally
 
$url = "https://raw.githubusercontent.com/SequinAzor/gfl/refs/heads/main/HB%20Toolbox%20Rev.1.16.0%20-%20Shared.ps1"
Invoke-RestMethod -Uri $url | Invoke-Expression