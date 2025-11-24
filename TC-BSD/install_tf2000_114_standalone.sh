#!/bin/sh
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up the TF2000 TwinCAT HMI Server (1.14)

# Constants
readonly user_path="/home/Administrator"
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"
tst="$(date +%Y%m%d_%H%M%S)"

echo ""
echo "SCRIPT D'INSTALLATION ET DE CONFIGURATION DE LA TF2000 (BAFR)"
echo ""

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
	echo ""
	echo "Le script doit etre execute en tant que root."
	echo ""
	exit 1
fi

# A password must be given (even if "1")
if [ -z "$1" ]; then
	echo ""
	echo "Un argument supplementaire est necessaire a l'execution du script : Mot de passe pour TwinCAT HMI."
	echo ""
	exit 1
fi
password="$1"

# Creation of a restore point before doing any change
echo ""
echo "Creation du point de restauration 'BAFR_before_TF2000' ..."
echo ""
prefix="BAFR_before_TF2000_"
touch ${script_path}/tmp_rplist.txt
restorepoint status > ${script_path}/tmp_rplist.txt
if ! grep -q ${prefix} ${script_path}/tmp_rplist.txt; then
	echo ""
	echo "Point de restauration créé !"
	echo ""
	restorepoint create "BAFR_before_TF2000_${tst}"
else
	echo ""
	echo "Le point de restauration existe deja."
	echo ""
fi
rm -f ${script_path}/tmp_rplist.txt

# Configure keyboard layout to AZERTY default (French)
echo ""
echo "Forcage du clavier console en francais standard (si ce n'est deja fait)..."
echo ""
sysrc keymap="fr.kbd"

# An upgrade of the pkg package manager is often necessary at this point
echo ""
echo "Mise a jour des depots et de pkg..."
echo ""
pkg update -f
pkg install -y pkg

# Install needed packages
echo ""
echo "Installation de paquets logiciels necessaires..."
echo ""
PACKAGES="
TF2000-HMI-Server
"

for PACKAGE in $PACKAGES; do
	pkg install -y $PACKAGE
done

# Initialisation of TwinCAT HMI server
echo ""
echo "Initialisation du serveur TwinCAT HMI..."
echo ""
TcHmiSrv --initialize --password="${password}"

# Creation of a restore point after the changes
echo ""
echo "Creation du point de restauration 'BAFR_after_TF2000' ..."
echo ""
restorepoint create "BAFR_after_TF2000_${tst}"
