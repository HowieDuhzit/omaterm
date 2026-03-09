install_packages() {
  local pacman_bin
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
  pacman_bin="$(require_linux_binary pacman)"
  run_privileged "$pacman_bin" -Syu --needed --noconfirm "${official_pkgs[@]}"

  if is_proot_environment; then
    skip_in_proot "AUR bootstrap and claude-code installation"
    return 0
  fi

  local aur_pkgs=(
    claude-code
  )

  if ! command -v yay &>/dev/null; then
    section "Installing yay..."
    local git_bin makepkg_bin
    local tmpdir=$(mktemp -d)
    git_bin="$(require_linux_binary git)"
    makepkg_bin="$(require_linux_binary makepkg)"
    "$git_bin" clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && "$makepkg_bin" -si --noconfirm)
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
