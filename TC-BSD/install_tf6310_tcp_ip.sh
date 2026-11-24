#!/bin/sh
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up TCP/IP with firewall relevent rule and custom server configuration

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
TF6310-TCP-IP
"

for PACKAGE in $PACKAGES; do
  pkg install -y $PACKAGE
done

# Open TCP ports for TF6310 TCP/IP (12000 = Quick Start sample, 200 = Sample01-03)
echo ""
echo "Ouverture des ports TCP 12000 et 200 (TF6310) dans le pare-feu..."
PF_BHF="/etc/pf.conf.d/bhf"
for PORT in 12000 200; do
  RULE="pass in quick proto tcp to port $PORT keep state"
  grep -qxF "$RULE" "$PF_BHF" 2>/dev/null || echo "$RULE" >> "$PF_BHF"
done
pfctl -nf /etc/pf.conf && pfctl -f /etc/pf.conf

# Restart TwinCAT system service to apply the new configuration
echo ""
echo "Redemarrage de TwinCAT..."
service TcSystemService restart

# Creation of a restore point after the changes
echo ""
echo "Creation d'un point de restauration systeme..."
restorepoint create BAFR-TF6310-TCP-IP

# Reboot system
echo ""
echo "Redemarrage du systeme..."
reboot
