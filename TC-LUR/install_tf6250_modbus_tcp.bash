#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up a Modbus TCP Server with firewall relevent rule and custom server configuration

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/bafr_tf6250_setup_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/bafr_tf6250_setup_${TIMESTAMP}.log"
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
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet d'installer la fonction TF6250 Modbus TCP et de configurer le pare-feu et le serveur Modbus.${NC}"
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
echo -e "${GREEN}Verification de l'acces reseau a deb.beckhoff.com ...${NC}"
if ! ping -c 1 -W 2 deb.beckhoff.com >/dev/null; then
	echo "${RED}Erreur : acces reseau a deb.beckhoff.com impossible. ${YELLOW}Verifiez la connectivite.${NC}"
	exit 1
fi

# Install needed packages
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
PACKAGES=(
tf6250-modbus-tcp
)
for PACKAGE in "${PACKAGES[@]}"; do
	echo ""
	echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
	apt-get install -y --no-install-recommends "$PACKAGE"
done

# Constants
readonly nftables_modbus_conf="/etc/nftables.conf.d/60-modbus.conf"
readonly modbus_server_conf="/etc/TwinCAT/Functions/TF6250-Modbus-TCP/TcModbusSrv.xml"
readonly modbus_server_conf_dir="/etc/TwinCAT/Functions/TF6250-Modbus-TCP/Server"
readonly modbus_server_conf_server="${modbus_server_conf_dir}/TcModbusSrv.xml"

# Firewall rule edit function
nftables_rule_edit() {
	touch "${nftables_modbus_conf}"
	cat >> "${nftables_modbus_conf}" << EOF
table inet filter {
  chain input {
    # accept ModbusTCP
    tcp dport 502 accept
  }
}

EOF
}

# Configure Modbus TCP Firewall rule
echo ""
echo -e "${GREEN}Creation de la regle de pare-feu pour Modbus TCP ...${NC}"
echo ""
if [ -e "${nftables_modbus_conf}" ]; then
	echo -e "${YELLOW}W: Le fichier de regle du pare-feu pour Modbus TCP existe deja.${NC}"
	echo ""
	rm -f "${nftables_modbus_conf}"
	echo -e "${RED}Le fichier a ete remplace${NC}"
	echo ""
	nftables_rule_edit
else
	nftables_rule_edit
fi
systemctl reload nftables

# Modbus TCP sever configuration edit function
modbus_server_conf_edit() {
	#touch "${modbus_server_conf}"
	mkdir -p ${modbus_server_conf_dir}
	touch "${modbus_server_conf_server}"
	cat >> "${modbus_server_conf_server}" << EOF
<?xml version="1.0"?>
<Configuration>
  <Port>502</Port>
  <IpAddr>127.0.0.1</IpAddr>
    <Mapping>
    <InputRegisters>
      <MappingInfo>
        <AdsPort>851</AdsPort>
        <StartAddress>32768</StartAddress>
        <EndAddress>33023</EndAddress>
        <VarName>GVL.mb_Input_Registers</VarName>
      </MappingInfo>
    </InputRegisters>
    <OutputRegisters>
      <MappingInfo>
        <AdsPort>851</AdsPort>
        <StartAddress>12288</StartAddress>
        <EndAddress>24575</EndAddress>
        <IndexGroup>16416</IndexGroup>
        <IndexOffset>0</IndexOffset>
      </MappingInfo>
      <MappingInfo>
        <AdsPort>851</AdsPort>
        <StartAddress>32768</StartAddress>
        <EndAddress>33023</EndAddress>
        <VarName>GVL.mb_Output_Registers</VarName>
      </MappingInfo>
    </OutputRegisters>
    <InputCoils>
      <MappingInfo>
        <AdsPort>851</AdsPort>
        <StartAddress>32768</StartAddress>
        <EndAddress>33023</EndAddress>
        <VarName>GVL.mb_Input_Coils</VarName>
      </MappingInfo>
    </InputCoils>
    <OutputCoils>
      <MappingInfo>
        <AdsPort>851</AdsPort>
        <StartAddress>32768</StartAddress>
        <EndAddress>33023</EndAddress>
        <VarName>GVL.mb_Output_Coils</VarName>
      </MappingInfo>
    </OutputCoils>
  </Mapping>
</Configuration>

EOF
}

# Create Modbus TCP Server configuration
echo ""
echo -e "${GREEN}Creation de la configuration du serveur Modbus TCP ...${NC}"
echo ""
if [ -e "${modbus_server_conf_server}" ]; then
	echo -e "${YELLOW}W: Le fichier de configuration du serveur Modbus TCP existe deja.${NC}"
	echo ""
	rm -f "${modbus_server_conf}"
	rm -f "${modbus_server_conf_server}"
	echo -e "${RED}Le fichier a ete remplace${NC}"
	echo ""
	modbus_server_conf_edit
else
	modbus_server_conf_edit
fi


