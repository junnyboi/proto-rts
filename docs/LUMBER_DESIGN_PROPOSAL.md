# Lumber and Living Landscapes — Design Proposal

**Date:** 2 September 2026  
**Status:** Implemented and expanded 2 September 2026  
**Scope:** The existing one-versus-one skirmish vertical slice

## Design goal

Add a third resource that deepens the opening economy and makes the Jade Meridian feel like a cultivated mythic landscape. Trees should not be decorative wallpaper or a texture covering invisible blockers: each is a finite Lumber node, an authoritative navigation obstacle, and a player-created opportunity to open new routes by harvesting it.

## Core rules

- **Lumber** joins Jade and Essence in each player's authoritative resource state.
- Workers harvest trees through the existing contextual gather command, cargo cycle, Stronghold drop-off, and automatic return behavior.
- Every tree contains **300 Lumber** and occupies one walkability cell while standing.
- Depleting a tree removes it from the battlefield and rebuilds pathfinding, permanently opening that cell for movement or construction.
- Players begin with **30 Lumber**. A normal War Camp costs **150 Jade, 80 Lumber, and 25 Essence**.
- One full 50-Lumber worker trip unlocks the first War Camp. This makes tree harvesting part of the opening without adding a long pre-production delay.
- Human Dynasty's 15% War Camp discount applies to all three construction resources.
- The computer receives **20 Lumber** with each disclosed economy stipend and can rebuild a destroyed War Camp when it has a worker and sufficient resources.

## Landscape and map play

The map contains **1,016 trees** in rotationally mirrored groves. The 254-cell authored layer expands each macro-cell to a 2 × 2 gameplay block, preserving the previous tree density across the doubled dimensions. The ground below every tree is meadow, so its sprite, collision, resource state, minimap marker, and eventual removal all describe the same gameplay fact.

The dense groves occupy the jungle bands between the three lanes and around selected outer edges. They preserve the map's initial movement topology while making it mutable: armies begin on the authored roads and crossing approaches, then workers can cut one-cell scouting gaps, reinforcement channels, or larger construction clearings. Contiguous grove interiors are intentionally reached from their edges, so opening a major shortcut requires sustained logging rather than harvesting one token tree.

The tree layer follows four placement rules:

- Keep both 2 × 2 Stronghold footprints, the enemy War Camp, workers, and all Jade/Essence nodes clear.
- Keep the three roads, bridge approaches, and a navigable shoulder around each main route open at match start.
- Use exact 180-degree rotational counterparts with matching species and yield for competitive fairness.
- Group pine, cedar, fir, and juniper sprites into coherent patches so the jungle reads as landscape rather than a noisy checkerboard.

The variants share identical gameplay values. Their differences are purely visual, keeping resource recognition and balance predictable. Base-side pines continue to teach the Lumber economy safely; mixed cedar, fir, juniper, and pine groves give the wider jungle varied evergreen silhouettes without changing harvesting efficiency.

## Implementation contract

- `MapCatalog.TREE_ROWS` is the authored 40 × 32 macro-grid tree layer. `P`, `C`, `F`, and `J` resolve to pine, cedar, fir, and juniper Lumber definitions.
- `MapCatalog.tree_definitions()` expands each authored tree to a 2 × 2 block of neutral resource entities during simulation setup.
- `RtsSimulation` remains authoritative for occupied cells, gathering, depletion, placement checks, and A* rebuilds.
- `Battlefield` only selects the matching GPT Image 2 sprite and draws resource feedback; `BattlefieldMinimap` projects the same entity state as green grove markers.
- The tree layer uses four GPT Image 2 masters and their processed transparent derivatives. Retired red-maple and flowering-plum masters remain immutable under `assets/source/` for provenance but are excluded from runtime processing and gameplay.

## Readability and interface

- Lumber appears in the top economy bar between Jade and Essence.
- Worker cargo pips and resource bars use a warm timber-gold color distinct from Jade green and Essence blue.
- Fully stocked trees do not show resource bars, preserving the landscape illustration; a bar appears once harvesting begins.
- Hover feedback and the selection panel identify all variants as **Lumber Tree**.
- The War Camp button displays abbreviated `J`, `L`, and `E` costs while its tooltip spells out the full resource names.
- Trees obey the existing fog-of-war rules and receive a distinct green minimap marker.

## Art direction

Three new GPT Image 2 source masters join the existing pine while matching its painterly, three-quarter isometric resource art:

1. Ancient windswept pine — the primary economy silhouette.
2. Broad, layered Chinese cedar — a stately horizontal silhouette.
3. Tall Chinese fir — a dense conical silhouette.
4. Ancient Chinese juniper — a twisting, cloud-pruned silhouette.

Each master uses the repository's flat magenta isolation background. Transparent runtime PNGs are derived only through `tools/process_assets.py`, which also records dimensions, source paths, and SHA-256 checksums.

## Acceptance criteria

- Lumber deposits, costs, affordability, and Human construction discounts are authoritative simulation state.
- Workers can gather every tree variant with the existing right-click resource command.
- Trees block placement and pathfinding until depleted; depleted tree cells become usable.
- Exactly 1,016 tree entities reproduce the intended jungle masses without permanent forest terrain underneath them.
- The initial tree-blocked walkability graph still connects both starting territories through the three river crossings.
- Bases, starting workers, roads, bridges, and Jade/Essence expansion sites do not overlap trees.
- The computer economy remains functional and can replace its production structure.
- All four runtime tree assets load, render with alpha, appear in the asset report, and pass checksum validation.
- The top bar, battlefield, fog of war, and minimap remain legible at 1280 × 720.
