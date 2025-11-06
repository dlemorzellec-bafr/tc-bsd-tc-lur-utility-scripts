#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
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

readonly apt_folder="/etc/apt"
readonly apt_auth_file="${apt_folder}/auth.conf.d/bhf.conf"
readonly apt_source_list="${apt_folder}/sources.list.d/bhf.list"
readonly apt_mirror_conf="${apt_folder}/mirror.list"
readonly dist_codename="trixie-stable"

readonly beckhoff_keyring_file="/usr/share/keyrings/bhf.asc"
readonly beckhoff_repo_url="https://deb.beckhoff.com/debian"
readonly beckhoff_public_key_url="https://deb.beckhoff.com/repo.pub"
readonly beckhoff_mirror_parent="/var/spool/apt-mirror"
readonly beckhoff_mirror_folder="${beckhoff_mirror_parent}/mirror"

readonly localrepo_folder="/srv/localrepo"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet d'installer un depot local permettant l'installation de paquets hors ligne depuis une clef USB.${NC}"
	echo ""
	echo -e "${YELLOW}Veuillez vous assurer que la clef USB a ete prealablement montee.${NC}"
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

# Verify the mirror exists in expected directory
MIRROR_FOLDER="deb.beckhoff-mirror"
found=0
while read dev mnt rest; do
    [ -d "$mnt/$MIRROR_FOLDER" ] && found=1 && break
done < /proc/mounts

if [ "$found" -eq 1 ]; then
	echo -e "${CYAN}Le miroir a ete detecte a l'emplacement prevu.${NC}"
else
	echo -e "${RED}Erreur: Le mirroir n'a pas ete detecte a l'emplacement prevu.${NC}"
	exit 1
fi

# Create the local repository
echo ""
echo -e "${GREEN}Creation du depot local ...${NC}"
echo ""
echo -e "${YELLOW}L'operation peut prendre plusieurs dizaines de minutes.${NC}"
mkdir -p ${localrepo_folder}
cp -rfv ${mnt}/${MIRROR_FOLDER} ${localrepo_folder}

# Change apt source list to point to the local repository
echo ""
echo -e "${GREEN}Ajustement des depots Beckhoff ...${NC}"
cat > "${apt_source_list}" << EOF
deb [trusted=yes] file:${localrepo_folder}/deb.beckhoff-mirror/debian ${dist_codename} main

EOF
apt-get update
