#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set (or get) the AMS NetId

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
	echo -e "${CYAN}On peut sinon lire l'adresse AMS NetId en remplacant l'adresse par l'option ${MAGENTA}--get${CYAN} .${NC}"
	echo ""
	exit 1
}

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
	echo -e "${RED}Veuillez executer ce script avec sudo.${NC}"
	echo ""
	usage
	exit 1
fi

# Handle options and arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 1
elif [[ "${1:-}" == "--get" || "${1:-}" == "-g" ]]; then
	MODE="get"
elif [ "$#" -eq 1 ]; then
	AMSNETID="$1"
	MODE="set"
elif [ "$#" -eq 0 ]; then
	read -rp "Entrez l'adresse AMS NetId : " AMSNETID
	echo
	MODE="set"
else
	echo -e "${RED}Nombre d'arguments invalide.${NC}"
	echo ""
	usage
	exit 1
fi

# Constants
readonly twincat_registry="/etc/TwinCAT/3.1/TcRegistry.xml"
readonly script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# To Hexadecimal conversion function
ams_to_hexa() {
    HEX_VALUE=""
	
	for BYTE in $(echo "$AMSNETID" | tr '.' ' '); do
		HEX_BYTE=$(printf "%02X" "$BYTE")
		HEX_VALUE="$HEX_VALUE$HEX_BYTE"
	done
	
	echo "$HEX_VALUE"
}

# From Hexadecimal conversion function
hexa_to_ams() {
	local HEX="$1"
	local AMS=""

	for ((i=0; i<${#HEX}; i+=2)); do
		BYTE_HEX="${HEX:$i:2}"
		BYTE_DEC=$((16#$BYTE_HEX))
		AMS+="${BYTE_DEC}."
	done

	echo "${AMS%.}"  # remove trailing dot
}

get_amsnetid_from_registry() {
	sed -n 's/.*<Value Name="AmsNetId" Type="BIN">\([0-9A-Fa-f]\{12\}\)<\/Value>.*/\1/p' "${twincat_registry}"
}

# SET MODE
if [[ "$MODE" == "set" ]]; then
	# Check if AMS NetId format is valid
	if ! [[ "$AMSNETID" =~ ^([0-9]{1,3}\.){5}[0-9]{1,3}$ ]]; then
		echo -e "${RED}L'adresse AMS NetId n'est pas valide. Format attendu : X.X.X.X.X.X${NC}"
		exit 1
	fi
	
	# Force TwinCAT to switch to CONFIG mode (normally not necessary)
	#TcSystemServiceUm -c /var/run/TcSystemServiceUm.pid
	
	# Replace hexadecimal value of the AMS NetId in the TwinCAT registry
	sed -i "/<Value Name=\"AmsNetId\"/s|>[^<]*<|>$(ams_to_hexa "$AMSNETID")<|" "${twincat_registry}"
	
	# Reload TwinCAT service
	systemctl restart TcSystemServiceUm

# GET MODE
elif [[ "$MODE" == "get" ]]; then
	# Get raw hexadecimal value from the TwinCAT registry
	HEX_VALUE="$(get_amsnetid_from_registry)"

	# Handle reading error
	if [[ -z "$HEX_VALUE" ]]; then
		echo -e "${RED}Impossible de lire l'AmsNetId dans le registre.${NC}"
		exit 1
	fi

	# Convert hexadecimal value to human-readable
	AMS_VALUE="$(hexa_to_ams "$HEX_VALUE")"
	echo -e "${GREEN}Adresse AMS NetId actuelle : ${CYAN}${AMS_VALUE}${NC}"
	
	# Export read AMS NetId into a text file adjacent to script
	output_file="${script_path}/amsnetid_get.txt"
	echo "${AMS_VALUE}" > "${output_file}"
fi