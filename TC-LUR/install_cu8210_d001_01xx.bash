#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up and configure a Beckhoff Wifi dongle

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/install_cu8210_d001_01xx_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/install_cu8210_d001_01xx_${TIMESTAMP}.log"
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
readonly network_country="FR"

readonly driver_repository_url="https://github.com/lwfinger/rtw88"

readonly wpa_supplicant_folder="/etc/wpa_supplicant"
readonly systemd_networkd_folder="/etc/systemd/network"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0$ <SSID du reseau Wifi> <mot de passe du reseau Wifi>{NC}"
	echo "   OU "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}     (Le SSID et le mot de passe du reseau Wifi vous seront demandes)"
	echo ""
	echo -e "${CYAN}Ce script permet d'installer et de configurer la clef Wifi Beckhoff.${NC}"
	echo -e "${YELLOW}La clef Wifi doit etre branchee sur un port USB de la machine.${NC}"
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
	echo -e "${RED}Erreur : Acces reseau a deb.beckhoff.com impossible. Verifiez la connectivite.${NC}"
	exit 1
fi

# Verify internet connection to github.com
echo "${GREEN}Verification de l'acces reseau a github.com ...${NC}"
if ! ping -c 1 -W 2 github.com >/dev/null; then
	echo -e "${RED}Erreur : Acces reseau a github.com impossible. Verifiez la connectivite.${NC}"
	exit 1
fi

# Collect credentials
if [ "$#" -eq 2 ]; then
	SSID="$1"
	PASSWORD="$2"
elif [ "$#" -eq 0 ]; then
	read -rp "Entrez le SSID du reseau Wifi : " SSID
	read -rsp "Entrez le mot de passe du reseau Wifi : " PASSWORD
	echo
else
	usage
	exit 1
fi

# Function to convert MAC address to network interface name
mac_to_wlx() {
	printf 'wlx%s\n' "$(printf '%s' "$1" | tr -d ':' | tr 'A-F' 'a-f')"
}

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
apt-get update -y
PACKAGES=(
usbutils
build-essential
dkms
git
"linux-headers-$(uname -r)"
wpasupplicant
)
for PACKAGE in "${PACKAGES[@]}"; do
	echo ""
	echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
	apt-get install -y --no-install-recommends "$PACKAGE"
done

# Clone driver repository
echo ""
echo -e "${GREEN}Telechargement des pilotes materiels ...${NC}"
cd /usr/src
if [ ! -d rtw88 ]; then
	git clone "${driver_repository_url}"
else
	echo -e "${YELLOW}W: Le depot des pilotes existe deja : ${MAGENTA}/usr/src/rtw88${NC}"
fi

# Build driver modules
if ! lsmod | grep -q '^rtw_8821au'; then
	echo ""
	echo -e "${GREEN}Compilation des pilotes ...${NC}"
	cd rtw88
	make clean || true
	make -j$(nproc)
	make install
	make install_fw
	cp -f rtw88.conf /etc/modprobe.d/ 2>/dev/null || true
else
	echo ""
	echo -e "${CYAN}Le module pilote rtw_8821au est deja charge. La compilation n'est pas necessaire.${NC}"
fi

# Reload drivers
echo ""
echo -e "${GREEN}Chargement des pilotes ...${NC}"
sudo modprobe -r rtw_8821au 2>/dev/null || true
sudo modprobe rtw_8821au || true

# Detection of network interface
echo ""
echo -e "${GREEN}Detection de l'interface reseau de la clef Wifi ...${NC}"
NIF=$(ip link | grep -oE '^[0-9]+: wlx[0-9a-f]+' | head -n1 | sed 's/^[0-9]*: //')
if [ -z "$NIF" ]; then
	echo -e "${RED}Erreur: L'interface Wifi n'est pas detectee. Veuillez verifier le branchement de la clef Wifi.${NC}"
	usage
	exit 1
fi
echo -e "${CYAN}Interface detectee : ${MAGENTA}$NIF${NC}"

# Creation of wpa_supplicant configuration
echo ""
echo -e "${GREEN}Creation de la configuration pour wpa_supplicant ...${NC}"
mkdir -p ${wpa_supplicant_folder}
touch "${wpa_supplicant_folder}/wpa_supplicant-$NIF.conf"
cat > "${wpa_supplicant_folder}/wpa_supplicant-$NIF.conf" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${network_country}

network={
    ssid="$SSID"
	psk="$PASSWORD"
}

EOF

# Creation of systemd-networkd configuration
echo ""
echo -e "${GREEN}Creation de la configuration pour systemd-networkd ...${NC}"
mkdir -p ${systemd_networkd_folder}
touch "${systemd_networkd_folder}"
cat > "${systemd_networkd_folder}/25-wireless.network" << EOF
[Match]
Name=$NIF

[Network]
DHCP=yes

EOF

# Start wpa_supplicant
echo ""
echo -e "${GREEN}Demarrage de wpa_supplicant ...${NC}"
pkill wpa_supplicant 2>/dev/null || true
wpa_supplicant -B -i $NIF -c "${wpa_supplicant_folder}/wpa_supplicant-$NIF.conf"

# Restart systemd-networkd
echo ""
echo -e "${GREEN}Redemarrage de systemd-networkd ...${NC}"
systemctl restart systemd-networkd

# Bring interface up
echo ""
echo -e "${GREEN}Activation de l'interface reseau ...${NC}"
ip link set $NIF up

# Wait for DHCP to assign IP address
echo ""
echo -e "${GREEN}En attente de l'attribution d'une adresse IP par DHCP ...${NC}"
sleep 8
IP=$(ip -4 addr show "$NIF" | grep 'inet ' | sed 's/.*inet \([0-9.\/]*\).*/\1/')
if [ -n "$IP" ]; then
	echo -e "${GREEN}L'interface Wifi ${MAGENTA}$NIF${GREEN}est connectee a l'adresse IP : ${MAGENTA}$IP${NC}"
else
	echo -e "${YELLOW}W: La configuration DHCP n'est pas terminee. Veuillez executer la commande ${MAGENTA}networkctl status $NIF${YELLOW} pour plus d'infos.${NC}"
fi

# Enable persistence on boot
echo ""
echo -e "${GREEN}Activation de la persistence de la configuration ...${NC}"
systemctl enable "wpa_supplicant@${NIF}" || true
systemctl enable systemd-networkd || true

# Reboot system to finish the setup
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