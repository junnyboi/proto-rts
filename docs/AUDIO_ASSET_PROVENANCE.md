# Mandate of Myth — ElevenLabs Audio Asset Provenance

**Generation date:** 2 September 2026  
**Generator:** Built-in ElevenLabs integrations exposed through Manus  
**Runtime target:** Godot 4.7 single-threaded Web export

## Generation record

One background-music source and twenty-four SFX audition reels were generated for this project. The music request targeted 150 seconds; the generated source is 145.659 seconds. The SFX prompts requested three related variants in each reel so the final runtime vocabulary could be selected without spending one generation call per candidate. The candidate library is retained outside the Godot import root at `/home/ubuntu/proto-rts-audio-candidates/`. Only selected, processed Ogg Vorbis derivatives enter the project.

The score prompt specified instrumental-only cinematic Chinese-mythology strategy music at approximately 76 BPM in D minor with D-pentatonic emphasis. Its palette comprises guzheng, xiao, restrained erhu, pipa harmonics, low bowed strings, sparse tanggu, muted bronze bells, and subtle wind-and-water ambience. The composition moves from a sparse title opening to measured economy and exploration, reaches a controlled tactical lift, then returns to the original tonal center and density. Vocals, choir, EDM bass, modern drums, trailer braams, abrupt endings, and existing melodies were explicitly excluded.

The SFX prompts share a hand-crafted, family-friendly fantasy treatment. Jade-like stone, antique bronze, bamboo, silk, timber, packed earth, tile, leather, rice, woven baskets, armor, bows, blades, spiritual air, and restrained bestial mass form a coherent material vocabulary. Voices, gore, modern weapons, electronic alarms, comedy buzzers, and excessive cinematic sub-bass were excluded.

## Runtime inventory

| Domain | Runtime files | Coverage |
|---|---:|---|
| Music | 1 | Continuous title, faction-select, match, pause, and outcome score |
| Interface | 4 | Confirmation, cancellation, invalid action, selection |
| Orders | 3 | Move and rally, attack and hunt, work and repair assignment |
| Economy | 4 | Gathering, depositing, food harvest, repair pulse |
| Construction and production | 3 | Foundation placement, structure completion, unit readiness |
| Combat | 7 | Melee, ranged, magic, beast, impact, unit death, structure destruction |
| Objectives and outcomes | 3 | Objective secured, victory, defeat |
| **Total** | **25** | **One BGM stream plus 24 SFX streams** |

## Candidate selection

`tools/process_audio_assets.py` splits each audition reel into three equal windows labeled A, B, and C. Each window is decoded to mono PCM for deterministic analysis. The score uses duration, RMS level, peak headroom, active-signal ratio, excessive-silence penalties, and clipping penalties. The highest technically valid score wins. Across this generation, twenty A windows, two B windows, and two C windows were selected.

Technical selection does not pretend to replace a human mastering session. It establishes a repeatable baseline and preserves stable cue IDs. Any future subjective replacement can overwrite one semantic OGG path without changing simulation or UI code. The machine-readable `assets/runtime/audio/audio-report.json` records source-reel hashes, per-candidate metrics and hashes, selected windows, runtime hashes, durations, and sizes.

## Processing contract

SFX winners are trimmed with a conservative silence gate, given short edge fades, normalized to controlled peak and integrated targets, resampled to 48 kHz stereo, and encoded with Ogg Vorbis quality 5. The score is normalized more gently, resampled to 48 kHz stereo, encoded with Ogg Vorbis quality 6, and receives a four-second equal-power wraparound crossfade. The loop begins after its original opening seam and ends with the same four-second opening material, which lets Godot return to the first processed frame without a discontinuity.

The generated source duration, selection metrics, and runtime hashes may change on regeneration. Runtime filenames, cue semantics, sample rate, and directory structure are the stable contract.

```bash
python3 tools/process_audio_assets.py
```

## Runtime integration

`AudioDirector` uses static `preload()` declarations for all 25 files, ensuring that Godot’s exporter includes them. It duplicates the imported Ogg music stream and enables looping at runtime. Sixteen pooled `AudioStreamPlayer` voices implement SFX playback. Cue policy defines bus, gain, pitch variance, cooldown, priority, and per-cue concurrency. Low-value repeated economy ticks yield to objective, destruction, error, and outcome cues.

The `Music`, `SFX`, and `UI` buses route to `Master`. They use gain only—no runtime audio effects—because Godot’s default low-latency Web Sample playback does not support bus effects.[1] Browser autoplay can require a user gesture, so `main.gd` attempts title playback and calls the unlock path again from every button and keyboard interaction.[2]

## References

[1]: https://docs.godotengine.org/en/4.7/tutorials/audio/audio_buses.html "Godot 4.7 audio buses"
[2]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html "Godot Engine: Exporting for the Web"
