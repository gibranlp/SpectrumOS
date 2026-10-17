from __future__ import annotations

from html import escape
import json
from pathlib import Path
from time import perf_counter

from .extractors import NATIVE_MODES, ExtractorError, extract_native_image, extract_with_matugen
from .palette import Palette, contrast_results


def evaluate_wallpapers(
    wallpapers: list[Path],
    output: Path,
    fallback: Palette,
    light_fallback: Palette,
    include_matugen: bool = True,
) -> tuple[Path, Path]:
    if not wallpapers:
        raise ExtractorError("Evaluation requires at least one wallpaper")
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for wallpaper in wallpapers:
        native_records = []
        for mode in NATIVE_MODES:
            native_records.append(
                _measure(
                    wallpaper,
                    mode,
                    lambda mode=mode: extract_native_image(
                        wallpaper, fallback, mode, light_fallback
                    ),
                )
            )
        records.extend(native_records)
        if include_matugen:
            variant = native_records[0]["variant"]
            selected_fallback = light_fallback if variant == "light" else fallback
            try:
                records.append(
                    _measure(
                        wallpaper,
                        "matugen",
                        lambda: extract_with_matugen(wallpaper, selected_fallback, variant),
                    )
                )
            except ExtractorError as error:
                records.append({"wallpaper": str(wallpaper.resolve()), "mode": "matugen", "error": str(error)})

    json_path = output / "report.json"
    html_path = output / "report.html"
    json_path.write_text(json.dumps({"records": records}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    html_path.write_text(_render_html(records), encoding="utf-8")
    return json_path, html_path


def _measure(wallpaper: Path, mode: str, extract) -> dict:
    started = perf_counter()
    palette = extract()
    elapsed_ms = (perf_counter() - started) * 1000
    checks = contrast_results(palette)
    return {
        "wallpaper": str(wallpaper.resolve()),
        "mode": mode,
        "variant": palette.variant,
        "elapsed_ms": round(elapsed_ms, 3),
        "passes": all(check["passes"] for check in checks),
        "contrast_checks": [
            {**check, "ratio": round(check["ratio"], 3)} for check in checks
        ],
        "roles": palette.roles,
    }


def _render_html(records: list[dict]) -> str:
    cards = "\n".join(_render_card(record) for record in records)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Spectrum palette evaluation</title>
<style>
body {{ margin: 0; padding: 2rem; background: #0c0d12; color: #eef2f8; font: 14px system-ui, sans-serif; }}
h1 {{ margin-top: 0; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 1rem; }}
.card {{ overflow: hidden; border: 1px solid #333846; border-radius: 14px; background: #161922; }}
.wallpaper {{ width: 100%; height: 150px; object-fit: cover; display: block; }}
.content {{ padding: 1rem; }}
.meta {{ color: #aab2c2; margin-bottom: .8rem; }}
.pass {{ color: #78dba9; }}
.fail {{ color: #ff8c9a; }}
.checks {{ display: grid; grid-template-columns: 1fr auto; gap: .2rem .8rem; margin: .8rem 0; font-size: 12px; }}
.swatches {{ display: grid; grid-template-columns: repeat(5, 1fr); gap: .35rem; }}
.swatch {{ min-height: 48px; padding: .35rem; border-radius: 7px; font-size: 10px; overflow: hidden; }}
.previews {{ display: grid; grid-template-columns: 1fr 1fr; gap: .5rem; margin-top: .8rem; }}
.preview {{ min-height: 70px; padding: .65rem; border-radius: 8px; border: 2px solid var(--accent); background: var(--background); color: var(--foreground); }}
.surface {{ background: var(--surface); }}
.muted {{ color: var(--muted); }}
.lock {{ text-align: center; padding-top: 1rem; }}
.prompt {{ border: 2px solid var(--accent); border-radius: 7px; padding: .35rem; margin-top: .4rem; }}
.error {{ padding: 1rem; color: #ff8c9a; }}
</style>
</head>
<body>
<h1>Spectrum palette evaluation</h1>
<p>Generated palette swatches and representative Kitty, Dunst, Hyprland, and Hyprlock surfaces.</p>
<div class="grid">{cards}</div>
</body>
</html>
"""


def _render_card(record: dict) -> str:
    if "error" in record:
        return (
            '<section class="card error">'
            f'<strong>{escape(record["mode"])}</strong><br>{escape(record["error"])}</section>'
        )
    roles = record["roles"]
    style = ";".join(f"--{role}:{color}" for role, color in roles.items())
    swatches = "".join(
        f'<div class="swatch" style="background:{color};color:{_label_color(color)}">'
        f"{escape(role)}<br>{escape(color)}</div>"
        for role, color in roles.items()
    )
    wallpaper_uri = Path(record["wallpaper"]).as_uri()
    status_class = "pass" if record["passes"] else "fail"
    status_label = "PASS" if record["passes"] else "FAIL"
    checks = "".join(
        f'<span>{escape(check["name"])}</span><span class="{"pass" if check["passes"] else "fail"}">'
        f'{check["ratio"]:.2f}:1 / {check["minimum"]:.2f}:1</span>'
        for check in record["contrast_checks"]
    )
    return f"""<section class="card" style="{style}">
<img class="wallpaper" src="{escape(wallpaper_uri)}" alt="">
<div class="content">
<h2>{escape(Path(record['wallpaper']).name)} · {escape(record['mode'])}</h2>
<div class="meta">{escape(record['variant'])} · {record['elapsed_ms']:.1f} ms · <strong class="{status_class}">{status_label}</strong></div>
<div class="swatches">{swatches}</div>
<div class="checks">{checks}</div>
<div class="previews">
<div class="preview">Kitty<br><span style="color:var(--accent)">$</span> spectrum theme</div>
<div class="preview surface">Dunst<br><span class="muted">Theme applied</span></div>
<div class="preview">Hyprland<br><span style="color:var(--accent)">Active border</span></div>
<div class="preview lock">12:34<div class="prompt">Password</div></div>
</div>
</div>
</section>"""


def _label_color(color: str) -> str:
    red, green, blue = (int(color[index : index + 2], 16) for index in (1, 3, 5))
    return "#111318" if red * 0.299 + green * 0.587 + blue * 0.114 > 150 else "#f4f6fa"
