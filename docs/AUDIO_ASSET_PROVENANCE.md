# Mandate of Myth — ElevenLabs Audio Asset Provenance

**Generation date:** 2 September 2026
**Interface-family regeneration:** 3 September 2026
**Unit-completion regeneration:** 3 September 2026
**Generator:** Built-in ElevenLabs integrations exposed through Manus
**Runtime target:** Godot 4.7 single-threaded Web export

## Generation record

One background-music source and twenty-four SFX audition reels were generated for this project. The repetitive `gather_resource` cue was subsequently retired, leaving twenty-three runtime SFX. The music request targeted 150 seconds; the generated source is 145.659 seconds. The SFX prompts requested three related variants in each reel so the final runtime vocabulary could be selected without spending one generation call per candidate. The candidate library is retained outside the Godot import root at `/home/ubuntu/proto-rts-audio-candidates/`. Only selected, processed Ogg Vorbis derivatives enter the project.

The score prompt specified instrumental-only cinematic Chinese-mythology strategy music at approximately 76 BPM in D minor with D-pentatonic emphasis. Its palette comprises guzheng, xiao, restrained erhu, pipa harmonics, low bowed strings, sparse tanggu, muted bronze bells, and subtle wind-and-water ambience. The composition moves from a sparse title opening to measured economy and exploration, reaches a controlled tactical lift, then returns to the original tonal center and density. Vocals, choir, EDM bass, modern drums, trailer braams, abrupt endings, and existing melodies were explicitly excluded.

The SFX prompts share a hand-crafted, family-friendly fantasy treatment. The regenerated interface family uses pipa, guzheng, guqin, bamboo, bangu, and paiban; unit completion uses warm paired taiko strikes; other gameplay actions retain jade-like stone, antique bronze, timber, packed earth, tile, leather, rice, woven baskets, armor, bows, blades, spiritual air, and restrained bestial mass. Voices, gore, modern weapons, electronic alarms, comedy buzzers, and excessive cinematic sub-bass were excluded.

## Interface-family regeneration

On 3 September 2026, the previous `ui_confirm`, `ui_cancel`, `ui_error`, and `unit_select` source reels, split candidates, and runtime OGG derivatives were deleted before replacement. Four new six-second ElevenLabs reels each contain three evenly spaced candidates. Confirmation uses upward pipa/guzheng and woodblock; cancellation uses descending pipa and bamboo; invalid actions use bangu and paiban; selection uses a quiet guqin or pipa articulation with bamboo. The semantic filenames remain stable so every existing menu, HUD, command-deck, production, pause, and selection trigger inherits the new palette without duplicating playback code.

Targeted processing selected candidate A for all four replacements. The resulting runtime SHA-256 hashes are `0ca070cdbc5170b231d7cb13dffa94538116293963cafc799cec0ab7be244423` (`ui_confirm`), `79cb48e72a9c3419fe731974d67de6683ff593c3a85fc406d340f1ed9394a230` (`ui_cancel`), `64386e4985ee6a397f25480a8e3f2b9e6e52a5f4d7c21a5cebd6c3045eeea511` (`ui_error`), and `4de5e6871d4a31aab85a59710981ffe1c7d5d200a5982c50ea87ac9da28a68e2` (`unit_select`). All are 48 kHz stereo Ogg Vorbis. The processor's new `--only-sfx ... --skip-bgm` mode preserves every unrelated runtime audio byte and report entry during focused replacement.

## Unit-completion regeneration

On 3 September 2026, the previous `unit_ready` source reel, all three split candidates, runtime OGG, and ignored Godot import sidecar were deleted before replacement. The new six-second ElevenLabs reel contains three evenly spaced paired-taiko completion candidates. Candidate A reached digital full scale and occupied almost its entire analysis window; candidate B retained 24.76 dB of peak headroom and a substantially cleaner transient profile. The reviewed pipeline therefore selected **candidate B** rather than the automatic loudness winner.

