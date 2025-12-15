#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up the TF1810 PLC HMI Web Server

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/bafr_tf1810_setup_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/bafr_tf1810_setup_${TIMESTAMP}.log"
fi
exec > >(tee -a "$LOG_FILE") 2>&1

# Define colours using ANSI escape codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # No colour (reset)

# Constants
readonly script_date="2025-12-15"
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"

readonly twincat_folder="/etc/TwinCAT"
readonly twincat_functions="${twincat_folder}/Functions"
readonly tf1810_path="${twincat_functions}/TF1810-PLC-HMI-Web"

readonly firewall_rulepath="/etc/nftables.conf.d/70-plchmiweb.conf"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet l'installation et la configuration TF1810.${NC}"
	exit 1
}
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 1
fi

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
	echo -e "${RED}Veuillez executer ce script avec sudo.${NC}"
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
tf1810-plc-hmi-web
)
for PACKAGE in "${PACKAGES[@]}"; do
	echo ""
	echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
	apt-get install -y --no-install-recommends "$PACKAGE"
done

# Clear APT cache to save space
echo ""
echo -e "${GREEN}Vidage du cache d'APT ...${NC}"
apt-get clean

# Add firewall rule for TF1810 and reload firewall
echo ""
echo -e "${GREEN}Ajout d'une exception du pare-feu pour TF1810 ...${NC}"
touch ${firewall_rulepath}
cat >> "${firewall_rulepath}" << EOF
table inet filter {
  chain input {
    # accept PLC HMI Web server
	tcp dport 42341 accept
  }
}

EOF
systemctl reload nftables

# Initialisation of TF1810 - PLC HMI Web server by restarting TwinCAT system service
echo ""
echo -e "${GREEN}Initialisation du serveur PLC HMI Web ...${NC}"
systemctl start TcSystemServiceUm.service
