# Repository Guidelines

## Project Structure & Module Organization
This repository is a Bash-first installer for Omaterm. The root [`install.sh`](/home/howie/Documents/Github/OmaProot/install.sh) is the entrypoint and dispatches to OS-specific installers in [`install/`](/home/howie/Documents/Github/OmaProot/install/) (`arch.sh`, `debian.sh`, `fedora.sh`). User-facing helper commands live in [`bin/`](/home/howie/Documents/Github/OmaProot/bin/). Default dotfiles and tool config are stored in [`config/`](/home/howie/Documents/Github/OmaProot/config/), including Neovim, Starship, and Lazygit settings. Keep new platform logic in `install/`, reusable shell helpers in `bin/`, and checked-in defaults under `config/`.

## Build, Test, and Development Commands
Use shell-native validation and direct script execution:

```bash
bash -n install.sh install/*.sh bin/*
```

Checks Bash syntax for the installer and helper scripts.

```bash
shellcheck install.sh install/*.sh bin/*
```

Runs static analysis for shell scripts when `shellcheck` is installed.

```bash
bash install.sh
```

Runs the installer locally. Read the script first: it installs packages, enables services, and writes to `$HOME`.

## Coding Style & Naming Conventions
Use Bash with `#!/usr/bin/env bash` for main scripts and `set -euo pipefail` for non-trivial executables. Follow the existing style: two-space indentation, lowercase snake_case function names like `install_packages`, and short imperative helper names like `section` or `finish`. Prefer small functions over long inline command chains. Keep filenames lowercase with hyphens for standalone commands in `bin/` and lowercase OS names for installer modules.

## Testing Guidelines
There is no committed automated test suite yet. At minimum, run `bash -n` on every changed script and execute the relevant installer path in a safe environment, such as a disposable VM or container for the target distro. When adding distro-specific logic, test only the matching file in `install/` and note any manual verification steps in the PR.

## Commit & Pull Request Guidelines
Recent commits use short, imperative subjects such as `Fix npm installs` and `Load kitty-terminfo`. Keep commit titles concise, present tense, and focused on one change. Pull requests should include a brief summary, affected OS targets, manual test notes, and screenshots only when UI-facing terminal output changes materially. Link related issues when applicable.

## Safety & Configuration Tips
Treat installer changes as system-level changes. Avoid hardcoding machine-specific paths beyond `$HOME`, document any new external dependency, and call out commands that require `sudo`, network access, or service restarts.
