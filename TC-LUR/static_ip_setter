#!/bin/bash
# SPDX-License-Identifier: 0BSD
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not guaranteed

# Script to set a static IP adress for a given network interface

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/static_ip_setup_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/static_ip_setup_${TIMESTAMP}.log"
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
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0 <Interface reseau> <Adresse IP> <Masque de sous-reseau> <Passerelle>${NC}"
	echo "   OU "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}     (Une interface reseau, une adresse IP, un masque de sous-reseau et une passerelle seront demandes)"
	echo ""
	echo -e "${CYAN}Ce script permet de configurer une adresse IP fixe pour une interface reseau donnee.${NC}"
	echo ""
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
if [ "$#" -eq 4 ]; then
	NETWORK_IF="$1"
	IP_ADDRESS="$2"
	SUBNET_MASK="$3"
	GATEWAY="$4"
elif [ "$#" -eq 0 ]; then
	read -rp "Entrez le nom de l'interface reseau : " NETWORK_IF
	read -rp "Entrez l'adresse IP : " IP_ADDRESS
	read -rp "Entrez le masque de sous-reseau : " SUBNET_MASK
	read -rp "Entrez la passerelle : " GATEWAY
	echo
else
	echo -e "${RED}Nombre d'arguments invalide.${NC}"
	echo ""
	usage
	exit 1
fi

# Constants
readonly static_ip_conf="/etc/systemd/network/10-${NETWORK_IF}-static.network"

# CIDR conversion function
subnet_to_cidr() {
    local cidr_bits=0
    local octet

    IFS='.' read -ra octets <<< "$SUBNET_MASK"
    for octet in "${octets[@]}"; do
        for ((i=0; i<8; i++)); do
            (( (octet >> i) & 1 )) && ((cidr_bits++))
        done
    done

    echo "/$cidr_bits"
}

# Configuration editing function
configuration_edit() {
	touch "${static_ip_conf}"
	cat >> "${static_ip_conf}" << EOF
[Match]
Name=${NETWORK_IF}

[Network]
Address=${IP_ADDRESS}$(subnet_to_cidr ${SUBNET_MASK})
Gateway=${GATEWAY}

EOF
}

# Creation of static IP configuration file
if [ -e "${static_ip_conf}" ]; then
	echo -e "${YELLOW}W: Le fichier de configuration pour l'interface ${NETWORK_IF} existe deja.${NC}"
	echo ""
	rm -f "${static_ip_conf}"
	echo -e "${RED}Le fichier a ete remplace${NC}"
	echo ""
	configuration_edit
else
	configuration_edit
fi

# Reload network configuration
networkctl reload
