#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to install development tools

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/bafr_devtools_setup_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/bafr_devtools_setup_${TIMESTAMP}.log"
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
readonly script_date="2026-02-19"
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"

readonly dist_codename="trixie-stable"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0 <courriel> <mot de passe>${NC}"
	echo "   OU "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}     (Une adresse de courriel et un mot de passe vous seront demandes)"
	echo ""
	echo -e "${CYAN}Ce script permet d'installer les outils de developpement.${NC}"
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
echo -e "${GREEN}Verification de l'acces reseau a deb.beckhoff.com ...${NC}"
if ! ping -c 1 -W 2 deb.beckhoff.com >/dev/null; then
	echo -e "${RED}Erreur : acces reseau a deb.beckhoff.com impossible. Verifiez la connectivite.${NC}"
	exit 1
fi

# Check if running stable version of repository and warn if not
REPO_URL="https://deb.beckhoff.com/debian"; line=$(grep "^deb " /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | grep "$REPO_URL" | head -n1 | tr -s ' '); set -- $line; if [[ "$2" == \[* ]]; then CODENAME="$4"; else CODENAME="$3"; fi; echo "$CODENAME"
if [[ "${CODENAME}" != "${dist_codename}" ]]; then
	echo -e "${YELLOW}W: Ce systeme n'utilise pas la derniere version stable des paquets. Comportement imprevisible.${NC}"
fi

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
FAILED_PACKAGES=()
PACKAGES=(
build-essential
git
"linux-headers-$(uname -r)"
meson
ninja-build
bhfinfo
)

if [ "$ARCH" = "x86_64" ]; then
	# nothing here yet
	:
elif [ "$ARCH" = "aarch64" ]; then
	# nothing here yet
	:
fi

for PACKAGE in "${PACKAGES[@]}"; do
	echo ""
	echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
	apt-get install -y --no-install-recommends "$PACKAGE" || {
		echo -e "${YELLOW}W: l'installation du paquet $PACKAGE a echoue.${NC}"
		FAILED_PACKAGES+=("$PACKAGE")
	}
done

# Warn if packages are not installed
if [ ${#FAILED_PACKAGES[@]} -ne 0 ]; then
    echo -e "${YELLOW}W: les paquets suivants n'ont pas pu etre installes : ${RED}${FAILED_PACKAGES[*]}${NC}"
fi

# Clear APT cache to save space
echo ""
echo -e "${GREEN}Vidage du cache d'APT ...${NC}"
apt-get clean
