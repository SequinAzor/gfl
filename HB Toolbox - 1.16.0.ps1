# Run-MyTools.ps1
# This fetches and runs the latest tools from GitHub without saving a file locally
 
$url = "https://raw.githubusercontent.com/SequinAzor/GFL-AD-Script/refs/heads/Production/HB%20Toolbox.ps1"
Invoke-RestMethod -Uri $url | Invoke-Expression
