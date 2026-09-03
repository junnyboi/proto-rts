#!/usr/bin/env python3
"""Process ElevenLabs audition reels and BGM into Godot-ready Ogg assets."""

from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import shutil
import struct
import subprocess
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path

LETTERS = ("A", "B", "C")
SAMPLE_RATE = 48_000
SILENCE_AMPLITUDE = 10 ** (-48.0 / 20.0)


@dataclass
class Metrics:
    duration_seconds: float
    peak_dbfs: float
    rms_dbfs: float
    active_ratio: float
    score: float


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        command,
        check=True,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.PIPE if capture else subprocess.DEVNULL,
    )


def probe_duration(path: Path) -> float:
    result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        capture=True,
    )
    return float(result.stdout.decode().strip())


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def decode_metrics(path: Path) -> Metrics:
    result = run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            str(path),
            "-ac",
            "1",
            "-ar",
            str(SAMPLE_RATE),
            "-f",
            "s16le",
            "-",
        ],
        capture=True,
    )
    samples = array.array("h")
    samples.frombytes(result.stdout)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        return Metrics(0.0, -120.0, -120.0, 0.0, -999.0)

    normalized = [sample / 32768.0 for sample in samples]
    peak = max(abs(value) for value in normalized)
    rms = math.sqrt(sum(value * value for value in normalized) / len(normalized))
    active = sum(1 for value in normalized if abs(value) >= SILENCE_AMPLITUDE) / len(normalized)
    peak_db = 20.0 * math.log10(max(peak, 1e-6))
    rms_db = 20.0 * math.log10(max(rms, 1e-6))
    duration = len(samples) / SAMPLE_RATE
    clipping_penalty = 6.0 if peak_db > -0.15 else 0.0
    silence_penalty = max(0.0, 0.12 - active) * 40.0
    score = rms_db + active * 7.0 - clipping_penalty - silence_penalty
    return Metrics(duration, peak_db, rms_db, active, score)


def split_reel(reel: Path, candidate_dir: Path) -> list[tuple[str, Path, Metrics]]:
    duration = probe_duration(reel)
    window = duration / 3.0
    candidates: list[tuple[str, Path, Metrics]] = []
    for index, letter in enumerate(LETTERS):
        output = candidate_dir / f"{reel.stem}_{letter}.mp3"
        run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-ss",
                f"{index * window:.6f}",
                "-t",
                f"{window:.6f}",
                "-i",
                str(reel),
                "-codec:a",
                "libmp3lame",
                "-q:a",
                "2",
                str(output),
            ]
        )
        candidates.append((letter, output, decode_metrics(output)))
    return candidates


def process_sfx(source: Path, output: Path, work_dir: Path) -> float:
    trimmed = work_dir / f"{source.stem}_trimmed.wav"
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-i",
            str(source),
            "-af",
            "silenceremove=start_periods=1:start_duration=0.02:start_threshold=-50dB:stop_periods=-1:stop_duration=0.16:stop_threshold=-50dB",
            "-ar",
            str(SAMPLE_RATE),
            "-ac",
            "2",
            str(trimmed),
        ]
    )
    duration = probe_duration(trimmed)
    fade_out_start = max(0.0, duration - 0.035)
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-i",
            str(trimmed),
            "-af",
            f"loudnorm=I=-17:TP=-2:LRA=7,afade=t=in:st=0:d=0.012,afade=t=out:st={fade_out_start:.6f}:d=0.035",
            "-ar",
            str(SAMPLE_RATE),
            "-codec:a",
            "libvorbis",
            "-q:a",
            "5",
            str(output),
        ]
    )
    trimmed.unlink(missing_ok=True)
    return probe_duration(output)


