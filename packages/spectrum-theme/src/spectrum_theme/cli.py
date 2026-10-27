from __future__ import annotations

import argparse
from importlib.resources import files
import json
import os
from pathlib import Path
import sys

from .extractors import NATIVE_MODES, ExtractorError, extract_native_image, extract_with_matugen, write_palette
from .evaluation import evaluate_wallpapers
from .comparison import compare_wallpapers
from .generation import DEFAULT_RETENTION, GenerationError, generate, rollback
from .palette import Palette, PaletteError, load_palette, validate_contrast
from .renderers import DEFAULT_FONT_FAMILY

# Monospace choices offered by /usr/lib/spectrumos/font-family-menu, keyed by the short
# slug persisted to state -- each is a Nerd Font actually present in SpectrumOS2's package
# manifest (bootstrap/packages/desktop.txt), never an arbitrary free-text family name, so a
# typo or an uninstalled font can never silently substitute something else.
FONT_FAMILIES = {
    "jetbrains-mono": DEFAULT_FONT_FAMILY,
    "fira-code": "FiraCode Nerd Font",
    "source-code-pro": "SauceCodePro Nerd Font",
    "cascadia-code": "CaskaydiaCove Nerd Font",
    "hack": "Hack Nerd Font",
    "ibm-plex-mono": "BlexMono Nerd Font",
    "iosevka": "Iosevka Nerd Font",
    "victor-mono": "VictorMono Nerd Font",
    "ubuntu-mono": "UbuntuMono Nerd Font",
    "meslo": "MesloLGS Nerd Font",
}


def default_palette_path() -> Path:
    return Path(str(files("spectrum_theme").joinpath("palettes/spectrum-dark.toml")))


def light_palette_path() -> Path:
    return Path(str(files("spectrum_theme").joinpath("palettes/spectrum-light.toml")))


def default_output_root() -> Path:
    cache_home = os.environ.get("XDG_CACHE_HOME")
    base = Path(cache_home) if cache_home else Path.home() / ".cache"
    return base / "spectrumos" / "theme"


def global_font_size() -> int:
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    try:
        value = int((state_home / "spectrumos/typography/font-size").read_text().strip())
    except (OSError, ValueError):
        return 13
    return value if 8 <= value <= 24 else 13


def global_font_family() -> str:
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    try:
        key = (state_home / "spectrumos/typography/font-family").read_text().strip()
    except OSError:
        return DEFAULT_FONT_FAMILY
    return FONT_FAMILIES.get(key, DEFAULT_FONT_FAMILY)


