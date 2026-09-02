# Extensive Cursor System Proposal

## Intent

Mandate of Myth should communicate the result of a click before the player commits it. The cursor is a compact command preview: it combines the current command mode, selection capabilities, hovered simulation entity, target validity, and camera gesture into one immediate signal.

The visual concept is **The Jade Command Relic**. Every cursor is a tiny mythic implement carved from celadon jade, antique gold, ink-dark metal, or cinnabar lacquer. Friendly and navigational actions emphasize jade; economy actions use their resource color; combat and rejection use cinnabar; route-setting uses sky blue and gold. The family belongs to the same world as the game's generated units and architecture without becoming miniature character art.

## Design principles

1. **Predict the click.** Contextual cursors follow the same precedence as `Battlefield` input handling. If a right-click would gather, attack, deposit, repair, move, or set a rally point, the hover state says so first.
2. **Command modes win.** An armed build, repair, attack-move, or patrol action overrides normal hover interpretation until confirmed or cancelled.
3. **Invalidity is explicit.** Targeted modes show the forbidden seal when the current cell or entity cannot accept the command.
4. **Simulation truth stays authoritative.** Cursor resolution reads entity teams, categories, visibility, health, completion, resources, and placement queries. It never changes gameplay state.
5. **Native cursor latency.** Runtime images are registered as Godot custom cursor shapes instead of rendering a sprite that trails the pointer.
6. **Browser-safe assets.** Every runtime cursor is a 64 × 64 transparent PNG, below common browser cursor-size limits, with a declared hotspot.
7. **Shape and color redundancy.** No state relies on hue alone: attack uses crossed weapons, gather uses a tool and material, repair uses hammer and gear, patrol uses looping arrows, and forbidden uses the universal slash.

## Cursor family

| State | Visual | Trigger | Hotspot |
|---|---|---|---|
| Select | Northwest jade spearhead | Default battlefield and passive UI space | Spear tip |
| UI action | Pointing jade ceremonial hand | Enabled buttons | Fingertip |
| Box select | Four inward jade brackets | Selection drag crosses the threshold | Center |
| Move | Four-way jade compass | Selected commandable units over ordinary ground or a non-context target | Center |
| Attack | Crossed spears on a red seal | Selected units over a hostile unit or structure | Center |
| Attack-move | Jade spear through a red pulse | Armed attack-move over an in-bounds cell | Center |
| Patrol | Paired blue/jade loop arrows | Armed patrol over an in-bounds cell | Center |
| Rally | Command banner in a waypoint ring | Selected friendly structure with no units | Base of banner |
| Gather Jade | Pick striking jade crystal | Selected workers over a Jade outcrop | Impact point |
| Gather Lumber | Axe biting a cedar log | Selected workers over a Lumber tree | Axe edge |
| Gather Essence | Spirit flame entering a vessel | Selected workers over an Essence shrine | Vessel opening |
| Hunt | Bow over an animal seal | Hunter over wildlife, or units over a Yaoguai Den | Center |
| Deposit | Resource satchel returning to a gate | Carrying worker over its Stronghold | Center |
| Repair | Hammer, jade gear, and spark | Workers over a valid damaged allied structure | Spark |
| Build | Mallet over a foundation plan | Armed placement over an affordable, valid footprint | Center |
| Forbidden | Cracked red seal and gold slash | Invalid armed target, disabled button, or selected army beyond map bounds | Center |
| Pan | Closed jade gauntlet and map bead | Middle-drag battlefield or interact with minimap | Center |

## Resolution precedence

The resolver is deliberately ordered. The first matching state wins:

1. inactive/outcome state → Select;
2. middle-button camera drag → Pan;
3. active selection rectangle → Box select;
4. structure placement → Build or Forbidden;
5. armed repair → Repair or Forbidden;
6. armed attack-move → Attack-move or Forbidden;
7. armed patrol → Patrol or Forbidden;
8. selected units outside the map → Forbidden;
9. Yaoguai Den target → Hunt;
10. hostile target → Hunt for wildlife, otherwise Attack;
11. carrying workers over a Stronghold → Deposit;
12. workers over a repairable structure → Repair;
13. workers over a resource → resource-specific gather state;
14. selected structure without units → Rally;
15. selected commandable units → Move;
16. fallback → Select.

This order matches the existing input contract. For example, a hostile Stronghold resolves to Attack before the deposit check, while a selected production structure resolves to Rally only when no selected units can receive a movement order.

## Architecture

### `CursorSystem`

`scripts/ui/cursor_system.gd` is the presentation-only registry. It owns:

- stable state identifiers;
- the mapping from state to a unique native `Input.CursorShape` slot;
- runtime texture, hotspot, and human-readable label;
- one-time registration through `Input.set_custom_mouse_cursor`;
- helpers for applying a state to any `Control`.

Using separate native shape slots is important. The battlefield changes only its `mouse_default_cursor_shape`; it does not replace the global Arrow bitmap on every hover. Consequently a HUD panel can always return to Select and a button can always display UI action or Forbidden without inheriting the last world action.

### `Battlefield`

`Battlefield.cursor_context_at()` is a pure presentation query returning `state`, `label`, `target_id`, and `valid`. It reads simulation state and shares the same decision ordering as the click handlers. `_refresh_cursor()` caches the last state so native cursor assignment occurs only on a transition. It refreshes on:

- mouse movement;
- drag-threshold changes;
- middle-button press/release;
- selection changes;
- command-mode arm/cancel;
- each presentation frame, so a moving or dying entity under a stationary pointer cannot leave a stale action.

### HUD and minimap

Enabled buttons use UI action; disabled command buttons use Forbidden. The minimap uses Pan to communicate camera movement. Non-interactive panels retain Select.

## Asset pipeline

The 17 immutable GPT Image 2 masters live under `assets/source/cursors/`, protected from export by the existing `assets/source/.gdignore`. `tools/process_assets.py` crops by source alpha, downsamples with Lanczos, centers the art on a 64 × 64 transparent canvas, and writes only runtime derivatives under `assets/runtime/cursors/`.

The processor records every cursor in `assets/runtime/asset-report.json` and refreshes `assets/runtime/SHA256SUMS`. Generation prompts are retained in `assets/source/CURSOR_GENERATION_PROMPTS.md`.

## Verification contract

- Cursor-state tests cover resolver precedence, contextual economy/combat actions, valid and invalid armed modes, box selection, pan, texture dimensions, and unique native shape allocation.
- The existing interaction suite remains the behavior gate for the clicks the cursors predict.
- Asset tests verify report and checksum integrity.
- The native visual harness renders a cursor-family gallery once so 64 px legibility can be reviewed at the actual runtime resolution.

## Extension rules

Future commands should add one stable state to `CursorSystem`, one generated master, one processor entry, and one resolver test. If the native cursor-shape slots are exhausted, related variants should share a slot only when they can never be active on different Controls at the same time; otherwise the system should move to a small global cursor router rather than mutate Arrow globally.
