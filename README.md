# Omaterm

An omakase headless setup for Arch Linux servers or dev boxes in the spirit of Omarchy by DHH.

## Requirements

- Base Arch Linux installation
- Internet connection
- `sudo` privileges

## Proot support

Omaterm can run inside a `proot` distro, but it operates in a reduced mode. User-space tools, configs, and local binaries are installed normally; system services and host-level integrations such as Docker, Tailscale service setup, and SSH daemon reconfiguration are skipped. If auto-detection misses your environment, run the installer with `OMATERM_PROOT=1`.

On Arch-based `proot` environments on Android, run the installer as the `root` user inside the distro. `sudo` authentication is often not wired up cleanly there and can fail with `Authentication token manipulation error`.

## Install

```bash
curl -fsSL https://omaterm.org/install | bash
```

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide
- **Editors**: Neovim (LazyVim), opencode, claude-code
- **Dev tools**: mise, docker, github-cli, lazygit, lazydocker
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

## Interactive prompts

During installation you'll be asked for:

- Git user name
- Git email address

And you'll be offered to setup:

- Tailscale
- GitHub
- SSH public keys
