from __future__ import annotations

import base64
from html import escape
import json
from pathlib import Path
import struct
from time import perf_counter
from urllib.parse import quote
import zlib

from .color import oklab
from .extractors import NATIVE_MODES, ExtractorError, decode_native_image, extract_colors, write_palette
from .interpretation import interpret, parameters
from .palette import CONTRAST_REQUIREMENTS, Palette, contrast_ratio


def png_sample(pixels, width: int, height: int) -> bytes:
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    rows = b''.join(b'\0' + bytes(channel for color in pixels[start:start + width] for channel in color)
                    for start in range(0, len(pixels), width))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def compare_wallpapers(wallpapers: list[Path], output: Path, dark: Palette, light: Palette,
                       overrides: dict | None = None) -> tuple[Path, Path]:
    if not wallpapers:
        raise ExtractorError('No supported wallpapers found for comparison')
    overrides = {} if overrides is None else overrides
    if not isinstance(overrides, dict) or set(overrides) - set(NATIVE_MODES):
        raise ExtractorError('Comparison parameters must be an object keyed by native backend name')
    options = {mode: parameters(mode, overrides.get(mode)) for mode in NATIVE_MODES}
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for index, wallpaper in enumerate(wallpapers, 1):
        pixels, width, height = decode_native_image(wallpaper)
        record = {'wallpaper': str(wallpaper.resolve()), 'name': wallpaper.name,
                  'image_size': [width, height], 'palettes': [], 'distances': {}}
        for mode in NATIVE_MODES:
            start = perf_counter()
            candidates = extract_colors(pixels, mode, (width, height), options[mode])
            extraction_ms = (perf_counter() - start) * 1000
            for variant, fallback in (('dark', dark), ('light', light)):
                debug = {}
                start = perf_counter()
                palette = interpret(candidates, wallpaper.name, mode, variant, fallback, options[mode], debug)
                debug.update({'mode': mode, 'variant': variant, 'spatial_coordinates_available': True,
                              'image_size': [width, height], 'extraction_ms': extraction_ms,
                              'interpretation_ms': (perf_counter() - start) * 1000})
                name = f'{index:02d}-{wallpaper.stem}-{mode}-{variant}.toml'
                write_palette(output / name, palette)
                record['palettes'].append({'mode': mode, 'variant': variant, 'roles': palette.roles,
                                           'file': name, 'debug': debug,
                                           'contrast': {label: {'ratio': contrast_ratio(palette.rgb(fg), palette.rgb(bg)),
                                                                 'minimum': minimum}
                                                        for label, fg, bg, minimum in CONTRAST_REQUIREMENTS}})
        for variant in ('dark', 'light'):
            palettes = [item for item in record['palettes'] if item['variant'] == variant]
            distances = {}
            for first_index, first in enumerate(palettes):
                for second in palettes[first_index + 1:]:
                    roles = ('background', 'foreground', 'accent', 'accent_alt')
                    distance = 0
                    for role in roles:
                        labs = [oklab(tuple(int(item['roles'][role][channel:channel + 2], 16)
                                            for channel in (1, 3, 5))) for item in (first, second)]
                        distance += sum((a - b) ** 2 for a, b in zip(*labs)) ** 0.5
                    distances[f"{first['mode']} / {second['mode']}"] = distance / len(roles)
            record['distances'][variant] = distances
        record['thumbnail'] = 'data:image/png;base64,' + base64.b64encode(png_sample(pixels, width, height)).decode('ascii')
        records.append(record)
    data_path, html_path = output / 'report.json', output / 'report.html'
    data_path.write_text(json.dumps({'schema': 1, 'wallpapers': records}, indent=2) + '\n', encoding='utf-8')
    html_path.write_text(render_report(records), encoding='utf-8')
    return data_path, html_path


