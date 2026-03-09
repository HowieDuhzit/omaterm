install_packages() {
  local packages=(
    build-essential git openssh-server libssl-dev sudo less net-tools whois
    fzf eza zoxide tmux btop jq man-db
    vim neovim luarocks
    clang llvm rustc libyaml-0-2
    curl wget gpg
    kitty-terminfo
  )

  section "Updating system packages..."
  run_privileged "$(find_linux_binary apt-get)" update
  run_privileged "$(find_linux_binary apt-get)" upgrade -y

  section "Installing Debian packages..."
  if is_proot_environment; then
    skip_in_proot "Docker and Tailscale package installation"
  else
    packages+=(docker.io docker-buildx docker-compose)
  fi

  run_privileged "$(find_linux_binary apt-get)" install -y "${packages[@]}"

  # tldr: Debian Trixie+ replaced tldr with tealdeer
  if apt-cache show tealdeer &>/dev/null; then
    run_privileged "$(find_linux_binary apt-get)" install -y tealdeer
  else
    run_privileged "$(find_linux_binary apt-get)" install -y tldr
  fi

  # github-cli (not in Debian/Ubuntu repos)
  if ! command -v gh &>/dev/null; then
    section "Installing GitHub CLI..."
    local keyring_tmp list_tmp
    keyring_tmp=$(mktemp)
    list_tmp=$(mktemp)
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$keyring_tmp"
    printf 'deb [arch=%s signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" >"$list_tmp"
    run_privileged install -D -m 0644 "$keyring_tmp" /usr/share/keyrings/githubcli-archive-keyring.gpg
    run_privileged install -D -m 0644 "$list_tmp" /etc/apt/sources.list.d/github-cli.list
    rm -f "$keyring_tmp" "$list_tmp"
    run_privileged "$(find_linux_binary apt-get)" update
    run_privileged "$(find_linux_binary apt-get)" install -y gh
  fi

  # tailscale (not in Debian/Ubuntu repos)
  if ! is_proot_environment && ! command -v tailscale &>/dev/null; then
    section "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  # starship (not in Debian/Ubuntu repos)
  if ! command -v starship &>/dev/null; then
    section "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
  fi

  # lazygit (not in Ubuntu repos)
  if ! command -v lazygit &>/dev/null; then
    section "Installing lazygit..."
    local LAZYGIT_VERSION
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    run_privileged install /tmp/lazygit /usr/local/bin/
    rm -f /tmp/lazygit.tar.gz /tmp/lazygit
  fi

  # lazydocker (not in Ubuntu repos)
  if ! command -v lazydocker &>/dev/null; then
    section "Installing lazydocker..."
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  fi

  # gum (from Charm apt repo)
  if ! command -v gum &>/dev/null; then
    section "Installing gum..."
    local charm_key_tmp charm_keyring_tmp charm_list_tmp
    charm_key_tmp=$(mktemp)
    charm_keyring_tmp=$(mktemp)
    charm_list_tmp=$(mktemp)
    curl -fsSL https://repo.charm.sh/apt/gpg.key -o "$charm_key_tmp"
    gpg --dearmor -o "$charm_keyring_tmp" "$charm_key_tmp"
    printf 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *\n' >"$charm_list_tmp"
    run_privileged mkdir -p /etc/apt/keyrings
    run_privileged install -D -m 0644 "$charm_keyring_tmp" /etc/apt/keyrings/charm.gpg
    run_privileged install -D -m 0644 "$charm_list_tmp" /etc/apt/sources.list.d/charm.list
    rm -f "$charm_key_tmp" "$charm_keyring_tmp" "$charm_list_tmp"
    run_privileged "$(find_linux_binary apt-get)" update
    run_privileged "$(find_linux_binary apt-get)" install -y gum
  fi

  # mise (not in Ubuntu repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh 2>/dev/null
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

install_npm_tools() {
  section "Installing AI coding assistants..."
  if ! command -v opencode &>/dev/null; then
    npm install -g opencode-ai
  fi
  if ! command -v claude-code &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
  fi
}

enable_services() {
  if is_proot_environment || ! supports_systemd; then
    skip_in_proot "system service enablement"
    return 0
  fi

  section "Enabling services..."

  run_privileged systemctl enable --now docker.service
  echo "✓ Docker"

  run_privileged systemctl enable --now ssh.service
  echo "✓ sshd"
}
