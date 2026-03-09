#!/usr/bin/env bash
set -euo pipefail

# Common functions for Omaterm installation
show_banner() {
  clear
  echo
  echo " ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄  
███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄
███    ███ ███   ███   ███   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███
███    ███ ███   ███   ███ ▀███████████     ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    █▄  ▀███████████ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    ███   ███    ███ ███   ███   ███
 ▀██████▀   ▀█   ███   █▀    ███    █▀     ▄████▀     ██████████   ███    ███  ▀█   ███   █▀ 
                                                                   ███    ███                "
}

section() {
  echo -e "\n==> $1"
}

is_proot_environment() {
  if [ "${OMATERM_PROOT:-0}" = "1" ]; then
    return 0
  fi

  if [ -n "${PROOT_TMP_DIR:-}" ] || [ -n "${PROOT_LOADER:-}" ] || [ -n "${PROOT_NO_SECCOMP:-}" ]; then
    return 0
  fi

  if [ -r /proc/mounts ] && grep -q "/data/data/com.termux" /proc/mounts 2>/dev/null; then
    return 0
  fi

  return 1
}

supports_systemd() {
  command -v systemctl &>/dev/null && [ -d /run/systemd/system ]
}

run_privileged() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
  elif command -v sudo &>/dev/null; then
    sudo "$@"
  else
    echo "Error: this step requires root privileges, but sudo is unavailable."
    return 1
  fi
}

skip_in_proot() {
  local step="$1"
  echo "Skipping $step in proot."
}

ensure_supported_user_context() {
  if is_proot_environment && [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Error: Arch proot installs must be run as root inside the proot."
    echo "Reason: sudo/password auth frequently fails in Android proot with 'Authentication token manipulation error'."
    echo "Fix: enter the distro as root and rerun, for example with 'proot-distro login <distro> --user root'."
    exit 1
  fi
}

install_omadots() {
  curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash
}

install_configs() {
  section "Installing configs..."
  mkdir -p "$HOME/.config"
  cp -Rf "$INSTALLER_DIR/config/"* "$HOME/.config/"
  echo "✓ Neovim"
  echo "✓ Starship"

  if ! grep -q "if \[\[ -z \$TMUX \]\]" "$HOME/.bashrc" 2>/dev/null; then
    cat >>"$HOME/.bashrc" <<'EOF'
if [[ -z $TMUX ]]; then
  t
fi
EOF
    echo "✓ Tmux auto-start"
  fi
}

install_bins() {
  section "Installing bins..."
  mkdir -p "$HOME/.local/bin"
  cp -Rf "$INSTALLER_DIR/bin/"* "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/"*
  echo "✓ omaterm-ssh"
  echo "✓ omaterm-theme"
  echo "✓ omaterm-refresh"
}

install_mise_tools() {
  section "Installing Ruby + Node..."
  eval "$(mise activate bash)" 2>/dev/null || true
  mise use -g node
  mise use -g ruby
  export PATH="$HOME/.local/share/mise/shims:$PATH"
}

setup_docker_group() {
  if is_proot_environment; then
    skip_in_proot "Docker group setup"
    return 0
  fi

  if ! groups | grep -q docker; then
    if command -v usermod &>/dev/null; then
      run_privileged usermod -aG docker "$USER"
    else
      run_privileged adduser "$USER" docker
    fi
  fi
}

interactive_setup() {
  section "Interactive setup..."

  if ! gh auth status &>/dev/null; then
    echo
    if gum confirm "Authenticate with GitHub?" </dev/tty; then
      gh auth login
    fi
  fi

  if ! tailscale status &>/dev/null; then
    echo
    if gum confirm "Connect to Tailscale network?" </dev/tty; then
      if is_proot_environment || ! supports_systemd; then
        echo "Skipping Tailscale connect: proot environments do not support the required system service setup."
        return 0
      fi
      echo "This might take a minute..."
      run_privileged systemctl enable --now tailscaled.service
      run_privileged tailscale up --ssh --accept-routes
    fi
  fi
}

finish() {
  section "Finished!"
  if is_proot_environment; then
    echo "Restart the proot session so PATH and shell changes take effect."
  else
    echo "Now logout and back in for everything to take effect"
  fi
}

run_installation() {
  # OS-specific package installation
  install_packages

  # Omadots
  install_omadots

  # Configs and bins
  install_configs
  install_bins

  # Mise tooling
  install_mise_tools

  # OS-specific tools that need npm (installed after mise provides node)
  install_npm_tools

  # OS-specific service enabling
  enable_services

  # Setup Docker group
  setup_docker_group

  # Interactive setup
  interactive_setup

  # Done!
  finish
}

# Getting started
show_banner
section "Installing Omaterm..."
ensure_supported_user_context()

# Ensure correct git is installed
if ! command -v git &>/dev/null; then
  if [ -f /etc/arch-release ]; then
    run_privileged pacman -Sy --noconfirm git
  elif [ -f /etc/debian_version ]; then
    run_privileged apt-get update
    run_privileged apt-get install -y git
  elif [ -f /etc/fedora-release ]; then
    run_privileged dnf install -y git
  fi
fi

REPO="https://github.com/omacom-io/omaterm.git"
INSTALLER_DIR="$(mktemp -d)"
trap 'rm -rf "$INSTALLER_DIR"' EXIT

git clone --depth 1 "$REPO" "$INSTALLER_DIR"

# OS detection and dispatch
if [ -f /etc/arch-release ]; then
  source "$INSTALLER_DIR/install/arch.sh"
elif [ -f /etc/debian_version ]; then
  source "$INSTALLER_DIR/install/debian.sh"
elif [ -f /etc/fedora-release ]; then
  source "$INSTALLER_DIR/install/fedora.sh"
else
  echo "Error: Unsupported operating system"
  echo "Omaterm supports Arch Linux, Debian/Ubuntu, and Fedora"
  exit 1
fi

run_installation
