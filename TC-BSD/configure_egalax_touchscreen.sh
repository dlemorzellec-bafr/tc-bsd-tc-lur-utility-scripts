#!/bin/sh
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to help a Beckhoff panel PC or touchscreen of the eGalax variety to be recognised by FreeBSD

echo ""
echo "Script BAFR - Configuration d'un ecran tactile eGalax pour Panel PCs et Ecrans Beckhoff"

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
	echo ""
	echo "Le script doit etre execute en tant que root."
	echo ""
	exit 1
fi

# Verify that there is an eGalax touchscreen present
if ! usbconfig list | grep -q "eGalaxTouch" ; then
	echo ""
	echo "Pas de dalle tactile de type eGalax n'a ete detectee."
	echo ""
	exit 1
fi

# Load cuse module in kernel
echo ""
echo "Chargement du module de noyau cuse..."
sysrc kld_list+=cuse
sysrc -f /boot/loader.conf cuse_load="YES"
kldload cuse

# Force device identification using webcamd
echo ""
echo "Execution de la reconaissance de la dalle eGalax..."
sysrc webcamd_enable="YES"
device_egalax=$(usbconfig list | grep "eGalaxTouch" | awk '{print $1}')
webcamd -d $device_egalax

# Create a script to force identification on each execution
echo ""
echo "Creation du script de reconnaissance de la dalle eGalax..."
touch /usr/local/etc/egalax_start.sh
cat > "/usr/local/etc/egalax_start.sh" << EOF
#!/bin/sh

device_egalax=$(usbconfig list | grep "eGalaxTouch" | awk '{print $1}')
webcamd -d $device_egalax

EOF
chmod +x /usr/local/etc/egalax_start.sh

# Add new script to cron schedule for each reboot
echo ""
echo "Planification de l'execution du script de reconnaissance..."
cat >> "/etc/cron.d/crontab" << EOF
@reboot root /usr/local/etc/egalax_start.sh
EOF

# Creation of a restore point after the changes
echo ""
echo "Creation d'un point de restauration systeme..."
restorepoint create BAFR-eGalaxTouch

