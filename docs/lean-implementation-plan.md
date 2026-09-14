# Lean RTS implementation plan

Status: proposed implementation; no gameplay, asset, or release changes have been applied by this plan.

Planning baseline: `dcdbc4ebbbf9cebaeebbbb3f75194eac7d62d161`, 14 September 2026. Engine: Godot 4.7.2. Preserve the existing uncommitted `project.godot` edit. Reconfirm the current revision and measurements when implementation starts.

## 1. Intended outcome and scope

Deliver one compact, complete RTS: a 48×48, 1v1 skirmish with two spendable resources, three unit kinds, three building kinds, four selectable faction identities, fog, clear commands, and a complete title-to-result loop. Reduce exported bytes, simulation work, long-match accumulation, and maintenance burden. Preserve English/Chinese, mouse/keyboard/gamepad/touch, responsive layouts, original audio, bounded effects, accessibility settings, onboarding, and offline local standings.

Use the current simulation as the authority. First optimize the current content so performance changes can be measured independently. Then introduce a lean ruleset, validate it, and remove its unreachable legacy code and resources. Keep a verified versioned Classic release/source archive available; do not permanently carry two complete gameplay implementations in the lean release.

This is a standalone `proto-rts` project plan. Keep its existing lowercase `assets/` namespace. Manus catalog publication, shared guidance regeneration, and changes to Manus repositories are separate work. If later requested, use the actual Addon owner and its current packaging contract, never legacy Sandbox template paths. Preserve existing GameDev, catalog, enrollment, and setup access during every archive or release transition.

All numerical balance values, runtime goals, and effort ranges below are proposed targets. Audit measurements are identified separately. New static raster art, if genuinely needed after scope changes, uses GPT Image 2; reuse the game's existing art for this work where it remains accurate.

## 2. Baseline and acceptance budgets

Sizes are MiB. Count a release's raw files once; count one negotiated encoding per response when measuring transport. Do not add identity, gzip, and Brotli variants together and call that a download.

| Area | Audited baseline | Proposed acceptance target |
|---|---|---|
| Raw Web artifacts | 66.0 MiB | ≤49 MiB after the first asset pass; improve further after lean content pruning |
| PCK | 27.94 MiB | ≤10 MiB after the first asset pass; set a tighter measured budget after lean pruning |
| Compressed response bodies | ~37.3 MiB with local gzip level 9 | ≤20 MiB for a cold release load with verified host encoding |
| CJK imported font | 13.78 MiB | ≤0.5 MiB, with complete required glyph coverage |
| Current-content simulation | Mean 10.55→15.71 ms/tick; p95 12.73→19.48 ms over the first minute | Target ≥30% lower median-of-runs mean tick cost on the identical fixture; no material p95 regression |
| Separation work | 52–64% of opening tick cost; 8,556 candidate pairs/tick initially | Target ≥50% lower separation time and ≥80% fewer candidates in the sparse opening fixture; correctness takes precedence |
| Accumulated deaths | 1,000 synthetic dead units increased mean tick cost ~47% | Fixed live workload remains within 10% after repeated churn, with bounded retired/presentation records |
| Lean match structure | 80×80, four teams, four currencies, multiple objective systems | 48×48, two teams, two currencies, three unit/building kinds, one victory condition |
| Lean pacing | Not measured | First army ≤2 min, meaningful contact ~90–150 s, median match 8–12 min, typical completion <18 min |
| Display performance | Existing test covers only native `_draw()` | Proposed supported-browser floor: p95 whole frame ≤33.3 ms at max supported lean population; record machine/browser first |
| Editable package | Contains unnecessary local `.venv` in current validator copy | No `.git`, `.godot`, `.venv`, masters, builds, or captures; imports and plays without the authoring environment |

The asset audit measured non-overlapping substitutions: CJK subset **13.498 MiB**, retained opaque texture imports **2.716 MiB**, unused title/forest **1.758 MiB**, reports **0.152 MiB**, and optional transparent foreground/pause compression **0.912 MiB**. These project **47.89 MiB raw**, or **46.98 MiB** with the optional conversion. They are not a rebuilt or visually accepted release. Do not count later audio, engine, resolution, or gameplay cuts as already achieved savings.

A planning-time integrity check found **200/200 `assets.lock.json` entries present locally with matching SHA-256 and declared size**, with no mismatches or missing files. Remote retrieval/hydration was not tested. Archive cutover still requires independent remote hash verification; local manifest consistency alone cannot prove recoverability.

## 3. Affected architecture

`+` means proposed new file; `~` means existing owner to update. Create collaborators only when extracting their corresponding responsibility; this is not a mandate to build a framework first.

