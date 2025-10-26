#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
PLUGINS_FILE="$DOTFILES_DIR/packages/krew/plugins.txt"
KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"
export PATH="$KREW_ROOT/bin:$PATH"

usage() {
  cat <<'USAGE'
Usage: ./scripts/install-krew.sh

Install the Kubernetes krew plugin manager and optional plugins listed in packages/krew/plugins.txt.
USAGE
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' is not available." >&2
    exit 1
  fi
}

install_krew() {
  if [[ -x "$KREW_ROOT/bin/kubectl-krew" ]]; then
    return 0
  fi

  require_command kubectl

  local os arch
  os=$(uname | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)
      arch="amd64"
      ;;
    arm64|aarch64)
      arch="arm64"
      ;;
    armv7l)
      arch="arm"
      ;;
    *)
      echo "Error: unsupported architecture '$arch' for krew installer." >&2
      exit 1
      ;;
  esac

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  pushd "$tmpdir" >/dev/null

  local tarball="krew-${os}_${arch}.tar.gz"
  local url="https://github.com/kubernetes-sigs/krew/releases/latest/download/${tarball}"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSLO "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url"
  else
    echo "Error: neither curl nor wget is available to download krew." >&2
    exit 1
  fi

  tar zxvf "$tarball" >/dev/null
  local installer="./krew-${os}_${arch}"
  chmod +x "$installer"
  "$installer" install krew

  popd >/dev/null
  rm -rf "$tmpdir"
  trap - EXIT

  export PATH="$KREW_ROOT/bin:$PATH"
  hash -r
}

install_plugins() {
  if [[ ! -f "$PLUGINS_FILE" ]]; then
    echo "packages/krew/plugins.txt not found; skipping plugin installation."
    return 0
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is required to manage krew plugins. Install kubectl first." >&2
    return 1
  fi

  if ! command -v kubectl-krew >/dev/null 2>&1 && ! kubectl krew version >/dev/null 2>&1; then
    echo "krew does not appear to be installed correctly." >&2
    return 1
  fi

  local had_failures=false
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    local line="${raw_line%%#*}"
    line="${line//$'\r'/}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    echo "Installing krew plugin: $line"
    if ! kubectl krew install "$line"; then
      echo "Warning: failed to install krew plugin '$line'" >&2
      had_failures=true
    fi
  done < "$PLUGINS_FILE"

  if [[ "$had_failures" == true ]]; then
    return 1
  fi
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage
    exit 1
    ;;
 esac

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is required before installing krew. Add kubectl to your apt package list or install it manually." >&2
  exit 1
fi

install_krew

if ! install_plugins; then
  exit 1
fi

echo "krew installation complete."
