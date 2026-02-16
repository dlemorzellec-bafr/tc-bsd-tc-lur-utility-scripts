#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to backup the system disk as a compressed image

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/bafr_system_backup_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/bafr_system_backup_${TIMESTAMP}.log"
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
readonly script_date="2026-02-09"
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"

readonly image_name="cx_backup_${TIMESTAMP}.img.zst"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash $0${NC}"
	echo ""
	echo -e "${CYAN}Ce script permet de sauvegarder le disque système des CX82xx/CX9240 sous la forme d'une image compressee utilisable avec Rufus.${NC}"
	echo ""
	echo -e "${YELLOW}Veuillez vous assurer qu'une seule clef USB a ete prealablement montee. Il est important de ne pas utiliser le PC pendant la sauvegarde.${NC}"
	echo ""
	echo -e "${RED}La sauvegarde est faite sur le systeme en cours d'execution. Le fonctionnement n'est pas garanti dans 100% des cas.${NC}"
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
	usage
	exit 1
fi

# Remount boot EFI partition anyway if something went wrong
cleanup() {
    if mountpoint -q "/boot/efi"; then
        mount -o remount,rw "/boot/efi" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Required commands (not packages)
REQUIRED_CMDS="lsblk findmnt awk zstd dd truncate df mountpoint"

MISSING_CMDS=""
for cmd in $REQUIRED_CMDS; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING_CMDS="$MISSING_CMDS $cmd"
done

# If needed packages are not installed, the network connection is required
if [[ -n "$MISSING_CMDS" ]]; then
	# Verify internet connection to deb.beckhoff.com
	echo -e "${YELLOW}W: commandes necessaires manquantes:${MAGENTA}${MISSING_CMDS}${NC}"
	echo -e "${GREEN}Verification de l'acces reseau a deb.beckhoff.com ...${NC}"
	if ! ping -c 1 -W 2 deb.beckhoff.com >/dev/null; then
		echo -e "${RED}Erreur : acces reseau a deb.beckhoff.com impossible. Verifiez la connectivite.${NC}"
		exit 1
	fi

	# Install needed packages if they are not available
	echo ""
	echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
	PACKAGES=(
	fdisk
	ntfs-3g
	zstd
	lshw
	)
	for PACKAGE in "${PACKAGES[@]}"; do
		echo ""
		echo -e "${GREEN}Installation de $PACKAGE ...${NC}"
		apt-get install -y --no-install-recommends "$PACKAGE"
	done
fi

# Identification of root disk (to avoid imaging anything else)
echo ""
echo -e "${GREEN}Identification du disque racine ..."
ROOT_DISK="/dev/$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)")"

if [[ ! -b "$ROOT_DISK" ]]; then
	echo -e "${RED}Erreur : impossible d'identifier le disque racine.${NC}"
	exit 1
fi

# Look for a mounted USB device
echo ""
echo -e "${GREEN}Recherche d'un support USB monte ...${NC}"
USB_MOUNT=""
while IFS= read -r line; do
    # line format: /dev/sdb1 /media/usb0 1
    dev=$(echo "$line" | cut -d' ' -f1)
    mountpoint=$(echo "$line" | cut -d' ' -f2)
    rmflag=$(echo "$line" | cut -d' ' -f3)

    if [[ "$rmflag" == "1" && -n "$mountpoint" ]]; then
        USB_MOUNT="$mountpoint"
        break
    fi
done < <(lsblk -rpo NAME,MOUNTPOINT,RM)

if [[ -z "${USB_MOUNT}" ]]; then
    echo -e "${RED}Erreur : pas de support USB monte detecte.${NC}"
    exit 1
fi

USB_PART="$(findmnt -n -o SOURCE --target "$USB_MOUNT")"
USB_DISK="/dev/$(lsblk -no PKNAME "${USB_PART}")"

if [[ "${USB_DISK}" == "${ROOT_DISK}" ]]; then
	echo -e "${RED}Erreur critique : le support detecte est le disque racine.${NC}"
	exit 1
fi

# Verify available space and writability on the USB device
echo ""
echo -e "${GREEN}Verification de l'espace disponible sur le support USB ...${NC}"
FREE_SPACE_GIO=$(df -BG --output=avail "$USB_MOUNT" | tail -n 1 | tr -d 'G ')

echo -e "${CYAN}Espace libre : ${MAGENTA}${FREE_SPACE_GIO} Gio.${NC}"

if (( FREE_SPACE_GIO < 6 )); then
	echo -e "${RED}Erreur : espace insuffisant sur le support USB (>= 6 Gio requis).${NC}"
	exit 1
fi

if [[ ! -w "${USB_MOUNT}" ]]; then
	echo -e "${RED}Erreur : le point de montage USB n'est pas disponible en ecriture.${NC}"
	exit 1
fi

truncate -s 6G "${USB_MOUNT}/.test.img" || {
	echo -e "${RED}Erreur : le systeme de fichiers de destination n'admet pas de fichiers assez larges.${NC}"
	exit 1
}
rm -f "${USB_MOUNT}/.test.img"

# Ensure system quiescence to avoid errors during backup
echo ""
echo -e "${GREEN}Preparation du systeme (Limitation des operations d'ecriture) ...${NC}"
sync
echo 3 > "/proc/sys/vm/drop_caches" || true
sync

EFI_REMOUNTED=0
if mountpoint -q "/boot/efi"; then
    mount -o remount,ro "/boot/efi" || echo -e "${YELLOW}W: Echec du remontage de /boot/efi en lecture seule.${NC}"
    EFI_REMOUNTED=1
fi

echo ""
echo -e "${RED}Attention : ${YELLOW}Veuillez ne pas utiliser ou interrompre le PC durant la sauvegarde.${NC}"

# Backup root disk to image
echo ""
echo -e "${GREEN}Creation de l'image du disque systeme ...${NC}"

if [[ ! "${1:-}" == "--dry-run" ]]; then
	echo -e "${YELLOW}L'operation peut prendre plusieurs heures !${NC}"
	# fullblock = avoid sparse imaging, -19 = max compression, -T1 = single CPU thread (to limit system load)
	dd if="${ROOT_DISK}" bs=1M iflag=fullblock status=progress | zstd -19 -T1 > "${USB_MOUNT}/${image_name}" || {
		echo -e "${RED}Erreur : la creation de l'image a echoue.${NC}"
		exit 1
	}
	echo -e "${CYAN}Operation terminee.${NC}"
	ls -lh "${USB_MOUNT}/${image_name}"

	# Verify image integrity
	echo ""
	echo -e "${GREEN}Verification de l'integrite du fichier image ...${NC}"
	zstd -t "${USB_MOUNT}/${image_name}"
	echo -e "${CYAN}Verification terminee.${NC}"

# Test mode for debug purposes
else
	echo -e "${YELLOW}Mode de test. Aucune image n'est realisee.${NC}"
fi

# Remount boot EFI partition to read-write
echo ""
if [[ "$EFI_REMOUNTED" -eq 1 ]]; then
    echo -e "${GREEN}Remontage de /boot/efi ...${NC}"
    mount -o remount,rw "/boot/efi" || echo -e "${YELLOW}W: Echec du remontage de ${MAGENTA}/boot/efi${NC}"
fi