```text
proto-rts/
├── docs/
│   ├── lean-implementation-plan.md         + this plan
│   ├── lean-baseline.md                    + measured fixtures and budgets
│   └── lean-delivery.md                    + release/archive/runbook
├── .gitignore                             ~ selected import sidecars/artifacts
├── export_presets.cfg                      ~ exclusions and release settings
├── project.godot                           ~ build identity only as needed
├── README.md                               ~ final shipped behavior and commands
├── template.json                           ~ final accurate description
├── assets.lock.json                        ~ through verified asset tooling
├── assets/
│   ├── source/
│   │   ├── .gdignore                      preserve
│   │   └── fonts/NotoSansCJKsc-Regular.otf + unchanged full font master
│   ├── fonts/                             ~ preserve ManusCC0 and notices
│   └── runtime/
│       ├── fonts/NotoSansCJKsc-UI.otf       + generated subset
│       ├── fonts/{font-report.json,SHA256SUMS} + font provenance
│       ├── **/*.import                     ~ tracked selective policies
│       ├── asset-report.json               ~ generated image inventory
│       ├── SHA256SUMS                      ~ generated checksums
│       └── audio/                          ~ retained cue set / optional encoding
├── resources/manuscc0*_font.tres            ~ all three fallback resources
├── config/
│   ├── size-budgets.json                    + build/performance budget inputs
│   ├── asset-import-policy.json             + explicit category settings
│   ├── package-profiles.json                + Web/editable/archive membership
│   ├── tweaks/catalog.gd                    ~ lean owner-preview controls
│   └── engine/web_minimal.gdbuild            + conditional engine experiment
├── scripts/
│   ├── data/
│   │   ├── faction_catalog.gd               ~ shared stats/cost modifiers
│   │   ├── map_catalog.gd                   ~ scenario access / legacy removal
│   │   ├── match_rules.gd                   + immutable rules definition
│   │   └── scenarios/
│   │       ├── scenario_definition.gd       + map/roster validation
│   │       ├── full_v1.gd                   + temporary comparison fixture
│   │       └── lean_v1.gd                   + final compact scenario
│   ├── sim/
│   │   ├── rts_simulation.gd                ~ sole authoritative command facade
│   │   ├── entity_index.gd                  + live/team/kind collections
│   │   ├── spatial_index.gd                 + deterministic nearby queries
│   │   ├── visibility_system.gd             + change-driven visibility
│   │   ├── navigation_system.gd             + occupancy/path query ownership
│   │   ├── economy_system.gd                + pay/reserve/complete/refund
│   │   └── ai_controller.gd                 + one state record per AI team
│   ├── view/
│   │   ├── battlefield.gd                  ~ rendering/input integration
│   │   ├── battlefield_minimap.gd          ~ dirty overlays
│   │   ├── fog_mask_builder.gd             ~ scenario dimensions
│   │   ├── terrain_layer.gd                + cached static rendering
│   │   └── effects/presentation_state.gd   ~ sparse bounded records
│   ├── ui/
│   │   ├── theme_factory.gd                 ~ subset reference
│   │   ├── title_screen.gd                 + cohesive extraction
│   │   ├── match_hud.gd                    + lean economy/commands
│   │   ├── pause_settings.gd               + cohesive extraction
│   │   ├── result_screen.gd                + cohesive extraction
│   │   └── leaderboard_dialog.gd           ~ ruleset-aware local history
│   ├── tutorial/tutorial_director.gd        ~ lean steps and versioning
│   ├── services/                           ~ profile migration/local-only release
│   ├── tuning/tweak_service.gd              ~ allowlist/migration/release gate
│   └── main.gd                            ~ flow and ownership, slimmer screens
├── localization/{en-US,zh-CN}.json          ~ complete lean copy
├── tools/
│   ├── process_assets.py                   ~ single derivative entry point
│   ├── process_fonts.py                    + helper invoked by asset processor
│   ├── process_audio_assets.py             ~ optional quality experiment
│   ├── requirements-assets.txt             + pinned authoring dependencies
│   ├── audit_export.py                     + PCK/category/encoding inventory
│   ├── export_web.sh                       + deterministic staging export
│   ├── verify_web_delivery.py              + headers/hash/encoding probe
│   ├── package_template.py                 + editable/master packages
│   ├── validate_template.sh                ~ shared package contract
│   ├── run_tests.sh                        ~ register relevant new gates
│   └── build_web_engine.sh                 + conditional engine build
├── tests/
│   ├── existing gameplay/UI/asset suites    ~ preserve surviving invariants
│   ├── simulation_performance_test.gd       + active-match fixtures
│   ├── entity_lifecycle_test.gd             + bounded churn/reference cleanup
│   ├── spatial_index_test.gd                + reference-oracle comparison
│   ├── lean_rules_test.gd                   + economy/supply/scenario contracts
│   └── asset_pipeline_test.py               + clean regeneration/package checks
├── .github/workflows/verify-release.yml     + maintainer CI and artifacts
├── build/web/                              ~ generated release, later untracked
└── captures/                               ~ configurable artifact destination
```

## 4. Milestones, dependencies, and work order

| Milestone | Work packages | Depends on | Deliverable | Rough engineering effort |
|---|---|---|---|---|
| M0 — Establish evidence | B0 | — | Reproducible baseline and budget report | 1–2 days |
| M1 — Reduce payload | A1–A4 | B0 | Current gameplay with smaller resources | 3–5 days |
| M2 — Reduce runtime work | R1–R6 | B0 | Optimized current-content baseline | 5–9 days |
| M3 — Introduce scenario contract | G1 | M2 | Equivalent full fixture plus validated 1v1 setup | 2–4 days |
| M4 — Complete lean game | G2–G4 | G1; M1 integration | Playable lean rules, UI, saves, tutorial | 5–9 days |
| M5 — Remove legacy burden | C1–C2 | M4 acceptance | One lean runtime and explicit resource closure | 2–4 days |
| M6 — Package and release | D1–D3 | M1 for staging; M5 for final | Compressed release, editable archive, rollback | 2–4 days |
| M7 — Conditional improvements | X1–X3 | Measured M6 candidate | Accepted experiments or documented no-go | 2–6 additional days |

These are planning ranges, not calendar commitments. Core work is roughly **20–37 engineering days**, plus playtesting time; the upper end reflects migration and rendering risk. Asset and runtime work can run in parallel after B0. Delivery tooling can start against M1 while gameplay work proceeds. Serialize edits/integration in `rts_simulation.gd`, `battlefield.gd`, and `main.gd`; assign other lanes to disjoint files. Test and push small cohesive commits on existing `main`.

Dependency path:

```text
B0 ── A1–A4 ───────────────────────────────┐
 └── R1 → R2 → R3/R4 → R5/R6 → G1 → G2 → G3/G4 → C1/C2 → final D1–D3
             D1–D3 tooling can start from the M1 candidate ─┘
                                                   └── X1/X2/X3 if useful
```

### B0. Freeze a reproducible baseline

Files: `docs/lean-baseline.md`, `config/size-budgets.json`, `tools/audit_export.py`, `tests/simulation_performance_test.gd`, `tests/performance_test.gd`, `tools/run_tests.sh`.

