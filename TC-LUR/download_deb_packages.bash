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

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet de telecharger les DEBs des paquets du depot Beckhoff pour une installation ulterieure via un depot local.${NC}"
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
echo "${GREEN}Verification de l'acces reseau a deb.beckhoff.com ...${NC}"
if ! ping -c 1 -W 2 deb.beckhoff.com >/dev/null; then
	echo -e "${RED}Erreur : acces reseau a deb.beckhoff.com impossible. Verifiez la connectivite.${NC}"
	exit 1
fi

# Ensure the apt source list is in its valid state
echo ""
echo -e "${GREEN}Ajustement des depots Beckhoff ...${NC}"
cat > "${apt_source_list}" << EOF
deb [signed-by=${beckhoff_keyring_file}] ${beckhoff_repo_url} ${dist_codename} main

EOF
apt-get update

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
PACKAGES=(
apt-mirror
rsync
)
for PACKAGE in "${PACKAGES[@]}"; do
	echo ""
	echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
	apt-get install -y --no-install-recommends "$PACKAGE"
done

# Configure apt-mirror
echo ""
echo -e "${GREEN}Configuration de apt-mirror ...${NC}"
cat > "${apt_mirror_conf}" << EOF
############# config ##################
#
set base_path    ${beckhoff_mirror_parent}
#
# set mirror_path  ''base_path/mirror
# set skel_path    ''base_path/skel
# set var_path     ''base_path/var
# set cleanscript ''var_path/clean.sh
# set defaultarch  <running host architecture>
# set postmirror_script ''var_path/postmirror.sh
# set run_postmirror 0
set nthreads     20
set _tilde 0
#
############# end config ##############

deb ${beckhoff_repo_url} ${dist_codename} main

clean ${beckhoff_repo_url}

EOF

# Run mirror
echo ""
echo -e "${GREEN}Creation du miroir de paquets dans ${MAGENTA}${beckhoff_mirror_folder}${GREEN} ...${NC}"
echo ""
echo -e "${YELLOW}L'operation peut prendre plusieurs dizaines de minutes.${NC}"
apt-mirror

echo ""
echo -e "${CYAN}Veuillez copier le miroir sur un peripherique amovible en utilisant la commande :${NC}"
echo -e "${MAGENTA}sudo rsync -av ${beckhoff_mirror_folder}/deb.beckhoff.com/debian <point de montage USB>/deb.beckhoff-mirror${NC}"