def _card(item: dict) -> str:
    roles = item['roles']
    style = ';'.join(f'--{role.replace("_", "-")}:{value}' for role, value in roles.items())
    swatches = ''.join(f'<span title="{escape(role)} {color}" style="background:{color}"></span>'
                       for role, color in roles.items())
    debug = item['debug']
    transformations = ''.join(
        f'<tr><td>{role}</td><td>{value["source"]}</td><td>{value["final"]}</td>'
        f'<td>{value.get("lightness_adjustment", 0):+.3f}</td>'
        f'<td>{value.get("chroma_adjustment", 0):+.3f}</td><td>{value.get("hue_shift", 0):+.1f}°</td></tr>'
        for role, value in debug['roles'].items())
    raw = ''.join(f'<i title="{entry["color"]} · mass {entry["weight"]:.0f} · '
                  f'{escape(entry["rejection_reason"] or "Selected for a role")}" '
                  f'style="background:{entry["color"]};outline:{"2px solid currentColor" if entry["selected"] else "none"}"></i>'
                  for entry in sorted(debug['raw_colors'], key=lambda entry: not entry['selected'])[:96])
    checks = ', '.join(f'{escape(label)}: {check["ratio"]:.2f}/{check["minimum"]:g}'
                       for label, check in item['contrast'].items())
    return f'''<article style="{style}"><h3>{escape(item['mode'].title())}</h3>
      <div class="desktop"><div class="bar">◉ &nbsp; Spectrum &nbsp; <b>14:32</b></div>
      <div class="window"><small>TIME & REGION</small><h4>Your desktop, your colors.</h4>
      <p>Readable text on a source-derived canvas.</p><div class="row"><span>Automatic time</span><em>● Enabled</em></div>
      <div class="row secondary"><span>Region settings</span><strong>America/Cancun</strong></div>
      <button>Apply changes</button><a class="link">Explore colors →</a>
      <footer><span class="success">● Connected</span><span class="warning">● Update</span><span class="error">● Alert</span></footer>
      </div></div><div class="swatches">{swatches}</div>
      <details><summary>Extraction & adjustments · {len(debug['raw_colors'])} candidates</summary>
      <p>Outlined raw colors are selected. Selected colors first, then population order; up to 96 shown. All candidates are in report.json.</p>
      <div class="raw">{raw}</div><table><tr><th>Role</th><th>Source</th><th>Final</th><th>ΔL</th><th>ΔC</th><th>Δh</th></tr>{transformations}</table>
      <p>{checks}</p><pre>{escape(json.dumps(debug['parameters'], indent=2))}</pre>
      <a href="{quote(item['file'])}">Download palette TOML</a></details></article>'''


def render_report(records: list[dict]) -> str:
    sections = []
    for index, record in enumerate(records, 1):
        groups = ''.join(f'<h3 class="variant">{variant.title()}</h3><div class="grid">' +
                         ''.join(_card(item) for item in record['palettes'] if item['variant'] == variant) + '</div>'
                         for variant in ('dark', 'light'))
        sections.append(f'<section id="wallpaper-{index}"><header><img src="{record["thumbnail"]}" alt="">'
                        f'<div><h2>{escape(record["name"])}</h2><p>Same image · four deliberate interpretations · both variants</p></div></header>{groups}</section>')
    navigation = ''.join(f'<a href="#wallpaper-{index}">{escape(record["name"])}</a>' for index, record in enumerate(records, 1))
    return '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Spectrum palette personalities</title><style>
    *{box-sizing:border-box}body{margin:0;padding:28px;background:#16181e;color:#e5e7ed;font:14px system-ui,sans-serif}
    h1{margin:0 0 10px}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}nav a{color:#a8c9ff}section{margin-bottom:42px}
    header{display:flex;gap:20px;align-items:center}header img{width:160px;max-height:100px;object-fit:cover;border-radius:8px}
    .grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px}.variant{margin:24px 0 8px}
    article{background:var(--background);color:var(--foreground);border-radius:10px;padding:16px;overflow:hidden}
    article h3{margin:0 0 12px;font-size:16px}.desktop{background:var(--background)}.bar{padding:10px;background:var(--surface-alt);border-radius:6px}.bar b{float:right}
    .window{margin-top:18px;background:var(--surface);padding:16px;border-radius:9px}small,p{color:var(--muted)}h4{font-size:18px;margin:12px 0}
    .row{margin:16px 0;padding:12px;background:var(--surface-alt);border-radius:6px;display:flex;flex-direction:column;gap:7px}.row em{color:var(--accent);font-style:normal}
    .secondary strong,.link{color:var(--accent-alt)}button{border:0;border-radius:6px;background:var(--accent);color:var(--background);font:inherit;font-weight:600;padding:10px 16px}
    .link{display:block;margin:14px 0}footer{display:flex;gap:10px;flex-wrap:wrap;font-size:11px}.success{color:var(--success)}.warning{color:var(--warning)}.error{color:var(--error)}
    .swatches{display:flex;margin:18px 0 8px}.swatches span{flex:1;height:23px}summary{cursor:pointer;font-size:12px}.raw{display:flex;flex-wrap:wrap;gap:4px}.raw i{height:16px;width:16px}
    table{width:100%;font-size:10px;text-align:left;border-spacing:0 8px}details p{font-size:11px}details a{color:var(--accent-alt)}pre{font-size:11px}
    @media(max-width:1100px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.grid{grid-template-columns:1fr}}
    </style><h1>Four backend personalities</h1><p>Compare the overall canvas, color hierarchy and atmosphere, not just individual swatches. Expand a card to inspect its source colors and adjustments.</p>
    <nav>''' + navigation + '</nav>' + ''.join(sections) + '</html>\n'