1. Record current source revision, dirty-state fingerprint, Godot/template hashes, hardware, OS, rendering driver, and available browser versions. Preserve user changes before synchronization. Export the current source into a staging directory rather than overwriting tracked output.
2. Record PCK entries by original resource path, imported type, and byte count. Report WASM, PCK, scripts, fonts, textures, audio, JSON, raw totals, gzip, and Brotli separately. Treat missing/ambiguous source-to-import mappings as errors.
3. Create seeded fixtures: opening minute with ordinary AI; populated four-team combat; repeated build/destroy/path-block changes; 1,000-unit death churn with a fixed living population; extreme zoom, rapid pan, pause, and rematch. Record tick phases, view `_process`, draw, allocations, live/retired/presentation/effect counts, and setup time separately.
4. Warm up, run each timed fixture at least three times, and compare median aggregate timings plus p95. Keep the OS/load/compiler configuration consistent. Use Dummy audio for non-audio probes and isolated user-data paths.
5. Keep the unoptimized full-content fixture as a reference until M2 finishes. Later compare both optimized full content and lean content, so fewer animals cannot masquerade as a faster algorithm.
6. Register `tests/economy_typography_test.gd`; it exists but is absent from `tools/run_tests.sh`. Keep view draw checks, but label their scope accurately.

Exit: baseline reports reconcile with actual files, all fixtures are reproducible, and current failures are resolved or explicitly documented before attributing changes to optimization. Native headless timings are not browser FPS or visual evidence.

### A1. Generate and ship a CJK subset

Files: `tools/process_assets.py`, new `tools/process_fonts.py`, pinned asset requirements, `assets/source/fonts/`, `assets/runtime/fonts/`, all three `resources/manuscc0*_font.tres`, `scripts/ui/theme_factory.gd`, `tests/localization_test.gd`, pipeline tests.

1. Preserve the original full font byte-for-byte, with its license and hash, under the ignored source-master area. Retire the old importable full-font path only after fallback references have switched. The full font must not remain in an importable folder under `all_resources`.
2. Keep `tools/process_assets.py` as the public derivative-generation entry point. Its font helper scans both locales, production code/scenes, UI symbols, formatting characters, and declared dynamic input ranges. Sort the Unicode set and pin FontTools and generation settings. Never subset a previous subset.
3. Produce `NotoSansCJKsc-UI.otf`, a separate font report, and checksums. Record source hash, character-set hash, dependency versions, missing characters, and import policy. Do not label FontTools output as GPT-generated art.
4. Update every fallback, including ThemeFactory, project theme resources, dynamic dialogs, combat values, and error paths. Preserve ManusCC0 and the recent Web loading-notice styling. Ensure tests do not succeed through installed system CJK fonts.
5. Keep current ASCII callsign constraints. If future unbounded remote/user text is added, change the declared coverage contract first. Validate coverage through the actual fallback chain and report any pre-existing missing symbol rather than silently accepting it.

Exit: deterministic regeneration, complete required coverage, EN/CN layout review, subset present in PCK, and full-font imports absent. The editable package includes the finished subset and can play without FontTools or the full master.

### A2. Make image import settings reproducible

Files: `config/asset-import-policy.json`, `tools/process_assets.py`, `.gitignore`, selected runtime `.import` sidecars, asset reports/checksums, pipeline tests.

1. Define an explicit policy: Lossy quality 0.82 for retained opaque backgrounds, portraits, and terrain; lossless for units/buildings, cursors, command markers, and small icons. Avoid a global lossy default.
2. Persist policy in tracked text `.import` sidecars using narrow `.gitignore` exceptions. Preserve Godot UID/remap data. The processor stamps policy and validates it; fresh clone imports must not depend on the developer's local Import dock.
3. For a newly generated asset: derivative generation → initial Godot import → policy application → final import. Existing sidecars make ordinary clean imports straightforward. Treat importer settings and source pixels as different provenance fields.
4. Test the foreground/pause-frame conversion as a separate selectable quality change. Accept only after reviewing soft alpha, halos, compositor behavior, and text-safe backgrounds. Keep it lossless if quality worsens; the ≤49-MiB target already allows that.

Exit: fresh `.godot` import reproduces intended modes and size ranges; native title/faction/menu/gameplay review passes at normal/max zoom and both orientations. Existing alpha masks, anchoring, and cursor hotspots remain correct. Compression alone is not a VRAM optimization.

### A3. Remove proven unused exports

Files: processor mapping, `scripts/view/battlefield.gd`, `export_presets.cfg`, `tests/assets_test.gd`, source package manifest, asset reports.

1. Retire only the unused title derivative and dormant forest derivative from generation/runtime references. Keep immutable source masters. Remove the forest preload and corresponding unreachable presentation branches; verify terrain definitions cannot request it.
2. Replace fixed inventory assertions coherently: the initial 121 image/audio references become 119 (95 images + 24 audio), before later gameplay pruning. Validate fonts independently.
3. Exclude lock/provenance/image/audio/font reports from browser PCK, while retaining them in the editable package. Preserve both localization JSON files and required notices. Do not blanket-exclude all JSON.
4. Keep `all_resources` with targeted exclusions initially. Generate explicit profile membership for later lean cleanup; account for faction art paths, cue registries, and other dynamic loads. A scene-only dependency scan is insufficient.
5. Prune only explicitly managed retired derivatives. Add a dry-run inventory and reject paths outside the managed runtime root; do not delete arbitrary source or user assets.

Exit: forbidden entries are absent from the actual PCK, resource closure is complete, and the source metadata/restore contract remains intact. Regenerate reports rather than hand-editing them.

### A4. Integrate the first asset release

Export current gameplay once after A1–A3; run the required native font/art checks, clean-source package boot, actual exported-pack boot, and size audit. Compare to B0 and record accepted settings. This candidate is independently useful before any gameplay cuts. Preserve the current engine, audio arrangement, and supported inputs.

### R1. Centralize entity lifecycle and live indexes

Files: `scripts/sim/rts_simulation.gd`, new `entity_index.gd`, `scripts/view/effects/presentation_state.gd`, lifecycle/simulation/command/effect tests.

1. Maintain canonical live IDs indexed by category/team/kind. Route spawn, normal death, resource depletion, resignation, cave ownership transfer, egg hatch, and reset through lifecycle helpers. Audit direct `alive` and `team` writes; indexes must not diverge from authority.
2. Capture necessary immutable event/death/score data before retiring an entity. Remove it from hot collections immediately at the appropriate tick boundary. Clean queued targets, builders, garrisons, guardian IDs, selection, and other references with explicit behavior for missing IDs.
3. Use monotonic IDs within a run. Keep only minimal bounded tombstones if a real consumer requires them; do not retain whole dead dictionaries indefinitely or invent replay storage. A proposed maximum is 256 tombstones, with queue activation treating expired IDs as invalid.
4. Make presentation records sparse: active health/selection/hit/movement transitions only; dead visual lifetime belongs to existing bounded death snapshots. Clear run-owned caches on rematch.

