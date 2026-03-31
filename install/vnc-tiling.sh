#!/usr/bin/env bash
set -euo pipefail

BANNER='
  ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄  
 ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄
 ███    ███ ███   ███   ███   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███
 ███    ███ ███   ███   ███   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███
 ███    ███ ███   ███   ███ ▀███████████     ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███
 ███    ███ ███   ███   ███   ███    ███     ███       ███    █▄  ▀███████████ ███   ███   ███
 ███    ███ ███   ███   ███   ███    ███     ███       ███    ███   ███    ███ ███   ███   ███
  ▀██████▀   ▀█   ███   █▀    ███    █▀     ▄████▀     ██████████   ███    ███  ▀█   ███   █▀ 
                                                                    ███    ███                
'

section() { echo -e "\n==> $1"; }
show_banner() { clear; echo "$BANNER"; }

is_proot() {
    ! systemctl --version &>/dev/null || \
    grep -q "PRoot" /proc/version 2>/dev/null
}

install_vnc_tiling_packages() {
    section "Installing VNC + Tiling packages..."

    local packages=(
        tigervnc x11vnc
        openbox herbstluftwm
        xorg-xauth xorg-fonts xorg-setxkbmap
        terminus-font
        firefox thunar
        xterm rxvt-unicode
        scrot feh
        nitrogen
        rofi
        tint2
    )

    pacman -Syu --needed --noconfirm "${packages[@]}"
    echo "✓ VNC + Tiling packages installed"
}

setup_vnc_config() {
    section "Configuring VNC server..."

    local vnc_dir="$HOME/.vnc"
    mkdir -p "$vnc_dir"

    cat > "$vnc_dir/xstartup" << 'EOF'
#!/bin/bash

xrdb ~/.Xresources 2>/dev/null || true

herbstluftwm --autostart &
# Or use openbox:
# openbox-session &

exec herbstluftwm
EOF

    chmod +x "$vnc_dir/xstartup"
    echo "✓ VNC xstartup configured"
}

setup_herbstluftwm() {
    section "Configuring herbstluftwm (tiling WM)..."

    local config_dir="$HOME/.config/herbstluftwm"
    mkdir -p "$config_dir"

    cat > "$config_dir/autostart" << 'EOF'
#!/bin/bash

xsetroot -solid '#1a1b26'

herbstclient set frame_border_active_color '#bb9af7'
herbstclient set frame_border_normal_color '#1a1b26'
herbstclient set frame_bg_normal_color '#1a1b26'
herbstclient set frame_bg_active_color '#7aa2f7'
herbstclient set gapless_grid true
herbstclient set smart_frame_borders on
herbstclient set smart_gaps on

herbstclient keybind Mod4-t spawn rofi -show run
herbstclient keybind Mod4-Return spawn xterm
herbstclient keybind Mod4-q close
herbstclient keybind Mod4-f fullscreen
herbstclient keybind Mod4-Space rotate
herbstclient keybind Mod4-j focus left
herbstclient keybind Mod4-k focus down
herbstclient keybind Mod4-l focus up
herbstclient keybind Mod4-; focus right
herbstclient keybind Mod4-h split explode
herbstclient keybind Mod4-Shift-j shift left
herbstclient keybind Mod4-Shift-k shift down
herbstclient keybind Mod4-Shift-l shift up
herbstclient keybind Mod4-Shift-; shift right
herbstclient keybind Mod4-d spawn dmenu_path
herbstclient keybind Mod4-m spawn nautilus
herbstclient keybind Mod4-Print spawn scrot

tint2 &
EOF

    chmod +x "$config_dir/autostart"
    echo "✓ herbstluftwm configured"
}

setup_openbox() {
    section "Configuring Openbox..."

    local config_dir="$HOME/.config/openbox"
    mkdir -p "$config_dir"

    cat > "$config_dir/rc.xml" << 'EOF'
<?xml version="1.0"?>
<openbox_config xmlns="http://openbox.org/3.5/rc">
  <keybind key="W-Return">
    <action name="Execute"><command>xterm</command></action>
  </keybind>
  <keybind key="W-f">
    <action name="ToggleFullscreen"/>
  </keybind>
  <keybind key="W-q">
    <action name="Close"/>
  </keybind>
  <keybind key="W-space">
    <action name="Execute"><command>rofi -show run</command></action>
  </keybind>
</openbox_config>
EOF

    echo "✓ Openbox configured"
}

setup_vnc_password() {
    section "Setting VNC password..."
    
    if [[ ! -f "$HOME/.vnc/passwd" ]]; then
        mkdir -p "$HOME/.vnc"
        vncpasswd || true
    else
        echo "✓ VNC password exists"
    fi
}

create_vnc_launcher() {
    section "Creating VNC launcher..."

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    cat > "$bin_dir/vnc-start" << 'EOF'
#!/bin/bash
: ${DISPLAY:=:1}
: ${VNC_PORT:=5901}

export DISPLAY=":$DISPLAY"
echo "Starting VNC on port $VNC_PORT..."

vncserver ":$DISPLAY" -geometry 1280x720 -depth 24 -localhost no
echo "VNC started. Connect with: vncviewer localhost:$VNC_PORT"
EOF

    chmod +x "$bin_dir/vnc-start"

    cat > "$bin_dir/vnc-stop" << 'EOF'
#!/bin/bash
: ${DISPLAY:=1}
vncserver -kill ":$DISPLAY" 2>/dev/null || true
EOF

    chmod +x "$bin_dir/vnc-stop"

    echo "✓ vnc-start and vnc-stop commands created"
}

install_tiling_scripts() {
    section "Installing tiling helper scripts..."

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    cat > "$bin_dir/tiling-help" << 'EOF'
#!/bin/bash
cat << 'HELP'
=== Tiling WM Shortcuts (herbstluftwm) ===

Mod4 = Windows key (Super)

Window Management:
  Mod4-h         Split horizontal
  Mod4-v         Split vertical  
  Mod4-Return    Focus into new split
  Mod4-Space     Rotate layout
  Mod4-f         Toggle fullscreen
  Mod4-q         Close window
  Mod4-t         Launch app (rofi)
  Mod4-d         App launcher (dmenu)

Navigation (vim-style):
  Mod4-j         Focus left
  Mod4-k         Focus down
  Mod4-l         Focus up
  Mod4-;         Focus right

Move Windows:
  Mod4+Shift-j  Shift left
  Mod4+Shift-k  Shift down
  Mod4+Shift-l  Shift up
  Mod4+Shift-;  Shift right

Commands:
  vnc-start      Start VNC server
  vnc-stop       Stop VNC server
HELP
EOF

    chmod +x "$bin_dir/tiling-help"
    echo "✓ Tiling help script installed"
}

finish() {
    section "Done!"
    echo ""
    echo "To start VNC desktop:"
    echo "  vnc-start"
    echo ""
    echo "Connect with any VNC client to:"
    echo "  <your-ip>:5901"
    echo ""
    echo "Shortcuts:"
    echo "  Mod4-Return  → xterm"
    echo "  Mod4-t       → rofi (app launcher)"
    echo "  Mod4-q       → close window"
    echo "  Mod4-f       → fullscreen"
    echo "  tiling-help  → show all shortcuts"
    echo ""
    echo "For tiling help: tiling-help"
}

main() {
    show_banner
    section "Installing VNC Tiling Desktop for PRoot..."

    install_vnc_tiling_packages
    setup_vnc_config
    setup_vnc_password
    setup_herbstluftwm
    setup_openbox
    create_vnc_launcher
    install_tiling_scripts
    finish
}

main "$@"
