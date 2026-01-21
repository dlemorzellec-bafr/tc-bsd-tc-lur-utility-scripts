#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set the AMS NetId

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/change_amsnetid_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/change_amsnetid_${TIMESTAMP}.log"
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
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0 <Adresse AMS NetId>${NC}"
	echo "   OU "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}     (Une adresse AMS NetId vous sera demandee)"
	echo ""
	echo -e "${CYAN}Ce script permet de changer l'adresse AMS NetId.${NC}"
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

# Collect credentials
if [ "$#" -eq 1 ]; then
	AMSNETID="$1"
elif [ "$#" -eq 0 ]; then
	read -rp "Entrez l'adresse AMS NetId : " AMSNETID
	echo
else
	echo -e "${RED}Nombre d'arguments invalide.${NC}"
	echo ""
	usage
	exit 1
fi

# Check if AMS NetId format is valid
if ! [[ "$AMSNETID" =~ ^([0-9]{1,3}\.){5}[0-9]{1,3}$ ]]; then
    echo -e "${RED}L'adresse AMS NetId n'est pas valide. Format attendu : X.X.X.X.X.X${NC}"
    exit 1
fi

# Constants
readonly twincat_registry="/etc/TwinCAT/3.1/TcRegistry.xml"

# Hexadecimal conversion function
ams_to_hexa() {
    HEX_VALUE=""
	
	for BYTE in $(echo "$AMSNETID" | tr '.' ' '); do
		HEX_BYTE=$(printf "%02X" "$BYTE")
		HEX_VALUE="$HEX_VALUE$HEX_BYTE"
	done
	
	echo "$HEX_VALUE"
}

# Force TwinCAT to switch to CONFIG mode (normally not necessary)
#TcSystemServiceUm -c /var/run/TcSystemServiceUm.pid

# Replace hexadecimal value of the AMS NetId in the TwinCAT registry
sed -i "/<Value Name=\"AmsNetId\"/s|>[^<]*<|>$(ams_to_hexa "$AMSNETID")<|" ${twincat_registry}

# Reload TwinCAT service
systemctl restart TcSystemServiceUm