Exit: surviving gameplay invariants pass; repeated churn reaches a bounded record/memory plateau at fixed live population; no stale command resurrects or rewards a removed actor. Profile tests must release their own references before measuring memory.

### R2. Replace full pairwise separation with neighboring buckets

Files: `spatial_index.gd`, separation/target queries in simulation, spatial/reference tests and active-match benchmark.

1. Bucket live movable actors by world position using a cell size derived from the interaction radius. Query neighboring buckets, emit each ordered `(min_id, max_id)` pair once, and process pairs in stable ID order.
2. Preserve both current separation passes and all overlap/garrison/relationship tests. Rebuild or update buckets for the second pass after displacement. Do not query only the viewport: off-screen gameplay remains authoritative.
3. Retain a small brute-force reference in test fixtures. Compare candidate completeness and local resulting displacement for boundaries, coincident actors, sparse actors, dense crowds, negative/edge coordinates, and both passes.
4. Reuse the index for nearest-enemy/local hunting queries only after separation is correct. Preserve distance and ID tie-breaking, fog eligibility, and ranges. Dense crowds may still approach quadratic work; document worst-case behavior.

Exit: identical local oracle behavior within declared floating-point tolerance, stable repeated runs, no corner/formation regressions, and measured sparse-scene candidate/time reduction. Do not promise bit-identical long simulations across platforms solely because ordering is stable.

### R3. Update visibility only when authoritative inputs change

Files: `visibility_system.gd`, simulation visibility APIs, Battlefield, minimap, visibility tests.

1. Define each emitter signature using floored world center, footprint, sight radius, team, alive/garrison state, and applicable map/rule revision. Dirty on spawn, movement across the relevant cell boundary, death, ownership/radius changes, setup, and reset.
2. Preserve 30-Hz command-visibility semantics and tick order. Initially recompute only dirty teams with reusable buffers; add contribution-count masks only if profiling justifies them. Explored cells remain persistent per team.
3. Expose a visibility revision and read-only snapshot contract. Avoid copying and comparing full dictionaries every 0.1 seconds when revision is unchanged.
4. Invalidate fog texture/minimap overlays on visibility or map changes. Preserve fog privacy for targeting, enemy information, effects, and audio; never substitute screen visibility for command authority.

Exit: dirty implementation matches a full recomputation oracle after each tested mutation, including ownership changes, map edges, camera motion, and rematches. No stale vision appears when the camera revisits an area.

### R4. Reduce repeated path/occupancy work

Files: `navigation_system.gd`, simulation placement/movement functions, map/command/fortification tests while those mechanics remain.

1. Extract navigation behind the existing command facade. Maintain cached static occupancy and per-team pass-through sets keyed by topology revision. Batch safe invalidations at deterministic mutation boundaries.
2. Initially cache occupancy/query preparation rather than entire paths. A whole-path cache is conditional: key by topology revision, team, start, goal, footprint, movement mode, carrier state, and dynamic avoidance revision; bound entries and reset between matches.
3. Preserve current friendly-pass-through, carrier restrictions, diagonal no-corner-cut rules, and dragon avoidance for M2 comparison. Remove obsolete variants only during lean scope cleanup.
4. Never leave temporarily relaxed A* cells visible to another query. Use owned query state or a guaranteed restore boundary. Do not reduce path retries without testing accepted-but-unreachable orders.

Exit: reference paths remain legal; construction/resource death invalidates cached preparation; repeated orders do not receive another team's permissions. Run relevant registered command, projection, simulation, and fortification suites.

### R5. Cache static presentation and eliminate redundant picking/HUD work

Files: Battlefield, new `terrain_layer.gd`, minimap, `presentation_state.gd`, HUD owner, view/interaction/projection tests and native captures.

1. Separate static terrain from animated water/entities/effects. Cache world-space geometry or bounded terrain chunks; use camera transforms and visible bounds rather than rebuilding the whole terrain each redraw. Avoid a giant map render texture that trades CPU for excessive GPU memory.
2. Rebuild wall/gate connectivity only on relevant placement, destruction, ownership, orientation, or map revisions during the full-content phase. Remove that machinery later if no lean consumer remains.
3. Cache pointer hit testing only while pointer, camera, viewport, fog, entity positions, and rendered silhouette transforms are unchanged. Broad-phase screen/world bounds must still allow alpha-mask picking and stable overlap priority. Animated bounce/sway can invalidate a hit even under a stationary pointer.
4. Reuse the existing alpha/content/ground caches and minimap terrain image; they already exist. Update dynamic minimap images and fog only when dirty. Redraw the camera rectangle separately from unchanged map layers.
5. Update HUD sections when their values/selection/order data change; update displayed seconds at 1 Hz. Keep responsiveness to commands immediate and all pause/focus behavior intact.
6. Restrict presentation residency to visible actors plus a small margin when profiling supports it. Off-screen simulation, economy, pathing, and deaths continue. Re-entry must derive current facing/health/state without replaying old effects in a burst.

Exit: measured `_process`, draw, upload, and allocation reductions; native captures show correct grounding/facing/occlusion, fog, alpha picking, and camera edges. Existing effects/voice limits remain bounded.

### R6. Simplify event handoff and consolidate runtime acceptance

Files: simulation `drain_events`, Battlefield event routing, effect/audio/tutorial consumers, event tests.

Swap the pending event array into a consumer-owned batch instead of deep-copying it repeatedly. Define event records as immutable after emission. If presentation adds `attack_family` or another derived field, create one local decorated record without mutating data observed by other subscribers. Preserve one drain owner, event order, fog filtering, terminal boundaries, and independent audio delivery.

Run B0 fixtures with unchanged full content after R1–R5, record each phase's cost, and accept or revert individual optimizations based on correctness and measured benefit. Keep this report before gameplay reductions change the workload.

