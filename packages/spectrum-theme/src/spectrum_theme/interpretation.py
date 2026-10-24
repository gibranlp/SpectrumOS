from __future__ import annotations

from dataclasses import dataclass
from math import isfinite

from .color import LCH, RGB, fit_contrast, hex_color, hue_distance, oklch, rgb
from .palette import CONTRAST_REQUIREMENTS, Palette, contrast_ratio, validate_contrast

BACKEND_DEFAULTS = {
    'spectrum': {'color_count': 16},
    'clustered': {'cluster_count': 6},
    'median-cut': {'color_count': 8},
    'weighted-regions': {},
}
PARAMETER_RANGES = {'cluster_count': (4, 16), 'color_count': (4, 35)}


def parameters(mode: str, overrides: dict | None = None) -> dict:
    if overrides is not None and not isinstance(overrides, dict):
        raise ValueError(f'{mode} parameters must be an object')
    values = BACKEND_DEFAULTS[mode].copy()
    for key, value in (overrides or {}).items():
        if key not in values or isinstance(value, bool) or not isinstance(value, (int, float)) or not isfinite(value):
            raise ValueError(f'Invalid {mode} parameter: {key}')
        low, high = PARAMETER_RANGES[key]
        if not low <= value <= high:
            raise ValueError(f'{mode}.{key} must be between {low} and {high}')
        if key in {'cluster_count', 'color_count'} and int(value) != value:
            raise ValueError(f'{mode}.{key} must be an integer')
        values[key] = int(value) if key in {'cluster_count', 'color_count'} else value
    return values


@dataclass(frozen=True)
class Candidate:
    color: RGB
    weight: float
    center: float = 0.0
    edge: float = 0.0
    focal: float = 0.0
    highlight: float = 0.0

    @property
    def lch(self) -> LCH:
        return oklch(self.color)


class Interpretation:
    def __init__(self, candidates: list[Candidate], variant: str, options: dict):
        self.candidates = candidates
        self.variant = variant
        self.options = options
        self.dominant = max(candidates, key=lambda item: (item.weight, item.color))
        total = sum(item.weight for item in candidates)
        average_chroma = sum(item.lch[1] * item.weight for item in candidates) / total
        self.chromatic = [item for item in candidates if
                          (item.lch[1] >= 0.035 and item.weight / total >= 0.001) or
                          (average_chroma >= 0.003 and item.lch[1] >= 0.003 and item.weight / total >= 0.001)]
        self.neutral = not self.chromatic
        self.roles: dict[str, LCH] = {}
        self.sources: dict[str, Candidate] = {}
        self.reasons: dict[str, str] = {}

    def put(self, role: str, source: Candidate, lightness: float, chroma: float, hue: float | None = None, reason: str = ''):
        source_hue = source.lch[2]
        self.roles[role] = (lightness, 0.0 if self.neutral else chroma, source_hue if hue is None else hue % 360)
        self.sources[role] = source
        self.reasons[role] = reason or f'Backend-specific {self.variant} tone derived from this source family'


def _blend(first: RGB, second: RGB, amount: float) -> RGB:
    return tuple(int(a + (b - a) * amount) for a, b in zip(first, second))


