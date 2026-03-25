# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Windows-side powershell script to connect to TC/LUR IPC and retrieve the license files

# Takes the IP address of the target as command-line option
param(
    [Parameter(Mandatory=$true)]
    [string]$remoteIP
)

# Stop on error
$ErrorActionPreference = "Stop"

# Generate timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

# Variables
$remoteUser = "Administrator"
$remoteLicenseFolder = "/etc/TwinCAT/3.1/Target/License"
$remoteZip = "/tmp/license-$timestamp.zip"
$localDir = "C:\temp"

# Create remotely ZIP archive of the license files
Write-Host "Creating license archive on $remoteIP ..."
ssh "$remoteUser@$remoteIP" "zip -r '$remoteZip' '$remoteLicenseFolder'"

# Prepare local ZIP archive directory
if (!(Test-Path $localDir)) {
	New-Item -ItemType Directory -Path $localDir | Out-Null
}
$localZip = Join-Path $localDir "license-$timestamp.zip"

# Download the remote ZIP archive
Write-Host "Download archive to $localDir ..."
$sftpCommands = @"
get $remoteZip $localZip
exit
"@

$sftpCommands | sftp "$remoteUser@$remoteIP"

# Delete remote ZIP archive if transfer suceeded
if (Test-Path $localZip) {
	Write-Host "Delete license archive on $remoteIP ..."
	ssh "$remoteUser@$remoteIP" "rm '$remoteZip'"
} else {
	Write-Warning "Download failed, remote file not deleted."
}

