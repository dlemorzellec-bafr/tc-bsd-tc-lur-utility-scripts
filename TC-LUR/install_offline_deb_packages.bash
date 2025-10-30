#!/bin/bash
# SPDX-License-Identifier: 0BSD
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to install DEB packages archives offline

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/offline_pkg_install_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/offline_pkg_install_${TIMESTAMP}.log"
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
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"
readonly working_dir="${script_path}/offline_pkgs_${TIMESTAMP}"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet d'installer les paquets hors ligne prealablement telecharges.${NC}"
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

# Verify presence of archive
if ! ls offline_pkgs_*.tar.gz >/dev/null 2>&1; then
	echo -e "${RED}Erreur: L'archive des paquets n'est pas dans le meme dossier que le script${NC}"
	echo ""
	usage
	exit 1
fi

# Extract archive contents
echo ""
latest_archive=$(ls -t offline_pkgs_*.tar.gz | head -n 1)
echo -e "${GREEN}Extraction de l'archive : ${MAGENTA}${latest_archive}${NC} ..."
mkdir -p "${working_dir}"
tar -xzf "${latest_archive}" -C "${working_dir}"

# Initialise apt metadata
echo ""
echo -e "${GREEN}Initialisation des meta-donnees de apt ...${NC}"
apt-get update -o Dir::Etc::sourcelist="-" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" >/dev/null 2>&1 || true

# Install all DEB packages
echo ""
echo -e "${GREEN}Installation des paquets DEB ...${NC}"
cd "${working_dir}"
apt-get install -y ./*.deb

# Delete working directory
echo ""
echo -e "${GREEN}Nettoyage des fichiers extraits ...${NC}"
rm -rf "${working_dir}"
