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
    [[ -f /proc/1/cmdline ]] && grep -q PRoot /proc/1/cmdline 2>/dev/null || \
    grep -q "PRoot" /proc/version 2>/dev/null || \
    ! systemctl --version &>/dev/null
}

prompt_git() {
    section "Git Configuration"
    read -rp "Git user.name: " git_name
    read -rp "Git user.email: " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    echo "✓ Git configured"
}

install_arch_packages() {
    section "Installing Arch packages..."
    pacman -Syu --needed --noconfirm \
        base-devel git openssh sudo less inetutils whois \
        starship fzf eza zoxide tmux btop jq gum man-db tldr \
        vim neovim luarocks clang llvm rust libyaml \
        github-cli lazygit lazydocker kitty-terminfo
    echo "✓ Packages installed"
}

install_mise() {
    section "Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo "✓ mise installed"
}

install_opencode() {
    if ! command -v opencode &>/dev/null; then
        section "Installing opencode..."
        curl -fsSL https://opencode.ai/install.sh | bash || true
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
    git clone --depth 1 https://github.com/omacom-io/omaterm.git "$repo" 2>/dev/null || true
    
    mkdir -p "$HOME/.config"
    cp -Rf "$repo/config/"* "$HOME/.config/" 2>/dev/null || true
    rm -rf "$repo"
    echo "✓ Configs installed"
}

install_omaterm_bins() {
    section "Installing omaterm scripts..."
    local repo
    repo=$(mktemp -d)
    git clone --depth 1 https://github.com/omacom-io/omaterm.git "$repo" 2>/dev/null || true
    
    mkdir -p "$HOME/.local/bin"
    cp -f "$repo/bin/"* "$HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/omaterm-* 2>/dev/null || true
    rm -rf "$repo"
    echo "✓ omaterm-ssh, omaterm-theme, omaterm-refresh"
}

install_node_ruby() {
    section "Installing Node.js and Ruby..."
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true
    mise use -g node 2>/dev/null || true
    mise use -g ruby 2>/dev/null || true
    echo "✓ Node/Ruby installed (via mise)"
}

setup_bashrc() {
    section "Configuring shell..."
    cat > ~/.bashrc << 'EOF'
# HowieDuhzit/omaterm setup
[[ -f ~/.config/shell/all ]] && source ~/.config/shell/all
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
EOF

    cat > ~/.profile << 'EOF'
[[ -f ~/.bashrc ]] && source ~/.bashrc
EOF
    echo "✓ Shell configured"
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
}

main() {
    show_banner
    section "Installing HowieDuhzit/omaterm..."

    install_arch_packages
    install_mise
    install_opencode
    install_omadots
    install_omaterm_configs
    install_omaterm_bins
    install_node_ruby
    install_docker_tailscale
    finish
}

main "$@"
