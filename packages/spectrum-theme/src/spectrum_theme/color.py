from __future__ import annotations

from functools import lru_cache
from math import atan2, cos, degrees, hypot, radians, sin

from .palette import contrast_ratio

RGB = tuple[int, int, int]
LCH = tuple[float, float, float]


def _linear(value: int) -> float:
    channel = value / 255
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


@lru_cache(maxsize=32768)
def oklab(rgb: RGB) -> tuple[float, float, float]:
    r, g, b = map(_linear, rgb)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def oklch(rgb: RGB) -> LCH:
    lightness, a, b = oklab(rgb)
    chroma = hypot(a, b)
    return lightness, chroma, degrees(atan2(b, a)) % 360 if chroma > 0.00001 else 0.0


def _linear_rgb(lch: LCH) -> tuple[float, float, float]:
    lightness, chroma, hue = lch
    a, b = chroma * cos(radians(hue)), chroma * sin(radians(hue))
    l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (lightness - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def rgb(lch: LCH) -> RGB:
    lightness, chroma, hue = lch
    lightness = max(0.0, min(1.0, lightness))
    chroma = max(0.0, chroma)
    channels = _linear_rgb((lightness, chroma, hue))
    if not all(-1e-7 <= channel <= 1.0000001 for channel in channels):
        # Reducir croma evita recortar canales y desviar el tono al salir del gamut sRGB.
        low, high = 0.0, chroma
        for _ in range(18):
            middle = (low + high) / 2
            if all(0 <= channel <= 1 for channel in _linear_rgb((lightness, middle, hue))):
                low = middle
            else:
                high = middle
        channels = _linear_rgb((lightness, low, hue))
    def encode(channel):
        channel = max(0.0, min(1.0, channel))
        return round(255 * (12.92 * channel if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055))
    return tuple(encode(channel) for channel in channels)


def hex_color(color: RGB) -> str:
    return '#' + ''.join(f'{channel:02x}' for channel in color)


def hue_distance(first: float, second: float) -> float:
    return abs((first - second + 180) % 360 - 180)


def fit_contrast(color: RGB, constraints: list[tuple[RGB, float]], variant: str) -> RGB:
    def passes(candidate):
        return all(contrast_ratio(candidate, background) >= minimum for background, minimum in constraints)
    if passes(color):
        return color
    lightness, chroma, hue = oklch(color)
    end = 1.0 if variant == 'dark' else 0.0
    # Buscar desde el color original mantiene el cambio perceptual mínimo, sin un gris común.
    previous = lightness
    for step in range(1, 201):
        current = lightness + (end - lightness) * step / 200
        candidate = rgb((current, chroma, hue))
        if passes(candidate):
            failed, passed = previous, current
            for _ in range(14):
                middle = (failed + passed) / 2
                if passes(rgb((middle, chroma, hue))):
                    passed = middle
                else:
                    failed = middle
            return rgb((passed, chroma, hue))
        previous = current
    raise ValueError('No hue-preserving color meets the requested contrast against these surfaces')