def process_bgm(source: Path, output: Path, work_dir: Path) -> dict[str, float]:
    duration = probe_duration(source)
    crossfade = 4.0
    if duration <= crossfade * 3:
        raise RuntimeError(f"BGM is too short for loop processing: {duration:.3f}s")
    main_trim = work_dir / "bgm_main.wav"
    head_trim = work_dir / "bgm_head.wav"
    temp = work_dir / "bgm_looped.wav"
    for start, end, destination in (
        (crossfade, duration, main_trim),
        (0.0, crossfade, head_trim),
    ):
        run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                str(source),
                "-af",
                f"atrim=start={start}:end={end},asetpts=PTS-STARTPTS",
                "-ar",
                str(SAMPLE_RATE),
                "-ac",
                "2",
                str(destination),
            ]
        )
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-i",
            str(main_trim),
            "-i",
            str(head_trim),
            "-filter_complex",
            f"[0:a][1:a]acrossfade=d={crossfade}:c1=qsin:c2=qsin,"
            "loudnorm=I=-20:TP=-2:LRA=10[out]",
            "-map",
            "[out]",
            "-ar",
            str(SAMPLE_RATE),
            "-ac",
            "2",
            str(temp),
        ]
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-i",
            str(temp),
            "-codec:a",
            "libvorbis",
            "-q:a",
            "6",
            str(output),
        ]
    )
    processed_duration = probe_duration(output)
    for working_file in (main_trim, head_trim, temp):
        working_file.unlink(missing_ok=True)
    return {
        "source_duration_seconds": duration,
        "crossfade_seconds": crossfade,
        "runtime_duration_seconds": processed_duration,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--candidates",
        type=Path,
        default=Path("/home/ubuntu/proto-rts-audio-candidates"),
    )
    parser.add_argument(
        "--runtime",
        type=Path,
        default=Path("assets/runtime/audio"),
    )
    parser.add_argument(
        "--only-sfx",
        nargs="+",
        default=[],
        help="Process only the named SFX reel stems and preserve all other report entries.",
    )
    parser.add_argument(
        "--skip-bgm",
        action="store_true",
        help="Preserve the existing BGM derivative and report entry.",
    )
    args = parser.parse_args()

    candidate_root = args.candidates.resolve()
    runtime_root = args.runtime.resolve()
    reel_dir = candidate_root / "reels"
    split_dir = candidate_root / "sfx"
    bgm_dir = runtime_root / "bgm"
    sfx_dir = runtime_root / "sfx"
    work_dir = candidate_root / ".work"
    for directory in (split_dir, bgm_dir, sfx_dir, work_dir):
        directory.mkdir(parents=True, exist_ok=True)

    report_path = runtime_root / "audio-report.json"
    if args.only_sfx or args.skip_bgm:
        if not report_path.exists():
            raise RuntimeError("Targeted processing requires an existing audio report")
        report: dict[str, object] = json.loads(report_path.read_text())
    else:
        report = {"sfx": {}}
    report["generated_at"] = datetime.now(timezone.utc).isoformat()
    report["generator"] = "Built-in ElevenLabs via Manus generate_music/generate_sound_effect"
    report["selection_policy"] = "Highest technical score across equal-third A/B/C reel windows"
    report.setdefault("sfx", {})

    reels = sorted(reel_dir.glob("*.mp3"))
    if args.only_sfx:
        requested = set(args.only_sfx)
        available = {reel.stem for reel in reels}
        missing = sorted(requested - available)
        if missing:
            raise RuntimeError(f"Missing requested SFX reels: {', '.join(missing)}")
        reels = [reel for reel in reels if reel.stem in requested]
    for reel in reels:
        candidates = split_reel(reel, split_dir)
        selected_letter, selected_path, selected_metrics = max(
            candidates,
            key=lambda item: item[2].score,
        )
        runtime_path = sfx_dir / f"{reel.stem}.ogg"
        runtime_duration = process_sfx(selected_path, runtime_path, work_dir)
        report["sfx"][reel.stem] = {
            "source_reel": str(reel),
            "source_reel_sha256": sha256(reel),
            "selected_candidate": selected_letter,
            "selected_source": str(selected_path),
            "selected_source_sha256": sha256(selected_path),
            "runtime_path": str(runtime_path),
            "runtime_sha256": sha256(runtime_path),
            "runtime_duration_seconds": runtime_duration,
            "runtime_size_bytes": runtime_path.stat().st_size,
            "candidates": {
                letter: {**asdict(metrics), "path": str(path), "sha256": sha256(path)}
                for letter, path, metrics in candidates
            },
        }
        print(f"{reel.stem}: selected {selected_letter} -> {runtime_path.name}")

    bgm_output = bgm_dir / "the_jade_meridian_endures.ogg"
    if args.skip_bgm:
        if not bgm_output.exists() or "bgm" not in report:
            raise RuntimeError("Cannot preserve a missing BGM derivative or report entry")
    else:
        bgm_source = candidate_root / "bgm" / "the_jade_meridian_endures.wav"
        bgm_metrics = process_bgm(bgm_source, bgm_output, work_dir)
        report["bgm"] = {
            "source": str(bgm_source),
            "source_sha256": sha256(bgm_source),
            "runtime_path": str(bgm_output),
            "runtime_sha256": sha256(bgm_output),
            "runtime_size_bytes": bgm_output.stat().st_size,
            **bgm_metrics,
        }

    shutil.rmtree(work_dir, ignore_errors=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    runtime_audio_paths = sorted([bgm_output, *sfx_dir.glob("*.ogg")])
    checksum_path = runtime_root / "SHA256SUMS"
    checksum_path.write_text(
        "".join(
            f"{sha256(path)}  {path.relative_to(runtime_root)}\n"
            for path in runtime_audio_paths
        )
    )
    print(f"Wrote {report_path}")
    print(f"Wrote {checksum_path}")


if __name__ == "__main__":
    main()
