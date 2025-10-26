# Manual Tool Installation: Starship & kubectl

Run the helper script whenever you need to install tooling that is not available via apt:

```bash
./scripts/install-tools.sh
```

The script will:

- Print the homepage for each tool so you can review upstream docs.
- Download and install binaries into `~/.local/bin` (creating the directory when needed).
- Remind you about any follow-up configuration steps.

## Starship

- **Homepage**: https://starship.rs/
- Uses the official `install.sh` script and places the binary under `~/.local/bin`.
- Ensures `~/.local/bin` is on `PATH` for the current shell; keep it in `~/.profile` or `configs/zsh/.zshrc` for persistence.
- This dotfiles repo already calls `eval "$(starship init zsh)"` inside `configs/zsh/.zshrc`, so opening a new shell activates the prompt automatically.
- Prompt configuration lives in `configs/starship.toml`, which `scripts/install-dotfiles.sh` symlinks into place.

## kubectl

- **Homepage**: https://kubernetes.io/docs/reference/kubectl/
- Downloads the latest stable release from `https://dl.k8s.io`, verifies the checksum, and installs it to `~/.local/bin/kubectl`.
- Enable autocompletion with `echo 'source <(kubectl completion zsh)' >> ~/.zshrc` or by adding a completion script under `~/.zshrc.d`.
- Add short aliases (e.g. `alias k=kubectl`) inside `configs/zsh/alias` or your personal overrides under `~/.zshrc.d`.
- Install the kubectl plugin manager by running `./install-krew.sh` after kubectl is working.

## Suggested order of operations

1. `./scripts/install-tools.sh` – install Starship and kubectl.
2. `./scripts/install-dotfiles.sh install` – set up symlinks for all configuration files.
3. `./scripts/install-krew.sh` – optional, if you plan to manage kubectl plugins.
4. Restart your shell (or run `exec zsh`) so PATH and other `eval` statements take effect.

Always review scripts before executing them in production environments to ensure they comply with your security policies.
