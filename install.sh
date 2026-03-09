#!/bin/bash
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

sanitize_proot_environment() {
  if ! is_proot_environment; then
    return 0
  fi

  # Termux's exec shim can leak into proot and redirect shebang execution to
  # Android system binaries, which breaks normal Linux script execution.
  unset LD_PRELOAD
  unset PREFIX TERMUX_APP_PID TERMUX_MAIN_PACKAGE_FORMAT TERMUX_VERSION
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  hash -r
}

find_linux_binary() {
  local name="$1"
  local candidate

  for candidate in "/usr/bin/$name" "/bin/$name" "/usr/sbin/$name" "/sbin/$name" "/usr/local/bin/$name" "/usr/local/sbin/$name"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

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
  local curl_bin bash_bin
  curl_bin="$(find_linux_binary curl)"
  bash_bin="$(find_linux_binary bash)"
  "$curl_bin" -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | LD_PRELOAD= "$bash_bin"
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
sanitize_proot_environment
show_banner
section "Installing Omaterm..."
ensure_supported_user_context()

# Ensure correct git is installed
if ! command -v git &>/dev/null; then
  if [ -f /etc/arch-release ]; then
    run_privileged "$(find_linux_binary pacman)" -Sy --noconfirm git
  elif [ -f /etc/debian_version ]; then
    run_privileged "$(find_linux_binary apt-get)" update
    run_privileged "$(find_linux_binary apt-get)" install -y git
  elif [ -f /etc/fedora-release ]; then
    run_privileged "$(find_linux_binary dnf)" install -y git
  fi
fi

REPO="${OMATERM_REPO:-https://github.com/HowieDuhzit/omaterm.git}"
SCRIPT_PATH="${0:-}"
SCRIPT_DIR=""

if [ -n "$SCRIPT_PATH" ] && [ "$SCRIPT_PATH" != "bash" ] && [ "$SCRIPT_PATH" != "-" ] && [ "$SCRIPT_PATH" != "/bin/bash" ]; then
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.sh" ] && [ -d "$SCRIPT_DIR/install" ] && [ -d "$SCRIPT_DIR/config" ] && [ -d "$SCRIPT_DIR/bin" ]; then
  INSTALLER_DIR="$SCRIPT_DIR"
else
  INSTALLER_DIR="$(mktemp -d)"
  trap 'rm -rf "$INSTALLER_DIR"' EXIT
  "$(find_linux_binary git)" clone --depth 1 "$REPO" "$INSTALLER_DIR"
fi

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
