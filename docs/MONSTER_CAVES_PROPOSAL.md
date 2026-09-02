# Monster Caves — Concept Proposal and Implementation Plan

**Status:** Implemented
**Date:** 2 September 2026
**Feature name:** Yaoguai Dens and Jadeclaws

## Concept

Yaoguai Dens add an optional risk-and-reward objective between economy and direct base warfare. Each den begins as neutral territory protected by three Jadeclaws. A player can hunt those guardians for immediate resources, hold the cleared ground to claim the den, and use the captured structure to call new Jadeclaws into their army.

The feature is intended to create three useful decisions:

- whether to spend early military strength on a PvE hunt or pressure the rival;
- whether to defend a captured production point away from the main base;
- whether to contest a den during capture or concede it and attack elsewhere.

Produced Jadeclaws remain loyal to the team that created them if the den later changes hands. Ownership controls future production; it does not retroactively convert armies.

## Gameplay Rules

| Rule | Implemented value |
| --- | --- |
| Dens per map | 2, placed with 180-degree symmetry at `(19, 21)` and `(59, 41)` |
| Initial guardians | 3 neutral Jadeclaws per den |
| Guardian behavior | Wanders within 3 cells of its cave entrance, attacks either team inside acquisition range, and returns when lured beyond a 5.5-cell leash |
| Bounty per guardian | 45 Jade, 30 Lumber, and 25 Essence, paid immediately to the killing team |
| Capture prerequisite | Every original guardian belonging to that den must be dead |
| Capture units | Vanguards, Mystics, and aligned Jadeclaws; Workers do not capture |
| Capture radius | 2.8 cells around the den |
| Capture time | 6 seconds of uncontested presence |
| Contest behavior | Progress pauses while both teams have military units in the ring |
| Abandon behavior | Partial progress decays at half speed when the ring is empty |
| Recapture | Any cleared den can change hands under the same hold rule |
| Transfer safety | An unfinished queue is cancelled on transfer and its reserved population is released |

## Jadeclaw Unit

| Attribute | Value |
| --- | --- |
| Role | Durable melee pressure from a forward production point |
| Health | 280 |
| Damage | 24 every 1.05 seconds |
| Range | 0.9 cells |
| Move speed | 1.62 cells per second |
| Acquisition range | 6 cells |
| Population | 3 |
| Cost | 90 Jade and 55 Essence |
| Training time | 12 seconds |

The unit deliberately sits between a Vanguard and a small siege threat: it is durable and efficient in sustained melee, but its three-population cost and remote production structure prevent it from replacing the faction army.

## Interaction and Readability

- Right-clicking a den with selected units sends an attack-move order to the objective.
- Neutral and rival dens can be selected for status inspection even though other enemy entities remain non-selectable.
- Three gold pips above a den show its living guardian count.
- A team-colored ring communicates neutral, player, or rival allegiance.
- A progress bar above the den shows active capture, and gold indicates a contested capture.
- The selection panel explains guardian count, bounty, ownership, capture progress, and production queue.
- The top bar shows the player's den count, and the minimap gives dens and neutral monsters distinct markers.
- The `E` army shortcut includes player-aligned Jadeclaws.

## Computer Commander

The computer uses the same simulation rules. Once it has three military units and owns no den, it prioritizes its nearest unowned den: it focus-fires living guardians, moves into the capture ring after the camp is clear, and begins calling Jadeclaws after capture. It returns to its normal Stronghold assault plan after securing a den. The AI receives no capture-speed, bounty, monster-stat, or vision advantage.

## Architecture

All authoritative fields—guardian association, leash origin, bounties, capture lock, owner, progress, contest state, queues, population reservations, and AI objectives—live in `scripts/sim/rts_simulation.gd`. `MapCatalog` owns only symmetric placement data and `FactionCatalog` owns static unit/structure statistics and runtime art paths.

`Battlefield`, `BattlefieldMinimap`, and `main.gd` read simulation state to render sprites and interface feedback. They do not decide capture outcomes, award resources, transfer ownership, or spawn monsters.

## Implementation Plan

1. **Map and data:** add two symmetric den definitions, guardian spawn cells, Jadeclaw statistics, den footprint data, and neutral runtime art paths.
2. **Neutral encounter:** spawn each den and its guardian pack, implement bidirectional neutral hostility, prevent den attacks, and leash guardians to their home objective.
3. **Rewards and capture:** award mixed kill bounties, unlock a den after its own guardian list is clear, resolve contested capture and decay in fixed simulation ticks, and support ownership transfer.
4. **Production and AI:** allow only owned dens to queue Jadeclaws, preserve population reservation rules, cancel queues safely on transfer, teach the AI to hunt/capture once and produce from owned dens.
5. **Presentation:** add sprites, allegiance rings, guardian pips, capture bars, minimap markers, contextual right-click behavior, selection details, resource notices, and a Jadeclaw command button.
6. **Assets:** generate the Yaoguai Den and Jadeclaw masters with GPT Image 2, keep them under `assets/source/`, generate runtime PNGs only through `tools/process_assets.py`, and refresh the report and checksums.
7. **Verification:** validate map symmetry and placement, runtime asset resolution, bounty/capture/production transitions, existing economy/combat/victory behavior, and one native visual capture.

## Completion Criteria

The feature is complete when both teams can encounter the same neutral rules, guardian kills visibly grant resources, cleared dens can be captured and recaptured, owned dens can produce controllable aligned Jadeclaws, the AI can use the system, the new art resolves in native Godot and browser-targeted resources, and all focused tests plus the visual harness pass.
