from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import tomllib


ROLE_NAMES = (
    "background",
    "surface",
    "surface_alt",
    "foreground",
    "muted",
    "accent",
    "accent_alt",
    "success",
    "warning",
    "error",
)
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")
CONTRAST_REQUIREMENTS = (
    ("Foreground/background", "foreground", "background", 4.5),
    ("Muted/background", "muted", "background", 3.0),
    ("Foreground/surface", "foreground", "surface", 4.5),
    ("Muted/surface", "muted", "surface", 3.0),
    ("Selection background/accent", "background", "accent", 4.5),
    ("Accent alternate/background", "accent_alt", "background", 3.0),
    ("Success/background", "success", "background", 3.0),
    ("Warning/background", "warning", "background", 3.0),
    ("Error/background", "error", "background", 3.0),
    # A selected row's highlight (accent) or its unfocused/secondary variant
    # (accent_alt) is drawn directly against a list/file-view row -- surface
    # or surface_alt (odd/even striping) -- not the window background. Only
    # requiring contrast against background let a highlight end up nearly the
    # same lightness as the rows around it, so the selection was "readable"
    # (guaranteed above) but effectively invisible as a highlight. 3.0 matches
    # WCAG 1.4.11 non-text contrast, the applicable rule for a fill color
    # rather than text.
    ("Accent/surface", "accent", "surface", 3.0),
    ("Accent/surface alternate", "accent", "surface_alt", 3.0),
    ("Accent alternate/surface", "accent_alt", "surface", 3.0),
    ("Accent alternate/surface alternate", "accent_alt", "surface_alt", 3.0),
)


class PaletteError(ValueError):
    pass


@dataclass(frozen=True)
class Palette:
    name: str
    variant: str
    source: str
    roles: dict[str, str]

    def color(self, role: str) -> str:
        return self.roles[role].lower()

    def bare(self, role: str) -> str:
        return self.color(role)[1:]

    def rgb(self, role: str) -> tuple[int, int, int]:
        value = self.bare(role)
        return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def load_palette(path: Path) -> Palette:
    try:
        with path.open("rb") as source:
            data = tomllib.load(source)
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise PaletteError(f"Cannot read palette {path}: {error}") from error

    metadata = data.get("palette")
    roles = data.get("roles")
    if not isinstance(metadata, dict) or not isinstance(roles, dict):
        raise PaletteError("Palette must contain [palette] and [roles] tables")

    missing = [role for role in ROLE_NAMES if role not in roles]
    extra = sorted(set(roles) - set(ROLE_NAMES))
    if missing:
        raise PaletteError(f"Missing palette roles: {', '.join(missing)}")
    if extra:
        raise PaletteError(f"Unknown palette roles: {', '.join(extra)}")

    normalized: dict[str, str] = {}
    for role in ROLE_NAMES:
        color = roles[role]
        if not isinstance(color, str) or HEX_COLOR.fullmatch(color) is None:
            raise PaletteError(f"Role {role} must be a #RRGGBB color")
        normalized[role] = color.lower()

    name = metadata.get("name")
    variant = metadata.get("variant")
    source_name = metadata.get("source", "fixed")
    if metadata.get("schema_version") != 1:
        raise PaletteError("Palette schema_version must be 1")
    if not isinstance(name, str) or not name.strip():
        raise PaletteError("Palette name must be a non-empty string")
    if variant not in {"dark", "light"}:
        raise PaletteError("Palette variant must be dark or light")
    if not isinstance(source_name, str) or not source_name.strip():
        raise PaletteError("Palette source must be a non-empty string")

    palette = Palette(name=name.strip(), variant=variant, source=source_name.strip(), roles=normalized)
    validate_contrast(palette)
    return palette


def relative_luminance(color: tuple[int, int, int]) -> float:
    channels = []
    for channel in color:
        value = channel / 255
        channels.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast_ratio(first: tuple[int, int, int], second: tuple[int, int, int]) -> float:
    lighter, darker = sorted((relative_luminance(first), relative_luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def validate_contrast(palette: Palette) -> None:
    failures = [result for result in contrast_results(palette) if not result["passes"]]
    if failures:
        first = failures[0]
        raise PaletteError(
            f'{first["name"]} contrast is {first["ratio"]:.2f}; expected at least {first["minimum"]:.2f}'
        )


def contrast_results(palette: Palette) -> list[dict]:
    results = []
    for name, foreground_role, background_role, minimum in CONTRAST_REQUIREMENTS:
        ratio = contrast_ratio(palette.rgb(foreground_role), palette.rgb(background_role))
        results.append({
            "name": name,
            "foreground_role": foreground_role,
            "background_role": background_role,
            "ratio": ratio,
            "minimum": minimum,
            "passes": ratio >= minimum,
        })
    return results
