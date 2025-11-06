#!/bin/sh
# SPDX-License-Identifier: BSD-2-Clause
# Dylan Erwan Le Morzellec (BECKHOFF Automation France SARL)
# The script is provided AS IS and its behaviour is not warranted

# Script to set up the TF1200-Sway graphical interface and HMI Client and custom configuration with TwinCAT PLC HMI Web.

# Constants
readonly graph_user="tf1200-user"
readonly user_path="/home/${graph_user}"
readonly tf1200_path="/usr/local/etc/TwinCAT/Functions/TF1200-UI-Client"
readonly tf1200_srcpath="/usr/local/etc/TwinCAT/Functions/TF1200-UI-Client/scripts"
readonly sway_userconfig="${user_path}/.config/sway"
readonly tf1200_userconfig="${user_path}/.config/TF1200-UI-Client"
readonly shrc_path="${user_path}/.shrc"
readonly script_path="$(cd "$(dirname "${0}")" && pwd)"
tst="$(date +%Y%m%d_%H%M%S)"

echo ""
echo "SCRIPT D'INSTALLATION ET DE CONFIGURATION DE LA TF1200 (BAFR)"
echo ""

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
	echo ""
	echo "Le script doit etre execute en tant que root."
	echo ""
	exit 1
fi

# A password must be given (even if "1")
if [ -z "$1" ]; then
	echo ""
	echo "Un argument supplementaire est necessaire a l'execution du script : Mot de passe pour TF1200."
	echo ""
	exit 1
fi
password="$1"

# Creation of a restore point before doing any change
echo ""
echo "Creation du point de restauration 'BAFR_before_TF1200' ..."
echo ""
prefix="BAFR_before_TF1200_"
touch ${script_path}/tmp_rplist.txt
restorepoint status > ${script_path}/tmp_rplist.txt
if ! grep -q ${prefix} ${script_path}/tmp_rplist.txt; then
	echo ""
	echo "Point de restauration créé !"
	echo ""
	restorepoint create "BAFR_before_TF1200_${tst}"
else
	echo ""
	echo "Le point de restauration existe deja."
	echo ""
fi
rm -f ${script_path}/tmp_rplist.txt

# Creation of the graphical user
echo ""
echo "Creation de l'utilisateur graphique..."
echo ""
pw useradd "${graph_user}" -m -s /bin/sh
echo "${password}" | pw usermod "${graph_user}" -h 0
if [ $? -eq 0 ]; then
	echo "Utilisateur graphique '${graph_user}' cree avec succes."
else
	echo "Erreur de creation de l'utilisateur graphique."
	exit 1
fi

# Configure keyboard layout to AZERTY default (French)
echo ""
echo "Forcage du clavier console en francais standard (si ce n'est deja fait)..."
echo ""
sysrc keymap="fr.kbd"

# An upgrade of the pkg package manager is often necessary at this point
echo ""
echo "Mise a jour des depots et de pkg..."
echo ""
pkg update -f
pkg install -y pkg

# Install needed packages
echo ""
echo "Installation de paquets logiciels necessaires..."
echo ""
PACKAGES="
TF1810-PLC-HMI-Web
TF1200-UI-Client
dejavu
foot
dmenu
dmenu-wayland
"

for PACKAGE in $PACKAGES; do
	pkg install -y $PACKAGE
done

# Initialisation of TF1810 - PLC HMI Web server by restarting TwinCAT system service
echo ""
echo "Initialisation du serveur PLC HMI Web..."
echo ""
service TcSystemService restart

# Add firewall rule for TF1810 and reload firewall
echo ""
echo "Ajout d'une exception du pare-feu pour TF1810"
echo ""
cat >> "/etc/pf.conf" << EOF

# allow incoming TCP connections on port 42341 (TF1810 - PLC HMI Web)
pass in quick proto tcp to port 42341 keep state

EOF
service pf restart
pfctl -f /etc/pf.conf
service pf restart

# Activate dbus
echo ""
echo "Activation de dbus..."
echo ""
sysrc dbus_enable="YES"
service dbus start

