# Preserved-gameplay optimization delivery

The approved implementation preserves the existing game: four players/factions,
the 80×80 map, all resources, units, structures, wildlife, objectives, commands,
UI/HUD, settings, tutorial, save formats, audio, artwork, and animation timing.
The earlier 1v1/content-removal plan is superseded by that constraint.

## Changes and measured results

Measurements use Godot 4.7.2, the existing official Web template, and the same
opening gameplay. The source reference is `eecf4a5`; the user's existing
`project.godot` edit is preserved and is not part of this implementation.

| Measurement | Before | After |
|---|---:|---:|
| Runtime Web files, identity bytes | 66.05 MiB | 50.65 MiB |
| PCK | 27.95 MiB | 12.54 MiB |
| Same runtime files over verified gzip | 37.32 MiB | 22.05 MiB |
| Same runtime files over verified Brotli | Not measured | 19.11 MiB |
| Imported CJK font | 13.78 MiB | 0.278 MiB |
| Median mean simulation tick, full first minute | 12.12 ms | 5.01 ms |
| Opening separation candidates per pass | 4,278 | 74 |

Web totals count the nine runtime files once. Delivery manifests and audit reports
are tooling metadata; gzip and Brotli are alternative responses, not extra game
downloads. HTTP values are measured response bodies from the local negotiated
server, not an assertion about a deployed host or actual browser cache behavior.
No production host was changed. The WASM is byte-identical to the previous build.

The CJK subset retains 1,759 glyphs, preserves all 828 supported required
codepoints, and keeps original outlines and horizontal/vertical metrics. The
native raster gate compares 827 visible characters at 12, 17, 24 and 48 px with
byte-identical output. Both 606-entry locale catalogs have identical shaped text
dimensions at ten sizes. The full original font remains available for authoring.

The PCK omits only the unused title texture, dormant forest texture, full CJK font,
and provenance/development files. All **119 retained imported textures/audio
resources are byte-identical** to the old PCK. All **121 source runtime image/audio
files remain unchanged** in the repository. There is no lossy re-encoding,
downscaling, replacement art, shorter music, or change to audio cues.

Spatial buckets reject distant separation pairs while preserving ID order,
floating-point accumulation, the narrow phase, and both passes. Visibility
signatures run at the original boundaries; unchanged masks are reused. Navigation
reuses friendly-footprint preparation only within the current path query.

The view caches immutable terrain projections, exact ordered wall signatures,
minimap paint commands, and fog generations. Animated water still uses the original
formula and cadence. Presentation skips already-settled timer work and removes
explicitly dead presentation records; death visuals remain in the existing
snapshot/effect systems. Ambiguous sprite picking still runs the complete original
tile-anchor fallback. UI layouts, HUD cadence, and input timing are unchanged.

## Affected architecture

```text
proto-rts/
├── .github/workflows/verify-release.yml    pinned maintainer verification
├── .gitignore                            local release/package/capture outputs
├── export_presets.cfg                    explicit unused/development exclusions
├── assets/runtime/fonts/                 subset, provenance, checksums
├── resources/manuscc0*_font.tres          same primary fonts; smaller CJK fallback
├── config/
│   ├── size-budgets.json                  identity/gzip/PCK/font and closure gates
│   └── package-profiles.json              editable/authoring membership
├── scripts/
│   ├── sim/{rts_simulation,spatial_grid}.gd
│   ├── ui/theme_factory.gd
│   └── view/
│       ├── battlefield.gd
│       ├── battlefield_minimap.gd
│       └── effects/presentation_state.gd
├── tests/
│   ├── runtime_{equivalence,performance}_test.gd
│   ├── support/runtime_reference.gd       frozen original algorithm oracle
│   ├── view_cache_test.gd                 draw-data/minimap/timer equivalence
│   ├── font_rendering_test.gd             native pixel comparison
│   ├── localization_test.gd              complete shaped-text comparison
│   ├── hud_test.gd                       isolated test-owned preferences
│   ├── release_pipeline_test.py          package/integrity/negotiation failures
│   └── *_visual_capture.gd               optional external capture destination
├── tools/
│   ├── process_assets.py + font_pipeline.py
│   ├── requirements-{assets,release}.txt
│   ├── benchmark_runtime.gd
│   ├── {audit_export,prepare_web_delivery,verify_web_delivery,serve_web}.py
│   ├── package_template.py
│   └── {export_web,run_tests,validate_template}.sh
├── docs/
│   ├── lean-implementation-plan.md        original proposal, superseded scope
│   ├── lean-delivery.md                   this implementation/runbook
│   └── performance/                      six-run data and reproduction notes
└── build/
    ├── web/                              existing tracked delivery refreshed
    ├── release/<build-id>/                complete local identity/gzip/Brotli set
    ├── packages/                         verified editable/authoring ZIPs
    └── verification/                     native captures and local logs
```

