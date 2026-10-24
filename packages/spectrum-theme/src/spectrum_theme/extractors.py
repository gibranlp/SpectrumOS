from __future__ import annotations

import json
import colorsys
import math
import re
from collections import Counter
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from .palette import Palette, PaletteError, validate_contrast
from .interpretation import Candidate, interpret, parameters as backend_parameters


class ExtractorError(RuntimeError):
    pass


RGB = tuple[int, int, int]
NATIVE_MODES = ("spectrum", "clustered", "median-cut", "weighted-regions")


def extract_colors(pixels: list[RGB], mode: str, image_size: tuple[int, int] | None, options: dict) -> list[Candidate]:
    if mode == "spectrum":
        pairs = _wal_candidates(pixels, image_size, options["color_count"])
    elif mode == "clustered":
        pairs = _clustered_candidates(pixels, options["cluster_count"])
    elif mode == "median-cut":
        pairs = _median_cut_candidates(pixels, options["color_count"])
    else:
        pairs = _weighted_region_candidates(pixels)
    return [Candidate(color, weight) for color, weight in pairs]


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
                          "extraction": {"spectrum": "ImageMagick / wal", "clustered": "RGB k-means / Colorz",
                                         "median-cut": "MMCQ / ColorThief", "weighted-regions": "RGB regions / Haishoku"}[mode]})
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


def _wal_candidates(pixels: list[RGB], image_size: tuple[int, int] | None, count: int = 16) -> list[tuple[RGB, int]]:
    executable = shutil.which("magick")
    if executable is None:
        raise ExtractorError("ImageMagick is required for the Spectrum (Pywal) backend")
    width, height = image_size or (len(pixels), 1)
    data = f"P6\n{width} {height}\n255\n".encode() + bytes(channel for color in pixels for channel in color)
    pairs = []
    target = min(count, len(set(pixels)))
    for requested in range(count, count + 20):
        try:
            result = subprocess.run([executable, "ppm:-", "+dither", "-colors", str(requested), "-depth", "8",
                                     "-format", "%c", "histogram:info:-"], input=data,
                                    check=True, capture_output=True, timeout=30)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            raise ExtractorError("ImageMagick could not quantize the wallpaper") from error
        pairs = []
        for line in result.stdout.decode().splitlines():
            match = re.search(r"^\s*(\d+):.*#([0-9A-Fa-f]{6})(?:\s|$)", line)
            if match:
                color = tuple(int(match[2][index:index + 2], 16) for index in (0, 2, 4))
                pairs.append((color, int(match[1])))
        if len(pairs) >= target:
            break
    if not pairs:
        raise ExtractorError("ImageMagick returned no usable colors")
    return sorted(pairs, key=lambda pair: (colorsys.rgb_to_yiq(*pair[0]), pair[0]))


def _clustered_candidates(pixels: list[RGB], count: int = 6) -> list[tuple[RGB, int]]:
    # Colorz limita V antes del agrupamiento y da el mismo peso a cada color único.
    observations = []
    for color in sorted(set(pixels)):
        hue, saturation, value = colorsys.rgb_to_hsv(*(channel / 256 for channel in color))
        value = max(170 / 256, min(200 / 256, value))
        observations.append(tuple(int(channel * 256) for channel in colorsys.hsv_to_rgb(hue, saturation, value)))
    histogram = Counter(observations)
    colors = sorted(histogram)
    centers = [colors[0]]
    distance = lambda a, b: sum((x - y) ** 2 for x, y in zip(a, b))
    while len(centers) < min(count, len(colors)):
        centers.append(max((color for color in colors if color not in centers),
                           key=lambda color: (min(distance(color, center) for center in centers), color)))
    for _ in range(64):
        groups = [[] for _ in centers]
        for color in colors:
            index = min(range(len(centers)), key=lambda index: (distance(color, centers[index]), index))
            groups[index].append((color, histogram[color]))
        updated = [_weighted_mean(group) for group in groups if group]
        if updated == centers:
            break
        centers = updated
    # Se recalculan los grupos para no publicar centros de la iteración anterior.
    masses = Counter()
    for color in colors:
        center = min(centers, key=lambda center: (distance(color, center), center))
        masses[center] += histogram[color]
    return sorted(masses.items(), key=lambda pair: (colorsys.rgb_to_hsv(*pair[0])[0], pair[0]))


