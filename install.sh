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

is_termux() {
    [[ -d /data/data/com.termux/files/usr ]] || \
    command -v termux-chroot &>/dev/null
}

prompt_git() {
    section "Git Configuration"
    read -rp "Git user.name: " git_name
    read -rp "Git user.email: " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    echo "✓ Git configured"
}

setup_arch_proot() {
    if ! command -v proot-distro &>/dev/null; then
        section "Installing proot-distro..."
        pkg update && pkg install proot-distro
    fi

    if ! proot-distro list 2>/dev/null | grep -q archlinux; then
        section "Installing Arch Linux via proot-distro..."
        proot-distro install archlinux
    fi
}

setup_user() {
    if ! id myuser &>/dev/null; then
        section "Creating user..."
        useradd -m -G wheel myuser
        passwd myuser
        echo "myuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        echo "✓ User 'myuser' created"
    else
        echo "✓ User 'myuser' exists"
    fi
}

setup_aur_helper() {
    if ! command -v paru &>/dev/null; then
        section "Installing paru (AUR helper)..."
        pacman -S --needed git base-devel
        cd /tmp
        rm -rf paru
        git clone https://aur.archlinux.org/paru.git
        cd paru && makepkg -si --noconfirm
        cd /tmp && rm -rf paru
        echo "✓ paru installed"
    else
        echo "✓ paru already installed"
    fi
}

install_arch_packages() {
    section "Installing Arch packages..."

    local packages=(
        base-devel git openssh sudo less inetutils whois
        starship fzf eza zoxide tmux btop jq gum man-db tldr
        vim neovim luarocks clang llvm rust libyaml
        github-cli lazygit lazydocker kitty-terminfo
        ripgrep fd bat dust fastfetch expac plocate
        alacritty playerctl pamixer brightnessctl
        python-gobject python-poetry-core
        noto-fonts noto-fonts-emoji
        terminus-font fontconfig
    )

    pacman -Syu --needed --noconfirm "${packages[@]}"
    echo "✓ Packages installed"
}

install_mise() {
    if ! command -v mise &>/dev/null; then
        section "Installing mise..."
        curl -fsSL https://mise.run | sh
        export PATH="$HOME/.local/bin:$PATH"
        echo "✓ mise installed"
    else
        echo "✓ mise already installed"
    fi
}

install_opencode() {
    if ! command -v opencode &>/dev/null; then
        section "Installing opencode..."
        curl -fsSL https://opencode.ai/install | bash || \
        npm install -g opencode-ai 2>/dev/null || true
        echo "✓ opencode installed"
    else
        echo "✓ opencode already installed"
    fi
}

install_claude_code() {
    if ! command -v claude &>/dev/null && command -v paru &>/dev/null; then
        section "Installing Claude Code (AUR)..."
        paru -S --needed --noconfirm claude-code-bin 2>/dev/null || true
        echo "✓ Claude Code"
    fi
}

install_omadots() {
    section "Installing omadots (shell configs)..."
    curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash 2>/dev/null || true
    section "Fixing ~/.bashrc for PATH..."
    cat > ~/.bashrc << 'EOF'
# HowieDuhzit/omaterm + omadots
[[ -f ~/.config/shell/all ]] && source ~/.config/shell/all
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
EOF
    echo "✓ ~/.bashrc updated with PATH"
}

install_omaterm_configs() {
    section "Installing omaterm configs..."
    local repo
    repo=$(mktemp -d)
    git clone --depth 1 https://github.com/HowieDuhzit/omaterm.git "$repo" 2>/dev/null || \
    git clone --depth 1 https://github.com/omacom-io/omaterm.git "$repo"
    
    mkdir -p "$HOME/.config"
    cp -Rf "$repo/config/"* "$HOME/.config/" 2>/dev/null || true
    rm -rf "$repo"
    echo "✓ Configs installed"
}

