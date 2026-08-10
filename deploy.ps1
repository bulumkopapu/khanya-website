# Deploys this site to FTP hosting via WinSCP CLI.
# Only uploads files that are new or changed (WinSCP "synchronize" compares timestamps),
# does not delete anything on the remote server.
#
# Setup (one-time):
#   1. Copy deploy.credentials.example.ps1 to deploy.credentials.ps1
#   2. Fill in your real FTP host/username/password/remote path in deploy.credentials.ps1
#      (this file is gitignored, it will never be committed)
#
# Usage:
#   .\deploy.ps1

$ErrorActionPreference = "Stop"

$CredentialsFile = Join-Path $PSScriptRoot "deploy.credentials.ps1"
if (-not (Test-Path $CredentialsFile)) {
    Write-Host "Missing deploy.credentials.ps1 - copy deploy.credentials.example.ps1 and fill in your FTP details first." -ForegroundColor Red
    exit 1
}
. $CredentialsFile

$WinScp = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\WinSCP","C:\Program Files\WinSCP","C:\Program Files (x86)\WinSCP" -Filter "WinSCP.com" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $WinScp) {
    Write-Host "WinSCP.com not found. Install WinSCP first (winget install --id WinSCP.WinSCP -e)." -ForegroundColor Red
    exit 1
}

$EncodedUser = [uri]::EscapeDataString($FtpUser)
$EncodedPass = [uri]::EscapeDataString($FtpPassword)
$SessionUrl  = "ftp://${EncodedUser}:${EncodedPass}@${FtpHost}/"

$LocalPath = $PSScriptRoot
# Exclude repo/tooling files that shouldn't be deployed to the live site
$ExcludeMask = '-filemask="| .git/; .gitignore; .claude/; deploy.ps1; deploy.log; deploy.credentials.ps1; deploy.credentials.example.ps1"'

$Command = @"
option batch on
option confirm off
open "$SessionUrl"
synchronize remote $ExcludeMask "$LocalPath" "$RemotePath"
close
exit
"@

$TempScript = New-TemporaryFile
Set-Content -Path $TempScript -Value $Command -Encoding ASCII

try {
    & $WinScp "/script=$TempScript" "/log=$PSScriptRoot\deploy.log"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Deploy complete." -ForegroundColor Green
    } else {
        Write-Host "Deploy failed (exit code $LASTEXITCODE). See deploy.log for details." -ForegroundColor Red
    }
} finally {
    Remove-Item $TempScript -ErrorAction SilentlyContinue
}
