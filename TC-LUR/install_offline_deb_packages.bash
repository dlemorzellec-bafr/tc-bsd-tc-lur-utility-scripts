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
readonly apt_source_list="/etc/apt/sources.list.d/bhf.list"

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
mkdir -p "${working_dir}"
echo -e "${GREEN}Extraction de l'archive : ${MAGENTA}${latest_archive}${GREEN} ...${NC}"
tar -xzf "${latest_archive}" -C "${working_dir}"

# Create repository file hierarchy
echo ""
echo -e "${GREEN}Creation de l'arborescence du depot local ...${NC}"
mkdir -p "${working_dir}/dists/trixie/main/binary-arm64"
mv "${working_dir}/Packages.gz" "${working_dir}/dists/trixie/main/binary-arm64/Packages.gz"

# Create local repository
echo ""
echo -e "${GREEN}Mise en place du depot local ...${NC}"
cat > "${apt_source_list}" << EOF
deb [trusted=yes] file:${working_dir} /

EOF

# Initialise apt metadata
echo ""
echo -e "${GREEN}Initialisation des meta-donnees de apt ...${NC}"
apt-get update -o Dir::Etc::sourcelist="-" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" >/dev/null 2>&1 || true

# Install all DEB packages
echo ""
echo -e "${GREEN}Installation des paquets DEB ...${NC}"
cd "${working_dir}"
#xargs -a "${working_dir}/pkg_list.txt" apt-get install -y --no-download
#apt-get install -y ./*.deb
for deb in ./*.deb; do
	dpkg -i "$deb" || true
done
apt-get install -y -f --no-download ./*.deb || true
#apt-get -y --fix-broken install --no-download ./*.deb || true
while dpkg -l | grep -q '^iU'; do
	echo ""
    echo -e "${GREEN}Configuration des derniers paquets non configures ...${NC}"
    dpkg --configure -a
done

# Delete working directory
echo ""
echo -e "${GREEN}Nettoyage des fichiers extraits ...${NC}"
rm -rf "${working_dir}"

# Return the apt source list to its original state
echo ""
echo -e "${GREEN}Suppression du depot local ...${NC}"
cat > "${apt_source_list}" << EOF
deb [signed-by=/usr/share/keyrings/bhf.asc] https://deb.beckhoff.com/debian trixie-unstable main

EOF
apt-get update || true
