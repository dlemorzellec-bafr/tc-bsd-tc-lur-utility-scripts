#!/bin/sh

echo ""
echo "Script BAFR - Installation et configuration de TF6250 Modbus TCP"

#Passage de la disposition du clavier en francais AZERTY
echo ""
echo "Passage du clavier en francais standard..."
sysrc keymap="fr.kbd"

#Mise a jour des depots de paquets et de pkg
echo ""
echo "Mise a jour de pkg et des depots de paquets..."
pkg update -f
pkg install -y pkg

#Installation de paquets supplementaires
echo ""
echo "Installation des paquets necessaires..."
PACKAGES="
TF6250-Modbus-TCP
"

for PACKAGE in $PACKAGES; do
  pkg install -y $PACKAGE
done

#Creation du fichier de configuration Modbus
echo ""
echo "Creation du fichier de configuration du serveur Modbus TCP..."
touch /usr/local/etc/TwinCAT/Functions/TF6250-Modbus-TCP/TcModbusSrv.xml
MBCONF="/usr/local/etc/TwinCAT/Functions/TF6250-Modbus-TCP/TcModbusSrv.xml"
echo "<Configuration>" >> "$MBCONF"
echo "  <Port>502</Port>" >> "$MBCONF"
echo "  <IpAddr>127.0.0.1</IpAddr>" >> "$MBCONF"
echo "    <Mapping>" >> "$MBCONF"
echo "    <InputRegisters>" >> "$MBCONF"
echo "      <MappingInfo>" >> "$MBCONF"
echo "        <AdsPort>851</AdsPort>" >> "$MBCONF"
echo "        <StartAddress>32768</StartAddress>" >> "$MBCONF"
echo "        <EndAddress>33023</EndAddress>" >> "$MBCONF"
echo "        <VarName>GVL.mb_Input_Registers</VarName>" >> "$MBCONF"
echo "      </MappingInfo>" >> "$MBCONF"
echo "    </InputRegisters>" >> "$MBCONF" 
echo "    <OutputRegisters>" >> "$MBCONF"
echo "      <MappingInfo>" >> "$MBCONF"
echo "        <AdsPort>851</AdsPort>" >> "$MBCONF"
echo "        <StartAddress>0</StartAddress>" >> "$MBCONF"
echo "        <EndAddress>24575</EndAddress>" >> "$MBCONF"
echo "        <IndexGroup>16416</IndexGroup>" >> "$MBCONF"
echo "        <IndexOffset>0</IndexOffset>" >> "$MBCONF"
echo "      </MappingInfo>" >> "$MBCONF"
echo "      <MappingInfo>" >> "$MBCONF"
echo "        <AdsPort>851</AdsPort>" >> "$MBCONF"
echo "        <StartAddress>32768</StartAddress>" >> "$MBCONF"
echo "        <EndAddress>33023</EndAddress>" >> "$MBCONF"
echo "        <VarName>GVL.mb_Output_Registers</VarName>" >> "$MBCONF"
echo "      </MappingInfo>" >> "$MBCONF"
echo "    </OutputRegisters>" >> "$MBCONF"
echo "    <InputCoils>" >> "$MBCONF"
echo "      <MappingInfo>" >> "$MBCONF"
echo "        <AdsPort>851</AdsPort>" >> "$MBCONF"
echo "        <StartAddress>32768</StartAddress>" >> "$MBCONF"
echo "        <EndAddress>33023</EndAddress>" >> "$MBCONF"
echo "        <VarName>GVL.mb_Input_Coils</VarName>" >> "$MBCONF"
echo "      </MappingInfo>" >> "$MBCONF"
echo "    </InputCoils>" >> "$MBCONF"
echo "    <OutputCoils>" >> "$MBCONF"
echo "      <MappingInfo>" >> "$MBCONF"
echo "        <AdsPort>851</AdsPort>" >> "$MBCONF"
echo "        <StartAddress>32768</StartAddress>" >> "$MBCONF"
echo "        <EndAddress>33023</EndAddress>" >> "$MBCONF"
echo "        <VarName>GVL.mb_Output_Coils</VarName>" >> "$MBCONF"
echo "      </MappingInfo>" >> "$MBCONF"
echo "    </OutputCoils>" >> "$MBCONF"
echo "  </Mapping>" >> "$MBCONF"
echo "</Configuration>" >> "$MBCONF"
echo "" >> "$MBCONF"

#Redemarrage du service TwinCAT pour prendre en compte la configuration
echo ""
echo "Redemarrage de TwinCAT..."
service TcSystemService restart

# Creation d'un point de restauration systeme
echo ""
echo "Creation d'un point de restauration systeme..."
restorepoint create BAFR-TF6250-Modbus-TCP

# Redemarrage de la machine
echo ""
echo "Redemarrage du systeme..."
reboot
