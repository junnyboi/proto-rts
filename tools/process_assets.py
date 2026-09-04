#!/usr/bin/env python3
"""Create optimized runtime derivatives from immutable GPT Image 2 masters."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "source"
RUNTIME = ROOT / "assets" / "runtime"

RESAMPLING = Image.Resampling.LANCZOS

# Original GPT Image 2 masters remain immutable. These aligned replacements
# correct source-facing outliers while preserving stable runtime asset paths.
FORTIFICATION_SOURCE_OVERRIDES = {
    ("celestial", "wall"): "celestial_wall_aligned.png",
    ("demon", "gate"): "demon_gate_aligned.png",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def probe_audio_duration(path: Path) -> float:
    result = subprocess.run(
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
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return float(result.stdout.strip())


def refresh_audio_checksums(audio_root: Path) -> None:
    runtime_audio_paths = sorted(
        [
            audio_root / "bgm" / "the_jade_meridian_endures.ogg",
            *(audio_root / "sfx").glob("*.ogg"),
        ]
    )
    checksum_lines = [
        f"{sha256(path)}  {path.relative_to(audio_root)}"
        for path in runtime_audio_paths
    ]
    (audio_root / "SHA256SUMS").write_text(
        "\n".join(checksum_lines) + "\n",
        encoding="utf-8",
    )


def truncate_audio_to_first_half(source: Path, cue_name: str) -> None:
    if Path(cue_name).name != cue_name or not cue_name:
        raise ValueError("Audio cue must be a filename stem without path separators")
    if not source.is_file():
        raise FileNotFoundError(f"Audio source does not exist: {source}")

    audio_root = RUNTIME / "audio"
    destination = audio_root / "sfx" / f"{cue_name}.ogg"
    if not destination.is_file():
        raise FileNotFoundError(f"Runtime audio cue does not exist: {destination}")
    if source.resolve() == destination.resolve():
        raise ValueError("Use a separate source file so truncation is repeatable")

    source_duration = probe_audio_duration(source)
    target_duration = source_duration / 2.0
    fade_duration = min(0.035, target_duration)
    fade_start = max(0.0, target_duration - fade_duration)
    original_runtime_sha256 = sha256(destination)

    with tempfile.TemporaryDirectory(prefix="proto-rts-audio-") as temp_dir:
        processed = Path(temp_dir) / destination.name
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                str(source),
                "-af",
                (
                    f"atrim=end={target_duration:.9f},asetpts=PTS-STARTPTS,"
                    f"afade=t=out:st={fade_start:.9f}:d={fade_duration:.9f}"
                ),
                "-ar",
                "48000",
                "-ac",
                "2",
                "-codec:a",
                "libvorbis",
                "-q:a",
                "5",
                str(processed),
            ],
            check=True,
        )
        processed.replace(destination)

    runtime_duration = probe_audio_duration(destination)
    report_path = audio_root / "audio-report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    cue_report = report["sfx"][cue_name]
    cue_report["runtime_sha256"] = sha256(destination)
    cue_report["runtime_duration_seconds"] = runtime_duration
    cue_report["runtime_size_bytes"] = destination.stat().st_size
    cue_report["postprocessing"] = {
        "operation": "keep_first_half",
        "input_sha256": sha256(source),
        "previous_runtime_sha256": original_runtime_sha256,
        "input_duration_seconds": source_duration,
        "target_duration_seconds": target_duration,
        "fade_out_seconds": fade_duration,
    }
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    refresh_audio_checksums(audio_root)
    print(
        f"{cue_name}: {source_duration:.6f}s -> {runtime_duration:.6f}s "
        "(kept first half)"
    )


def save_webp(source: Path, destination: Path, size: tuple[int, int], quality: int = 84) -> dict:
    image = Image.open(source).convert("RGB")
    image.thumbnail(size, RESAMPLING)
    canvas = Image.new("RGB", size, (12, 20, 22))
    offset = ((size[0] - image.width) // 2, (size[1] - image.height) // 2)
    canvas.paste(image, offset)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "WEBP", quality=quality, method=6)
    return describe(destination, source)


def remove_magenta(
    image: Image.Image,
    feather_end: float = 145.0,
    decontaminate_edge: bool = False,
) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    samples = [pixels[4, 4], pixels[width - 5, 4], pixels[4, height - 5], pixels[width - 5, height - 5]]
    key = tuple(sum(sample[channel] for sample in samples) / len(samples) for channel in range(3))

    for y in range(height):
        for x in range(width):
            red, green, blue, _ = pixels[x, y]
            distance = ((red - key[0]) ** 2 + (green - key[1]) ** 2 + (blue - key[2]) ** 2) ** 0.5
            magenta_dominance = min(red, blue) - green
            if magenta_dominance < 45 or red < 125 or blue < 125:
                alpha = 255
            elif distance <= 55:
                alpha = 0
            elif distance >= feather_end:
                alpha = 255
            else:
                alpha = round(255 * (distance - 55) / (feather_end - 55))
            if decontaminate_edge and 0 < alpha < 255:
                opacity = alpha / 255.0
                red = round((red - (1.0 - opacity) * key[0]) / opacity)
                green = round((green - (1.0 - opacity) * key[1]) / opacity)
                blue = round((blue - (1.0 - opacity) * key[2]) / opacity)
                red = max(0, min(255, red))
                green = max(0, min(255, green))
                blue = max(0, min(255, blue))
            pixels[x, y] = (red, green, blue, alpha)
    return rgba


def save_isolated(
    source: Path,
    destination: Path,
    canvas_size: tuple[int, int],
    content_size: tuple[int, int],
    bottom_margin: int,
    feather_end: float = 145.0,
    decontaminate_edge: bool = False,
    preserve_source_alpha: bool = False,
) -> dict:
    source_image = Image.open(source)
    image = (
        source_image.convert("RGBA")
        if preserve_source_alpha
        else remove_magenta(source_image, feather_end, decontaminate_edge)
    )
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"No subject pixels found in {source}")
    image = image.crop(bbox)
    image.thumbnail(content_size, RESAMPLING)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (canvas_size[0] - image.width) // 2
    y = canvas_size[1] - bottom_margin - image.height
    canvas.alpha_composite(image, (x, max(0, y)))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "PNG", optimize=True)
    return describe(destination, source)


def save_transparent_icon(
    source: Path,
    destination: Path,
    canvas_size: tuple[int, int] = (64, 64),
    content_size: tuple[int, int] = (58, 58),
) -> dict:
    """Trim and downsample a transparent UI master without changing its silhouette."""
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 2 else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"No cursor pixels found in {source}")
    image = image.crop(bbox)
    image.thumbnail(content_size, RESAMPLING)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    offset = ((canvas_size[0] - image.width) // 2, (canvas_size[1] - image.height) // 2)
    canvas.alpha_composite(image, offset)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "PNG", optimize=True)
    return describe(destination, source)


def save_transparent_layer(
    source: Path,
    destination: Path,
    size: tuple[int, int],
) -> dict:
    """Resize a full-canvas GPT Image 2 layer while preserving authored alpha."""
    image = Image.open(source).convert("RGBA").resize(size, RESAMPLING)
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, "PNG", optimize=True)
    return describe(destination, source)


def save_keyed_icon(
    source: Path,
    destination: Path,
    canvas_size: tuple[int, int] = (64, 64),
    content_size: tuple[int, int] = (58, 58),
) -> dict:
    """Extract a magenta-isolated UI master, trim it, and center it on alpha."""
    image = remove_magenta(Image.open(source), feather_end=220.0, decontaminate_edge=True)
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 2 else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"No icon pixels found in {source}")
    image = image.crop(bbox)
    image.thumbnail(content_size, RESAMPLING)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    offset = ((canvas_size[0] - image.width) // 2, (canvas_size[1] - image.height) // 2)
    canvas.alpha_composite(image, offset)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "PNG", optimize=True)
    return describe(destination, source)


def save_cursor(
    source: Path,
    destination: Path,
    canvas_size: tuple[int, int] = (64, 64),
    content_size: tuple[int, int] = (58, 58),
) -> dict:
    return save_transparent_icon(source, destination, canvas_size, content_size)


def describe(path: Path, source: Path) -> dict:
    with Image.open(path) as image:
        extrema = image.getchannel("A").getextrema() if "A" in image.getbands() else None
        return {
            "path": str(path.relative_to(ROOT)),
            "source": str(source.relative_to(ROOT)),
            "width": image.width,
            "height": image.height,
            "mode": image.mode,
            "alpha_extrema": list(extrema) if extrema else None,
            "sha256": sha256(path),
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--truncate-audio-first-half",
        metavar="CUE",
        help="Keep the first half of one existing runtime SFX cue.",
    )
    parser.add_argument(
        "--audio-source",
        type=Path,
        help="Separate input file for --truncate-audio-first-half.",
    )
    args = parser.parse_args()
    if args.truncate_audio_first_half:
        if args.audio_source is None:
            parser.error("--audio-source is required when truncating audio")
        truncate_audio_to_first_half(
            args.audio_source.resolve(),
            args.truncate_audio_first_half,
        )
        return
    if args.audio_source is not None:
        parser.error("--audio-source requires --truncate-audio-first-half")

    records: list[dict] = []

    records.append(
        save_webp(
            SOURCE / "key_art" / "mandate_of_myth_title.png",
            RUNTIME / "ui" / "mandate_of_myth_title.webp",
            (1600, 900),
            quality=86,
        )
    )
    records.append(
        save_webp(
            SOURCE / "backgrounds" / "jade_meridian_backdrop.png",
            RUNTIME / "backgrounds" / "jade_meridian_backdrop.webp",
            (1600, 900),
            quality=86,
        )
    )
    records.append(
        save_transparent_layer(
            SOURCE / "foregrounds" / "jade_meridian_foreground.png",
            RUNTIME / "foregrounds" / "jade_meridian_foreground.png",
            (1600, 900),
        )
    )
    records.append(
        save_transparent_layer(
            SOURCE / "ui" / "mandate_pause_frame.png",
            RUNTIME / "ui" / "mandate_pause_frame.png",
            (560, 660),
        )
    )
    records.append(
        save_isolated(
            SOURCE / "ui" / "idle_worker_alert.png",
            RUNTIME / "ui" / "idle_worker_alert.png",
            (48, 80),
            (42, 74),
            3,
            decontaminate_edge=True,
        )
    )

    for cursor in (
        "select",
        "ui_action",
        "box_select",
        "move",
        "attack",
        "attack_move",
        "patrol",
        "rally",
        "gather_jade",
        "gather_lumber",
        "gather_essence",
        "hunt",
        "deposit",
        "repair",
        "build",
        "forbidden",
        "pan",
    ):
        records.append(
            save_cursor(
                SOURCE / "cursors" / f"{cursor}.png",
                RUNTIME / "cursors" / f"{cursor}.png",
            )
        )

    for indicator, content_size in (
        ("destination_flag", (72, 90)),
        ("interaction_ring", (90, 90)),
        ("attack_swords", (90, 90)),
    ):
        records.append(
            save_transparent_icon(
                SOURCE / "command_indicators" / f"{indicator}.png",
                RUNTIME / "command_indicators" / f"{indicator}.png",
                (96, 96),
                content_size,
            )
        )

    for resource_icon in ("jade", "lumber", "essence", "population", "dens"):
        records.append(
            save_keyed_icon(
                SOURCE / "ui" / "resource_icons" / f"{resource_icon}.png",
                RUNTIME / "ui" / "resource_icons" / f"{resource_icon}.png",
                (64, 64),
                (58, 58),
            )
        )
    records.append(
        save_transparent_icon(
            SOURCE / "ui" / "resource_icons" / "food.png",
            RUNTIME / "ui" / "resource_icons" / "food.png",
            (64, 64),
            (58, 58),
        )
    )

    for utility_icon in ("pause", "resume", "audio_on"):
        records.append(
            save_keyed_icon(
                SOURCE / "ui" / "utility_icons" / f"{utility_icon}.png",
                RUNTIME / "ui" / "utility_icons" / f"{utility_icon}.png",
                (64, 64),
                (54, 54),
            )
        )
    records.append(
        save_transparent_icon(
            SOURCE / "ui" / "utility_icons" / "audio_muted.png",
            RUNTIME / "ui" / "utility_icons" / "audio_muted.png",
            (64, 64),
            (54, 54),
        )
    )

    for faction in ("celestial", "demon", "beast", "human"):
        records.append(
            save_webp(
                SOURCE / "factions" / f"{faction}_portrait.png",
                RUNTIME / "portraits" / f"{faction}.webp",
                (360, 480),
                quality=84,
            )
        )
        for kind in ("worker", "vanguard", "mystic"):
            records.append(
                save_isolated(
                    SOURCE / "units" / f"{faction}_{kind}.png",
                    RUNTIME / "units" / f"{faction}_{kind}.png",
                    (160, 176),
                    (140, 158),
                    8,
                )
            )
        if faction != "celestial":
            hunter_source = "human_hunter_female.png" if faction == "human" else f"{faction}_hunter.png"
            records.append(
                save_isolated(
                    SOURCE / "units" / hunter_source,
                    RUNTIME / "units" / f"{faction}_hunter.png",
                    (160, 176),
                    (140, 158),
                    8,
                    decontaminate_edge=True,
                )
            )
        for kind in ("stronghold", "war_camp"):
            records.append(
                save_isolated(
                    SOURCE / "buildings" / f"{faction}_{kind}.png",
                    RUNTIME / "buildings" / f"{faction}_{kind}.png",
                    (288, 240),
                    (264, 222),
                    8,
                )
            )
        for kind, canvas_size, content_size in (
            ("wall", (192, 160), (180, 148)),
            ("gate", (400, 272), (384, 256)),
            ("sentry_tower", (304, 288), (288, 272)),
        ):
            source_name = FORTIFICATION_SOURCE_OVERRIDES.get(
                (faction, kind),
                f"{faction}_{kind}.png",
            )
            records.append(
                save_isolated(
                    SOURCE / "buildings" / source_name,
                    RUNTIME / "buildings" / f"{faction}_{kind}.png",
                    canvas_size,
                    content_size,
                    8,
                    decontaminate_edge=True,
                    preserve_source_alpha=faction == "demon" and kind == "wall",
                )
            )

    records.append(
        save_isolated(
            SOURCE / "units" / "neutral_jadeclaw.png",
            RUNTIME / "units" / "neutral_jadeclaw.png",
            (192, 176),
            (180, 164),
            6,
        )
    )
    records.append(
        save_isolated(
            SOURCE / "units" / "neutral_shenlong.png",
            RUNTIME / "units" / "neutral_shenlong.png",
            (336, 272),
            (320, 256),
            6,
            220.0,
            True,
        )
    )
    records.append(
        save_isolated(
            SOURCE / "objectives" / "shenlong_egg.png",
            RUNTIME / "objectives" / "shenlong_egg.png",
            (176, 176),
            (160, 160),
            6,
            220.0,
            True,
        )
    )

    for wildlife, canvas_size, content_size in (
        ("chicken", (96, 88), (82, 74)),
        ("deer", (144, 120), (132, 108)),
        ("bison", (176, 136), (164, 124)),
        ("boar", (144, 112), (132, 100)),
        ("bear", (176, 136), (164, 124)),
    ):
        records.append(
            save_isolated(
                SOURCE / "wildlife" / f"{wildlife}.png",
                RUNTIME / "wildlife" / f"{wildlife}.png",
                canvas_size,
                content_size,
                6,
                decontaminate_edge=True,
            )
        )
    records.append(
        save_isolated(
            SOURCE / "buildings" / "neutral_yaoguai_den.png",
            RUNTIME / "buildings" / "neutral_yaoguai_den.png",
            (320, 272),
            (304, 254),
            8,
        )
    )

    for source_name, runtime_name, canvas_size, content_size in (
        ("rice_farm", "rice_farm", (336, 280), (320, 264)),
        ("hunters_lodge_v2", "hunters_lodge", (304, 256), (288, 240)),
    ):
        records.append(
            save_isolated(
                SOURCE / "buildings" / f"{source_name}.png",
                RUNTIME / "buildings" / f"{runtime_name}.png",
                canvas_size,
                content_size,
                8,
                decontaminate_edge=True,
            )
        )

    terrain_names = (
        "jade_meadow",
        "inkstone_ridge",
        "celadon_water",
        "jade_forest",
        "meridian_road",
        "moon_bridge",
    )
    for terrain in terrain_names:
        source = SOURCE / "terrain" / f"{terrain}.png"
        destination = RUNTIME / "terrain" / f"{terrain}.webp"
        image = Image.open(source).convert("RGB").resize((512, 512), RESAMPLING)
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.save(destination, "WEBP", quality=82, method=6)
        records.append(describe(destination, source))

    for resource in ("jade_outcrop", "essence_shrine"):
        records.append(
            save_isolated(
                SOURCE / "resources" / f"{resource}.png",
                RUNTIME / "resources" / f"{resource}.png",
                (176, 160),
                (158, 142),
                8,
            )
        )

    for tree in ("lumber_pine", "lumber_cedar", "lumber_fir", "lumber_juniper"):
        records.append(
            save_isolated(
                SOURCE / "resources" / f"{tree}.png",
                RUNTIME / "resources" / f"{tree}.png",
                (224, 256),
                (212, 244),
                6,
                220.0,
                True,
            )
        )

    report = {"generator": "GPT Image 2", "runtime_asset_count": len(records), "assets": records}
    report_path = RUNTIME / "asset-report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    sums = [f"{sha256(ROOT / record['path'])}  {record['path']}" for record in records]
    sums.append(f"{sha256(report_path)}  {report_path.relative_to(ROOT)}")
    (RUNTIME / "SHA256SUMS").write_text("\n".join(sums) + "\n", encoding="utf-8")

    print(f"Processed {len(records)} runtime assets")
    for record in records:
        print(f"{record['path']}: {record['width']}x{record['height']} {record['mode']}")


if __name__ == "__main__":
    main()