## Verification evidence

The registered suite contains 29 Godot tests plus the Python release pipeline
tests. It covers existing gameplay, fortifications, visibility, UI, input, tutorial,
localization, persistence, assets, effects, command behavior, and performance.
`economy_typography_test.gd` is now registered. The HUD test was corrected to use
its own tweak/tutorial files; it previously inherited the player's saved reduced
motion preference. Actual user preferences were preserved.

Six alternating original/candidate runs each simulate 60 seconds with the same
default AI. Entity/player/RNG/visibility hashes agree at 20, 40 and 60 seconds, and
the complete ordered event digest agrees in every run. Median mean tick cost is
58.6% lower. These are native CPU measurements on an Apple M5 Pro, not browser FPS.
See [performance/README.md](performance/README.md) and its raw JSON for scope and
reproduction. Focused oracle tests additionally cover mixed-unit separation,
ownership/tower visibility changes, navigation restoration, lifecycle semantics,
terrain at multiple camera/water states, minimap pixels, and presentation timers.

Native capture generators rendered 40 gameplay/UI/effect/fortification states and
nine Chinese states. Reviewed title, combat, portrait HUD, and Chinese gameplay
captures retain the existing composition and typography. The font raster test is
an exact pixel gate; dynamic full-screen captures are review evidence rather than
an assertion that separately timed screenshots have identical pixels.

The actual exported PCK boots using an empty external project directory. The
editable package imports and boots without the source masters, full CJK font,
`.godot`, or `.venv`, and passes locale/font coverage. Godot loads the configured
project font before its first import scan; the validator primes only its disposable
copy without that eager setting, restores exact project bytes, and requires a
normal error-free import and boot with the font enabled.

Identity, gzip, and Brotli responses are decoded and hash-checked for all nine
runtime files, including both audio worklets. The audit verifies PCK member hashes,
loader-declared sizes, required resources, forbidden resources, and size budgets.
Packaging verifies exact membership, duplicate/unsafe paths, embedded file hashes,
and authored ManusCC0 import policies. Forced pack shutdown and the existing
Chinese capture harness can report shutdown resource warnings; these are also
present in the unchanged baseline and are not a claim of a leak-free full match.

## Build and reproduce

Use Godot 4.7.2 with matching official Web export templates. Authoring dependencies
are pinned separately from release compression dependencies. Neither is needed to
play the editable package.

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements-assets.txt -r tools/requirements-release.txt
.venv/bin/python tools/process_assets.py --fonts-only
.venv/bin/python tools/process_assets.py --check-fonts
tools/run_tests.sh
tools/validate_template.sh

mkdir -p build/verification/native build/verification/chinese
RTS_CAPTURE_DIR="$PWD/build/verification/native" "$GODOT_BIN" --audio-driver Dummy --path . --script tests/visual_capture.gd
RTS_CAPTURE_DIR="$PWD/build/verification/chinese" "$GODOT_BIN" --audio-driver Dummy --path . --script tests/localization_visual_capture.gd
"$GODOT_BIN" --audio-driver Dummy --path . --script tests/font_rendering_test.gd

