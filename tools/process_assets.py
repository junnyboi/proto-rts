#!/usr/bin/env python3
"""Create optimized runtime derivatives from immutable GPT Image 2 masters."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "source"
RUNTIME = ROOT / "assets" / "runtime"

RESAMPLING = Image.Resampling.LANCZOS


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


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
) -> dict:
    image = remove_magenta(Image.open(source), feather_end, decontaminate_edge)
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
        save_isolated(
            SOURCE / "ui" / "idle_worker_alert.png",
            RUNTIME / "ui" / "idle_worker_alert.png",
            (48, 80),
            (42, 74),
            3,
            decontaminate_edge=True,
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
