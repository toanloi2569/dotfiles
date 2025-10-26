#!/usr/bin/env bash
set -euo pipefail

# Install tools that are not distributed via apt: starship and kubectl.
# The script logs the homepage for each tool, installs it into ~/.local/bin by default,
# and provides post-install configuration hints.

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
PATH="$LOCAL_BIN:$PATH"

log_section() {
  local title="$1"
  echo
  echo "============================================================"
  echo "${title}"
  echo "============================================================"
}

ensure_downloader() {
  if command -v curl >/dev/null 2>&1; then
    echo curl
    return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    echo wget
    return 0
  fi
  echo "Error: require either 'curl' or 'wget' to download files." >&2
  exit 1
}

install_starship() {
  log_section "Starship"
  echo "Homepage: https://starship.rs/"

  if command -v starship >/dev/null 2>&1; then
    echo "Starship is already installed at $(command -v starship); skipping installation."
  else
    local downloader
    downloader=$(ensure_downloader)
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    echo "Downloading starship installer script..."
    case "$downloader" in
      curl)
        curl -fsSL https://starship.rs/install.sh -o "$tmpdir/install.sh"
        ;;
      wget)
        wget -q https://starship.rs/install.sh -O "$tmpdir/install.sh"
        ;;
    esac

    chmod +x "$tmpdir/install.sh"
    echo "Running installer (placing binary in $LOCAL_BIN)..."
    sh "$tmpdir/install.sh" --yes --bin-dir "$LOCAL_BIN"
    hash -r

    if command -v starship >/dev/null 2>&1; then
      echo "Starship installed successfully at $(command -v starship)."
    else
      echo "Warning: starship not found after installation." >&2
    fi

    trap - RETURN
    rm -rf "$tmpdir"
  fi

  cat <<'POST'
Post-install notes:
- Ensure your PATH includes ~/.local/bin (this script already prepends it for the current session).
- Add `eval "$(starship init zsh)"` to ~/.zshrc to enable the Starship prompt.
  This dotfiles repository already includes that line near the end of configs/zsh/.zshrc.
POST
}

install_kubectl() {
  log_section "kubectl"
  echo "Homepage: https://kubernetes.io/docs/reference/kubectl/"

  if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is already installed at $(command -v kubectl); skipping installation."
    return
  fi

  require_arch_support

  local downloader
  downloader=$(ensure_downloader)
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  pushd "$tmpdir" >/dev/null

  local os="$(uname | tr '[:upper:]' '[:lower:]')"
  local arch
  arch=$(normalize_arch)

  local version
  case "$downloader" in
    curl)
      version=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
      ;;
    wget)
      version=$(wget -qO- https://dl.k8s.io/release/stable.txt)
      ;;
  esac

  if [[ -z "$version" ]]; then
    echo "Could not determine the latest kubectl version; please check your network connection." >&2
    exit 1
  fi

  local base_url="https://dl.k8s.io/release/${version}/bin/${os}/${arch}"

  echo "Downloading kubectl ${version} for ${os}/${arch}..."
  case "$downloader" in
    curl)
      curl -fsSLO "${base_url}/kubectl"
      curl -fsSLO "${base_url}/kubectl.sha256"
      ;;
    wget)
      wget -q "${base_url}/kubectl"
      wget -q "${base_url}/kubectl.sha256"
      ;;
  esac

  echo "Verifying checksum..."
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status || {
    echo "Checksum mismatch for kubectl binary." >&2
    exit 1
  }

  chmod +x kubectl
  mv kubectl "$LOCAL_BIN/kubectl"

  popd >/dev/null
  trap - RETURN
  rm -rf "$tmpdir"

  hash -r

  if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl installed successfully at $(command -v kubectl)."
  else
    echo "Warning: kubectl not found after installation." >&2
  fi

  cat <<'POST'
Post-install notes:
- Enable autocompletion with `echo 'source <(kubectl completion zsh)' >> ~/.zshrc`
  or store the completion script under ~/.zshrc.d within this dotfiles repo.
- Add short aliases (e.g. `alias k=kubectl`) in configs/zsh/alias or ~/.zshrc.d as needed.
POST
}

normalize_arch() {
  local machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64)
      echo "amd64"
      ;;
    arm64|aarch64)
      echo "arm64"
      ;;
    armv7l)
      echo "arm"
      ;;
    *)
      echo "Error: architecture '${machine}' is not supported for kubectl downloads." >&2
      return 1
      ;;
  esac
}

require_arch_support() {
  normalize_arch >/dev/null
}

main() {
  case "${1:-}" in
    -h|--help)
      echo "Usage: ./scripts/install-tools.sh"
      echo "Install starship and kubectl without using apt."
      return 0
      ;;
    "")
      ;;
    *)
      echo "Invalid option: $1" >&2
      return 1
      ;;
  esac

  install_starship
  install_kubectl

  echo
  echo "Completed installation of manual tools."
}

main "$@"
