from __future__ import annotations

import json
from collections import Counter
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from .palette import Palette, PaletteError, validate_contrast
from .color import oklab, oklch
from .interpretation import Candidate, interpret, parameters as backend_parameters


class ExtractorError(RuntimeError):
    pass


RGB = tuple[int, int, int]
NATIVE_MODES = ("spectrum", "clustered", "median-cut", "weighted-regions")


def extract_colors(pixels: list[RGB], mode: str, image_size: tuple[int, int] | None, options: dict) -> list[Candidate]:
    if mode == "weighted-regions" and image_size is not None:
        return _spatial_candidates(pixels, image_size, options["spatial_grid_size"])
    if mode == "clustered":
        pairs = _clustered_candidates(pixels, options["cluster_count"])
    elif mode == "median-cut":
        pairs = _median_cut_candidates(pixels, options["color_count"])
    elif mode == "weighted-regions":
        pairs = _weighted_region_candidates(pixels)
    else:
        pairs = _binned_colors(pixels)
    return [Candidate(color, weight, center=weight ** 0.5, edge=weight, focal=weight ** 0.5 * oklch(color)[1],
                      highlight=weight ** 0.5 * oklch(color)[0] ** 3) for color, weight in pairs]


def palette_from_pixels(
    pixels: list[RGB], image_name: str, fallback: Palette, mode: str = "spectrum",
    light_fallback: Palette | None = None, variant: str = "auto", *,
    image_size: tuple[int, int] | None = None, parameters: dict | None = None,
    debug: dict | None = None,
) -> Palette:
    if not pixels:
        raise ExtractorError("Native extraction requires at least one pixel")
    if mode not in NATIVE_MODES:
        raise ExtractorError(f"Unknown native extraction mode: {mode}")
    if variant not in {"auto", "dark", "light"}:
        raise ExtractorError(f"Unknown native palette variant: {variant}")
    if image_size is not None and (min(image_size) <= 0 or image_size[0] * image_size[1] != len(pixels)):
        raise ExtractorError("Image dimensions must match the pixel count")
    if variant == "auto":
        average = sum(_luminance(pixel) for pixel in pixels) / len(pixels)
        variant = "light" if average >= 0.62 else "dark"
    semantic = light_fallback if variant == "light" and light_fallback is not None else fallback
    try:
        options = backend_parameters(mode, parameters)
        candidates = extract_colors(pixels, mode, image_size, options)
        palette = interpret(candidates, image_name, mode, variant, semantic, options, debug)
        if debug is not None:
            debug.update({"mode": mode, "variant": variant, "image_size": image_size,
                          "spatial_coordinates_available": image_size is not None,
                          "extraction": "spatial grid" if mode == "weighted-regions" and image_size else mode})
        return palette
    except (PaletteError, ValueError) as error:
        raise ExtractorError(f"Native palette failed Spectrum validation: {error}") from error


def extract_native_ppm(
    image: Path,
    fallback: Palette,
    mode: str = "spectrum",
    light_fallback: Palette | None = None,
    variant: str = "auto",
) -> Palette:
    try:
        data = image.read_bytes()
    except OSError as error:
        raise ExtractorError(f"Cannot read wallpaper {image}: {error}") from error
    pixels, width, height = _decode_ppm(data)
    return palette_from_pixels(pixels, image.name, fallback, mode, light_fallback, variant, image_size=(width, height))


def extract_native_image(
    image: Path,
    fallback: Palette,
    mode: str = "spectrum",
    light_fallback: Palette | None = None,
    variant: str = "auto",
    *, parameters: dict | None = None, debug: dict | None = None,
) -> Palette:
    pixels, width, height = decode_native_image(image)
    return palette_from_pixels(pixels, image.name, fallback, mode, light_fallback, variant,
                               image_size=(width, height), parameters=parameters, debug=debug)


