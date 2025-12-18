#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up the TF1200-Sway graphical interface and HMI Client and custom configuration with TwinCAT HMI Server

set -eu -o pipefail

# Logging script return
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/bafr_tf1200_setup_${TIMESTAMP}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
	LOG_FILE="/tmp/bafr_tf1200_setup_${TIMESTAMP}.log"
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
readonly script_date="2025-11-06"
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"

readonly twincat_folder="/etc/TwinCAT"
readonly twincat_functions="${twincat_folder}/Functions"
readonly tf1200_path="${twincat_functions}/TF1200-UI-Client"
readonly tf1200_srcpath="${tf1200_path}/scripts"
readonly tf2000_path="${twincat_functions}/TF2000-HMI-Server"

readonly firewall_rulepath="/etc/nftables.conf.d/70-twincat-hmi.conf"

readonly graph_user="tf1200-user"
readonly graph_user_path="/home/${graph_user}"
readonly graph_user_bashrc_path="${graph_user_path}/.bashrc"
readonly graph_user_profile_path="${graph_user_path}/.profile"
readonly sway_userconfig="${graph_user_path}/.config/sway"
readonly tf1200_userconfig="${graph_user_path}/.config/TF1200-UI-Client"

# Usage display function
usage() {
	echo ""
	echo "USAGE : "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0 <mot de passe pour TF1200-TF2000>${NC}"
	echo "   OU "
	echo -e "  ${GREEN}sudo bash ${MAGENTA}$0${NC}     (Un mot de passe pour l'utilisateur graphique et TwinCAT HMI vous sera demande)"
	echo ""
	echo -e "${CYAN}Ce script permet l'installation et la configuration de TF1200 et TF2000.${NC}"
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
echo "Verification de l'acces reseau a deb.beckhoff.com ..."
if ! ping -c 1 -W 2 deb.beckhoff.com >/dev/null; then
	echo -e "${RED}Erreur : acces reseau a deb.beckhoff.com impossible. Verifiez la connectivite.${NC}"
	exit 1
fi

# Collect credentials
if [ "$#" -eq 1 ]; then
	HMI_PASSWORD="$1"
elif [ "$#" -eq 0 ]; then
	read -rsp "Entrez le mot de passe pour TwinCAT HMI : " HMI_PASSWORD
	echo
else
	usage
	exit 1
fi

# Install needed packages (to edit as needed)
echo ""
echo -e "${GREEN}Installation de paquets supplementaires ...${NC}"
PACKAGES=(
tf2000-hmi-server
tf1200-ui-client
seatd
dbus
mesa-utils
mesa-va-drivers
fonts-dejavu
foot
bemenu
grim
grimshot
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

# Add firewall rule for TF2000 and reload firewall
echo ""
echo -e "${GREEN}Ajout d'une exception du pare-feu pour TF2000 ...${NC}"
touch ${firewall_rulepath}
cat >> "${firewall_rulepath}" << EOF
table inet filter {
  chain input {
    # accept TwinCAT HMI server
	tcp dport 2010 accept
	tcp dport 2020 accept
  }
}

EOF
systemctl reload nftables

# Initialise TwinCAT HMI server
echo ""
echo -e "${GREEN}Initialisation du serveur TwinCAT HMI ...${NC}"
TcHmiSrv --initialize --password="${HMI_PASSWORD}"

systemctl enable --now TcHmiSrv.service
systemctl start TcHmiSrv.service

# Initialise seatd
echo ""
echo -e "${GREEN}Initialisation de seatd ...${NC}"
systemctl enable --now seatd.service
systemctl start seatd.service

# Initialise dbus
echo ""
echo -e "${GREEN}Initialisation de dbus ...${NC}"
systemctl enable --now dbus.service
systemctl start dbus.service

# Creation of the graphical user
echo ""
echo -e "${GREEN}Creation de l'utilisateur graphique ${graph_user} ...${NC}"
useradd -c "User for TwinCAT UI Client" -m -s "$(command -v bash)" "${graph_user}"
sed -i "s/^${graph_user}:\!:/${graph_user}::/g" /etc/shadow
usermod -aG video "${graph_user}"

# Configuration of the Wayland runtime for the graphical user
echo ""
echo -e "${GREEN}Configuration du runtime Wayland pour l'utilisateur graphique ...${NC}"
if [ -z "$(grep -F "export XDG_RUNTIME_DIR" "${graph_user_profile_path}")" ]; then
	cat >> "${graph_user_profile_path}" <<- EOF
	# All compositors using Wayland will need a runtime directory
	XDG_RUNTIME_DIR=/run/user/$(id -u "${graph_user}") export XDG_RUNTIME_DIR
	# Fix software rendering issues (EDIT BAFR)
	# WLR_RENDERER_ALLOW_SOFTWARE=1 export WLR_RENDERER_ALLOW_SOFTWARE

EOF
fi 

# Creation of configuration folders
echo ""
echo -e "${GREEN}Creation des dossiers de configuration ...${NC}"
mkdir -p ${graph_user_path}/.config
mkdir -p ${graph_user_path}/.config/sway
mkdir -p ${graph_user_path}/.config/TF1200-UI-Client
chown -R ${graph_user} ${graph_user_path}/.config
chown -R ${graph_user} ${sway_userconfig}
chown -R ${graph_user} ${tf1200_userconfig}

# Creation of the Sway configuration file
echo ""
echo -e "${GREEN}Creation de la configuration de Sway ...${NC}"
touch ${sway_userconfig}/config
cat > "${sway_userconfig}/config" << EOF
# Configuration de Sway (BAFR, DELM, 2025-05-06)

### EDIT BAFR : Support for XWayland
xwayland enable

### Variables
#
# Logo key. Use Mod1 for Alt.
set \$mod Mod4
# Home row direction keys, like vim
set \$left h
set \$down j
set \$up k
set \$right l
# Your preferred terminal emulator
set \$term foot
# Your preferred application launcher
#set \$menu \$dmenu_path | dmenu | xargs swaymsg exec --    #EDIT BAFR
set \$menu bemenu-run -i

### Output configuration
#
# Default wallpaper (more resolutions are available in /usr/local/share/backgrounds/sway/)
#output * bg /usr/local/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
#
# TC/LUR wallpaper
output * bg ${tf1200_srcpath}/backgrounds/tclinux_1366x768.png center #FFFFFF
#
# Example configuration:
#
#	output HDMI-A-1 resolution 1920x1080 position 0,0    # Left screen
#   output HDMI-A-2 resolution 1920x1080 position 1920,0    # Right screen
#
# You can get the names of your outputs by running: swaymsg -t get_outputs
#
# Add definition of a font for display and avoid tofu	# EDIT BAFR (Correctif Bug Caracteres)
font pango:DejaVu Sans Mono 10

# Display default configuration    # EDIT BAFR (force 1920x1080)
output DP-1 resolution 1920x1080 position 0,0

### Idle configuration
#
# Example configuration:
#
# exec swayidle -w \
#          timeout 300 'swaylock -f -c 000000' \
#          timeout 600 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
#          before-sleep 'swaylock -f -c 000000'
#
# This will lock your screen after 300 seconds of inactivity, then turn off
# your displays after another 300 seconds, and turn your screens back on when
# resumed. It will also lock your screen before your computer goes to sleep.

### Input configuration
#
# Example configuration:
#
#   input "2:14:SynPS/2_Synaptics_TouchPad" {
#       dwt enabled
#       tap enabled
#       natural_scroll enabled
#       middle_emulation enabled
#   }
#
# You can get the names of your inputs by running: swaymsg -t get_inputs
# Read  "man 5 sway-input"  for more information about this section.
#

# Inputs default configuration		# EDIT BAFR (force basic generic mouse and touchpad configurations)
# Mouse configuration
input type:pointer {
	accel_profile flat
	pointer_accel 0.00
	natural_scroll enabled
}
# Touchpad configuration
input type:touchpad {
	dwt enabled
	tap enabled
	natural_scroll enabled
}
# Touchscreen configuration
input "type:touch" {
	dwt enabled
	tap enabled
	natural_scroll enabled
}

# Set files of rules to be used for keyboard mapping composition.
input * xkb_rules evdev
#
# Set the layout of the keyboard like us, fr or de. Multiple layouts can be
# specified by separating them with commas.
# input * xkb_layout de	# EDIT BAFR (Clavier en francais)
input * xkb_layout "fr"

### Touchscreen and Screen orientation configuration
#
# Set the calibration matrix for touch input devices. This is useful when the
# screen is transformed. The following matrices can be used to calibrate the
# touch input when applying a transformation:
#
# transform = 0 (this default value does not have to be set explicitly)
# input type:touch calibration_matrix 1 0 0 0 1 0
#
# transform = 90
# input type:touch calibration_matrix 0 1 0 "-1" 0 1
#
# transform = 180
# input type:touch calibration_matrix "-1" 0 1 0 "-1" 1
#
# transform = 270
# input type:touch calibration_matrix 0 "-1" 1 1 0 0
#
# transform = flipped
# input type:touch calibration_matrix "-1" 0 1 0 1 0
#
# transform = flipped-90
# input type:touch calibration_matrix 0 "-1" 1 "-1" 0 1
#
# transform = flipped-180
# input type:touch calibration_matrix 1 0 0 0 "-1" 1
#
# transform = flipped-270
# input type:touch calibration_matrix 0 1 0 1 0 0
#
# Transform the screen to the given value. Use 90, 180 or 270 to rotate the
# screen by the specified number of degrees. Use flipped, flipped-90,
# flipped-180 or flipped-270 to flip and rotate the screen by the specified
# number of degrees. If you are using a touch input device, you should also
# set the corresponding calibration matrix above.
# output * transform <transform>

### Autostart configuration
#
# Execute the TwinCAT UI Client with the specified arguments. #	EDIT BAFR Force debug logging
#exec "$(cd "$(dirname "${script_path}")" && pwd)/TF1200-UI-Client" \$@
exec "${tf1200_path}/TF1200-UI-Client" --user=${graph_user} > ${tf1200_userconfig}/tf1200-out.log 2> ${tf1200_userconfig}/tf1200-err.log

### Key bindings
#
# Basics:
#
	# Start a terminal
	bindsym \$mod+Return exec \$term

	# Kill focused window
	bindsym \$mod+Shift+q kill

	# Start your launcher
	bindsym \$mod+d exec \$menu

	# (Re-)Start TF1200-UI-Client Electron browser 		(Ajout BAFR - Raccourci pour UI Client)
	bindsym \$mod+Alt+k exec ${tf1200_path}/TF1200-UI-Client

	# Drag floating windows by holding down \$mod and left mouse button.
	# Resize them with right mouse button + \$mod.
	# Despite the name, also works for non-floating windows.
	# Change normal to inverse to use left mouse button for resizing and right
	# mouse button for dragging.
	floating_modifier \$mod normal

	# Reload the configuration file
	bindsym \$mod+Shift+c reload

	# Exit sway (logs you out of your Wayland session)
	bindsym \$mod+Shift+e exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'
#
# Moving around:
#
	# Move your focus around
	bindsym \$mod+\$left focus left
	bindsym \$mod+\$down focus down
	bindsym \$mod+\$up focus up
	bindsym \$mod+\$right focus right
	# Or use \$mod+[up|down|left|right]
	bindsym \$mod+Left focus left
	bindsym \$mod+Down focus down
	bindsym \$mod+Up focus up
	bindsym \$mod+Right focus right

	# Move the focused window with the same, but add Shift
	bindsym \$mod+Shift+\$left move left
	bindsym \$mod+Shift+\$down move down
	bindsym \$mod+Shift+\$up move up
	bindsym \$mod+Shift+\$right move right
	# Ditto, with arrow keys
	bindsym \$mod+Shift+Left move left
	bindsym \$mod+Shift+Down move down
	bindsym \$mod+Shift+Up move up
	bindsym \$mod+Shift+Right move right
#
# Workspaces:
#
	# Switch to workspace
	bindsym \$mod+1 workspace number 1
	bindsym \$mod+2 workspace number 2
	bindsym \$mod+3 workspace number 3
	bindsym \$mod+4 workspace number 4
	bindsym \$mod+5 workspace number 5
	bindsym \$mod+6 workspace number 6
	bindsym \$mod+7 workspace number 7
	bindsym \$mod+8 workspace number 8
	bindsym \$mod+9 workspace number 9
	bindsym \$mod+0 workspace number 10
	# Move focused container to workspace
	bindsym \$mod+Shift+1 move container to workspace number 1
	bindsym \$mod+Shift+2 move container to workspace number 2
	bindsym \$mod+Shift+3 move container to workspace number 3
	bindsym \$mod+Shift+4 move container to workspace number 4
	bindsym \$mod+Shift+5 move container to workspace number 5
	bindsym \$mod+Shift+6 move container to workspace number 6
	bindsym \$mod+Shift+7 move container to workspace number 7
	bindsym \$mod+Shift+8 move container to workspace number 8
	bindsym \$mod+Shift+9 move container to workspace number 9
	bindsym \$mod+Shift+0 move container to workspace number 10
	# Note: workspaces can have any name you want, not just numbers.
	# We just use 1-10 as the default.
#
# Layout stuff:
#
	# You can "split" the current object of your focus with
	# \$mod+b or \$mod+v, for horizontal and vertical splits
	# respectively.
	bindsym \$mod+b splith
	bindsym \$mod+v splitv

	# Switch the current container between different layout styles
	bindsym \$mod+s layout stacking
	bindsym \$mod+w layout tabbed
	bindsym \$mod+e layout toggle split

	# Make the current focus fullscreen
	bindsym \$mod+f fullscreen

	# Toggle the current focus between tiling and floating mode
	bindsym \$mod+Shift+space floating toggle

	# Swap focus between the tiling area and the floating area
	bindsym \$mod+space focus mode_toggle

	# Move focus to the parent container
	bindsym \$mod+a focus parent
#
# Scratchpad:
#
	# Sway has a "scratchpad", which is a bag of holding for windows.
	# You can send windows there and get them back later.

	# Move the currently focused window to the scratchpad
	bindsym \$mod+Shift+minus move scratchpad

	# Show the next scratchpad window or hide the focused scratchpad window.
	# If there are multiple scratchpad windows, this command cycles through them.
	bindsym \$mod+minus scratchpad show
#
# Resizing containers:
#
mode "resize" {
	# left will shrink the containers width
	# right will grow the containers width
	# up will shrink the containers height
	# down will grow the containers height
	bindsym \$left resize shrink width 10px
	bindsym \$down resize grow height 10px
	bindsym \$up resize shrink height 10px
	bindsym \$right resize grow width 10px

	# Ditto, with arrow keys
	bindsym Left resize shrink width 10px
	bindsym Down resize grow height 10px
	bindsym Up resize shrink height 10px
	bindsym Right resize grow width 10px

	# Return to default mode
	bindsym Return mode "default"
	bindsym Escape mode "default"
}
bindsym \$mod+r mode "resize"
#
# Utilities:
#
	# Special keys to adjust volume via PulseAudio
	bindsym --locked XF86AudioMute exec pactl set-sink-mute \@DEFAULT_SINK@ toggle
	bindsym --locked XF86AudioLowerVolume exec pactl set-sink-volume \@DEFAULT_SINK@ -5%
	bindsym --locked XF86AudioRaiseVolume exec pactl set-sink-volume \@DEFAULT_SINK@ +5%
	bindsym --locked XF86AudioMicMute exec pactl set-source-mute \@DEFAULT_SOURCE@ toggle
	# Special keys to adjust brightness via brightnessctl
	bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-
	bindsym --locked XF86MonBrightnessUp exec brightnessctl set 5%+
	# Special key to take a screenshot with grim
	bindsym Print exec grim

#
# Status Bar:
#
# Read  "man 5 sway-bar"  for more information about this section.
bar {
	position top

	# When the status_command prints a new line to stdout, swaybar updates.
	# The default just shows the current date and time.
	status_command while date +'%Y-%m-%d %X'; do sleep 1; done

	colors {
		statusline #ffffff
		background #323232
		inactive_workspace #32323200 #32323200 #5c5c5c
	}
}

include /usr/local/etc/sway/config.d/*
EOF
chown -R ${graph_user} ${sway_userconfig}/config

# Creation of the TF1200 configuration file
echo ""
echo -e "${GREEN}Creation de la configuration de TF1200-UI-Client ...${NC}"
touch ${tf1200_userconfig}/config
cat > "${tf1200_userconfig}/config.json" << EOF
{
    "allowMove": true,
    "allowResize": true,
    "autoUpdateConfig": true,
    "commandLineSwitches": ["ignore-certificate-errors"],
    "configVersion": "1.10",
    "defaultTheme": "",
    "enableDevTools": true,
    "enableIncognitoMode": true,
    "enableKioskMode": false,
    "enableMenuBar": true,
    "extensions": {},
    "historyGoBackKeys": "Alt+Left",
    "historyGoForwardKeys": "Alt+Right",
	"ignoreErrorCodes": [
		-3
	],
    "maxVisualZoomLevelLimit": 1,
    "openDevTools": false,
    "persistPosition": true,
    "persistSize": true,
    "position": {
        "x": 2,
        "y": 48
    },
    "quitApplicationKeys": "Esc",
    "reloadBrowserWindowKeys": "F5",
    "resetZoomKeys": "CmdOrCtrl+0",
    "retryErrorCodes": [
        -7,
        -100,
        -101,
        -102,
        -103,
        -104,
        -106,
        -109,
        -118,
        -119,
        -120,
        -121,
        -130,
        -133,
        -137,
        -139,
        -154,
        -202,
        -352,
        -802,
        -803
    ],
    "retryInterval": 5000,
    "retryMaxCount": 5,
    "size": {
        "width": 956,
        "height": 1030
    },
    "startUrl": "https://127.0.0.1:2020", 
    "toggleDevToolsKeys": "",
    "windowTitle": "",
    "zoomInKeys": "CmdOrCtrl+Plus",
    "zoomOutKeys": "CmdOrCtrl+-"
}
EOF
chown -R ${graph_user} ${tf1200_userconfig}/config.json

# Configuration of Sway Autostart and debug logging
echo ""
echo -e "${GREEN}Configuration du demarrage automatique de Sway ...${NC}"
touch ${graph_user_bashrc_path}
if [ -z "$(grep -F "start the Sway Compositor and execute the command" "${graph_user_bashrc_path}")" ]; then
	cat >> "${graph_user_bashrc_path}" << EOF

# start the Sway Compositor and execute the command defined in
# ${sway_userconfig}/config
sway -c "${sway_userconfig}/config" > ${sway_userconfig}/sway-out.log 2> ${sway_userconfig}/sway-err.log
EOF
fi
chown -R ${graph_user} ${graph_user_bashrc_path}

# Configuration of graphical user auto log-in
echo ""
echo -e "${GREEN}Configuration de l'auto log-in de l'utilisateur graphique ...${NC}"
${tf1200_srcpath}/setup-autologin.sh --user=${graph_user}

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
