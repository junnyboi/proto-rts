# Jade Command Altar HUD — Implementation Plan

**Status:** Implemented and verified

**Target:** Godot 4.7.2, desktop browser viewport 1280×720

**Source concept:** [`HUD_REVAMP_CONCEPT_PROPOSAL.md`](HUD_REVAMP_CONCEPT_PROPOSAL.md)

## Outcome

Replace the existing text-led match overlay with the production-ready **Jade Command Altar** HUD while preserving all gameplay behavior and the simulation/view boundary.

The completed HUD will provide:

- An icon-led economy ribbon with Jade, Lumber, Essence, Food income, population, den control, time, and pause.
- A collapsible three-step objective tracker.
- A bottom command altar containing a larger minimap, compact map utilities, illustrated selection state, global production queue, and invariant command slots.
- Visual states for no selection, one unit, mixed units, structures, resources, wildlife, neutral/contested/owned dens, production, placement, repair, patrol, attack-move, pause, victory, and defeat.
- Tiered feedback toasts that do not compete with selection information.
- Responsive behavior at the supported logical viewport and larger desktop windows.
- Keyboard focus, redundant state communication, readable disabled controls, and tooltips.

## Architectural contract

`scripts/sim/rts_simulation.gd` remains the only owner of resources, Food, population reservations, orders, production queues, construction, health, bounties, capture state, and outcomes.

The HUD may:

- Read simulation dictionaries to build presentation view models.
- Aggregate player-owned production queues for display.
- Store presentation-only state such as objective collapse and current toast lifetime.
- Invoke existing simulation and battlefield commands.

The HUD must not:

- Mutate resources, queues, orders, health, capture progress, or entity ownership directly.
- Create alternate timers for construction, training, harvesting, capture, or combat.
- Duplicate command validation.

## Files and responsibilities

### New files

#### `scripts/ui/hud_icon.gd`

A deterministic icon control for small interface glyphs. It draws resource and utility silhouettes using Godot canvas primitives so no new runtime art pipeline is required for functional icons.

Required glyphs:

- `jade`, `lumber`, `essence`, `food`, `population`, `den`, `clock`
- `move`, `attack_move`, `patrol`, `repair`, `stop`, `rally`, `cancel`
- `fog`, `ping`, `zoom`, `objective`, `health`, `order`, `cargo`, `queue`

All glyphs accept a semantic color and remain recognizable without color.

#### `scripts/ui/hud_command_button.gd`

A reusable command tile built on `Button` with:

- Existing representational texture or deterministic glyph.
- Short uppercase command label.
- Rich-text icon-like resource costs.
- Dynamic hotkey badge.
- Native hover, press, focus, and disabled styles.
- Tooltip supplied by the caller, including unavailable reason.

The button contains no gameplay validation and emits only its normal `pressed` signal.

### Modified files

#### `scripts/ui/theme_factory.gd`

Add the Jade Command Altar visual tokens and component styles:

- Ink, lacquer, raised lacquer, jade, gold, ivory, muted sage, cinnabar, Essence violet.
- Economy chip, command deck, inset bay, objective, toast, portrait, queue tile, progress bar, and compact utility styles.
- Button focus states at least 2 px thick.
- Disabled command contrast that keeps labels readable.

#### `scripts/main.gd`

Replace `_build_top_bar`, `_build_bottom_hud`, `_build_help_panel`, and `_build_minimap` with a single coordinated match HUD build while retaining the public/internal names used by tests.

New presentation references include:

- Individual resource value labels and chip panels.
- Objective rows and collapse button.
- Minimap utility buttons.
- Selection portrait, name, allegiance/status, health bar, health value, order, metadata, detail, and multi-selection stack row.
- Five global queue tiles.
- Nine fixed command slots with contextual buttons layered into invariant positions.
- Toast panel and label.

Update flow:

1. `_update_hud()` refreshes resources, objectives, selection, queue, commands, armed-mode treatment, and minimap utilities.
2. Selection changes trigger an immediate update.
3. The existing 10 Hz HUD refresh keeps live progress and timers current.
4. Battle notices and interaction feedback map to toast tiers.

Contextual command layout:

| Slot | Worker | Military/Hunter | Stronghold | War Camp | Hunter's Lodge | Owned Den |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | Build War Camp | Move | Train Worker | Train Vanguard | Train Hunter | Call Jadeclaw |
| 2 | Build faction Food I | Attack-Move | — | Train Mystic | — | — |
| 3 | Build faction Food II | Patrol | — | — | — | — |
| 4 | Move | Stop | Set Rally | Set Rally | Set Rally | Set Rally |
| 5 | Repair | — | Cancel Last | Cancel Last | Cancel Last | Cancel Last |
| 6–9 | Stop / reserved | Reserved | Reserved | Reserved | Reserved | Reserved |

Unavailable faction food actions remain absent. Unaffordable actions remain present but disabled with the missing resource identified in the tooltip.

Selection states:

- **No selection:** short direct-control hint and visible worker/army shortcut chips.
- **Single unit:** art, health, order, queued-order count, worker cargo, and role.
- **Multiple units:** stack buttons by unit kind with count and worst-health indicator; clicking selects that subgroup.
- **Structure:** art, health/construction, rally state, output or role, and selected queue.
- **Resource:** source art, remaining amount, and visible assigned-worker count.
- **Wildlife:** animal art, health, flee/retaliate behavior, and Food bounty.
- **Den:** guardian count, owner seal, capture/contest progress, health, rally, and production status.

Global queue behavior:

