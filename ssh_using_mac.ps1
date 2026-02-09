# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Windows-side powershell script to connect to TC/LUR IPC with the MAC address as input (using EUI-64 method)

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "ssh n'est pas disponible." -ForegroundColor Red
    exit 1
}

function Get-ActiveInterfaceIndex {
    # Get first physical adapter that is up
    $adapter = Get-NetAdapter |
        Where-Object { $_.Status -eq "Up" -and $_.HardwareInterface -eq $true } |
        Select-Object -First 1

    if (-not $adapter) { throw "Aucune interface reseau active trouvee." }

    # Get the interface index
    $ifaceIndex = (Get-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv6).InterfaceIndex | Select-Object -First 1
    return $ifaceIndex
}

function Get-LinkLocalIPv6FromMac {
    param ([string]$MacAddress)

    $mac = $MacAddress -replace '[-:]',''
    if ($mac.Length -ne 12) {
        throw "Adresse MAC invalide."
    }

    $firstByte = [Convert]::ToByte($mac.Substring(0,2),16)
    $firstByte = $firstByte -bxor 0x02

    $eui64 = @(
        "{0:x2}" -f $firstByte
        $mac.Substring(2,2)
        $mac.Substring(4,2)
        "ff"
        "fe"
        $mac.Substring(6,2)
        $mac.Substring(8,2)
        $mac.Substring(10,2)
    )

    return "fe80::{0}{1}:{2}{3}:{4}{5}:{6}{7}" -f $eui64
}

# INPUT : MAC address
$mac = Read-Host "Entrez l'adresse MAC de la machine Debian"
if ([string]::IsNullOrWhiteSpace($mac)) { exit 1 }

# Network interface
try {
    $ifaceIndex = Get-ActiveInterfaceIndex
    Write-Host "Interface détectée automatiquement : $iface" -ForegroundColor Cyan
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}

# User (Administrator as default)
$user = Read-Host "Login SSH (default: Administrator)"
if ([string]::IsNullOrWhiteSpace($user)) {
    $user = "Administrator"
}

# Port (22 as default)
$portInput = Read-Host "Port SSH (vide = 22)"
$port = if ($portInput) { [int]$portInput } else { 22 }

try {
    $ipv6 = Get-LinkLocalIPv6FromMac $mac
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}

$target = "$ipv6%$ifaceIndex"
$sshCmd = "ssh -6 -p $port $user@$target"

Write-Host "Connexion à $target" -ForegroundColor Green

Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $sshCmd
