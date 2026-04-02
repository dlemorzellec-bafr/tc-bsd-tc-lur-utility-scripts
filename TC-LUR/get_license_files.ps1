# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Windows-side powershell script to connect to TC/LUR IPC and retrieve or send back the license files

# Takes the IP address of the target as command-line option
param(
    [Parameter(Mandatory=$true)]
    [string]$remoteIP,
	
	[switch]$Send,
	
	[string]$Path
)

# Stop on error
$ErrorActionPreference = "Stop"

# Generate timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

# Variables
$remoteUser = "Administrator"
$remoteLicenseFolder = "/etc/TwinCAT/3.1/Target/License"
$localTempDir = "C:\temp"

# Send licenses mode
if ($Send) {
	Write-Host "Le script est mode RESTAURATION."
	
	# Does Path parameter exists ?
	if (-not $Path) {
		Write-Error "Il est necessaire de specifier le parametre -Path avec le chemin du dossier ou se trouve l'archive ZIP des licences."
		exit 1
	}
	
	# Is the path valid ?
	if (-not (Test-Path $Path)) {
		Write-Error "Le chemin renseigne n'existe pas : $Path"
		exit 1
	}
	
	# Is the path a directory ?
	if (-not (Get-Item $Path).PSIsContainer) {
        Write-Error "Le chemin renseigne doit contenir l'archive ZIP des licences."
        exit 1
    }
	
	# List all ZIP archives in the Path folder, there should be only one !
	$localZipArchives = @(Get-ChildItem -Path $Path -Filter "license-*.zip" | Where-Object { $_.Name -match '^license-\d{4}-\d{2}-\d{2}-\d{6}\.zip$' })
	if ($localZipArchives.Count -eq 0) {
		Write-Error "Aucune archive ZIP avec un nom valide ('license-yyyy-MM-dd-HHmmss.zip') n'a ete trouvee dans $Path."
		exit 1
	}
	if ($localZipArchives.Count -gt 1) {
		Write-Error "Plusieurs archives ZIP ont ete trouvees dans $Path. Veuillez utiliser un dossier avec une seule archive ZIP valide."
		$localZipArchives | ForEach-Object { Write-Host " - $($_.Name)" }
		exit 1
	}
	
	# Transfer archive to target
	$localZip = $localZipArchives[0].FullName
	$remoteZip = "/tmp/$($localZipArchives[0].Name)"
	Write-Host "Transfert de l'archive ZIP vers $remoteIP ..."
	$sftpCommands = @"
put $localZip $remoteZip
exit
"@
	$sftpCommands | sftp "$remoteUser@$remoteIP"

	# Extract ZIP archive remotely
	Write-Host "Extraction de l'archive ZIP dans le dossier des licences de TwinCAT ..."
	ssh -t "$remoteUser@$remoteIP" "sudo unzip -o '$remoteZip' -d '$remoteLicenseFolder'"
	
}

# Retrieve licenses mode
else {
	Write-Host "Le script est en mode SAUVEGARDE."

	# Create remotely ZIP archive of the license files
	$remoteZip = "/tmp/license-$timestamp.zip"
	Write-Host "Archivage des licences TwinCAT de $remoteIP au format ZIP ..."
	ssh "$remoteUser@$remoteIP" "cd '$remoteLicenseFolder' && zip -r '$remoteZip' ."

	# Prepare local ZIP archive directory
	if (!(Test-Path $localTempDir)) {
		New-Item -ItemType Directory -Path $localTempDir | Out-Null
	}
	
	# Download the remote ZIP archive
	$localZip = Join-Path $localTempDir "license-$timestamp.zip"
	Write-Host "Téléchargement de l'archive ZIP vers $localTempDir ..."
	$sftpCommands = @"
get $remoteZip $localZip
exit
"@
	$sftpCommands | sftp "$remoteUser@$remoteIP"

	# Delete remote ZIP archive if transfer suceeded
	if (Test-Path $localZip) {
		Write-Host "Suppression de l'archive ZIP dans $remoteIP ..."
		ssh "$remoteUser@$remoteIP" "rm '$remoteZip'"
	} else {
		Write-Warning "Le telechargement a echoue. L'archive ZIP distante n'a pas ete supprimee."
	}

}
