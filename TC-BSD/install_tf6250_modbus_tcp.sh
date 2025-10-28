#!/bin/sh
# SPDX-License-Identifier: 0BSD
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up a Modbus TCP Server with firewall relevent rule and custom server configuration

echo ""
echo "Script BAFR - Installation et configuration de TF6250 Modbus TCP"

# Configure keyboard layout to AZERTY default (French)
echo ""
echo "Passage du clavier en francais standard..."
sysrc keymap="fr.kbd"

# An upgrade of the pkg package manager is often necessary at this point
echo ""
echo "Mise a jour de pkg et des depots de paquets..."
pkg update -f
pkg install -y pkg

# Install needed packages
echo ""
echo "Installation des paquets necessaires..."
PACKAGES="
TF6250-Modbus-TCP
"

for PACKAGE in $PACKAGES; do
  pkg install -y $PACKAGE
done

# Create Modbus TCP Server configuration
echo ""
echo "Creation du fichier de configuration du serveur Modbus TCP..."
touch /usr/local/etc/TwinCAT/Functions/TF6250-Modbus-TCP/TcModbusSrv.xml
cat > "/usr/local/etc/TwinCAT/Functions/TF6250-Modbus-TCP/TcModbusSrv.xml" << EOF
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

# Restart TwinCAT system service to apply the new configuration
echo ""
echo "Redemarrage de TwinCAT..."
service TcSystemService restart

# Creation of a restore point after the changes
echo ""
echo "Creation d'un point de restauration systeme..."
restorepoint create BAFR-TF6250-Modbus-TCP

# Reboot system
echo ""
echo "Redemarrage du systeme..."
reboot
