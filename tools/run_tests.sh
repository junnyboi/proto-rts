#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

for test_script in \
  tests/projection_test.gd \
  tests/assets_test.gd \
  tests/simulation_test.gd
do
  echo "==> ${test_script}"
  "${GODOT_BIN}" --headless --path "${ROOT}" --script "${ROOT}/${test_script}"
done
