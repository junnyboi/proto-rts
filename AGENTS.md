# Repository Instructions

## Project contract

Mandate of Myth targets Godot 4.7.2 and desktop browsers. Preserve the authoritative simulation/view split: `scripts/sim/rts_simulation.gd` owns gameplay truth; projection, sprites, camera state, and interface feedback remain presentation concerns.

## Generated assets

Do not overwrite files under `assets/source/`. Create runtime derivatives only through `tools/process_assets.py`. Preserve `.gdignore` so high-resolution source masters do not enter the browser export. Update `assets/runtime/asset-report.json` and `SHA256SUMS` whenever runtime art changes.

## Verification

Use the smallest relevant gate. For simulation or projection changes, run `tools/run_tests.sh`. For interface or rendering changes, also run the native visual harness once. For release changes, perform one Web export and confirm non-empty HTML, JavaScript, WASM, and PCK files. Avoid repeated full validation after unrelated documentation edits.

## Git

Protect uncommitted work before synchronization. Use fast-forward pulls and never rewrite shared `main` history. Commits created by Manus must include the required Manus co-author trailer.
