# Mandate of Myth — Audio System Proposal

**Author:** Manus AI
**Date:** 2 September 2026
**Target:** Godot 4.7, single-threaded browser export

## Executive decision

Mandate of Myth should adopt a **cohesive generated-audio language** built around ritual bronze, carved jade, silk-and-bamboo instruments, natural materials, and restrained supernatural energy. The implementation will add **22 reusable sound-effect cue families** and **one 150-second instrumental background-music track**. The score will remain continuous from the title screen into the skirmish. Screen changes will alter music gain rather than restart the composition.

The system will use non-positional `AudioStreamPlayer` nodes because the game is an isometric strategy title with a zoomable camera and a browser target. Godot documents this node as appropriate for user interfaces, menus, and background music, and it supports overlapping playback through polyphony or multiple players.[1] Browser exports use the Web Audio API and may block autoplay until a user gesture. The title screen will request playback immediately, while every button and gameplay input will also call the audio-unlock path so the first click reliably begins the score.[2]

## Audio identity

The score and effects should sound as though the Jade Meridian is a functioning mythological realm rather than a museum exhibit. **Pipa, guzheng, guqin, bamboo, bangu, and paiban** define interface confirmation, cancellation, rejection, and selection. **Wood, stone, cloth, bowstrings, metal, and earth** define economic and martial actions. **Breath, resonant air, and restrained spectral tails** define Celestial and Mystic power. **Low animal mass and bone-heavy impacts** define Jadeclaw attacks. No cue should use spoken language, modern firearms, science-fiction lasers, comedy stingers, or exaggerated cinematic sub-bass.

The mix should prioritize information. Commands and warnings must be audible over music. Repeating economy cues must remain quiet and short. Combat cues must overlap without clipping or becoming an undifferentiated percussion solo. Godot routes audio through named buses and uses decibel gain; the master output should remain below 0 dB to avoid clipping.[3]

## Runtime cue sheet

The following cue families cover every player-visible interaction and unit action currently implemented. A family may serve several semantically related events. This keeps the vocabulary learnable and the browser download bounded.

| Cue ID | Trigger coverage | Target character | Duration | Priority | Cooldown |
|---|---|---|---:|---:|---:|
| `ui_confirm` | Start, faction choice, train queue, resume, fog toggle | Bright upward pipa/guzheng plucks with a light woodblock tap | 0.45 s | High | 0.05 s |
| `ui_cancel` | Back, cancel order, cancel production, pause | Soft descending pipa plucks ending in a muted bamboo clack | 0.50 s | High | 0.05 s |
| `ui_error` | Invalid placement, insufficient resources, invalid target | Compact bangu and paiban low-high-low rejection figure | 0.70 s | Critical | 0.15 s |
| `unit_select` | Unit or structure selection | Quiet guqin harmonic or pipa pluck with a tiny bamboo tap | 0.40 s | Medium | 0.10 s |
| `order_move` | Move, rally, patrol, control-group recall | Brief command drum and leather step | 0.75 s | High | 0.10 s |
| `order_attack` | Focus fire, attack-move, hunt order | Taut bowstring snap with a low war-drum accent | 0.90 s | High | 0.10 s |
| `order_work` | Gather assignment, repair, construction assignment | Tool pickup, cloth movement, small wooden knock | 0.85 s | High | 0.10 s |
| `deposit_resource` | Cargo delivered to a Stronghold | Ceramic tokens poured into a carved wooden ledger tray | 0.95 s | Medium | 0.25 s |
| `harvest_food` | Rice Farm food-production cycles | Rice stalk brush, woven basket settle, and soft grain patter | 0.85 s | Low | 0.40 s |
| `repair_tick` | Successful building repair pulse | Wooden mallet, tightening timber joint, and small pin settle | 0.80 s | Low | 0.32 s |
| `structure_placed` | Valid building foundation placement | Heavy timber seating into packed earth | 1.10 s | High | 0.15 s |
| `structure_complete` | War Camp, Rice Farm, Lodge, or other structure finished | Timber lock, hanging bronze bell, restrained celebratory tail | 1.80 s | High | 0.25 s |
| `unit_ready` | Worker, Hunter, Vanguard, Mystic, or Jadeclaw produced | Warm deep taiko strike followed by a tighter taiko punctuation | 2.00 s | High | 0.20 s |
| `attack_melee` | Worker or Vanguard melee attack | Fast polearm or blade cut with controlled metal impact | 0.75 s | Medium | 0.08 s |
| `attack_ranged` | Hunter arrow attack | Bowstring release, arrow flight, light terminal strike | 0.85 s | Medium | 0.08 s |
| `attack_magic` | Mystic ranged attack | Focused jade-energy pulse with airy spiritual tail | 1.00 s | Medium | 0.10 s |
| `attack_beast` | Jadeclaw and dangerous wildlife attack | Heavy claw swipe, body mass, short bestial breath | 0.95 s | Medium | 0.10 s |
| `impact_damage` | Damage confirmation when no stronger attack cue dominates | Compact armor/wood/flesh impact layer | 0.60 s | Low | 0.06 s |
| `unit_death` | Unit, guardian, or wildlife death | Armor and cloth collapse into earth, no voice | 1.20 s | High | 0.12 s |
| `structure_destroyed` | Building or Stronghold destruction | Timber, tile, stone, and earth collapse | 2.30 s | Critical | 0.30 s |
| `objective_secured` | Bounty, cave cleared, cave captured | Ascending jade-and-bronze ritual cadence | 2.10 s | Critical | 0.35 s |
| `match_outcome` | Victory or defeat, selected by pitch direction | Four-second ritual cadence with triumphant or mournful variant | 4.20 s | Critical | 1.00 s |