def decode_native_image(image: Path) -> tuple[list[RGB], int, int]:
    executable = shutil.which("ffmpeg")
    if executable is None:
        raise ExtractorError("FFmpeg is required to decode wallpaper images")
    if not image.is_file():
        raise ExtractorError(f"Wallpaper is not a readable file: {image}")
    command = (
        executable,
        "-v",
        "error",
        "-i",
        str(image),
        "-vf",
        "scale=160:160:force_original_aspect_ratio=decrease",
        "-f",
        "image2pipe",
        "-vcodec",
        "ppm",
        "-",
    )
    try:
        result = subprocess.run(command, check=True, capture_output=True, timeout=30)
    except subprocess.TimeoutExpired as error:
        raise ExtractorError("FFmpeg timed out while decoding the wallpaper") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.decode(errors="replace").strip() or "unknown FFmpeg error"
        raise ExtractorError(f"FFmpeg could not decode the wallpaper: {detail}") from error
    return _decode_ppm(result.stdout)


def _clustered_candidates(pixels: list[RGB], count: int = 8) -> list[tuple[RGB, int]]:
    histogram = Counter(dict(_binned_colors(pixels)))
    colors = sorted(histogram)
    centers = [max(colors, key=lambda color: (histogram[color], tuple(-value for value in color)))]
    while len(centers) < min(count, len(colors)):
        centers.append(
            max(
                (color for color in colors if color not in centers),
                key=lambda color: (min(_distance_squared(color, center) for center in centers), histogram[color], color),
            )
        )
    assignments: dict[RGB, list[tuple[RGB, int]]] = {}
    for _ in range(12):
        assignments = {center: [] for center in centers}
        for color in colors:
            center = min(centers, key=lambda candidate: (_distance_squared(color, candidate), candidate))
            assignments[center].append((color, histogram[color]))
        updated = [_weighted_mean(group) if group else center for center, group in assignments.items()]
        if updated == centers:
            break
        centers = updated
    result = []
    for center, group in assignments.items():
        result.append((center, sum(weight for _, weight in group)))
    return sorted(result, key=lambda item: (-item[1], item[0]))


def _binned_colors(pixels: list[RGB]) -> list[tuple[RGB, int]]:
    groups = {}
    for color, count in Counter(pixels).items():
        entry = groups.setdefault(_quantize(color), [0, [0, 0, 0]])
        entry[0] += count
        for channel in range(3):
            entry[1][channel] += color[channel] * count
    return sorted([(tuple(round(channel / count) for channel in channels), count)
                   for count, channels in groups.values()], key=lambda item: (-item[1], item[0]))


def _median_cut_candidates(pixels: list[RGB], count: int = 8) -> list[tuple[RGB, int]]:
    histogram = Counter(pixels)
    boxes = [list(histogram.items())]
    while len(boxes) < min(count, len(histogram)):
        splittable = [box for box in boxes if len(box) > 1]
        if not splittable:
            break
        box = max(splittable, key=lambda group: (_box_range(group) * sum(weight for _, weight in group), group))
        boxes.remove(box)
        channel = max(range(3), key=lambda index: max(color[index] for color, _ in box) - min(color[index] for color, _ in box))
        ordered = sorted(box, key=lambda item: (item[0][channel], item[0]))
        midpoint = sum(weight for _, weight in ordered) / 2
        running = 0
        split = 1
        for index, (_, weight) in enumerate(ordered[:-1], start=1):
            running += weight
            if running >= midpoint:
                split = index
                break
        boxes.extend((ordered[:split], ordered[split:]))
    result = [(_weighted_mean(box), sum(weight for _, weight in box)) for box in boxes]
    return sorted(result, key=lambda item: (-item[1], item[0]))


