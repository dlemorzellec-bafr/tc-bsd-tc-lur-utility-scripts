#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to download packages and their dependancies in DEB format to use for offline installation

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/pkg_deb_download_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/pkg_deb_download_${TIMESTAMP}.log"
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
readonly working_dir="${script_path}/pkg_download_${TIMESTAMP}"
readonly archive_name="offline_pkgs_${TIMESTAMP}.tar.gz"
readonly apt_source_list="/etc/apt/sources.list.d/bhf.list"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0 <paquet(s) a telecharger>  ${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet de telecharger les DEBs des paquets specifies avec leurs dependances.${NC}"
	echo ""
	exit 1
}
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 1
fi

# Needs packages
PKG_TO_DOWNLOAD=("$@")
if [[ $# -lt 1 ]]; then
	echo -e "${RED}Argument(s) necessaire(s) : Paquet(s) a telecharger.${NC}"
	echo ""
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

# Ensure the apt source list is in its valid state
echo ""
echo -e "${GREEN}Ajustement des depots Beckhoff ...${NC}"
cat > "${apt_source_list}" << EOF
deb [signed-by=/usr/share/keyrings/bhf.asc] https://deb.beckhoff.com/debian trixie-unstable main

EOF
apt-get update

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
PACKAGES=(
apt-rdepends
dpkg-dev
)
for PACKAGE in "${PACKAGES[@]}"; do
	echo ""
	echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
	apt-get install -y --no-install-recommends "$PACKAGE"
done

# Identify all package dependencies
echo ""
echo -e "${GREEN}Analyse des dependances ...${NC}"
mkdir -p "${working_dir}"
cd "${working_dir}"
apt-rdepends "${PKG_TO_DOWNLOAD[@]}" | grep -v "^ " | grep -v "^Pre" | sort -u > pkg_list.txt
echo ""
echo -e "${CYAN}Liste des paquets enregistree dans : ${MAGENTA}${working_dir}/pkg_list.txt${NC}"

# Create apt package dependency resolution
echo ""
echo -e "${GREEN}Creation du fichier de resolution des dependences pour apt (Packages.gz)${NC}"
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# Filter out packages with no candidate in current repositories
echo ""
echo -e "${GREEN}Filtrage des paquets non disponibles dans les depots courants ...${NC}"
> pkg_list_filtered.txt
while read -r PKG; do
	# Check if package actually exists in repositories
	if apt-cache policy "$PKG" | grep -q 'Candidate: (none)'; then
		echo -e "${YELLOW}W: Paquet ignore (no candidate ou virtuel) : ${PKG}${NC}"
	else
		echo "$PKG" >> pkg_list_filtered.txt
	fi
done < pkg_list.txt
mv pkg_list_filtered.txt pkg_list.txt

# Download requested packages and all dependencies
echo ""
echo -e "${GREEN}Telechargement des paquets specifies ...${NC}"
echo -e "${CYAN}Les avertissements ${YELLOW}(13: Permission denied)${CYAN} sont normaux et n'empechent pas le telechargement des paquets.${NC}"
echo -e "${CYAN}  Ils peuvent etre ignores sans risque.${NC}"
xargs -a pkg_list.txt -r -n 1 apt-get download || true

# Compress all these in TAR.GZ archive
echo ""
echo -e "${GREEN}Compression des paquets dans : ${MAGENTA}${archive_name}${NC}"
chown -R $SUDO_USER:$SUDO_USER "${working_dir}"
if ls *.deb >/dev/null 2>&1; then
	tar -czf "${script_path}/${archive_name}" *.deb pkg_list.txt Packages.gz
	echo -e "${GREEN}Archive creee avec succes.${NC}"
else
	echo -e "${RED}Erreur: Aucun fichier DEB detecte.${NC}"
	exit 1
fi

# Delete working directory
echo ""
echo -e "${GREEN}Nettoyage des fichiers extraits : ${MAGENTA}${working_dir} ${GREEN}...${NC}"
rm -rf "${working_dir}"