### G1. Introduce an explicit scenario/rules contract

Files: new `match_rules.gd`, scenario definitions, map/faction catalogs, simulation, Battlefield/minimap/fog, `main.gd`, map/boot/projection tests.

1. Define immutable match data: `ruleset_id`, `ruleset_version`, scenario ID, dimensions/terrain, starts/roster, allowed resources/units/buildings/commands, economy/supply data, AI profile, objective, and score version.
2. Inject scenario data into the simulation and its observers. Replace assumptions based on four teams, four starts, static `MapCatalog.SIZE`, den counts, and extra-AI timer dictionaries. Validate shape, coordinates, team IDs, reachable spawns/resources, and a possible terminal outcome.
3. Use one AI state record per participating AI team. Preserve the old full fixture as the temporary default and verify equivalent commands, spawning, results, and rematch reset before changing rules.
4. Initialize a two-player fixture and a second synthetic map in the same process to prove there is no shared global map/cache contamination. No campaign or user-facing scenario browser is required.

Exit: full behavior still passes; roster/map variation is data-driven; invalid definitions fail back to a usable localized screen rather than starting an unwinnable match.

### G2. Implement the lean economy, map, combat roster, and AI

The following is the proposed initial balance sheet, not a claim of balanced play.

| System | Lean v1 contract |
|---|---|
| Map | 24×24 authored macro grid at 2× scale = 48×48 gameplay cells; mirrored bases, open center, two useful flanks |
| Starting state | One Stronghold and three Workers per team; 320 Jade and 120 Lumber |
| Spendable currencies | Jade and Lumber only; remove Food/Essence balances, costs, cargo, payouts, and score entries |
| Actors | Worker, Vanguard (melee), Mystic (ranged); reuse current art and IDs |
| Worker | 55 Jade; 6 s train time; 1 supply |
| Vanguard | 75 Jade; 7.5 s; 2 supply |
| Mystic | 50 Jade + 35 Lumber; 10 s; 2 supply |
| Buildings | Stronghold; War Camp (150 Jade + 80 Lumber); Supply Farm (60 Lumber) |
| Supply | Stronghold 12 capacity; each completed living Farm +6; hard ceiling 24. Supply is capacity, never currency |
| Farm role | Reuse `rice_farm` ID/art initially; no staffing, stored Food, harvest timer, or production cycle |
| Existing combat/gather values | Preserve initial HP/damage/range/speed and gather/carry timings while evaluating the new economy; adjust deliberately afterward |
| Victory | Destroy the opposing Stronghold; own Stronghold loss or resignation is defeat; no den, egg, time, or score victory |
| Content | Starting budget: six mirrored Jade deposits and about 64 Lumber trees; no wildlife, guardians, dragon, or egg |

Files: match/scenario/faction definitions, simulation/economy/AI owners, HUD, `tests/lean_rules_test.gd`, existing map/command/simulation tests.

Implementation order:

1. Author and validate the mirrored map, base exit clearance, resources, and both flanks. Equal distance/opportunity matters more than an attractive overhead silhouette. Test dense base construction and depleted resources.
2. Make all payment/refund logic iterate the allowed currency list. Store actual paid costs in queued orders so faction discounts refund correctly. Use ceiling for positive discounted costs, preserve zero costs as zero, and clamp invalid input before payment. Apply the same resolver to AI, HUD, queues, and cancellation.
3. Define supply as `live_used`, `reserved`, and `capacity`. Enqueue only when `live_used + reserved + cost <= capacity`. Completion transfers reserved supply to live usage; cancellation releases reservations. On farm loss, preserve existing units and paid reservations, allow already-reserved units to complete, and reject new orders until capacity recovers. Thus temporary oversupply is explicit and does not delete units or confiscate purchases. Hard ceiling 24 applies to available capacity and enqueue admission; grandfathered orders are bounded by previously admitted supply.
4. Farm capacity appears on completion and disappears exactly once on destruction. Additional farms beyond the two needed to reach 24 are rejected with a localized capacity-limit message in lean v1; count living foundations toward the two-farm limit to prevent concurrent-placement bypass. Preserve the current eight-second base construction rule initially. Construction cancellation and recovery remain defined.
5. Retain the free recovery Worker when no living or queued Worker exists. Normal supply validation still applies; test loss of the last worker before/after supply destruction and exhausted Jade. Never create an AI-only free-economy exception.
6. Use ordinary structure occupancy. Remove lean rotation, wall/gate special cases, and friendly-building phasing. Placement must leave a traversable base exit and access to at least one remaining gather target when such a target exists; test spawn/rally connectivity so the player cannot accidentally create an unrecoverable economy. Do not reject every construction merely because all finite deposits have already been exhausted.
7. Retain selection, formations, move, attack-move, contextual gather/build/repair, Stop, rally, queued commands, cancellation, and control groups. Exclude patrol and demolition from the initial lean command surface unless a concrete recovery use remains; construction cancellation stays. Simulation rejects retired commands even if called without the HUD.
8. Give each faction one data-defined cost modifier: proposed Celestial −10% Mystic Jade, Demon −10% Vanguard Jade, Beast −10% Worker Jade, Human −10% building Lumber. Remove procedural faction healing, kill income, farming/hunting permissions, and speed/range exceptions. Test rounding and actual paid refunds for every faction.
9. Simplify AI to gathering/recovering workers, one-second strategy decisions, a six-worker target, Camp construction, supply planning, mixed production, nearby defense, and attack-move toward the known enemy start. First committed assault target is ~90 seconds only with a viable army. Target acquisition still respects fog; no hidden-resource stipend or remote entity knowledge.

Exit: exact lean roster/currency/building counts; valid mirrored starts; no retired actors spawn; normal victories/defeats/retries work for all factions; queues/refunds/supply losses/recovery have explicit, tested outcomes.

### G3. Simplify screens, command modes, tutorial, and score

Files: `main.gd`, cohesive UI extractions, Battlefield command state, tutorial director, localization files, HUD/input/tutorial/localization/economy typography tests.

