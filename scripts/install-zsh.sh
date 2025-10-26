#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
PLUGINS_FILE="$DOTFILES_DIR/configs/zsh/plugins.txt"
RUN_UPDATE=true

usage() {
  cat <<'USAGE'
Usage: ./scripts/install-zsh.sh [--no-update]

Ensure zsh is installed and install zsh plugins listed in configs/zsh/plugins.txt.

Options:
  --no-update   Skip running apt-get update when installing zsh
  -h, --help    Show this help message
USAGE
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

while (( $# > 0 )); do
  case "$1" in
    --no-update)
      RUN_UPDATE=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

ensure_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "zsh is not installed and apt-get is unavailable; install zsh manually." >&2
    return 1
  fi

  local apt_cmd=("apt-get")
  if command -v sudo >/dev/null 2>&1; then
    apt_cmd=("sudo" "apt-get")
  fi

  if [[ "$RUN_UPDATE" == true ]]; then
    echo "Updating package index before installing zsh..."
    "${apt_cmd[@]}" update
  fi

  echo "Installing zsh..."
  "${apt_cmd[@]}" install -y zsh
}

install_plugins() {
  if [[ ! -f "$PLUGINS_FILE" ]]; then
    echo "No configs/zsh/plugins.txt found; skipping plugin installation."
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "git not available; skipping zsh plugin installation."
    return 0
  fi

  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local plugins_dir="$custom_dir/plugins"
  mkdir -p "$plugins_dir"

  local had_failures=false

  while IFS= read -r raw_line; do
    local line="${raw_line%%#*}"
    line="${line//$'\r'/}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    local name url extra
    IFS=$' \t' read -r name url extra <<<"$line"

    if [[ -z "$name" || -z "$url" ]]; then
      echo "Skipping malformed plugin line: ${raw_line}" >&2
      had_failures=true
      continue
    fi

    url="${url%%#*}"
    url="$(trim "$url")"

    if [[ -n "$extra" ]]; then
      echo "Skipping malformed plugin line: ${raw_line}" >&2
      had_failures=true
      continue
    fi

    local target="$plugins_dir/$name"
    if [[ -d "$target/.git" ]]; then
      echo "Updating zsh plugin: $name"
      if ! git -C "$target" pull --ff-only --quiet; then
        echo "Warning: could not update $name" >&2
        had_failures=true
      fi
    elif [[ -d "$target" ]]; then
      echo "Skipping $name (directory exists but is not a git repo)"
    else
      echo "Installing zsh plugin: $name"
      if ! git clone --depth 1 "$url" "$target"; then
        echo "Warning: could not clone $name" >&2
        had_failures=true
      fi
    fi
  done < "$PLUGINS_FILE"

  if [[ "$had_failures" == true ]]; then
    return 1
  fi
}

if ! ensure_zsh; then
  exit 1
fi

if ! install_plugins; then
  exit 1
fi
