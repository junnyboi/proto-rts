# GPT Image 2 — Wood Fortification Masters

Generated on 3 September 2026 with the built-in GPT Image 2 tool. Each image was generated as a new single-subject asset while referencing the matching existing faction Stronghold under `assets/source/buildings/` for palette, material language, and ornamental continuity. The generated masters are immutable inputs; runtime isolation and resizing are owned by `tools/process_assets.py`.

## Shared art direction

> Create one production-ready building asset for a stylized Chinese-mythology real-time strategy game. Match the attached faction Stronghold's painterly 3D-rendered isometric language, camera angle, lighting, palette, timber treatment, and ornamental motifs. Show exactly one complete structure, centered, fully visible, with generous empty margin. Use a clean three-quarter isometric game view, readable silhouette, crisp material separation, and no characters, text, UI, labels, terrain tile, cast-off props, or cropped parts. The structure must be primarily wood and immediately legible at small RTS scale.

For keyed outputs the final sentence was:

> Place the isolated subject on a perfectly flat, uniform chroma-magenta background (#ff00ff), with no ground plane and no magenta lighting or reflections on the subject.

The Demon Wall master was returned with a clean alpha channel, so its prompt used:

> Return a transparent-background PNG with clean alpha, no ground plane, and no shadow detached from the structure.

## Structure-specific prompts

### Wall

> Design a compact modular 1×1 wooden palisade wall segment. It must connect visually at both ends when repeated in a straight line, have a low rectangular footprint, thick defensive posts, a clear base, and no gate opening. Keep the silhouette compact enough that adjacent copies read as one continuous barrier.

### Gate

> Design a 2×4 wooden fortified gate module with a broad, unmistakably open central passage that friendly units can walk through. Use substantial timber doors, beams, and faction ornament around the opening, but do not block the passage. The long axis and threshold must remain legible when the sprite is mirrored for the alternate map orientation.

### Sentry tower

> Design a 2×2 wooden sentry tower with sturdy supports, a visible stair or ladder language, and a broad open fighting platform. Do not add any roof, canopy, cap, ceiling, or overhead ornament above the platform. The empty top must remain visually clear so a Hunter or Mystic sprite can be composited standing on it in game.

## Faction differentiators

| Faction | Reference | Prompt addition | Outputs |
| --- | --- | --- | --- |
| Celestial Court | `buildings/celestial_stronghold.png` | Pale jade-painted timber, teal and gold celestial trim, cloud-scroll braces, restrained luminous turquoise accents, elegant symmetrical joinery. | `celestial_wall.png`, `celestial_gate.png`, `celestial_sentry_tower.png` |
| Demon Host | `buildings/demon_stronghold.png` | Charred dark wood, iron bindings, ember-red cloth and glow, hornlike carved stakes, aggressive but functional asymmetry. | `demon_wall.png`, `demon_gate.png`, `demon_sentry_tower.png` |
| Beast Clans | `buildings/beast_stronghold.png` | Rough honey-brown logs, rope lashings, hide and bone accents, claw/tusk motifs, practical tribal construction. | `beast_wall.png`, `beast_gate.png`, `beast_sentry_tower.png` |
| Human Dynasty | `buildings/human_stronghold.png` | Warm red lacquered timber, dark tiled trim used only below the tower platform, brass fittings, disciplined imperial brackets and banners. | `human_wall.png`, `human_gate.png`, `human_sentry_tower.png` |

## Facing-aligned replacement masters

A visual audit of all eight wall and gate masters found two source-facing outliers. The original files remain immutable. On 3 September 2026, the built-in GPT Image 2 edit workflow produced these authoritative replacements:

| Runtime asset | Preserved original | Aligned master | Correction |
| --- | --- | --- | --- |
| `runtime/buildings/celestial_wall.png` | `buildings/celestial_wall.png` | `buildings/celestial_wall_aligned.png` | Horizontal mirror to match the Demon, Beast, and Human wall masters. |
| `runtime/buildings/demon_gate.png` | `buildings/demon_gate.png` | `buildings/demon_gate_aligned.png` | Horizontal mirror to match the Celestial, Beast, and Human gate masters. |

Both edits used the original image as the sole edit target with this invariant: change only the horizontal facing; preserve the exact structure design, silhouette, proportions, materials, colors, lighting, ornament, camera elevation, scale, complete framing, and chroma-magenta isolation background; add or remove nothing. `tools/process_assets.py` maps these versioned masters back to the stable runtime filenames and records the selected source in `assets/runtime/asset-report.json`.