def current_palette(output: Path) -> tuple[Palette, Path | None]:
    current = (output / "current").resolve(strict=True)
    palette_data = json.loads((current / "palette.json").read_text(encoding="utf-8"))
    metadata = json.loads((current / "generation.json").read_text(encoding="utf-8"))
    palette = Palette(
        name=palette_data["name"], variant=palette_data["variant"],
        source=palette_data["source"], roles=palette_data["roles"],
    )
    validate_contrast(palette)
    wallpaper_value = metadata.get("wallpaper")
    return palette, Path(wallpaper_value) if wallpaper_value else None


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="spectrum-theme")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate", help="Validate a Spectrum palette")
    validate.add_argument("palette", type=Path)

    render = subparsers.add_parser("render", help="Render and atomically activate a Spectrum palette")
    render.add_argument("--palette", type=Path)
    render.add_argument("--output", type=Path, default=default_output_root())
    render.add_argument("--appearance-state", type=Path, help="Wallpaper appearance settings retained for rollback")
    render.add_argument("--strict", action="store_true", help="Fail instead of using the packaged fallback")
    render.add_argument("--wallpaper", type=Path, help="Wallpaper associated with this generation")
    render.add_argument("--retention", type=int, default=DEFAULT_RETENTION)

    rollback_parser = subparsers.add_parser("rollback", help="Activate the previous complete theme generation")
    rollback_parser.add_argument("--output", type=Path, default=default_output_root())

    rerender = subparsers.add_parser("rerender-current", help="Regenerate the active palette")
    rerender.add_argument("--output", type=Path, default=default_output_root())

    extract = subparsers.add_parser("extract", help="Extract a Spectrum palette from a wallpaper")
    extract.add_argument("backend", choices=("native", "matugen"))
    extract.add_argument("image", type=Path)
    extract.add_argument("--output", type=Path, required=True)
    extract.add_argument("--mode", choices=NATIVE_MODES, default="spectrum")
    extract.add_argument("--variant", choices=("auto", "dark", "light"), default="auto")
    extract.add_argument("--parameters", type=Path, help="JSON backend parameter overrides")
    extract.add_argument("--debug", type=Path, help="Export native extraction and role decisions as JSON")

    compare = subparsers.add_parser("compare", help="Preview all four native backends in dark and light")
    compare.add_argument("image", type=Path, help="Wallpaper or directory of wallpapers")
    compare.add_argument("--output", type=Path, required=True)
    compare.add_argument("--parameters", type=Path, help="JSON overrides keyed by native backend name")

    evaluate = subparsers.add_parser("evaluate", help="Compare extractor modes across wallpapers")
    evaluate.add_argument("wallpaper_directory", type=Path)
    evaluate.add_argument("--output", type=Path, required=True)
    evaluate.add_argument("--without-matugen", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = build_parser().parse_args(argv)
    try:
        if arguments.command == "validate":
            palette = load_palette(arguments.palette)
            print(f"Valid palette: {palette.name} ({palette.variant})")
            return 0

        if arguments.command == "extract":
            fallback = load_palette(default_palette_path())
            light_fallback = load_palette(light_palette_path())
            if arguments.backend == "native":
                overrides = json.loads(arguments.parameters.read_text()) if arguments.parameters else None
                if overrides is not None and not isinstance(overrides, dict):
                    raise ExtractorError("Backend parameters must be a JSON object")
                debug = {} if arguments.debug else None
                palette = extract_native_image(
                    arguments.image, fallback, arguments.mode, light_fallback, arguments.variant,
                    parameters=overrides, debug=debug,
                )
            else:
                if arguments.parameters or arguments.debug:
                    raise ExtractorError("Parameters and diagnostics are supported by native extraction only")
                variant = "dark" if arguments.variant == "auto" else arguments.variant
                selected_fallback = light_fallback if variant == "light" else fallback
                palette = extract_with_matugen(arguments.image, selected_fallback, variant)
            write_palette(arguments.output, palette)
            if arguments.debug:
                arguments.debug.parent.mkdir(parents=True, exist_ok=True)
                arguments.debug.write_text(json.dumps(debug, indent=2) + "\n", encoding="utf-8")
            print(f"Extracted palette: {palette.name}")
            print(f"Palette: {arguments.output}")
            return 0

        if arguments.command == "compare":
            wallpapers = [arguments.image] if arguments.image.is_file() else sorted(
                path for path in arguments.image.iterdir() if path.is_file() and
                path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".ppm"})
            overrides = json.loads(arguments.parameters.read_text()) if arguments.parameters else None
            json_path, html_path = compare_wallpapers(wallpapers, arguments.output,
                                                     load_palette(default_palette_path()),
                                                     load_palette(light_palette_path()), overrides)
            print(f"Comparison data: {json_path}")
            print(f"Comparison preview: {html_path}")
            return 0

        if arguments.command == "rollback":
            generation, wallpaper = rollback(arguments.output)
            print(f"Activated generation: {generation}")
            print(f"Wallpaper: {wallpaper}")
            return 0

        if arguments.command == "rerender-current":
            palette, wallpaper = current_palette(arguments.output)
            generation = generate(
                palette, arguments.output, wallpaper,
                font_size=global_font_size(), font_family=global_font_family(),
                appearance=json.loads(((arguments.output / "current").resolve() / "generation.json").read_text()).get("appearance"),
            )
            print(f"Activated theme: {palette.name}")
            print(f"Generation: {generation}")
            return 0

        if arguments.command == "evaluate":
            wallpapers = sorted(
                path
                for path in arguments.wallpaper_directory.iterdir()
                if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
            )
            fallback = load_palette(default_palette_path())
            light_fallback = load_palette(light_palette_path())
            json_path, html_path = evaluate_wallpapers(
                wallpapers,
                arguments.output,
                fallback,
                light_fallback,
                not arguments.without_matugen,
            )
            print(f"Evaluation data: {json_path}")
            print(f"Evaluation report: {html_path}")
            return 0

        requested = arguments.palette or default_palette_path()
        try:
            palette = load_palette(requested)
        except PaletteError as error:
            if arguments.strict or arguments.palette is None:
                raise
            print(f"Warning: {error}", file=sys.stderr)
            print("Using packaged fallback palette.", file=sys.stderr)
            palette = load_palette(default_palette_path())

        appearance = None
        if arguments.appearance_state:
            appearance = json.loads(arguments.appearance_state.read_text())
            if not isinstance(appearance, dict) or appearance.get("mode") not in NATIVE_MODES or appearance.get("variant") not in {"auto", "dark", "light"}:
                raise ValueError("Invalid wallpaper appearance settings")
            if not isinstance(appearance.get("scheme"), str) or not isinstance(appearance.get("rendered_wallpaper"), str):
                raise ValueError("Invalid rendered wallpaper metadata")
        generation = generate(
            palette, arguments.output, arguments.wallpaper, arguments.retention,
            font_size=global_font_size(), font_family=global_font_family(),
            appearance=appearance,
        )
        print(f"Activated theme: {palette.name}")
        print(f"Generation: {generation}")
        return 0
    except (PaletteError, ExtractorError, GenerationError, OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
