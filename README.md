# Personal Dotfiles

These dotfiles collect shell, Git, and Kubernetes configuration alongside helper scripts. Clone the repository (recommended path: `~/.dotfiles`) and run the setup scripts to link everything into place.

## Directory Layout

```
.
├── bin/                     # Executable helper scripts (e.g. logcolor)
├── configs/
│   ├── fastfetch/           # Fastfetch JSON config
│   ├── ghostty/             # Ghostty terminal config
│   ├── git/                 # gitconfig (gitconfig.local is ignored)
│   ├── nvim/                # LazyVim bootstrap (init.lua, lua/, lazy-lock.json, stylua.toml)
│   ├── starship.toml        # Starship prompt configuration
│   ├── wget/                # wgetrc
│   └── zsh/                 # .zshrc, alias/, functions/, plugins.txt
├── docker/
│   └── config.json
├── docs/
│   └── manual-tools.md
├── packages/
│   ├── apt/packages.txt     # apt install list
│   ├── krew/plugins.txt     # kubectl krew plugins
│   └── pipx/packages.txt    # pipx packages (e.g. poetry)
├── scripts/                 # Bootstrap + installer helpers
│   ├── bootstrap-apt.sh
│   ├── install-dotfiles.sh
│   ├── install-krew.sh
│   ├── install-pipx.sh
│   ├── install-tools.sh
│   └── install-zsh.sh
└── tools/
    └── secret-scan/         # gitleaks + pre-commit fences (full repo + symlinks)
```

Feel free to add more configs under `configs/` (e.g. `tmux/`, `alacritty/`) and update `scripts/install-dotfiles.sh` to link them.

## Quick Start

```bash
# Clone into ~/.dotfiles (recommended)
git clone git@github.com:toanloi2569/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Link dotfiles into $HOME (creates backups when needed)
./scripts/install-dotfiles.sh install

# Install apt packages listed in packages/apt/packages.txt
./scripts/bootstrap-apt.sh

# Install pipx and packages (e.g. poetry)
./scripts/install-pipx.sh

# Install non-apt tools (starship, kubectl) and optionally krew
./scripts/install-tools.sh
./scripts/install-krew.sh
```

After running these scripts, open a fresh shell (or `exec zsh`) so PATH updates and `eval` statements take effect.

> ⚠️ Update `configs/git/gitconfig` with your own name/email or place overrides in `~/.gitconfig.local`.

## Highlights

- **Zsh functions** (`configs/zsh/functions/*.zsh`)
  - `gco`: interactively select branches with `fzf`; create via `gco --create feature-branch`.
  - Kubernetes helpers such as `klogs-label`, `kexec-label`, `kpods-clean`, `kxp`, `kctxmerge`.
  - Base64 utilities (`decodeb64`, `encodeb64`, `basicauth`).
- **bin/logcolor**: colorize common log levels when reading files or `tail -f` output.
- **configs/starship.toml**: Starship prompt tuned for Kubernetes-aware shells.
- **configs/nvim/**: LazyVim-based Neovim setup including `lua/config/*`, optional plugin specs, and `lazy-lock.json` for reproducible installs.
- **scripts/install-*.sh**: modular installers for apt, zsh plugins, pipx apps, starship/kubectl, and krew.
- **tools/secret-scan**: gitleaks + pre-commit guard that scans staged files, the entire repo, and every symlink target.

## Customize

- Add new scripts under `bin/` and run `chmod +x`.
- Drop additional functions or aliases into `configs/zsh/functions/` or `configs/zsh/alias/`.
- Create `~/.zshrc.local` for machine-specific overrides without touching the repo.
- When adding new dotfiles, update `scripts/install-dotfiles.sh` with matching `link_file` entries.
- Extend package/plugin lists in `packages/apt/packages.txt`, `packages/pipx/packages.txt`, `configs/zsh/plugins.txt`, or `packages/krew/plugins.txt`.

## Recommended Dependencies

- [`fzf`](https://github.com/junegunn/fzf) for fuzzy selection.
- [`kubectl`](https://kubernetes.io/) together with `krew` for plugin management.
- [`git`](https://git-scm.com/), [`direnv`](https://direnv.net/), [`starship`](https://starship.rs/).

Happy shell hacking! 🚀
