#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    printf '%s\n' "${GODOT_BIN}"
    return
  fi

  local candidate
  for candidate in godot4 godot /Applications/Godot.app/Contents/MacOS/Godot; do
    if [[ "${candidate}" == /* ]]; then
      if [[ -x "${candidate}" ]]; then
        printf '%s\n' "${candidate}"
        return
      fi
    elif command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return
    fi
  done

  return 1
}

if ! GODOT_BIN="$(find_godot)"; then
  echo "Godot 4.7.2 was not found. Set GODOT_BIN to the Godot executable." >&2
  exit 1
fi
if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "GODOT_BIN is not executable: ${GODOT_BIN}" >&2
  exit 1
fi
GODOT_VERSION="$("${GODOT_BIN}" --version)"
if [[ "${GODOT_VERSION}" != 4.7.2* ]]; then
  echo "Godot 4.7.2 is required; found ${GODOT_VERSION}." >&2
  exit 1
fi

export GODOT_SILENCE_ROOT_WARNING=1

if [[ ! -f "${ROOT}/.godot/global_script_class_cache.cfg" ]]; then
  echo "==> Initializing Godot imports and global script classes"
  "${GODOT_BIN}" --headless --path "${ROOT}" --import
fi

for test_script in \
  tests/projection_test.gd \
  tests/assets_test.gd \
  tests/simulation_test.gd \
  tests/core_regression_test.gd \
  tests/battlefield_regression_test.gd \
  tests/ui_regression_test.gd
do
  echo "==> ${test_script}"
  "${GODOT_BIN}" --headless --path "${ROOT}" --script "${ROOT}/${test_script}"
done
