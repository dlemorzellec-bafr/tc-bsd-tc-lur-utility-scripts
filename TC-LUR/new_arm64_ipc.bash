#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up repositories, TwinCAT XAR runtime and some French accessibility for Beckhoff CX82xx and CX9240 IPCs

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
readonly script_date="2025-11-12"

readonly twincat_folder="/etc/TwinCAT"
readonly twincat_functions="${twincat_folder}/Functions"

readonly apt_folder="/etc/apt"
readonly apt_auth_file="${apt_folder}/auth.conf.d/bhf.conf"

readonly beckhoff_source_list="${apt_folder}/sources.list.d/bhf.list"
readonly debian_sources_list="${apt_folder}/sources.list"

readonly dist_version="trixie"
readonly dist_codename="${dist_version}-stable"
readonly dist_security="${dist_version}-security"

readonly beckhoff_keyring_file="/usr/share/keyrings/bhf.asc"
readonly beckhoff_repo_url="https://deb.beckhoff.com/debian"
readonly beckhoff_public_key_url="https://deb.beckhoff.com/repo.pub"

readonly debian_mirror_url="https://deb-mirror.beckhoff.com/debian"
readonly debian_mirror_security_url="https://deb-mirror.beckhoff.com/debian-security"

readonly etc_keyboard_conf="/etc/default/keyboard"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0 <courriel> <mot de passe>${NC}"
	echo "   OU "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}     (Une adresse de courriel et un mot de passe vous seront demandes)"
	echo ""
	echo -e "${CYAN}Ce script permet de configurer le gestionnaire de paquets, l'installation de TwinCAT XAR et l'accessibilite francaise sur une nouvelle image TC/LUR.${NC}"
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

# Collect credentials
if [ "$#" -eq 2 ]; then
	EMAIL="$1"
	PASSWORD="$2"
elif [ "$#" -eq 0 ]; then
	read -rp "Entrez le courriel myBeckhoff : " EMAIL
	read -rsp "Entrez le mot de passe myBeckhoff : " PASSWORD
	echo
else
	usage
	exit 1
fi

echo ""
echo -e "${YELLOW} --- BAFR - Script de configuration de TC/LUR - ${script_date} --- ${NC}"
echo ""

# Create APT auth config
echo ""
echo -e "${GREEN}Creation du fichier d'authentification pour APT ...${NC}"
mkdir -p "$(dirname "$apt_auth_file")"
touch "${apt_auth_file}"
cat > "${apt_auth_file}" << EOF
machine deb.beckhoff.com
login $EMAIL
password $PASSWORD

machine deb-mirror.beckhoff.com
login $EMAIL
password $PASSWORD

EOF
chmod 600 "$apt_auth_file"

# Add Beckhoff APT repositories
echo ""
echo -e "${GREEN}Ajustement des depots Beckhoff ...${NC}"
mkdir -p "$(dirname "$beckhoff_source_list")"
rm -f "${beckhoff_source_list}"
touch "${beckhoff_source_list}"
cat >> "${beckhoff_source_list}" << EOF
deb [signed-by=${beckhoff_keyring_file}] ${beckhoff_repo_url} ${dist_codename} main

EOF
cat > "${debian_sources_list}" << EOF
deb ${debian_mirror_url} ${dist_version} main contrib non-free non-free-firmware
deb ${debian_mirror_security_url} ${dist_security} main contrib non-free non-free-firmware

EOF

# Import Beckhoff GPG key if not already present
if [ ! -f "${beckhoff_keyring_file}" ]; then
	echo -e "${YELLOW}W: La clef publique de Beckhoff n'est pas presente.${NC}"
	echo -e "${GREEN}Tentative d'importation de la clef publique ...${NC}"
	if command -v gpg > /dev/null; then
		curl -fsSL "${beckhoff_public_key_url}" | gpg --dearmor -o "${beckhoff_keyring_file}"
	else
		echo -e "${YELLOW}W: GnuPG n'est pas disponible.${NC}"
		echo -e "${GREEN}Tentative avec une clef en base 64 enregistree ...${NC}"
		curl -fsSL "${beckhoff_public_key_url}"
		base64 -d >> "${beckhoff_keyring_file}" << EOF
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
EOF
		chmod 644 "${beckhoff_keyring_file}"
	fi
fi

# Update and upgrade all packages
echo ""
echo -e "${GREEN}Mise a jour des depots et des paquets de la distribution ...${NC}"
apt-get -y update -o Acquire::Retries=3
apt-get -y upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Configure timezone (France metropolitaine)
echo ""
echo -e "${GREEN}Configuration du fuseau horaire sur Europe/Paris ...${NC}"
timedatectl set-timezone Europe/Paris
echo "$(date)"

# Configure keyboard layout to AZERTY default (French)
echo ""
echo -e "${GREEN}Configuration du clavier AZERTY francais ...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends keyboard-configuration console-setup

echo 'keyboard-configuration  keyboard-configuration/layoutcode  select  fr' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/modelcode   select  pc105' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/variantcode select  latin9' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/layout      select  French' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/variant     select  Latin9' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/model       select  PC105' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/store_defaults_in_debconf_db boolean true' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/toggle      select  No toggling' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/altgr       select  The default for the keyboard layout' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/compose     select  No compose key' | debconf-set-selections
echo 'keyboard-configuration  keyboard-configuration/xkb-keymap  select  fr' | debconf-set-selections

DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive keyboard-configuration

rm -f "${etc_keyboard_conf}"
touch "${etc_keyboard_conf}"
cat > "${etc_keyboard_conf}" << EOF
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page

XKBMODEL="pc105"
XKBLAYOUT="fr"
XKBVARIANT=""
XKBOPTIONS="lv3:ralt_switch"

BACKSPACE="guess"

EOF

# Update console configuration and initramfs
echo ""
echo -e "${GREEN}Mise a jour de la configuration de la console et d'initramfs ...${NC}"
setupcon --force
update-initramfs -u

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
PACKAGES=(
gnupg
dialog
apt-utils
apt-rdepends
dpkg-dev
git
lshw
tc31-xar-um
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

# Reboot system to finish set up TwinCAT/LUR
echo ""
echo -e "${RED}Un redemarrage du systeme est necessaire.${NC}"
if [ "$#" -eq 0 ]; then
	read -rp "Redemarrer le systeme maintenant ? [Y/n] : " REBOOT_CHOICE
	if [[ "$REBOOT_CHOICE" =~ ^[OoYy]?$ ]]; then
		reboot
	else
		echo -e "${RED}Redemarrage annule. Veuillez redemarrer manuellement pour finaliser la configuration.${NC}"
	fi
else
	reboot
fi