def _median_cut_candidates(pixels: list[RGB], count: int = 8) -> list[tuple[RGB, int]]:
    # MMCQ usa cinco bits por canal y descarta blancos; un lienzo blanco sigue siendo válido.
    source = [color for color in pixels if not all(channel > 250 for channel in color)] or pixels
    histogram = Counter(tuple(channel >> 3 for channel in color) for color in source)
    boxes = [list(histogram.items())]

    def volume(box):
        return math.prod(max(color[i] for color, _ in box) - min(color[i] for color, _ in box) + 1
                         for i in range(3))

    while len(boxes) < min(count, len(histogram)):
        available = [box for box in boxes if len(box) > 1]
        if not available:
            break
        population_phase = len(boxes) < math.ceil(count * 0.75)
        box = max(available, key=lambda box: (sum(weight for _, weight in box) *
                                             (1 if population_phase else volume(box)), box))
        boxes.remove(box)
        channel = max(range(3), key=lambda i: max(c[i] for c, _ in box) - min(c[i] for c, _ in box))
        ordered = sorted(box, key=lambda pair: (pair[0][channel], pair[0]))
        total = sum(weight for _, weight in ordered)
        cumulative = 0
        median = ordered[0][0][channel]
        for color, weight in ordered:
            cumulative += weight
            median = color[channel]
            if cumulative > total / 2:
                break
        low, high = ordered[0][0][channel], ordered[-1][0][channel]
        cut = min(high - 1, int(median + (high - median) / 2)) if median - low <= high - median else max(low, int(median - 1 - (median - low) / 2))
        values = sorted(set(color[channel] for color, _ in ordered))
        cut = max(values[0], min(values[-2], cut))
        boxes.extend(([pair for pair in ordered if pair[0][channel] <= cut],
                      [pair for pair in ordered if pair[0][channel] > cut]))
    result = []
    for box in boxes:
        total = sum(weight for _, weight in box)
        color = tuple(min(255, int(sum((color[i] + 0.5) * 8 * weight for color, weight in box) / total))
                      for i in range(3))
        result.append((color, total))
    return sorted(result, key=lambda pair: (colorsys.rgb_to_yiq(*pair[0]), pair[0]))


def _weighted_region_candidates(pixels: list[RGB]) -> list[tuple[RGB, int]]:
    histogram = Counter(pixels)
    minimum = tuple(min(color[index] for color in histogram) for index in range(3))
    maximum = tuple(max(color[index] for color in histogram) for index in range(3))
    groups: dict[tuple[int, int, int], list[tuple[RGB, int]]] = {}
    for color, weight in histogram.items():
        region = tuple(_region_index(color[index], minimum[index], maximum[index]) for index in range(3))
        groups.setdefault(region, []).append((color, weight))
    result = [(_weighted_mean(group), sum(weight for _, weight in group)) for group in groups.values()]
    selected = sorted(result, key=lambda item: (item[1], item[0]), reverse=True)[:8]
    return sorted(selected, key=lambda pair: (colorsys.rgb_to_yiq(*pair[0]), pair[0]))


def _weighted_mean(colors: list[tuple[RGB, int]]) -> RGB:
    total = sum(weight for _, weight in colors)
    return tuple(int(sum(color[index] * weight for color, weight in colors) / total) for index in range(3))


def _region_index(value: int, minimum: int, maximum: int) -> int:
    if maximum == minimum:
        return 2
    return min(2, int((value - minimum) * 3 / (maximum - minimum)))


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
