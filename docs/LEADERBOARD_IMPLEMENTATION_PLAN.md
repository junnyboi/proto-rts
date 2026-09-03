# Leaderboard Implementation Plan

## Goal

Add a local-first leaderboard to Mandate of Myth, expose it from the title and match-result screens, and connect web exports to the same parent-window request/response pattern used by `proto-scroller-simple` for optional shared global rankings.

The existing score owned by `scripts/sim/rts_simulation.gd` remains the only gameplay score. The leaderboard records that score after a match; it does not recalculate, mutate, or duplicate simulation rules.

## Affected architecture

```text
proto-rts/
├── captures/
│   ├── title.png
│   ├── leaderboard-title.png
│   ├── result.png
│   └── leaderboard-result.png
├── docs/
│   └── LEADERBOARD_IMPLEMENTATION_PLAN.md
├── scripts/
│   ├── main.gd
│   ├── services/
│   │   ├── leaderboard_store.gd
│   │   ├── leaderboard_store.gd.uid
│   │   ├── leaderboard_bridge.gd
│   │   └── leaderboard_bridge.gd.uid
│   └── ui/
│       ├── leaderboard_dialog.gd
│       └── leaderboard_dialog.gd.uid
├── tests/
│   ├── leaderboard_test.gd
│   ├── leaderboard_test.gd.uid
│   ├── hud_test.gd
│   └── visual_capture.gd
└── tools/
    └── run_tests.sh
```

No static art is required. No file under `assets/source/` or `assets/runtime/` changes.

## Reference behavior to preserve

The reference implementation in `proto-scroller-simple` is local-first:

- An anonymous device profile and editable callsign live in a versioned JSON save.
- Completed runs are retained locally and sorted into a deterministic local leaderboard.
- A browser export can exchange versioned messages with a same-origin parent page that owns the global service.
- Native builds and web builds without a compatible parent remain usable and explicitly show local fallback data.
- Only the public profile summary is sent to the host; full run history remains on the device.

## Data and ranking design

`LeaderboardStore` owns persistence, validation, and local ranking. Its versioned profile contains:

- a random anonymous profile ID;
- a generated, editable callsign;
- total matches and victories;
- the best lifetime score;
- up to 30 completed match records;
- a last-updated Unix timestamp.

Each match record contains a unique run ID, match sequence number, final score, result, faction, elapsed seconds, and completion timestamp. Local ranking sorts by score descending, elapsed time ascending, completion time ascending, then run ID. This makes tied scores deterministic and rewards reaching the same score more quickly.

The store writes through a temporary file and rotates the previous valid save to a backup before replacing it. Loading attempts the primary file first and the backup second, then falls back to a fresh profile if neither validates.

Callsigns are 3–20 characters and accept letters, numbers, spaces, hyphens, and underscores. The generated default follows the `MERIDIAN-XXXX` form.

## Global bridge contract

`LeaderboardBridge` mirrors the reference project's browser boundary. It never owns ranking truth and never changes game state.

- Channel: `mandate-of-myth-leaderboard`
- Protocol version: `1`
- Request types: `submit`, `list`, and `update_callsign`
- Response correlation: a unique `requestId`
- Security boundary: responses must come from `window.parent`, share the current origin, match the channel/version, and match an outstanding request
- Timeout: four seconds
- Result cap: 20 sanitized rows, with the UI requesting 10

The public submission payload contains the anonymous profile ID, callsign, best score, total matches, victories, last faction, source revision, and updated timestamp. It does not contain local run history or unrelated player data.

Bridge states are `native_local`, `syncing`, `online`, `offline`, and `error`. Native builds are deliberately local-only. In a standalone web export, unavailable or timed-out global requests switch the dialog to an explicit local fallback instead of blocking the player.

The host receives this envelope:

```json
{
  "channel": "mandate-of-myth-leaderboard",
  "version": 1,
  "type": "list | submit | update_callsign",
  "requestId": "unique-client-request-id",
  "payload": {}
}
```

It answers with the same channel, version, and request ID plus `ok`. Successful `list` and `submit` responses return `payload.entries` and an optional `payload.personalRank`:

```json
{
  "channel": "mandate-of-myth-leaderboard",
  "version": 1,
  "requestId": "unique-client-request-id",
  "ok": true,
  "payload": {
    "entries": [
      {"rank": 1, "callsign": "JADE GENERAL", "score": 6840, "victories": 7, "faction": "human"}
    ],
    "personalRank": {"rank": 12, "score": 2725}
  }
}
```

A compatible backend keeps one public row per anonymous profile, applies a monotonic `max(existing_score, submitted_score)` update, validates callsigns again server-side, hashes the anonymous profile ID before storage, and ranks by best score descending with a stable server-owned tie break. Callsign updates never lower or replace the stored best score.

### Hosting boundary

This repository currently exports a static Godot build to GitHub Pages and contains no authenticated database service or deployment target. The client-side protocol and graceful fallback can be implemented and tested here end to end. A genuinely shared cross-device table additionally requires a compatible same-origin parent host/backend, like the separate hosted service used by `proto-scroller-simple`; provisioning that external service is outside this repository and requires a deployment target and credentials.

## Dialog and screen flow

One reusable `LeaderboardDialog` is created for each active game screen and layered above it.

- The title screen keeps `START GAME` as the primary focused action and adds `LEADERBOARD` beneath it.
- The result screen records the completed score exactly once, shows `SCORE: N`, and adds `LEADERBOARD` alongside the existing next actions.
- Opening the dialog starts on `LOCAL`, showing saved match records immediately.
- The `GLOBAL` tab asks the bridge to refresh. While unavailable, the same local rows remain visible under a clear fallback status.
- The callsign can be edited and saved from either tab. Local persistence completes immediately; global synchronization is best effort.
- `Escape`, the close button, or the backdrop closes the dialog and restores focus to the button that opened it.
- While the dialog is open, game/title shortcuts are consumed so input cannot leak to the obscured screen.

## Implementation work packages

1. Persistence and ranking
   - Add profile creation, schema validation, atomic save/backup recovery, callsign validation, match recording, bounded history, deterministic sorting, and public-profile projection.
2. Browser bridge
   - Add native fallback, browser listener installation, same-origin postMessage requests, response correlation, timeout handling, and defensive response sanitization.
3. Reusable interface
   - Add the themed modal, callsign editor, Local/Global tabs, status/personal-rank messaging, ten rank rows, refresh, close, and focus restoration.
4. Game integration
   - Initialize the persistent services outside the disposable screen tree; add title/result buttons; submit `simulation.team_score(TEAM_PLAYER)` once per result; show the final score; route bridge state into the active dialog.
5. Verification
   - Add isolated store/bridge tests using temporary `user://` files.
   - Extend HUD integration coverage for both launch points, score recording, duplicate-event protection, and dialog input capture.
   - Add title/result dialog screenshots to the native visual harness.
   - Register the new test and run `tools/run_tests.sh`, followed by one native visual harness run.

## Completion criteria

- Scores shown and persisted are the authoritative simulation score.
- Every completed match is recorded once, including defeats.
- Local ranking survives process restarts and keeps at most 30 runs.
- Title and result leaderboard buttons open the same dialog behavior.
- The result screen shows the final score.
- Malformed saves and malformed or stale bridge responses cannot crash or corrupt the profile.
- Native and offline web play remain fully functional with honest fallback status.
- A compatible web host can list, submit, and update callsigns through the documented protocol without game-code changes.
- Automated tests and the native visual harness pass.