`match_outcome` will have two selected runtime files, `victory.ogg` and `defeat.ogg`, because opposite outcomes require opposite harmonic direction. This produces **23 runtime SFX files from 22 cue families**.

## Candidate-generation and selection policy

Each important cue will receive **three ElevenLabs candidates** generated from the same semantic prompt with identical target duration. The implementation will retain candidates outside the Godot project. A deterministic analysis script compares duration accuracy, peak headroom, integrated loudness, silence ratio, and file integrity. It selects the strongest technically valid candidate by default, while an explicit reviewed A/B/C override can reject a technically loud but aesthetically inferior candidate. The selection report preserves all scores, the selection method, and chosen source hashes.

This automated policy is appropriate because the user requested end-to-end implementation and delegated creative selection. A future subjective audio review can replace any selected file without changing cue IDs or game code. The cue contract is therefore stable even if individual recordings evolve. A bureaucracy with hot-swappable gongs; civilization has peaked.

## Background-music direction

The score, working title **“The Jade Meridian Endures,”** will be a 150-second instrumental loop at approximately 76 BPM in D minor with a D pentatonic emphasis. Its core palette will use guzheng, xiao, restrained erhu, pipa harmonics, low bowed strings, sparse tanggu, muted bronze bells, and a nearly subliminal wind-and-water bed. The arrangement must remain playable under both contemplative menus and active combat.

| Time | Function | Arrangement | Intensity |
|---|---|---|---:|
| 0:00–0:20 | Title opening | Xiao breath, low drone, isolated guzheng harmonics | 2/10 |
| 0:20–0:52 | Realm established | Measured guzheng ostinato, pipa punctuation, restrained strings | 3/10 |
| 0:52–1:24 | Economy and exploration | Light frame pulse, fuller erhu counterline, subtle bronze | 4/10 |
| 1:24–1:58 | Battle-capable lift | Low tanggu pattern and denser strings without becoming trailer music | 6/10 |
| 1:58–2:22 | Strategic release | Percussion recedes; guzheng motif resolves | 4/10 |
| 2:22–2:30 | Loop seam | Return to the opening D drone and matching xiao breath | 2/10 |

The prompt will explicitly forbid vocals, choir, abrupt endings, modern drum kits, EDM bass, heroic trailer braams, and quotation of existing melodies. The first and final eight seconds will share instrumentation, tonal center, ambience, and density to support a clean loop. Post-processing will trim encoder delay where possible, apply a short equal-power seam crossfade if required, normalize conservatively, and export Ogg Vorbis for the Godot runtime.

## Godot architecture

A new `AudioDirector` node will persist beneath the root application node while screens are rebuilt. It will own one BGM player and a bounded SFX player pool. Static `preload()` declarations will make every selected asset discoverable by the exporter. The pool will cap simultaneous effects, enforce per-cue cooldowns, randomize pitch by only ±2–4%, and steal the oldest low-priority voice before a critical cue.

The simulation remains authoritative. Its visual-event dictionaries will gain semantic metadata such as attacker kind, target category, resource kind, and team. `Battlefield` will emit drained simulation events to the root. The root will filter inaudible enemy events through current visibility and forward relevant events to `AudioDirector`. Immediate player inputs such as selection and orders will emit semantic cue IDs from `Battlefield`, which avoids waiting for a later simulation tick.

| Component | Responsibility |
|---|---|
| `AudioDirector` | Asset registry, BGM loop, SFX pool, gain, cooldown, priority, mute, and cue mapping |
| `RtsSimulation` | Emit semantic event metadata without owning playback |
| `Battlefield` | Emit player interaction cues and forward visible simulation events |
| `main.gd` | Persist the director, connect screens, unlock browser audio, manage pause/outcome mix, and expose mute |
| `default_bus_layout.tres` | Separate `Music`, `SFX`, and `UI` gain domains without Web-incompatible effects |
| Audio tests | Verify asset integrity, static coverage, event mapping, cooldown, pooling, loop configuration, and Web pack inclusion |

## Mixing and browser policy

The initial mix target is `Music -15 dB`, `SFX -5 dB`, and `UI -4 dB`, all routed to `Master -2 dB`. The title state will raise music by 2 dB. Active matches will use the base music level. Pause will lower music by 4 dB without stopping the loop. Outcomes will lower music by 6 dB while the victory or defeat cadence plays.

The browser build will retain Godot’s default low-latency **Sample** playback mode. This avoids the increased latency of Stream playback in a single-threaded export.[2] The design will not rely on bus effects because Godot notes that Web Sample playback does not support `AudioEffects`.[2] All tonal shaping and limiting must therefore be baked into the selected OGG files.

## Acceptance criteria

The implementation is complete when every cue path resolves, the BGM stream loops, title and match transitions do not restart the track, the first eligible player gesture unlocks Web audio, invalid commands use the error cue, simultaneous combat cannot exceed the voice cap, hidden enemy activity stays silent, victory and defeat use distinct outcomes, and the Web PCK contains every selected OGG. The existing projection, simulation, interaction, visibility, and visual-capture gates must continue to pass.

## References

[1]: https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer.html "Godot 4.7 AudioStreamPlayer class reference"
[2]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html "Godot Engine: Exporting for the Web"
[3]: https://docs.godotengine.org/en/4.7/tutorials/audio/audio_buses.html "Godot 4.7 audio buses"
