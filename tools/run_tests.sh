#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    printf '%s\n' "${GODOT_BIN}"
    return
  fi
  local candidate
  for candidate in \
    godot4 \
    godot \
    /Applications/Godot.app/Contents/MacOS/Godot \
    /home/ubuntu/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
  do
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return
    fi
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return
    fi
  done
  return 1
}

GODOT_BIN="$(find_godot || true)"
if [[ -z "${GODOT_BIN}" || ! -x "${GODOT_BIN}" ]]; then
  echo "Godot 4.7.2 was not found. Set GODOT_BIN to an executable." >&2
  exit 1
fi
GODOT_VERSION="$("${GODOT_BIN}" --version)"
if [[ "${GODOT_VERSION}" != 4.7.2* ]]; then
  echo "Godot 4.7.2 is required; found ${GODOT_VERSION}." >&2
  exit 1
fi

export GODOT_SILENCE_ROOT_WARNING=1

# A clean clone has no global-script cache. Prime imports before direct SceneTree scripts.
if [[ ! -s "${ROOT}/.godot/global_script_class_cache.cfg" ]]; then
  echo "==> initializing Godot imports"
  "${GODOT_BIN}" --headless --editor --path "${ROOT}" --import --quit-after 2
fi

TEST_LOG_DIR="$(mktemp -d)"
trap 'rm -rf "${TEST_LOG_DIR}"' EXIT

for test_script in \
	  tests/map_test.gd \
	  tests/projection_test.gd \
	  tests/assets_test.gd \
	  tests/audio_test.gd \
	  tests/effect_director_test.gd \
	  tests/cursor_test.gd \
	  tests/localization_test.gd \
	  tests/leaderboard_test.gd \
	  tests/hud_test.gd \
	  tests/interaction_test.gd \
  tests/command_system_test.gd \
  tests/fortification_test.gd \
  tests/visibility_test.gd \
	  tests/view_overlay_test.gd \
  tests/simulation_test.gd \
	  tests/core_regression_test.gd \
	  tests/battlefield_regression_test.gd \
	  tests/ui_regression_test.gd \
	  tests/performance_test.gd
do
  echo "==> ${test_script}"
  test_log="${TEST_LOG_DIR}/$(basename "${test_script}").log"
  "${GODOT_BIN}" --headless --path "${ROOT}" --script "${ROOT}/${test_script}" 2>&1 | tee "${test_log}"
  if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|No loader found for resource|Failed to load script' "${test_log}"; then
    echo "Fatal Godot diagnostic detected in ${test_script}" >&2
    exit 1
  fi
done