# Choose a new build-id each time; the exporter refuses an existing destination.
RTS_BUILD_ID="$(date -u +%Y%m%dT%H%M%SZ)"
PYTHON_BIN="$PWD/.venv/bin/python" BROTLI=1 tools/export_web.sh build/release/$RTS_BUILD_ID
.venv/bin/python tools/verify_web_delivery.py --local-directory build/release/$RTS_BUILD_ID \
  --manifest build/release/$RTS_BUILD_ID/delivery-manifest.json --encodings identity gzip br
python3 tools/package_template.py --profile editable --output build/packages/editable.zip
python3 tools/package_template.py --profile authoring --output build/packages/authoring.zip
```

Set `GODOT_BIN` to the executable on your machine. The shell tools default to the
macOS application path. Without `BROTLI=1`, export generates and verifies gzip
using Python's standard library; Brotli requires the pinned optional package.
`export-audit.json` records the resource inventory; `delivery-manifest.json`
records identity/encoding hashes, sizes, and source revision/dirty status.

For manual Web acceptance, run `python3 tools/serve_web.py build/release/$RTS_BUILD_ID`
and open the printed HTTP URL. Keep browser audio muted except during explicit
audio testing. The CLI delivery probe requires no browser and closes its temporary
server automatically. Actual browser startup/frame/memory measurements and live
host compression remain separate acceptance work.

## Packaging and publication

The editable ZIP embeds all runnable resources, the finished subset, source code,
tests, tools, notices, and provenance. The authoring ZIP also includes immutable
art/audio masters and the full font. Both omit generated outputs and local caches;
neither includes `.git`. ZIP timestamps and entry order are deterministic, and
`package-manifest.json` verifies every embedded file. The editable package does not
need to download anything before playing.

`assets.lock.json` remains untouched as upstream provenance. It is not relabeled
as a new CDN publication and does not prove remote master retrieval. The local
package manifest covers the new embedded font and every packaged file. Retain
existing masters and tracked builds/captures until any future archive publication
has independently verified retrieval; this change does not rewrite history or
switch catalog/hydration routes.

CI pins the official engine/template downloads by SHA-256, verifies dependencies,
runs the suite and clean package boot, captures native screens, exports and probes
delivery, and uploads revision-specific artifacts. Shared-runner timings are
reported; exact correctness and spatial-candidate gates remain enforced. No CI job
deploys or changes an existing host. A source push is not a live site deployment.

To publish later, upload a complete new release directory under a revisioned URL,
verify it using `verify_web_delivery.py`, then atomically change the entry pointer.
Keep old revision directories available for existing sessions and rollback. The
supplied local server uses correct original MIME types, negotiated encodings,
`Vary: Accept-Encoding`, and revalidation for stable filenames. Long-lived immutable
caching belongs only on immutable revisioned assets; configure the actual host
after its capabilities are known.

## Decisions on the remaining original proposals

| Original proposal | Preservation decision |
|---|---|
| B0, A1, A3/A4 | Implemented: measurements, exact font subset, unused exports, integration |
| A2, X1, X3 | Lossy images/audio and lower resolutions rejected by the preservation constraint; current imported bytes retained |
| R1 | Dead presentation records retire; authoritative dead records remain because existing entity lookups and mutable references require them |
| R2–R4 | Deterministic nearby pairs, same-boundary visibility, query-local navigation preparation implemented; speculative long-lived indexes omitted |
| R5 | Terrain/wall/minimap/fog/presentation caches implemented; no HUD throttling or stale pre/post-animation picking cache |
| R6 | Event defensive copies retained: callers mutate/read dictionaries; removing ownership boundaries is not a verified equivalent optimization |
| G1–G4, C1–C2, X4–X6 | Gameplay simplification, roster/map/economy cuts, save migrations, UI/debug/input/faction removals superseded by the user's constraint |
| D1–D3 | Release tooling, verified local compression, packages, gates, and CI implemented; live host cutover requires an identified host |
| X2 | Custom engine not adopted: official template is preserved; no browser compatibility/startup evidence justifies replacing it |
| X7 | Smaller packages and CI artifacts added; no history rewrite, destructive cleanup, or removal of accessible masters/builds |

Remaining opportunities are long-match profiling within the retained dictionary
contract, actual host compression/cache setup, and browser acceptance on target
hardware. None requires removing game content.
