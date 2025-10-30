#!/bin/bash
# SPDX-License-Identifier: 0BSD
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set and activate automatic mounting of removable devices

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/automount_activation_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/automount_activation_${TIMESTAMP}.log"
fi
exec > >(tee -a "$LOG_FILE") 2>&1

# Define colours using ANSI escape codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # No colour (reset)

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet d'installer et d'activer le montage automatique de peripheriques amovibles.${NC}"
	echo ""
	exit 1
}
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 1
fi

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
	echo -e "${RED}Veuillez executer ce script avec sudo.${NC}"
	echo ""
	usage
	exit 1
fi

# Verify internet connection to deb.beckhoff.com
echo "Verification de l'acces reseau a deb.beckhoff.com ..."
if ! ping -c 1 -W 2 deb.beckhoff.com >/dev/null; then
	echo -e "${RED}Erreur : acces reseau a deb.beckhoff.com impossible. Verifiez la connectivite.${NC}"
	exit 1
fi

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
PACKAGES=(
ntfs-3g
udevil
)
for PACKAGE in "${PACKAGES[@]}"; do
	echo ""
	echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
	apt-get install -y --no-install-recommends "$PACKAGE"
done

# Restart udevil service
echo ""
echo -e "${GREEN}Demarrage du service de montage automatique ...${NC}"
systemctl enable --now devmon@Administrator.service