1. Extract title, match HUD, pause/settings, and result responsibilities while keeping one application state/pause owner. Replace mutually exclusive armed booleans with one command mode plus payload. Preserve focus, Escape/cancel, Shift queueing, touch/gamepad equivalence, and modal input capture. WASD remains camera movement only.
2. Show Jade, Lumber, Supply, time, selection, and the small contextual command set. Remove retired resource chips, farm-income timers, den counters, egg UI, garrison slots, fortification rotation, and unsupported faction explanations. Resolve mixed-selection command-card collisions explicitly.
3. Use short opening guidance: gather, build Camp, train, increase supply, defeat enemy Stronghold. Keep one terminal objective. Supply Farm copy must describe capacity rather than Food.
4. Make tutorial steps state-backed and event-driven: select → gather → Camp → train → attack, with contextual pause guidance. An already-completed action must satisfy a later step. Keep visible localized Skip at every step, replay, timeouts, input hints, exact pause restoration, and no developer-control content.
5. Version tutorial completion by ruleset/content. Existing full-game completion cannot suppress lean onboarding.
6. Define lean score version 1 from enemy combat/destruction plus victory/time achievement. Exclude gathering, building, training, repair, and resource-payout score farming. Put weights in match data; an initial recipe is 25 per enemy Worker, 50 per military unit, 100 per War Camp, 50 per Farm, 500 per Stronghold, 1,000 per victory, and a victory-only `max(0, 600 - floor(elapsed_seconds))` time bonus. These are provisional. Count each death and terminal result once; no self-destruction/resignation kill credit.

Exit: no stale rules or raw localization keys in either language; every supported input can finish the tutorial and match; tutorial pre-completion and Skip never trap play; score deterministically finalizes once and cannot be farmed through reversible economy actions.

### G4. Migrate local history and settings safely

Files: leaderboard store/dialog, optional bridge, tutorial director, tweak service/catalog, migration/local persistence tests.

1. Add `user://mandate_of_myth_profile_v2.json`. On first use, read the old v1 primary or backup without changing either. Do not merely increment `SCHEMA_VERSION`: the current loader would treat old data as invalid and save a fresh profile.
2. Preserve callsign, anonymous identity, legacy aggregates, and bounded run history under an archived `full_v1` partition. Start a separate `lean_v1` standings partition with `ruleset_id`, ruleset version, scenario ID, score version, and integrity marker on every new run.
3. Show lean standings by default and keep old results available as history. Do not fabricate reconstructed historical aggregates from the last 30 rows. Write atomically with backups and idempotent migration markers; retries after partial writes must not duplicate history.
4. Preserve locale, music/mute, accessibility, and presentation preferences. Import only still-supported developer deltas into the matching ruleset; archive unknown/retired ones. Release builds ignore persisted gameplay overrides.
5. Keep lean standings offline/local. Exclude the disconnected global host adapter/tab from release reachability; do not submit a new score model through a v1 full-game protocol. A future global feature requires its own complete opt-in integration.
6. No active-match conversion is necessary: the current game does not persist resumable match state. Rollback uses the untouched legacy save path; new lean records remain separately recoverable.

Exit: old primary/backup files stay byte-identical, identities and old aggregates survive, repeated migration is idempotent, new/old rankings never mix, malformed v2 data recovers safely, and normal player settings remain usable offline.

### C1. Remove unreachable legacy systems and trim maintainability costs

Files: simulation/data/view/effect/audio/UI owners, temporary scenario fixture, localization, asset membership, README, template metadata, affected tests.

1. After the lean slice passes, make lean the only normal release ruleset. Remove temporary full-v1 runtime selection/definitions and dead branches from production; preserve the verified Classic source/build externally by revision.
2. Retire hunting, wildlife retaliation/regeneration, Hunters/Lodge, dens/guardians/Jadeclaw, dragon/egg escort/hatch, garrisons, walls/gates/towers, Stronghold upgrades, legacy pass-through/avoidance, four-player-specific logic, retired commands, and obsolete faction passives.
3. Remove their corresponding runtime preloads, cues, shader branches, cursor modes, icons, art inventory entries, localization, and unsupported tweak descriptors only after tracing consumers. Preserve generic selection/combat/death cues shared by retained actions and all original master assets.
4. Keep cohesive simulation collaborators behind the command facade. Avoid a new ECS/plugin framework or separate full/lean simulation. File splitting is maintenance work; do not report it as a download saving.
5. Replace obsolete test expectations with surviving invariants and lean contracts. Keep historical full-mode tests with the Classic source revision rather than importing broken legacy classes into the lean project. The common regression runner must have no unregistered required tests or stale script paths.
6. Update the standalone README and template description only after implementation matches them. Preserve template ID, genre, and actual static capability metadata. Do not edit generated Manus outputs from this project.

Exit: full-mode-only actors/commands/resources are absent from release reachability and PCK; the normal code path is lean; previous Classic artifacts remain retrievable; every surviving advertised feature works.

### C2. Finalize development controls and bounded presentation

Files: tweak catalog/service/panel, main/UI factories, audio/effect catalogs, tests and release membership.

Regenerate the lean tweak descriptors after gameplay, assets, copy, and baseline balance are final. Preserve all six existing categories with relevant controls, supported application boundaries, validated deltas, reset, and sticky run-integrity taint. Keep the owner-preview launcher and shortcuts behind an explicit build gate, with their existing safe-area/input behavior. Release omits access to developer controls and ignores saved gameplay tweaks; ordinary audio/display/accessibility settings remain available.

Keep bounded audio voices, effects, death snapshots, and reduced-motion settings. Remove only orphaned presentation families. Validate no late event or rematch duplicates music, subscribers, transient actors, or cursor state.

Exit: owner-preview tuning works, release control access is absent, persisted debug data cannot affect release gameplay, and all pool/cache counts remain bounded under repeated runs.

### D1. Export compressed, versioned artifacts and verify delivery

Files: `tools/export_web.sh`, `audit_export.py`, `verify_web_delivery.py`, export presets, package/budget config, delivery runbook, actual host configuration once identified.

