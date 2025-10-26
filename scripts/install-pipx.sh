#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
PACKAGES_FILE="$DOTFILES_DIR/packages/pipx/packages.txt"
RUN_UPDATE=true

usage() {
  cat <<'USAGE'
Usage: ./scripts/install-pipx.sh [--no-update]

Ensure pipx is available and install packages listed in packages/pipx/packages.txt.

Options:
  --no-update   Skip running apt-get update when installing pipx
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

ensure_pipx() {
  if command -v pipx >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    local apt_cmd=("apt-get")
    if command -v sudo >/dev/null 2>&1; then
      apt_cmd=("sudo" "apt-get")
    fi

    if [[ "$RUN_UPDATE" == true ]]; then
      echo "Updating package index before installing pipx..."
      "${apt_cmd[@]}" update
    fi

    echo "Installing pipx via apt..."
    if "${apt_cmd[@]}" install -y pipx; then
      return 0
    else
      echo "Warning: apt installation of pipx failed; attempting pip-based install." >&2
    fi
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: pipx not found and python3 is unavailable; install python3 or pipx manually." >&2
    return 1
  fi

  if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "Bootstrapping pip..."
    python3 -m ensurepip --upgrade >/dev/null 2>&1 || true
  fi

  echo "Installing pipx via pip..."
  python3 -m pip install --user --upgrade pipx
  python3 -m pipx ensurepath >/dev/null 2>&1 || true
  export PATH="$HOME/.local/bin:$PATH"
  hash -r

  if ! command -v pipx >/dev/null 2>&1; then
    echo "Error: pipx installation failed; ensure ~/.local/bin is in your PATH." >&2
    return 1
  fi
}

install_packages() {
  if [[ ! -f "$PACKAGES_FILE" ]]; then
    echo "packages/pipx/packages.txt not found; nothing to install."
    return 0
  fi

  local had_failures=false
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    local line="${raw_line%%#*}"
    line="${line//$'\r'/}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    read -ra args <<<"$line"
    if (( ${#args[@]} == 0 )); then
      continue
    fi

    echo "Installing pipx package: ${args[*]}"
    if ! pipx install --force "${args[@]}"; then
      echo "Warning: failed to install ${args[0]} via pipx" >&2
      had_failures=true
    fi
  done < "$PACKAGES_FILE"

  if [[ "$had_failures" == true ]]; then
    return 1
  fi
}

if ! ensure_pipx; then
  exit 1
fi

if ! install_packages; then
  exit 1
fi

echo "pipx packages installation complete."
