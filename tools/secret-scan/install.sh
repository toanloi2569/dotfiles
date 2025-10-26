#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

echo "[setup] Installing pre-commit"
if ! need_cmd pre-commit; then
  if need_cmd pipx; then
    pipx install pre-commit
  elif need_cmd pip3; then
    pip3 install --user pre-commit
  elif need_cmd pip; then
    pip install --user pre-commit
  else
    echo "[setup] Unable to find pip/pip3/pipx. Please install Python + pip first." >&2
    exit 2
  fi
else
  echo "[setup] pre-commit already present."
fi

echo "[setup] Installing gitleaks"
if ! need_cmd gitleaks; then
  UNAME="$(uname -s || true)"
  case "$UNAME" in
    Darwin)
      if need_cmd brew; then
        brew install gitleaks
      else
        echo "[setup] Homebrew not detected on macOS. Installing via the official gitleaks script."
        curl -sSL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | bash
      fi
      ;;
    Linux)
      # Ubuntu/WSL
      curl -sSL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | bash
      ;;
    *)
      echo "[setup] Unsupported OS detected ($UNAME). Falling back to the default install script."
      curl -sSL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | bash
      ;;
  esac
else
  echo "[setup] gitleaks already present."
fi

echo "[setup] Marking pre-push script as executable"
chmod +x "${ROOT_DIR}/prepush-gitleaks.sh"

echo "[setup] Installing pre-commit & pre-push hooks (custom config)"
# run from repo root so pre-commit sees the config file path
(
  cd "${ROOT_DIR}/../.."
  pre-commit install --config tools/secret-scan/.pre-commit-config.yaml --hook-type pre-commit --hook-type pre-push
)

echo "[setup] Done. Validate the entire repo with:"
echo "  pre-commit run --all-files --config tools/secret-scan/.pre-commit-config.yaml"