1. Export to a clean staging directory with pinned Godot and release identity. Confirm nonempty HTML, JS, WASM, PCK, icons/worklets and required licenses. Boot the exported pack independently of source-tree resources.
2. Generate deterministic gzip/Brotli sidecars and a manifest of original/encoded hashes and sizes. Preserve original Godot loader metadata; never hand-edit generated JS to pretend compressed bytes are uncompressed bytes.
3. Identify the real host before adding provider configuration. Serve correct original MIME types, particularly `application/wasm`; negotiate `Content-Encoding`, `Vary: Accept-Encoding`, accurate encoded lengths, and identity fallback. Avoid double compression.
4. Put artifacts under immutable revisioned URLs with long-lived caching. Make stable entry HTML/pointers revalidate. Upload the entire release, verify it, then switch the pointer atomically. Keep old complete releases for open sessions and rollback. Do not add a service worker or PWA cache in this effort.
5. Probe identity/gzip/Brotli responses with an HTTP tool: decompress and compare original hashes; verify compression for `.pck`, `.wasm`, JS, and worklets. Report cold/warm transferred bytes distinctly.

Exit: no missing/mixed-version resources, encoding/hash checks pass, expected raw/PCK budgets pass, and measured cold response bodies meet the transfer target. If the host cannot negotiate compression, retain the working host while preparing a compatible delivery option; do not report local gzip size as actual user transfer.

### D2. Separate Web, editable, and source-master packages

Files: `package-profiles.json`, `tools/package_template.py`, `validate_template.sh`, asset manifest tooling, `.gitignore`, capture scripts and documentation links.

1. Build a Web package containing only runnable artifacts/notices/delivery metadata; an editable package containing project/runtime media/subset font/scripts/config/docs/tools/tests/provenance; and a source-master archive with immutable full art/audio/fonts and reproducible recipes/dependency versions.
2. Make validator assembly use the same membership rules. Exclude `.venv`, `__pycache__`, `.git`, `.godot`, temporary outputs, captures, and Web builds from the editable package. Retain text import sidecars, localization, licenses, test/tool executable permissions, and `assets.lock.json`.
3. Before removing local tracked media or switching hydration, verify every manifest local path, declared size/hash, and archive/CDN retrieval. Resolve existing mismatches through the actual publisher/hydration contract; do not claim a byte-changing remote conversion is lossless restoration. Keep a self-contained editable package as the reliable first delivery.
4. Verify archive + editable package can regenerate runtime derivatives. A missing source archive should block regeneration, not ordinary game boot. Preserve source availability until independent retrieval and regeneration succeed.
5. Publish future Web builds/captures as revision-linked release artifacts. Update README images and capture-script output destinations before removing their tracked copies. Remove generated artifacts from Git tracking only after the replacement artifact is complete and reachable; keep user-local output available.
6. Publish archives without disabling catalog/setup routes or removing prior asset versions. Use resumable/hash-verified installs and retain completed media on retry. Never force a game boot to wait for authoring masters.

Exit: clean editable package boots with no private paths or author cache; all runtime media resolves; full regeneration from archived masters is proven; old access remains available. Repository reduction does not equal browser savings.

### D3. Add maintainer CI and finish release acceptance

Files: `.github/workflows/verify-release.yml`, test runner, package/export tools, runbooks, baseline reports.

CI uses pinned Godot/export templates and pinned authoring dependencies. Correctness, glyph coverage, clean import, export resource closure, and size checks are merge/release gates. Native timing comparisons run on a controlled host; noisy shared-runner performance is reported rather than treated as a precise universal threshold. Store manifests, timings, native captures, and candidate artifacts by revision.

Use repository maintainer CI to collect integrated browser download/startup/frame/memory evidence where available. The ordinary game implementation handoff remains focused native checks, current exported-pack checks, and a playable candidate for user Web acceptance; do not add a repetitive agent-driven browser self-test. Record pending browser acceptance honestly. Any opened browser tab is muted, temporarily unmuted only for explicit audio verification, then muted and closed.

Commit and push tested source/documentation changes to existing personal-project `main`. Fetch before synchronization, use fast-forward updates, stage only owned changes, and preserve the user's edit. Never force-push or rewrite shared history. No new branch is required; if one later becomes necessary, fetch and base it on the latest verified `origin/main`, never a deployment branch.

## 5. Conditional proposals and decision rules

These cover the remaining audit suggestions. Evaluate them; do not stack incompatible product variants or perform optimizations without a measured benefit.

| ID | Proposal | Implementation and acceptance rule |
|---|---|---|
| X1 | Lower audio payload | Through `process_audio_assets.py`, compare lower Vorbis quality and mono for appropriate SFX. Keep the 141.66-s composition/cue timing initially. Require ≥0.5 MiB combined saving with clean loop/onsets/levels and full semantic coverage. Preserve original masters and exactly one BGM. Record the accepted cue set; do not count speculative savings. |
| X2 | Custom 2D Godot Web engine | Add pinned build profile/script, remove proven unused 3D/physics/modules incrementally, compare against official 4.7.2. Preserve GDScript, AStarGrid2D, actual GUI controls, regex, advanced text/CJK, PNG/WebP/Ogg/Vorbis and used Web bridges. Require ≥10% compressed WASM reduction without meaningful startup/frame regression. Retain official templates as rollback. Do not blanket-disable advanced GUI or text support. |
| X3 | Reduce decoded texture memory | Only if memory profiling remains problematic: compare smaller terrain/background derivatives or bounded chunk residency. Halving width/height cuts pixels by 75%, but measure actual PCK/VRAM/time. Preserve max-zoom clarity, source anchors, masks and UI legibility. Use the asset processor and native visual gate. |
| X4 | Keep hunting with only ~24 wildlife | Alternative stop point if the full game's hunting is retained. Reduce herds/types and rebalance food supply, bounty, regeneration and AI together. Skip for the final zero-wildlife lean design; do not spend time balancing content scheduled for removal. |
| X5 | Automatic towers; one neutral objective | Alternative if a later playtest specifically needs fortification/objective depth. Replace garrison complexity with autonomous towers, or retain den capture or egg escort, never both by default. The proposed three-building lean game removes these entirely. A failed playtest does not automatically justify restoring every legacy system. |
| X6 | Fewer factions / desktop-only input | No default cut: faction logic becomes one cost modifier, and input/localization are valuable template capabilities. Evaluate only if a later explicit product scope chooses it; measure actual bytes before removing art/input support. |
| X7 | Git storage maintenance | Prefer artifact distribution, source packages, shallow consumer clones, and normal safe Git packing. Measure before/after. Do not prescribe `prune --expire=now`, aggressive concurrent GC, history rewriting, or LFS migration as a prerequisite. Existing history will not disappear when current files become untracked. |

