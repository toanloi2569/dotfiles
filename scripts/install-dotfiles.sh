#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
BACKUP_ROOT="$DOTFILES_DIR/.backup"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
MANIFEST=""
declare -a BACKED_UP=()

die() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: ./scripts/install-dotfiles.sh [command]

Commands:
  install            Back up existing files and create symlinks (default)
  restore [name]     Restore files from a backup directory (default: latest)
  list               List available backups
  help               Show this help message
USAGE
}

ensure_backup_dir() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
  fi
  if [[ -z "$MANIFEST" ]]; then
    MANIFEST="$BACKUP_DIR/manifest.tsv"
    : > "$MANIFEST"
  fi
}

backup() {
  local target="$1"
  local desired="${2:-}"

  if [[ -L "$target" ]]; then
    local current
    current=$(readlink "$target")
    if [[ -n "$desired" && "$current" == "$desired" ]]; then
      return 1
    fi
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    ensure_backup_dir

    local backup_target
    if [[ "$target" == "$HOME"* ]]; then
      backup_target="$BACKUP_DIR/home/${target#$HOME/}"
    else
      backup_target="$BACKUP_DIR/system/${target#/}"
    fi

    mkdir -p "$(dirname "$backup_target")"
    mv "$target" "$backup_target"
    printf '%s\t%s\n' "$target" "$backup_target" >> "$MANIFEST"
    BACKED_UP+=("$target")
    echo "Backed up: $target -> $backup_target"
    return 0
  fi

  return 1
}

link_file() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"
  backup "$target" "$source" || true
  ln -sfn "$source" "$target"
  echo "Linked: $target -> $source"
}

install_bins() {
  local bin_dir="$DOTFILES_DIR/bin"
  local target_dir="$HOME/.local/bin"

  [[ -d "$bin_dir" ]] || return 0
  mkdir -p "$target_dir"

  for file in "$bin_dir"/*; do
    [[ -f "$file" ]] || continue
    local target="$target_dir/$(basename "$file")"
    backup "$target" "$file" || true
    ln -sfn "$file" "$target"
    chmod +x "$file"
    echo "Linked bin: $target -> $file"
  done
}

perform_install() {
  echo "Installing dotfiles from $DOTFILES_DIR"

  # Link core configuration files into $HOME

  link_file "$DOTFILES_DIR/configs/zsh/.zshrc" "$HOME/.zshrc"
  link_file "$DOTFILES_DIR/configs/zsh/functions" "$HOME/.config/zsh/functions"
  link_file "$DOTFILES_DIR/configs/zsh/alias" "$HOME/.config/zsh/alias"
  link_file "$DOTFILES_DIR/configs/git/gitconfig" "$HOME/.gitconfig"
  link_file "$DOTFILES_DIR/configs/starship.toml" "$HOME/.config/starship.toml"
  link_file "$DOTFILES_DIR/configs/wget/wgetrc" "$HOME/.wgetrc"
  link_file "$DOTFILES_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  link_file "$DOTFILES_DIR/configs/ghostty/config" "$HOME/.config/ghostty/config"
  link_file "$DOTFILES_DIR/configs/nvim" "$HOME/.config/nvim"

  if [[ -f "$DOTFILES_DIR/docker/config.json" ]]; then
    link_file "$DOTFILES_DIR/docker/config.json" "$HOME/.docker/config.json"
  fi

  if [[ -f "$DOTFILES_DIR/configs/git/gitconfig.local" ]]; then
    link_file "$DOTFILES_DIR/configs/git/gitconfig.local" "$HOME/.gitconfig.local"
  fi

  install_bins

  echo
  echo "Installation complete."
  if (( ${#BACKED_UP[@]} > 0 )); then
    echo "Backups stored in $BACKUP_DIR"
    for path in "${BACKED_UP[@]}"; do
      echo "  • $path"
    done
  else
    echo "No existing files required backup."
  fi
  echo "Remember to update configs/git/gitconfig with your real name and email."
}

choose_backup_dir() {
  local requested="$1"
  local selected=""

  if [[ ! -d "$BACKUP_ROOT" ]]; then
    die "No backups available."
  fi

  if [[ "$requested" == "latest" ]]; then
    selected=$(ls -1d "$BACKUP_ROOT"/* 2>/dev/null | sort | tail -n1)
  else
    if [[ -d "$BACKUP_ROOT/$requested" ]]; then
      selected="$BACKUP_ROOT/$requested"
    elif [[ -d "$requested" ]]; then
      selected="$requested"
    fi
  fi

  [[ -n "$selected" && -d "$selected" ]] || die "Backup '$requested' not found."
  echo "$selected"
}

perform_restore() {
  local requested="${1:-latest}"
  local selected
  selected=$(choose_backup_dir "$requested")
  local manifest="$selected/manifest.tsv"

  [[ -f "$manifest" ]] || die "Manifest file missing in $selected"

  echo "Restoring files from $selected"
  while IFS=$'\t' read -r original backup_path; do
    [[ -z "$original" ]] && continue
    if [[ -e "$backup_path" || -L "$backup_path" ]]; then
      mkdir -p "$(dirname "$original")"
      if [[ -e "$original" || -L "$original" ]]; then
        rm -rf "$original"
      fi
      mv "$backup_path" "$original"
      echo "Restored: $original"
    fi
  done < "$manifest"

  echo "Restore complete."
}

list_backups() {
  if [[ ! -d "$BACKUP_ROOT" ]]; then
    echo "No backups available."
    return
  fi

  echo "Available backups:"
  ls -1d "$BACKUP_ROOT"/* 2>/dev/null | sort | sed "s#^$BACKUP_ROOT/##"
}

COMMAND="${1:-install}"
shift || true

case "$COMMAND" in
  install)
    perform_install "$@"
    ;;
  restore)
    perform_restore "${1:-latest}"
    ;;
  list)
    list_backups
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
 esac