The deleted runtime SHA-256 was `548b8926f0d06a0423a02964b91055a15f28618ce5e7bdae9f1f5903ab0e3f6d`. Its replacement is a 1.970-second, 48 kHz stereo Ogg Vorbis file with SHA-256 `85b2683cfc87690dbfdf445c9864220554e15958cde86bd951fb3908e0288133`. The stable `unit_ready` cue ID means completed Worker, Hunter, Vanguard, Mystic, and Jadeclaw training events inherit the taiko effect without simulation changes. Every other runtime audio file remained byte-identical.

## Runtime inventory

| Domain | Runtime files | Coverage |
|---|---:|---|
| Music | 1 | Continuous title, faction-select, match, pause, and outcome score |
| Interface | 4 | Confirmation, cancellation, invalid action, selection |
| Orders | 3 | Move and rally, attack and hunt, work and repair assignment |
| Economy | 3 | Depositing, food harvest, repair pulse |
| Construction and production | 3 | Foundation placement, structure completion, unit readiness |
| Combat | 7 | Melee, ranged, magic, beast, impact, unit death, structure destruction |
| Objectives and outcomes | 3 | Objective secured, victory, defeat |
| **Total** | **24** | **One BGM stream plus 23 SFX streams** |

## Candidate selection

`tools/process_audio_assets.py` splits each audition reel into three equal windows labeled A, B, and C. Each window is decoded to mono PCM for deterministic analysis. The score uses duration, RMS level, peak headroom, active-signal ratio, excessive-silence penalties, and clipping penalties. The highest technically valid score wins unless a reviewed `--select-candidate NAME=LETTER` override is supplied. After the unit-completion regeneration and earlier cue retirement, nineteen A windows, three B windows, and one C window are selected across the twenty-three runtime SFX.

Technical selection does not pretend to replace a human mastering session. It establishes a repeatable baseline and preserves stable cue IDs; the taiko replacement demonstrates the auditable reviewed-override path. Any future subjective replacement can overwrite one semantic OGG path without changing simulation or UI code. The machine-readable `assets/runtime/audio/audio-report.json` records source-reel hashes, per-candidate metrics and hashes, selected windows, selection methods, runtime hashes, durations, and sizes.

## Processing contract

SFX winners are trimmed with a conservative silence gate, given short edge fades, normalized to controlled peak and integrated targets, resampled to 48 kHz stereo, and encoded with Ogg Vorbis quality 5. The score is normalized more gently, resampled to 48 kHz stereo, encoded with Ogg Vorbis quality 6, and receives a four-second equal-power wraparound crossfade. The loop begins after its original opening seam and ends with the same four-second opening material, which lets Godot return to the first processed frame without a discontinuity.

The generated source duration, selection metrics, and runtime hashes may change on regeneration. Runtime filenames, cue semantics, sample rate, and directory structure are the stable contract.

```bash
python3 tools/process_audio_assets.py
```

## Runtime integration

`AudioDirector` uses static `preload()` declarations for all 24 files, ensuring that Godot’s exporter includes them. It duplicates the imported Ogg music stream and enables looping at runtime. Sixteen pooled `AudioStreamPlayer` voices implement SFX playback. Cue policy defines bus, gain, pitch variance, cooldown, priority, and per-cue concurrency. Low-value repeated economy ticks yield to objective, destruction, error, and outcome cues.

The `Music`, `SFX`, and `UI` buses route to `Master`. They use gain only—no runtime audio effects—because Godot’s default low-latency Web Sample playback does not support bus effects.[1] Browser autoplay can require a user gesture, so `main.gd` attempts title playback and calls the unlock path again from every button and keyboard interaction.[2]

## References

[1]: https://docs.godotengine.org/en/4.7/tutorials/audio/audio_buses.html "Godot 4.7 audio buses"
[2]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html "Godot Engine: Exporting for the Web"