## 6. Verification matrix and release gates

| Change | Required meaningful checks |
|---|---|
| Font/import/export | Clean import without cached resources; actual fallback glyph coverage; PCK subset/full-font assertions; deterministic processor check; EN/CN native screen review; nonempty release artifacts |
| Lifecycle/events | Spawn/death/depletion/resign/capture/hatch/reset; stale orders; single reward/result; subscriber immutability; fixed-live-population churn |
| Spatial/navigation | Brute-force neighbor oracle; dense/sparse cells; overlap tie handling; topology mutation; no corner cutting; route permissions; formation/rally/placement |
| Visibility/view | Full-recompute visibility oracle; hidden target/event privacy; camera pan/zoom and map changes; stationary-pointer moving sprites; fog/minimap invalidation; native grounding/facing/occlusion |
| Lean game | Two teams/currencies; three units/buildings; supplies/reservations/refunds; all modifiers; reachable economy; recovery; one terminal outcome; retired API rejection; repeated rematches |
| UI/tutorial/input | EN→CN→EN retention; portrait/landscape; long counters; mixed selection; modal focus; all supported inputs; every Skip step; already-completed actions; no tuning in tutorial |
| Saves/tweaks | v1 primary/backup preservation; v2 migration retry/recovery; separate ruleset scores; no old global submission; settings preservation; debug override rejection in release |
| Delivery/archive | Correct encodings/MIME/cache headers; decoded hash equality; atomic version switch; old open sessions; editable boot; master restore/regeneration; no private-cache dependency |

Run `tools/run_tests.sh` for simulation/projection changes as required by the repository; register the new focused suites there. Run each cohesive UI/art batch through the native visual harness once, inspecting relevant captures. The current capture scripts write tracked paths: add configurable destinations before CI artifact migration. A documentation-only plan requires reference checks and `git diff --check`, not engine boot or regenerated media.

Before final lean release:

1. Pass the complete applicable registered regression suite on final source, plus the actual exported-pack/resource and size checks. A success exit with Godot parse/load errors is a failure.
2. Compare B0 full-content measurements to the accepted R6 full-content measurements, then separately report final lean results. If a repeat is needed after legacy pruning, run the pinned archived comparison build; do not restore retired mechanics into production just to preserve the old workload. Run bounded max-population combat, repeated churn/rematch, and camera stress. Do not use empty-map FPS as evidence.
3. Play the 12 distinct ordered faction matchups with mirrored starts (24 scenarios); add same-faction mirror checks. Start with a small fixed seed set and expand only on imbalance or failure. Record win/defeat time, economy stalls, unit mixes, first contact, army navigation, and supply recovery. Test Worker rush and mass-ranged strategies deliberately.
4. Inspect title/HUD/pause/settings/tutorial/results/local-history screens in both languages at 1280×720 and the currently supported portrait/compact layouts. Check grounding/facing sequences for every retained moving type, water/terrain seams, selection masks, font coverage, and effects saturation.
5. Verify owner-preview controls, release exclusion, ordinary settings, music loop/unlock, SFX coverage, pause/retry cleanup, and storage-unavailable behavior. Keep audio muted except during its verification.
6. Publish a complete candidate with revision/manifest, preserve prior release, verify delivery, and collect user Web acceptance for sustained play, input, sound, locale, and persistence. Only then label Web acceptance complete.

## 7. Rollout and recovery

Deliver M1 and M2 as independently testable improvements before switching gameplay. Prepare an immutable Classic source/build archive with hashes and retrieval evidence. Switch the normal candidate to lean only after the lean loop, migration, and package are complete. Remove legacy production code after that decision is validated, retaining historical artifacts rather than dormant implementation copies.

For a broken candidate, point new sessions back to the last complete release and keep all old versioned assets reachable. Existing sessions continue loading their original version. The new profile path preserves old saves for rollback; never downgrade-write a v2 profile into the legacy path. Failed archive or hydration verification leaves existing media and access in place. Neither pushing source nor uploading an archive is proof of a deployed, playable game.

## 8. Proposal coverage and recommended first work

| Audit recommendation | Plan coverage |
|---|---|
| Font subsetting and coverage | A1 |
| WebP reimport inflation and alpha-image option | A2 |
| Unused title, dormant forest, provenance payload | A3 |
| Compression, caching, actual transfer measurement | D1 |
| Engine/audio/resolution experiments | X1–X3 |
| Live indexes, dead retention, sparse presentation | R1 |
| Spatial separation and local target queries | R2 |
| Dirty visibility, fog/minimap | R3, R5 |
| Navigation occupancy/query caching | R4 |
| Static terrain, wall lookup, picking, HUD | R5 |
| Repeated event copies | R6 |
| Simulation/UI modularity, per-team AI, command mode | G1, G3, C1 |
| Compact map/roster and two-resource economy | G2 |
| Wildlife, hunting, garrison, fortification and objective cuts | G2, C1; alternatives X4–X5 |
| Tutorial, localization, scores/settings compatibility | G3–G4 |
| Debug/optional services | G4, C2 |
| Build/capture history and smaller editable package | D2, X7 |
| Active-match/browser/performance evidence | B0, D3, verification matrix |

Begin with **B0 + A1**, then **A2/A3** alongside **R1/R2**. The three next implementation batches are: smaller reproducible payload; faster bounded simulation; complete lean ruleset and migration. Detailed steps are proposals until implemented and verified.

Technical references: [Godot image compression](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html#compress-mode), [Godot Web serving](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#serving-the-files), [Godot build-size optimization](https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html), [FontTools subsetting](https://fonttools.readthedocs.io/en/latest/subset/index.html). Check compile/import flags against pinned 4.7.2 before execution; current online stable documentation can move independently of this project.