def _weighted_region_candidates(pixels: list[RGB]) -> list[tuple[RGB, int]]:
    histogram = Counter(pixels)
    minimum = tuple(min(color[index] for color in histogram) for index in range(3))
    maximum = tuple(max(color[index] for color in histogram) for index in range(3))
    groups: dict[tuple[int, int, int], list[tuple[RGB, int]]] = {}
    for color, weight in histogram.items():
        region = tuple(_region_index(color[index], minimum[index], maximum[index]) for index in range(3))
        groups.setdefault(region, []).append((color, weight))
    result = [(_weighted_mean(group), sum(weight for _, weight in group)) for group in groups.values()]
    return sorted(result, key=lambda item: (-item[1], item[0]))[:8]


def _spatial_candidates(pixels: list[RGB], image_size: tuple[int, int], grid_size: int) -> list[Candidate]:
    width, height = image_size
    mean_lab = tuple(sum(oklab(color)[index] for color in pixels) / len(pixels) for index in range(3))
    groups = {}
    for position, color in enumerate(pixels):
        cell_x = min(grid_size - 1, (position % width) * grid_size // width)
        cell_y = min(grid_size - 1, (position // width) * grid_size // height)
        x, y = (cell_x + 0.5) / grid_size, (cell_y + 0.5) / grid_size
        radius = max(abs(2 * x - 1), abs(2 * y - 1))
        center, edge = (1 - radius) ** 2, radius ** 2
        lab = oklab(color)
        salience = sum((first - second) ** 2 for first, second in zip(lab, mean_lab)) ** 0.5
        lightness, chroma, _ = oklch(color)
        key = _quantize(color)
        entry = groups.setdefault(key, [0, [0, 0, 0], 0.0, 0.0, 0.0, 0.0])
        entry[0] += 1
        for index in range(3):
            entry[1][index] += color[index]
        entry[2] += center
        entry[3] += edge
        entry[4] += salience * (0.25 + center)
        entry[5] += lightness ** 3 * (0.02 + chroma)
    candidates = []
    for count, channels, center, edge, focal, highlight in groups.values():
        color = tuple(round(channel / count) for channel in channels)
        root = count ** 0.5
        candidates.append(Candidate(color, count, center / root, edge, focal / root, highlight / root))
    return sorted(candidates, key=lambda item: (-item.weight, item.color))


def _weighted_mean(colors: list[tuple[RGB, int]]) -> RGB:
    total = sum(weight for _, weight in colors)
    return tuple(round(sum(color[index] * weight for color, weight in colors) / total) for index in range(3))


def _distance_squared(first: RGB, second: RGB) -> float:
    return sum((a - b) ** 2 for a, b in zip(oklab(first), oklab(second)))


def _box_range(colors: list[tuple[RGB, int]]) -> int:
    return max(max(color[index] for color, _ in colors) - min(color[index] for color, _ in colors) for index in range(3))


def _region_index(value: int, minimum: int, maximum: int) -> int:
    if maximum == minimum:
        return 0
    return min(2, int((value - minimum) * 3 / (maximum - minimum + 1)))


def _decode_ppm(data: bytes) -> tuple[list[RGB], int, int]:
    position = 0

    def token() -> bytes:
        nonlocal position
        while position < len(data):
            if data[position] == 35:
                while position < len(data) and data[position] not in (10, 13):
                    position += 1
            elif chr(data[position]).isspace():
                position += 1
            else:
                break
        start = position
        while position < len(data) and not chr(data[position]).isspace() and data[position] != 35:
            position += 1
        return data[start:position]

    magic = token()
    try:
        width = int(token())
        height = int(token())
        maximum = int(token())
    except ValueError as error:
        raise ExtractorError("PPM header contains an invalid number") from error
    if magic not in {b"P3", b"P6"} or width <= 0 or height <= 0 or maximum != 255:
        raise ExtractorError("Native prototype supports 8-bit P3 and P6 PPM images")

    count = width * height * 3
    if magic == b"P3":
        try:
            channels = [int(token()) for _ in range(count)]
        except ValueError as error:
            raise ExtractorError("PPM pixel data is invalid") from error
    else:
        if position >= len(data) or not chr(data[position]).isspace():
            raise ExtractorError("PPM header is not terminated")
        position += 1
        channels = list(data[position : position + count])
    if len(channels) != count or any(channel < 0 or channel > 255 for channel in channels):
        raise ExtractorError("PPM pixel data has the wrong size or range")
    return [tuple(channels[index : index + 3]) for index in range(0, count, 3)], width, height


def _read_ppm(data: bytes) -> list[RGB]:
    return _decode_ppm(data)[0]


def _quantize(color: RGB) -> RGB:
    return tuple(min(255, (channel // 8) * 8 + 4) for channel in color)


def _luminance(color: RGB) -> float:
    return sum(weight * channel for weight, channel in zip((0.2126, 0.7152, 0.0722), color)) / 255



def palette_from_matugen_data(
    data: dict, image_name: str, fallback: Palette, variant: str = "dark"
) -> Palette:
    if variant not in {"dark", "light"}:
        raise ExtractorError(f"Unsupported Matugen variant: {variant}")
    try:
        colors = data["colors"]

        def selected(role: str) -> str:
            return colors[role][variant]["color"]

        roles = {
            "background": selected("background"),
            "surface": selected("surface_container"),
            "surface_alt": selected("surface_container_high"),
            "foreground": selected("on_background"),
            "muted": selected("on_surface_variant"),
            "accent": selected("primary"),
            "accent_alt": selected("secondary"),
            "success": fallback.color("success"),
            "warning": fallback.color("warning"),
            "error": selected("error"),
        }
    except (KeyError, TypeError) as error:
        raise ExtractorError(f"Matugen JSON is missing required color data: {error}") from error

    palette = Palette(
        name=f"Spectrum · {image_name}",
        variant=variant,
        source=f"matugen:{variant}:{image_name}",
        roles={role: value.lower() for role, value in roles.items()},
    )
    try:
        validate_contrast(palette)
    except (PaletteError, ValueError) as error:
        raise ExtractorError(f"Matugen palette failed Spectrum validation: {error}") from error
    return palette


def extract_with_matugen(image: Path, fallback: Palette, variant: str = "dark") -> Palette:
    executable = shutil.which("matugen")
    if executable is None:
        raise ExtractorError("Matugen is not installed")
    if not image.is_file():
        raise ExtractorError(f"Wallpaper is not a readable file: {image}")

    command = (
        executable,
        "image",
        str(image),
        "--dry-run",
        "--source-color-index",
        "0",
        "--json",
        "hex",
        "--mode",
        variant,
        "--quiet",
    )
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=30)
        data = json.loads(result.stdout)
    except subprocess.TimeoutExpired as error:
        raise ExtractorError("Matugen timed out while reading the wallpaper") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or "unknown Matugen error"
        raise ExtractorError(f"Matugen failed: {detail}") from error
    except json.JSONDecodeError as error:
        raise ExtractorError(f"Matugen returned invalid JSON: {error}") from error

    return palette_from_matugen_data(data, image.name, fallback, variant)


def write_palette(path: Path, palette: Palette) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = _palette_toml(palette)

    # El reemplazo evita dejar un archivo cortado si se interrumpe la extracción.
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent, text=True)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as target:
            target.write(content)
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)
    except OSError as error:
        temporary.unlink(missing_ok=True)
        raise ExtractorError(f"Cannot write extracted palette: {error}") from error


def _palette_toml(palette: Palette) -> str:
    metadata = (
        "[palette]\n"
        "schema_version = 1\n"
        f'name = {json.dumps(palette.name)}\n'
        f'variant = {json.dumps(palette.variant)}\n'
        f'source = {json.dumps(palette.source)}\n'
        "\n[roles]\n"
    )
    roles = "".join(f'{role} = "{color}"\n' for role, color in palette.roles.items())
    return metadata + roles
