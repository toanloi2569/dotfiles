#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
PKG_FILE="$DOTFILES_DIR/packages/apt/packages.txt"
RUN_UPDATE=true

usage() {
  cat <<'USAGE'
Usage: ./scripts/bootstrap-apt.sh [--no-update]

Install Apt packages listed in packages/apt/packages.txt.

Options:
  --no-update   Skip running apt-get update before installation
  -h, --help    Show this help message
USAGE
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

if [[ ! -f "$PKG_FILE" ]]; then
  echo "packages/apt/packages.txt not found; nothing to install."
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get not available; skipping package installation."
  exit 0
fi

mapfile -t PACKAGES < <(sed 's/#.*$//' "$PKG_FILE" | awk 'NF')
if (( ${#PACKAGES[@]} == 0 )); then
  echo "No packages listed in packages/apt/packages.txt; nothing to install."
  exit 0
fi

APT_CMD=("apt-get")
if command -v sudo >/dev/null 2>&1; then
  APT_CMD=("sudo" "apt-get")
fi

if [[ "$RUN_UPDATE" == true ]]; then
  echo "Updating package index..."
  "${APT_CMD[@]}" update
fi

echo "Installing packages: ${PACKAGES[*]}"
"${APT_CMD[@]}" install -y "${PACKAGES[@]}"