# Creation of configuration folders for tf1200-user
echo ""
echo "Creation des dossiers de configuration..."
echo ""
mkdir ${user_path}/.config
mkdir ${user_path}/.config/sway
mkdir ${user_path}/.config/TF1200-UI-Client
chown -R ${graph_user} ${user_path}/.config
chown -R ${graph_user} ${user_path}/.config/sway
chown -R ${graph_user} ${user_path}/.config/TF1200-UI-Client

# Using Beckhoff BADE script to set up Sway and Wayland
echo ""
echo "Installation de Sway et de Wayland..."
echo ""
${tf1200_srcpath}/setup-sway.sh --user=${graph_user}

# Generate Sway configuration file
echo ""
echo "Configuration de Sway..."
echo ""
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
#set \$menu wmenu-run	#EDIT BAFR
#set \$menu \$dmenu_path | dmenu_wl | xargs swaymsg exec --
set \$menu dmenu-wl_run -i

### Output configuration
#
# Default wallpaper (more resolutions are available in /usr/local/share/backgrounds/sway/)
#output * bg /usr/local/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
#
# TC/BSD wallpaper
output * bg ${tf1200_srcpath}/backgrounds/tcbsd_1366x768.png center #FFFFFF
#
# Example configuration:
#
#   output HDMI-A-1 resolution 1920x1080 position 1920,0
#
# You can get the names of your outputs by running: swaymsg -t get_outputs
#
# Add definition of a font for display and avoid tofu	# EDIT BAFR (Correctif Bug Caracteres)
font pango:DejaVu Sans Mono 10

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
exec "/usr/local/etc/TwinCAT/Functions/TF1200-UI-Client/TF1200-UI-Client" --user=${graph_user} > ${tf1200_userconfig}/tf1200-out.log 2> ${tf1200_userconfig}/tf1200-err.log

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
	
	# Start Beckhoff TF1200 HMI UI Client
	bindsym \$mod+Alt+k exec /usr/local/etc/TwinCAT/Functions/TF1200-UI-Client/TF1200-UI-Client

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

# Generate TF1200 UI Client configuration
echo ""
echo "Configuration de la fonction TF1200..."
echo ""
touch ${tf1200_userconfig}/config.json
cat > "${tf1200_userconfig}/config.json" << EOF
{
    "allowMove": true,
    "allowResize": true,
    "autoUpdateConfig": true,
    "commandLineSwitches": ["ignore-certificate-errors"],
    "configVersion": "1.9",
    "defaultTheme": "",
    "enableDevTools": true,
    "enableIncognitoMode": true,
    "enableKioskMode": false,
    "enableMenuBar": true,
    "extensions": {},
    "historyGoBackKeys": "Alt+Left",
    "historyGoForwardKeys": "Alt+Right",
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
    "startUrl": "http://127.0.0.1:42341/Tc3PlcHmiWeb/Port_851/Visu/webvisu.htm", 
    "toggleDevToolsKeys": "",
    "windowTitle": "",
    "zoomInKeys": "CmdOrCtrl+Plus",
    "zoomOutKeys": "CmdOrCtrl+-"
}
EOF
chown -R ${graph_user} ${tf1200_userconfig}/config.json

# Set up automatic Sway execution with debug logging in user config folder
echo ""
echo "Configuration du demarrage automatique de Sway..."
echo ""
touch ${shrc_path}
if test -z "$(grep -F "start the Sway Compositor and execute the command" "${shrc_path}")"; then
	cat >> "${shrc_path}" << EOF

# start the Sway Compositor and execute the command defined in
# ${sway_userconfig}/config
sway -c "${sway_userconfig}/config" > ${sway_userconfig}/sway-out.log 2> ${sway_userconfig}/sway-err.log
EOF
fi
chown -R ${graph_user} ${shrc_path}

# Auto log-in configuration
echo ""
echo "Configuration de l'auto log-in..."
echo ""
${tf1200_srcpath}/setup-autologin.sh --user=${graph_user}

# Creation of a restore point after the changes
echo ""
echo "Creation du point de restauration 'BAFR_after_TF1200' ..."
echo ""
restorepoint create "BAFR_after_TF1200_${tst}"
