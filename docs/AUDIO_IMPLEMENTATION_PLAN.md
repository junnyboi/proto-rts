# Mandate of Myth — Audio Implementation Plan

**Author:** Manus AI
**Date:** 2 September 2026

## Delivery strategy

Implementation will proceed in six ordered phases: generate, evaluate, process, integrate, verify, and release. The plan preserves the existing simulation/view boundary. Audio receives semantic events but never changes gameplay state. Static resource paths and Ogg Vorbis runtime files will keep the single-threaded Web export predictable.[1]

## Phase plan

| Phase | Work | Output | Exit gate |
|---|---|---|---|
| 1. Candidate generation | Generate one 150-second instrumental score and three ElevenLabs candidates for each SFX cue | External lossless/MP3 candidate library with manifest | Every requested file exists and decodes |
| 2. Technical evaluation | Measure duration, peak, loudness, silence, and integrity; select one candidate per outcome | Machine-readable selection report | One technically valid winner per runtime cue |
| 3. Runtime processing | Trim, fade, normalize, and transcode selected assets to Ogg Vorbis | `assets/runtime/audio/bgm` and `assets/runtime/audio/sfx` | OGG files decode; BGM seam and duration are valid |
| 4. Godot integration | Add buses, `AudioDirector`, simulation metadata, battlefield signals, main-state wiring, and mute control | Playable native project with persistent music and semantic SFX | Headless boot and audio tests pass |
| 5. Release verification | Import, run focused tests, run Godot-native captures, export Web, and inspect PCK | Current Web bundle with audio | Existing suite, audio suite, and exported-pack checks pass |
| 6. Distribution | Commit and push Godot source, update WebDev-managed runtime files and iframe shell, save checkpoint | GitHub source plus Manus WebDev checkpoint | Clean synchronized source and deliverable checkpoint |

## Generation batches

The 72 SFX candidate windows will be generated in bounded batches. Twenty-two ordinary cue families produce three candidates each, while the match-outcome family produces separate three-candidate victory and defeat sets. The music track requires one generation call because its duration is below 180 seconds. The complete prompt will declare duration, tempo, key, instrumental-only status, palette, structure, ambience, production quality, loop seam, and exclusions at the beginning and within the arrangement instructions.

Candidate names will use `{cue}_{A|B|C}.mp3`. Generated candidates will stay outside the Godot repository at `/home/ubuntu/proto-rts-audio-candidates/`. Selected runtime files will use stable semantic names such as `order_move.ogg` and `attack_magic.ogg`. This separates creative iteration from runtime contracts.

## Technical selection

A project tool will invoke `ffprobe` and `ffmpeg` to produce duration, decoded sample count, maximum volume, mean volume, and silence ratio for each candidate. A candidate fails if it cannot decode, misses the target duration by more than 35%, contains excessive leading or trailing silence, clips, or is effectively inaudible. The score rewards duration accuracy, healthy but conservative peak level, limited silence, and consistent loudness. The report will preserve the selected candidate, input hash, score, processing command, output hash, duration, codec, and size.

## Processing specification

SFX will receive short edge fades, conservative peak normalization, stereo preservation, and Ogg Vorbis encoding at a quality appropriate for short effects. The BGM will be encoded at higher quality. The processor will avoid aggressive loudness matching because transient cues and sustained music have different perceptual requirements. Baked gain and Godot bus gain will share responsibility.

The BGM loop will use the generated 150-second structure. If the seam has a measurable discontinuity, the processor will create a short equal-power overlap between matching beginning and ending ambience. Godot will set `AudioStreamOggVorbis.loop = true` on a duplicated runtime stream.

## Code changes

`AudioDirector` will expose `play_ui`, `play_cue`, `handle_simulation_event`, `set_state`, `ensure_bgm`, `toggle_muted`, and diagnostic methods. It will create a bounded pool of `AudioStreamPlayer` nodes on the `SFX` and `UI` buses. Per-cue policy will define gain, pitch variance, cooldown, priority, and maximum concurrent instances.

`RtsSimulation._add_event` will accept optional metadata. Construction, production, gather, deposit, repair, capture, attack, death, bounty, and outcome call sites will attach kind, category, resource, and team fields. `Battlefield` will emit `audio_cue` for immediate input and `simulation_event` when events are drained for drawing. It will not play files directly.

`main.gd` will create the persistent director before the first screen, connect buttons and battlefield signals, request BGM in the title state, and adjust music gain for title, match, pause, and outcome states. A compact `AUDIO ON/OFF  M` control will be available in the match top bar. The `M` key will toggle all audio.

## Verification design

A new headless audio test will prove that every cue ID has a preloaded stream, the SFX pool is bounded, BGM looping is enabled, state gain changes preserve playback, cooldown suppresses spam, and representative simulation events map to expected cues. Existing simulation tests will confirm that added event metadata does not alter mechanics. Asset validation will include the new audio directories.

The native visual harness will run once because UI changes add a mute control. It cannot validate sound perception, so a deterministic audio diagnostic will log cue playback requests and active voice counts. The release export will then be inspected for every OGG path and booted from the exported PCK.

## Risk controls

| Risk | Control |
|---|---|
| Browser autoplay blocks title music | Attempt title playback, then call `ensure_bgm()` from every first user gesture |
| Combat produces excessive overlap | Per-cue cooldowns, concurrency limits, priority, and a fixed player pool |
| Hidden enemy actions reveal information | Visibility filter before forwarding battlefield events |
| Music masks orders | Conservative music bus level and state-based ducking |
| Web effects differ from native | Use Sample playback and bake processing into files; no runtime audio effects |
| Export misses dynamic assets | Static `preload()` declarations and PCK content assertions |
| Generated cue is poor | Stable cue IDs and retained candidate manifest allow isolated replacement |
| Download size grows | Ogg Vorbis runtime encoding and one reusable cue per semantic family |

## Definition of done

The task is done only after the proposal, prompts, generated candidate manifest, selected OGG assets, `AudioDirector`, semantic event wiring, mute flow, automated tests, Godot-native capture, Web export, PCK inspection, Git synchronization, and updated Manus WebDev checkpoint all exist and pass. Producing files without wiring them is not implementation; it is merely an unusually expensive folder.

## References

[1]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html "Godot Engine: Exporting for the Web"
[2]: https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer.html "Godot 4.7 AudioStreamPlayer class reference"
[3]: https://docs.godotengine.org/en/4.7/tutorials/audio/audio_buses.html "Godot 4.7 audio buses"