install_omaterm_bins() {
    section "Installing omaterm scripts..."
    local repo
    repo=$(mktemp -d)
    git clone --depth 1 https://github.com/HowieDuhzit/omaterm.git "$repo" 2>/dev/null || \
    git clone --depth 1 https://github.com/omacom-io/omaterm.git "$repo"
    
    mkdir -p "$HOME/.local/bin"
    cp -f "$repo/bin/"* "$HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/omaterm-*" 2>/dev/null || true
    rm -rf "$repo"
    echo "✓ omaterm-ssh, omaterm-theme, omaterm-refresh"
}

install_omarchy_configs() {
    section "Installing Omarchy configs..."

    local omarchy_path="$HOME/.local/share/omarchy"
    if [[ ! -d "$omarchy_path" ]]; then
        git clone --depth 1 https://github.com/basecamp/omarchy.git "$omarchy_path" 2>/dev/null || true
    fi

    if [[ -f "$omarchy_path/install/config/git.sh" ]]; then
        bash "$omarchy_path/install/config/git.sh" 2>/dev/null || true
        echo "✓ Omarchy git config"
    fi

    echo "✓ Omarchy configs (partial - desktop configs skipped)"
}

install_node_ruby() {
    section "Installing Node.js and Ruby..."
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true
    mise use -g node 2>/dev/null || true
    mise use -g ruby 2>/dev/null || true
    echo "✓ Node/Ruby installed (via mise)"
}

install_desktop() {
    if is_proot; then
        section "Desktop Environment"
        echo "⚠ Skipped (requires systemd, not available in PRoot)"
        echo "  For desktop, use real Arch install or SSH to a desktop machine"
        return
    fi

    section "Installing desktop environment (Hyprland)..."
    pacman -S --needed --noconfirm \
        hyprland waybar wofi thunar rofi kitty-terminfo \
        sddm polkit-gnome xdg-desktop-portal-hyprland \
        nwg-look swaylock-effects \
        grim slurp wl-clipboard swaybg mako

    systemctl enable sddm
    echo "✓ Hyprland desktop installed"
}

install_docker_tailscale() {
    if is_proot; then
        section "Docker/Tailscale"
        echo "⚠ Skipped (requires systemd, not available in PRoot)"
        return
    fi

    section "Installing Docker..."
    pacman -Syu --needed --noconfirm docker docker-buildx docker-compose
    systemctl enable --now docker.service
    echo "✓ Docker installed"

    section "Installing Tailscale..."
    pacman -Syu --needed --noconfirm tailscale
    systemctl enable --now tailscaled.service
    echo "✓ Tailscale installed"
}

finish() {
    section "Done!"
    echo ""
    echo "Restart your shell or run: source ~/.bashrc"
    echo ""
    echo "Key shortcuts:"
    echo "  c     → opencode"
    echo "  n     → neovim"
    echo "  t     → tmux"
    echo "  g     → git"
    echo "  lzd   → lazydocker"
    echo "  lg    → lazygit"
    echo "  zd    → smart cd"
    echo ""
    echo "For desktop: install on real Arch (omarchy.org)"
}

main() {
    if is_termux; then
        if [[ ! -d /etc/pacman.d ]]; then
            show_banner
            section "Setting up Arch Linux via proot-distro..."
            setup_arch_proot
            section "Login to Arch Linux"
            echo "Run: proot-distro login archlinux"
            echo "Then re-run this script inside Arch Linux."
            return
        fi
    fi

    show_banner
    section "Installing HowieDuhzit/omaterm..."

    if ! is_proot; then
        setup_user
        setup_aur_helper
    fi

    install_arch_packages
    install_mise
    install_opencode
    install_claude_code
    install_omadots
    install_omaterm_configs
    install_omaterm_bins
    install_omarchy_configs
    install_node_ruby
    prompt_git
    install_desktop
    install_docker_tailscale
    finish
}

main "$@"
