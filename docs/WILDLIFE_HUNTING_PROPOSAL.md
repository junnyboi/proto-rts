# Wildlife Hunting — Concept Proposal and Implementation Plan

## Outcome

Wildlife turns Food from a purely passive build-and-wait resource into a contested map objective. Ten mirrored herds roam tree-free glades across the Jade Divide. A dedicated Hunter trained at a Hunter's Lodge can pursue them for immediate Food, but higher-value prey takes longer to bring down and boars and bears retaliate.

The first release uses finite herds with no respawn. This creates an opening and midgame race for Food without becoming an infinite income loop or replacing food infrastructure.

## Faction Food Traditions

| Faction | Rice Farm | Hunter's Lodge | Hunter | Strategic identity |
| --- | --- | --- | --- | --- |
| Celestial Court | Yes | No | No | Safe, space-intensive farming |
| Demon Host | No | Yes | Yes | Aggressive map-based hunting |
| Beast Clans | No | Yes | Yes | Fast hunting and map pressure |
| Human Dynasty | Yes | Yes | Yes | Flexible hybrid economy |

These are authoritative simulation restrictions. Invalid buildings cannot be placed through direct commands, unavailable units cannot be queued, AI follows the same rules, and the interface hides inaccessible commands.

## Hunter

The Hunter is an economic ranged unit produced only at a completed Hunter's Lodge.

| Statistic | Value |
| --- | ---: |
| Health | 88 |
| Speed | 1.90 cells/second |
| Damage | 8 |
| Wildlife damage | 24 (3× specialization) |
| Range | 4.5 cells |
| Attack period | 1.1 seconds |
| Cost | 45 Jade, 25 Food |
| Population | 1 |
| Train time | 6.5 seconds |

Hunters can defend themselves against rival armies, but their low base damage keeps them from replacing Vanguards or Mystics. Only Hunters can target wildlife. Hunter production consumes Food like every other unit, so a hunting faction must invest part of its starting reserve before it can harvest more.

## Wildlife Roster

| Species | Herds × size | Health | Speed | Food bounty | Response |
| --- | ---: | ---: | ---: | ---: | --- |
| Wild Chicken | 2 × 5 | 18 | 1.45 | 12 | Flees |
| Sika Deer | 2 × 4 | 55 | 2.05 | 30 | Flees |
| Wild Bison | 2 × 3 | 150 | 1.25 | 70 | Flees |
| Wild Boar | 2 × 3 | 100 | 1.65 | 48 | Retaliates for 13 damage |
| Moon Bear | 2 × 2 | 230 | 1.40 | 95 | Retaliates for 22 damage |

Each herd has a fixed territory origin and radius but independently chooses deterministic local destinations. Chickens, deer, and bison path away when struck. Boars and bears target the attacking Hunter and chase only within their herd territory plus a short retaliation leash, preventing neutral animals from being dragged across the whole map.

## Authored Herd Layout

Every herd has an exact 180-degree counterpart so both starting positions receive equal species, counts, and theoretical Food.

| Species | Territory centers | Radius |
| --- | --- | ---: |
| Chicken | (12, 13), (67, 50) | 3.0 |
| Deer | (14, 47), (65, 16) | 4.0 |
| Bison | (26, 10), (53, 53) | 3.5 |
| Boar | (32, 34), (47, 29) | 3.0 |
| Bear | (38, 20), (41, 43) | 2.5 |

The full map contains 34 animals and 1,274 finite Food. Spawn offsets keep members visually clustered, movement uses the shared navigation grid, and mobile wildlife never becomes a static pathfinding obstacle.

## Player Experience

- Wildlife is hidden by fog unless currently visible because it moves and should not leave stale positional information.
- Animals can be selected to inspect health, bounty, and flee/retaliation behavior.
- Selecting one or more Hunters and right-clicking wildlife issues a hunt order; non-Hunters receive a clear rejection.
- A successful kill immediately adds the configured Food bounty and emits world feedback plus a battle notice.
- The minimap shows visible wildlife in a distinct warm neutral color.
- Hunter's Lodge selection exposes Hunter production alongside its established passive Food cadence.

## Architecture

The simulation/view contract remains intact:

- scripts/data/faction_catalog.gd owns Hunter and wildlife statistics, faction permissions, and runtime art paths.
- scripts/data/map_catalog.gd owns mirrored herd territories and counts.
- scripts/sim/rts_simulation.gd owns spawning, deterministic roaming, flee/retaliation state, hunting eligibility, damage specialization, bounties, and AI orders.
- scripts/view/battlefield.gd projects existing state, performs contextual input translation, and renders sprites, selection, and health feedback.
- scripts/main.gd presents faction restrictions, Hunter production, animal inspection, and notices.
- tools/process_assets.py alone turns immutable GPT Image 2 masters into transparent runtime derivatives and refreshes provenance hashes.

## Execution Plan

1. Add faction farm/hunt capability rules and enforce them in placement, training, affordability, AI, and command visibility.
2. Add the Hunter unit, Hunter's Lodge production eligibility, Food/population reservation, and AI Hunter caps.
3. Add mirrored herd definitions and authoritative wildlife entities with deterministic seed, local territories, and species statistics.
4. Add bounded wandering, passive flee reactions, boar/bear retaliation, leash recovery, Hunter-only targeting, 3× wildlife damage, and Food bounties.
5. Add live-fog rendering, contextual selection/right-click behavior, HUD production, minimap markers, and animal status details.
6. Generate three eligible faction Hunter masters and five wildlife masters with GPT Image 2; process only through the asset pipeline.
7. Add map, simulation, interaction, visibility, and runtime-asset coverage; run the focused suite and one native visual capture.

## Acceptance Criteria

- Exactly 34 animals spawn in ten mirrored herds, with all five requested species represented.
- Idle animals visibly wander while remaining inside their authored territory.
- Chickens, deer, and bison flee from a Hunter's nonlethal hit.
- Boars and bears target and damage the Hunter that attacked them, then stop chasing beyond their leash.
- Only an eligible faction's Hunter can target wildlife, deals the configured specialization damage, and receives the exact Food bounty on a kill.
- Celestials can farm but cannot build a Hunter's Lodge or train Hunters; Demons and Beasts can hunt but cannot build Rice Farms; Humans can do both.
- The AI establishes only legal food infrastructure, trains Hunters when eligible, and sends idle Hunters toward living herds.
- All eight shipped GPT Image 2 masters produce valid transparent runtime sprites listed in asset-report.json and SHA256SUMS.
- The focused test suite and native visual harness pass.
