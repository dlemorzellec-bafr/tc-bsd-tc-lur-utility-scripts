#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up the TF2000 TwinCAT HMI Server

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/bafr_tclur_setup_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/bafr_tclur_setup_${TIMESTAMP}.log"
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
readonly script_date="2025-11-25"
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"

readonly twincat_folder="/etc/TwinCAT"
readonly twincat_functions="${twincat_folder}/Functions"
readonly tf2000_path="${twincat_functions}/TF2000-HMI-Server"

readonly firewall_rulepath="/etc/nftables.conf.d/70-twincat-hmi.conf"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0 <mot de passe pour TF1200-TF2000>${NC}"
	echo "   OU "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}     (Un mot de passe pour TwinCAT HMI vous sera demande)"
	echo ""
	echo -e "${CYAN}Ce script permet l'installation et la configuration TF2000.${NC}"
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

# Collect credentials
if [ "$#" -eq 1 ]; then
	HMI_PASSWORD="$1"
elif [ "$#" -eq 0 ]; then
	read -rsp "Entrez le mot de passe pour TwinCAT HMI : " HMI_PASSWORD
	echo
else
	usage
	exit 1
fi

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
PACKAGES=(
tf2000-hmi-server
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

# Add firewall rule for TF2000 and reload firewall
echo ""
echo -e "${GREEN}Ajout d'une exception du pare-feu pour TF2000 ...${NC}"
touch ${firewall_rulepath}
cat >> "${firewall_rulepath}" << EOF
table inet filter {
  chain input {
    # accept TwinCAT HMI server
	tcp dport 2010 accept
	tcp dport 2020 accept
  }
}

EOF
systemctl reload nftables

# Initialise TwinCAT HMI server
echo ""
echo -e "${GREEN}Initialisation du serveur TwinCAT HMI ...${NC}"
TcHmiSrv --initialize --password="${HMI_PASSWORD}"

systemctl enable --now TcHmiSrv.service
systemctl start TcHmiSrv.service
