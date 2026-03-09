install_packages() {
  local official_pkgs=(
    base-devel git openssh sudo less inetutils whois
    starship fzf eza zoxide tmux btop jq gum man-db tldr
    vim neovim luarocks
    clang llvm rust mise libyaml
    github-cli lazygit lazydocker opencode
  )

  if is_proot_environment; then
    skip_in_proot "Docker and Tailscale package installation"
  else
    official_pkgs+=(docker docker-buildx docker-compose tailscale)
  fi

  section "Installing Arch packages..."
  run_privileged "$(require_linux_binary pacman)" -Syu --needed --noconfirm "${official_pkgs[@]}"

  if is_proot_environment; then
    skip_in_proot "AUR bootstrap and claude-code installation"
    return 0
  fi

  local aur_pkgs=(
    claude-code
  )

  if ! command -v yay &>/dev/null; then
    section "Installing yay..."
    local tmpdir=$(mktemp -d)
    "$(require_linux_binary git)" clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && "$(require_linux_binary makepkg)" -si --noconfirm)
    rm -rf "$tmpdir"
  fi

  section "Installing AUR packages..."
  yay -S --needed --noconfirm "${aur_pkgs[@]}"
}

install_npm_tools() {
  :
}

enable_services() {
  if is_proot_environment || ! supports_systemd; then
    skip_in_proot "system service enablement"
    return 0
  fi

  section "Enabling services..."

  run_privileged systemctl enable --now docker.service
  echo "✓ Docker"

  run_privileged systemctl enable --now sshd.service
  echo "✓ sshd"
}
