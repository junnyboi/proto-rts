# Command System Implementation Plan

## Goal

Add five production-quality RTS command features without weakening the authoritative simulation/view split:

- numbered control groups;
- shift-queued unit orders;
- worker repair orders;
- repeating patrol routes;
- production-queue cancellation with refunds.

`RtsSimulation` remains the sole owner of unit orders, command queues, repair costs, patrol state, production queues, population reservations, and resource refunds. `Battlefield` owns selection-oriented control-group membership and translates input into simulation commands. `main.gd` owns global keyboard shortcuts and command-panel feedback.

## 1. Control groups

### Input contract

- `Ctrl/Cmd + 0–9` replaces a control group with the current friendly selection.
- `Ctrl/Cmd + Shift + 0–9` appends the current friendly selection to a group.
- `0–9` recalls a group, replacing the current selection.
- `Shift + 0–9` merges a group into the current selection.
- Pressing the same group number twice within 450 ms recalls it and centers the camera on the living group members.

### State and lifecycle

- Store groups in `Battlefield`, because membership is a local selection convenience and has no gameplay effect.
- Accept living player units and structures; ignore resources, enemies, and neutral objectives.
- Preserve stable entity-id order and remove dead or invalid members lazily when a group is recalled or extended.
- Clear all groups when a new `Battlefield` is created for a rematch.

## 2. Shift-queued orders

### Input contract

- Holding Shift while right-clicking appends contextual move, attack, gather, deposit/return, or repair orders.
- Holding Shift when confirming an armed attack-move or patrol command appends that order.
- A command issued without Shift replaces the active order and clears all queued orders.
- Stop clears the active order and every queued order.

### Simulation representation

Each commandable unit receives a `command_queue` array. Queue entries are immutable dictionaries with an order `type` and the minimum payload required to activate it:

- `move` / `attack_move`: `destination`;
- `attack`: `target_id`;
- `gather`: `target_id`;
- `repair`: `target_id`;
- `patrol`: `destination`; the origin is captured when the queued command activates so a patrol queued after movement begins at the preceding waypoint.

Public command methods accept an `append := false` parameter. A shared dispatcher either activates the order immediately or appends it. Immediate activation clears stale path, target, patrol, and attack-move state before applying the new command.

### Completion rules

- Move and attack-move complete on arrival.
- Direct attack completes when its target dies, becomes invalid, or leaves permitted knowledge.
- Repair completes when the target reaches maximum health or becomes invalid.
- Gather completes when its source is depleted; automatic return/deposit remains part of that order. A queued successor takes precedence over automatic tree retargeting after deposit.
- Patrol repeats indefinitely until replaced or stopped, so later queued orders remain behind it by design.
- Invalid queued targets are skipped deterministically until a valid command is found or the unit becomes idle.

## 3. Repair

### Rules

- Only living player-aligned workers may repair.
- The target must be a living, completed, damaged allied structure.
- Workers move to normal worker interaction range before repairing.
- Every 0.5 seconds, each worker restores up to 15 HP and consumes 1 Lumber.
- Repair pauses in place when Lumber is unavailable and emits a rate-limited battle notice.
- Fully repaired or destroyed targets complete the order and activate the next queued command.

### Controls

- Right-clicking a damaged allied structure with workers issues contextual repair.
- `R` or the worker command-panel button arms repair targeting.
- Shift may append the repair order in either interaction path.

## 4. Patrol

### Rules

- Patrol is available to player-controlled military units.
- The patrol route begins at each unit’s position when the command activates and alternates between that origin and the chosen destination.
- Patrol units acquire visible hostile targets using their normal acquisition radius.
- After combat, they resume toward the currently active patrol endpoint.
- Patrol state is distinct from attack-move state so replacing, stopping, and queue activation cannot leak destinations across commands.

### Controls

- `T` or the military command-panel button arms patrol targeting (`P` remains Pause).
- The next ground click confirms the destination; Shift appends it.

## 5. Production-queue cancellation

### Rules

- A training queue item stores the resources charged at enqueue time alongside its reserved population.
- Cancel removes the newest queued item. This avoids unexpectedly discarding the nearly completed front item when multiple units are queued.
- Cancellation refunds 100% of the stored Jade, Lumber, Essence, and Food cost and releases reserved population.
- The command is rejected for empty, enemy, neutral, dead, or incomplete structures.
- Destruction or Den recapture continues to clear queues without resource refunds.

### Controls

- A `CANCEL LAST` button appears when the selected production structure owns at least one queued unit.
- Selection details identify the queue length; feedback names the cancelled unit and refund.

## 6. Verification

### Automated coverage

Add focused tests for:

- replace, append, merge, recall, cleanup, and double-recall control-group behavior;
- two sequential move orders and replacement/Stop queue clearing;
- patrol endpoint reversal and resumption after combat;
- repair range, HP restoration, Lumber cost, completion, and invalid targets;
- production cancellation resource refund and population release;
- modifier-aware input forwarding for Shift-queued contextual orders.

### Repository gates

1. Run `tools/run_tests.sh`.
2. Run the native visual harness once from a temporary repository copy so the user’s existing generated captures are not overwritten.
3. Re-read the overlapping simulation and battlefield diffs to confirm the concurrent correctness work remains intact.