def _pywal(context: Interpretation, backend: str):
    candidates = context.candidates
    darkest, brightest = candidates[0], candidates[-1]
    black, white = (0, 0, 0), (255, 255, 255)
    light = context.variant == 'light'
    canvas = darkest
    if backend == 'wal':
        canvas = brightest if light else darkest
        background = _blend(canvas.color, white, 0.85) if light else (
            canvas.color if canvas.color[0] < 16 else _blend(canvas.color, black, 0.40))
        ink = darkest if light else brightest
        foreground = ink.color if light else _blend(ink.color, (238, 238, 238), 0.5)
        # Wal elige la mitad superior de la paleta; las imágenes con pocos colores conservan sus familias.
        pool = candidates[len(candidates) // 2:] if len(candidates) >= 16 else candidates
    elif backend == 'colorthief':
        background = _blend(canvas.color, white, 0.90) if light else _blend(canvas.color, black, 0.80)
        ink = darkest
        foreground = _blend(ink.color, black, 0.75) if light else _blend(ink.color, white, 0.60)
        pool = candidates[1:-1] or candidates
    else:
        seed = _blend(canvas.color, white, 0.40) if backend == 'haishoku' else canvas.color
        background = _blend(seed, white, 0.95) if light else _blend(seed, black, 0.80)
        ink = canvas
        foreground = _blend(background, black, 0.75) if light else _blend(background, white, 0.75)
        pool = candidates if backend == 'colorz' else (candidates[1:-1] or candidates)

    # Algunos extremos de wal no permiten texto legible; sólo se corrige el lienzo cuando hace falta.
    lch = oklch(background)
    bound = max(0.94, lch[0]) if light else min(0.32, lch[0])
    background = rgb((bound, lch[1], lch[2]))
    meaningful = [item for item in pool if item in context.chromatic] or context.chromatic
    if not meaningful:
        meaningful = [max(candidates, key=lambda item: (item.weight, item.color))]
    anchor = max(meaningful, key=lambda item: (item.lch[1], item.weight, item.color))
    alternate = max(meaningful, key=lambda item: (
        hue_distance(anchor.lch[2], item.lch[2]) * item.lch[1], item.weight, item.color))

    def put(role, source, color, reason):
        context.put(role, source, *oklch(color), reason=reason)

    put('background', canvas, background, f'{backend}: Pywal dark/light background adjustment')
    put('surface', canvas, _blend(background, foreground, 0.06), 'Source canvas lifted toward Pywal foreground')
    put('surface_alt', canvas, _blend(background, foreground, 0.12), 'Second source-canvas elevation')
    put('foreground', ink, foreground, f'{backend}: Pywal foreground adjustment')
    put('muted', ink, _blend(background, foreground, 0.68), 'Pywal foreground softened against the canvas')
    put('accent', anchor, anchor.color, f'{backend}: chromatic palette representative, no saturation boost')
    put('accent_alt', alternate, alternate.color, f'{backend}: second extracted family, no hue rotation')
    if backend == 'wal':
        for (role, target_hue), tone in zip(
                (('success', 145), ('warning', 85), ('error', 25)),
                (0.32, 0.43, 0.54) if light else (0.84, 0.74, 0.64)):
            source = min(context.chromatic or candidates, key=lambda item: (
                hue_distance(item.lch[2], target_hue), -item.weight, item.color))
            context.put(role, source, tone, source.lch[1],
                        reason='Nearest extracted wallpaper family with a distinct semantic tone')


INTERPRETERS = {
    'spectrum': lambda context: _pywal(context, 'wal'),
    'clustered': lambda context: _pywal(context, 'colorz'),
    'median-cut': lambda context: _pywal(context, 'colorthief'),
    'weighted-regions': lambda context: _pywal(context, 'haishoku'),
}


def interpret(candidates: list[Candidate], image_name: str, mode: str, variant: str,
              fallback: Palette, options: dict, debug: dict | None = None) -> Palette:
    context = Interpretation(candidates, variant, options)
    INTERPRETERS[mode](context)
    colors = {role: rgb(value) for role, value in context.roles.items()}
    before_contrast = colors.copy()
    for role in ('success', 'warning', 'error'):
        if role not in colors:
            colors[role] = fallback.rgb(role)
    for role in ('foreground', 'muted', 'accent', 'accent_alt', 'success', 'warning', 'error'):
        constraints = [(colors[background], minimum) for _, foreground, background, minimum in CONTRAST_REQUIREMENTS if foreground == role]
        # El texto de selección usa el fondo sobre el acento; el contraste también es simétrico.
        constraints.extend((colors[foreground], minimum) for _, foreground, background, minimum
                           in CONTRAST_REQUIREMENTS if background == role and foreground == 'background')
        colors[role] = fit_contrast(colors[role], constraints, variant)
    palette = Palette(f'Spectrum · {image_name}', variant, f'native:{mode}:{image_name}',
                      {role: hex_color(color) for role, color in colors.items()})
    validate_contrast(palette)
    if debug is not None:
        selected = set(context.sources.values())
        raw = [{'color': hex_color(item.color), 'weight': round(item.weight, 4),
                'oklch': list(item.lch), 'center': item.center, 'edge': item.edge,
                'focal': item.focal, 'highlight': item.highlight,
                'selected': item in selected,
                'rejection_reason': None if item in selected else (
                    'Insufficient source chroma or area for an accent' if item not in context.chromatic else
                    'Outside the selected backend role hierarchy')} for item in candidates]
        debug.update({'parameters': options, 'neutral': context.neutral, 'raw_colors': raw,
                      'selected_colors': [item['color'] for item in raw if item['selected']],
                      'rejected_colors': [item for item in raw if not item['selected']],
                      'roles': {}})
        for role, source in context.sources.items():
            final = oklch(colors[role])
            source_lch = source.lch
            target = context.roles[role]
            debug['roles'][role] = {
                'source': hex_color(source.color), 'source_oklch': list(source_lch),
                'intended_oklch': list(target), 'gamut_mapped': hex_color(before_contrast[role]),
                'final': palette.color(role), 'final_oklch': list(final),
                'lightness_adjustment': final[0] - source_lch[0],
                'chroma_adjustment': final[1] - source_lch[1],
                'hue_shift': (final[2] - source_lch[2] + 180) % 360 - 180 if min(source_lch[1], final[1]) > 0.00001 else 0,
                'hue_defined': min(source_lch[1], final[1]) > 0.00001,
                'contrast_lightness_adjustment': final[0] - oklch(before_contrast[role])[0],
                'reason': context.reasons[role],
            }
        for role in ('success', 'warning', 'error'):
            if role in context.sources:
                continue
            source, final = oklch(fallback.rgb(role)), oklch(colors[role])
            debug['roles'][role] = {'source': fallback.color(role), 'source_oklch': list(source),
                                    'intended_oklch': list(source), 'final': palette.color(role),
                                    'final_oklch': list(final), 'gamut_mapped': fallback.color(role),
                                    'lightness_adjustment': final[0] - source[0],
                                    'chroma_adjustment': final[1] - source[1],
                                    'hue_shift': (final[2] - source[2] + 180) % 360 - 180,
                                    'contrast_lightness_adjustment': final[0] - source[0],
                                    'reason': 'Stable semantic hue; only minimum accessibility correction'}
        debug['contrast'] = {label: {'ratio': contrast_ratio(colors[fg], colors[bg]), 'minimum': minimum}
                             for label, fg, bg, minimum in CONTRAST_REQUIREMENTS}
    return palette
