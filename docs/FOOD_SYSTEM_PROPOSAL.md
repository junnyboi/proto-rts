# Food Economy — Concept Proposal and Implementation Plan

## Concept

Food becomes the fourth stockpiled resource alongside Jade, Lumber, and Essence. It is the economic brake on army growth: every newly queued unit consumes Food immediately, while existing units have no upkeep. This keeps the mechanic legible in a short skirmish and avoids retroactively punishing an army that is already on the field.

The player begins with **160 Food**, enough to expand or field an opening force, but sustained production requires dedicated food infrastructure:

| Structure | Cost | Footprint | Output | Strategic role |
| --- | --- | --- | --- | --- |
| **Rice Farm** | 55 Jade, 45 Lumber | 2 × 2 | 8 Food every 4 seconds | Cheap, efficient baseline income that consumes valuable meadow space |
| **Hunter's Lodge** | 90 Jade, 75 Lumber, 15 Essence | 1 × 1 | 18 Food every 5 seconds | Expensive, compact, high-throughput income for developed bases |

Both buildings begin producing only after construction completes. Their Food is added directly to the owning faction's stockpile, avoiding a second worker-return loop that would duplicate the existing gathering system without adding a meaningful decision.

The later wildlife expansion adds faction food traditions: Celestials can build only Rice Farms; Demons and Beasts can build only Hunter's Lodges and train Hunters; Humans can use both branches. See `WILDLIFE_HUNTING_PROPOSAL.md` for the authoritative hunting design.

## Unit Food Costs

| Unit | Food cost | Intent |
| --- | ---: | --- |
| Worker | 30 | Economic expansion competes with army growth |
| Hunter | 25 | Active hunting requires an upfront Food investment |
| Vanguard | 40 | Core combat unit remains accessible |
| Mystic | 50 | Premium ranged pressure needs deeper economy |
| Jadeclaw | 65 | Captured-den production remains powerful but demanding |

Food is paid when an item enters a production queue, at the same authoritative seam as the unit's existing Jade, Lumber, and Essence costs. Population reservation remains a separate constraint.

## Player Experience

- The top economy bar shows Food at all times.
- Selecting a worker exposes the War Camp plus only the food buildings available to the chosen faction.
- Placement previews use each structure's true footprint and the existing meadow/occupancy rules.
- Selecting a food building shows its yield cadence and time until the next harvest.
- Unit buttons show Food costs and disable immediately when Food is insufficient.
- A gold production meter on completed food buildings makes the next harvest visible in the world.
- The computer commander must construct food infrastructure and pays the same Food costs as the player. Its disclosed Jade/Lumber/Essence stipend does not grant Food.

## Architecture

`scripts/sim/rts_simulation.gd` remains authoritative for Food stockpiles, construction, harvest timers, affordability, payment, AI build priorities, and unit-queue validation. `scripts/data/faction_catalog.gd` owns static structure and unit costs/yields. `scripts/view/battlefield.gd` owns only placement feedback, sprite projection, meters, and input interpretation. `scripts/main.gd` presents the authoritative values and issues public simulation commands.

The two new structures use shared faction-neutral GPT Image 2 sprites. Ownership is conveyed with deterministic team-colored ground rings and construction/health feedback, keeping the asset scope proportionate while preserving the four factions' existing unit and primary-building identities.

## Implementation Plan

1. Add Food, unit Food costs, food-building statistics, generic structure placement, and harvest timers to the authoritative simulation.
2. Add AI food-economy priorities and validate that AI production cannot bypass Food costs.
3. Generalize battlefield placement mode for all three constructible structures and render true multi-cell footprints, shared food-building art, ownership rings, and harvest progress.
4. Extend the HUD, selection details, help copy, costs, disabled states, and feedback for Food.
5. Generate the Rice Farm and Hunter's Lodge masters with GPT Image 2, process runtime derivatives only through `tools/process_assets.py`, and update the asset manifest and hashes.
6. Add simulation, interaction, and asset-resolution coverage; run the focused test suite and one native visual capture.

## Acceptance Criteria

- Every trainable unit has a positive Food cost and cannot be queued without sufficient Food.
- A valid worker can construct its faction's available food buildings; faction restrictions, invalid terrain, and occupied footprints are rejected.
- Incomplete food buildings produce nothing; completed buildings add exactly their configured yield on cadence.
- Rice Farm and Hunter's Lodge state survives normal simulation advancement and is visible in selection details and world feedback.
- The AI constructs food infrastructure, never receives stipend Food, and trains units only when all costs are affordable.
- Both new runtime sprites resolve through `FactionCatalog`, are included in `asset-report.json` and `SHA256SUMS`, and render in the native visual harness.
