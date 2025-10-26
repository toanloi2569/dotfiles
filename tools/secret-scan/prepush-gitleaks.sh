#!/usr/bin/env bash
set -euo pipefail

# Always run the script from the repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.gitleaks.toml"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

if ! need_cmd gitleaks; then
  echo "[pre-push] gitleaks is not installed. Aborting push." >&2
  echo "[pre-push] Run tools/secret-scan/install.sh to install dependencies." >&2
  exit 1
fi

# cross-platform realpath
resolve_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import os,sys
print(os.path.realpath(sys.argv[1]))
PY
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    python - "$1" <<'PY'
import os,sys
print(os.path.realpath(sys.argv[1]))
PY
    return 0
  fi
  echo "$1"
}

echo "[pre-push] Gitleaks: scanning repository contents (no VCS metadata)"
gitleaks detect --no-git --source "${REPO_ROOT}" --redact --config "${CONFIG_FILE}"

echo "[pre-push] Gitleaks: scanning every symlink target reachable from the repo"
mapfile -d '' SYMLINKS < <(find "${REPO_ROOT}" -type l -print0 || true)

# Dedup targets
declare -A TARGETS=()

for L in "${SYMLINKS[@]:-}"; do
  T="$(resolve_realpath "$L" 2>/dev/null || true)"
  [ -z "${T}" ] && continue
  if [ ! -e "${T}" ]; then
    echo "  - skip (dangling symlink): ${L} -> ${T}" >&2
    continue
  fi
  if [ -d "${T}" ]; then
    TARGETS["${T}"]=dir
  else
    TARGETS["${T}"]=file
  fi
done

for T in "${!TARGETS[@]}"; do
  TYPE="${TARGETS[$T]}"
  echo "  - scanning ${TYPE}: ${T}"
  if [ "${TYPE}" = "dir" ]; then
    gitleaks detect --no-git --source "${T}" --redact --config "${CONFIG_FILE}"
  else
    PARENT="$(dirname "${T}")"
    gitleaks detect --no-git --source "${PARENT}" --redact --config "${CONFIG_FILE}"
  fi
done

echo "[pre-push] ✓ No secrets detected (repository + symlink targets)"