- Aggregate living player-owned structure queues in stable entity order.
- Display up to five items with art, remaining time, and stack count.
- Clicking a tile selects its producer; a second click centers it through battlefield selection focus.
- The command card's Cancel Last action continues to call `command_cancel_training` for the selected producer.

#### `scripts/view/battlefield.gd`

Add explicit UI-armable Move and Rally modes so every visible command tile is functional.

- `begin_move(append := false)` arms a left-click destination for selected commandable units.
- `begin_rally()` arms a left-click destination for the primary selected allied structure.
- Both use existing authoritative `command_move`/`set_rally` calls.
- `cancel_modes()` and hover feedback include both modes.
- Right-click behavior remains unchanged.

#### `scripts/view/battlefield_minimap.gd`

Polish minimap contrast and hierarchy:

- Threats drawn after allies.
- Distinct den diamonds and structure squares.
- 2 px camera boundary.
- Slightly larger map margins suitable for the new bay.
- Public zoom helpers for compact `+` and `−` controls if necessary.

#### `tests/visual_capture.gd`

Retain the existing captures and add deterministic HUD states:

- Worker selected with build commands.
- Multi-unit stack selection.
- Owned den with a two-item Jadeclaw queue.
- Armed attack-move or placement state.

#### `tests/hud_test.gd`

Add focused, headless presentation coverage:

- All resource chips exist and update from simulation values.
- Objective collapse toggles without changing simulation state.
- Worker, group, structure, resource, wildlife, and den selections populate the expected visible panels.
- Command buttons preserve repair, patrol, cancel, and faction availability.
- Global queue tiles select their producer.
- Toast tier changes color and expires.
- Move and rally UI commands arm and execute through battlefield/simulation APIs.

Add the test to `tools/run_tests.sh`.

## Detailed build sequence

### 1. Foundation and styles

1. Add `HudIcon` and `HudCommandButton`.
2. Expand `ThemeFactory` tokens and named helpers.
3. Build static HUD geometry with real containers and 1280×720 minimums.
4. Ensure UI input blocks world clicks only inside visible controls.

### 2. Economy, objectives, and alerts

1. Replace the single `_resource_label` sentence with individual chips.
2. Bind values at 10 Hz without layout shifts.
3. Create objective rows from actual food-building availability and den ownership.
4. Add a collapse toggle that stores only UI state.
5. Move feedback into a centered toast above the command deck.

### 3. Selection and queue

1. Resolve the selected entity's existing runtime art.
2. Map entity state into short visual fields.
3. Implement progress bars for health, construction, capture, and food timing.
4. Build multi-selection stack buttons and subgroup selection.
5. Aggregate global production queues and connect producer focus.

### 4. Command card

1. Create nine persistent slot containers.
2. Place every existing and new command action into its semantic slot.
3. Bind current costs and tooltips from `FactionCatalog`.
4. Compute precise unavailable reasons from player resources, population, completion, and faction availability.
5. Reflect armed modes through active borders and `Esc Cancel` status.

### 5. Minimap integration

1. Move `BattlefieldMinimap` into the deck.
2. Replace the full-width fog button with a compact icon utility.
3. Add player shortcuts `Q`, `E`, and `Space` beside the map.
4. Retain click/drag recentering and fog-aware drawing.

### 6. Responsive and accessible behavior

1. Use proportional expansion for the selection bay and fixed minimums for map/command bays.
2. Collapse objective detail automatically only when the viewport cannot sustain the full state.
3. Keep essential type at least 13 px and controls at least 44 px.
4. Verify keyboard focus across pause, objective toggle, minimap utilities, queue items, and command tiles.

### 7. Verification and iteration

1. Run `tools/run_tests.sh` after script changes stabilize.
2. Run the native visual harness once.
3. Inspect every generated capture at original resolution.
4. Fix layout overflow, low contrast, inaccurate state, or gameplay regressions.
5. Re-run only the smallest failing gate after each fix; run the full focused suite once more at completion if simulation-facing mode APIs changed.

## Acceptance criteria

- The match HUD visually follows the Jade Command Altar concept at 1280×720.
- The center battlefield remains unobstructed outside transient toasts.
- Every displayed command is functional and validated by existing gameplay truth.
- Resource, selection, objective, queue, and timer text never overlap or wrap unexpectedly.
- The minimap is at least 210×140 logical pixels and remains clickable/draggable.
- Queue progress is visible without selecting a producer.
- No paragraph is required to understand health, order, cargo, construction, capture, or production.
- Unsupported hotkeys are never invented; known bindings are `F`, `T`, `R`, `X`, `Q`, `E`, `Space`, `P`, and control-group digits.
- The simulation/view split remains intact.
- Focused tests and the native visual harness pass.
- No runtime art manifest changes are required because representational buttons reuse existing processed runtime art and functional glyphs are code-drawn.

## Completion record

Implemented on 2 September 2026. The final build includes the Jade Command Altar economy ribbon, progressive objective tracker, integrated tactical map and utilities, illustrated selection states, global producer queue, fixed 3 × 3 command geography, precise affordability tooltips, armed Move/Rally/Attack-Move/Patrol/Repair treatment, tiered toasts, and a centered pause banner. Existing control groups, Shift queues, repair, patrol, production cancellation, Food, and wildlife hunting behavior remain intact.

Verification completed with:

- `tools/run_tests.sh`, including the new focused `tests/hud_test.gd` gate.
- The native `tests/visual_capture.gd` harness, including queue, mixed-selection, and armed-command captures.
- Original-resolution inspection of the rendered 1280 × 720 HUD states.
