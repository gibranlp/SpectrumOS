from __future__ import annotations

from dataclasses import dataclass
from math import isfinite, sqrt

from .color import LCH, RGB, fit_contrast, hex_color, hue_distance, oklch, rgb
from .palette import CONTRAST_REQUIREMENTS, Palette, contrast_ratio, validate_contrast

BACKEND_DEFAULTS = {
    'spectrum': {'target_chroma': 0.22, 'hue_separation': 95.0, 'saturation_boost': 1.4},
    'clustered': {'cluster_count': 8, 'harmony_threshold': 65.0, 'target_chroma': 0.12},
    'median-cut': {'color_count': 12, 'fidelity_strength': 0.92, 'max_chroma_adjustment': 0.012},
    'weighted-regions': {'center_weight': 2.8, 'edge_weight': 2.0, 'focal_weight': 4.0,
                         'luminance_weight': 1.5, 'spatial_grid_size': 5},
}
PARAMETER_RANGES = {
    'target_chroma': (0.04, 0.27), 'hue_separation': (40, 160), 'saturation_boost': (1, 2),
    'cluster_count': (4, 16), 'harmony_threshold': (20, 100), 'color_count': (4, 24),
    'fidelity_strength': (0.5, 1), 'max_chroma_adjustment': (0, 0.04),
    'center_weight': (0, 8), 'edge_weight': (0, 8), 'focal_weight': (0, 8),
    'luminance_weight': (0, 4), 'spatial_grid_size': (3, 12),
}


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
        if key in {'cluster_count', 'color_count', 'spatial_grid_size'} and int(value) != value:
            raise ValueError(f'{mode}.{key} must be an integer')
        values[key] = int(value) if key in {'cluster_count', 'color_count', 'spatial_grid_size'} else value
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


def _spectrum(context: Interpretation):
    strong_families = [item for item in context.chromatic if item.lch[1] >= 0.035]
    if strong_families:
        context.chromatic = strong_families
    vivid = max(context.chromatic or context.candidates, key=lambda item: (item.lch[1], sqrt(item.weight), item.color))
    family = [item for item in context.chromatic if item != vivid]
    alternate = max(family, key=lambda item: (min(context.options['hue_separation'], hue_distance(vivid.lch[2], item.lch[2])) * item.lch[1], item.weight)) if family else vivid
    primary_hue = vivid.lch[2]
    alternate_hue = alternate.lch[2]
    canvas = context.dominant if context.dominant.lch[1] >= 0.018 else vivid
    chroma = min(0.27, max(context.options['target_chroma'], vivid.lch[1] * context.options['saturation_boost']))
    if context.variant == 'dark':
        context.put('background', canvas, 0.23, 0.045, reason='Rich chromatic dark canvas')
        context.put('surface', vivid, 0.30, 0.055)
        context.put('surface_alt', alternate, 0.365, 0.065, alternate_hue)
        context.put('foreground', vivid, 0.94, 0.035)
        context.put('muted', alternate, 0.74, 0.05, alternate_hue)
        context.put('accent', vivid, 0.74, chroma, primary_hue, 'Most vivid source family with expressive chroma')
        context.put('accent_alt', alternate, 0.70, chroma * 0.9, alternate_hue, 'Secondary source family with boosted chroma')
    else:
        context.put('background', canvas, 0.968, 0.025, reason='Bright source-tinted canvas')
        context.put('surface', vivid, 0.925, 0.04)
        context.put('surface_alt', alternate, 0.875, 0.05, alternate_hue)
        context.put('foreground', vivid, 0.24, 0.055)
        context.put('muted', alternate, 0.43, 0.065, alternate_hue)
        context.put('accent', vivid, 0.48, chroma, primary_hue, 'Confident saturated accent on a bright canvas')
        context.put('accent_alt', alternate, 0.46, chroma * 0.9, alternate_hue, 'Vivid secondary source family on a bright canvas')

    tones = (0.84, 0.74, 0.64) if context.variant == 'dark' else (0.32, 0.43, 0.54)
    for (role, target_hue, chroma_scale), lightness in zip(
            (('success', 145, 0.65), ('warning', 85, 0.85), ('error', 25, 1.0)), tones):
        source = min(context.chromatic or context.candidates, key=lambda item: (
            hue_distance(item.lch[2], target_hue), -item.weight, item.color))
        context.put(role, source, lightness, chroma * chroma_scale,
                    reason='Wallpaper family with a distinct status tone; no synthetic hue')


def _clustered(context: Interpretation):
    anchor = max(context.chromatic or context.candidates, key=lambda item: (item.weight * sqrt(max(item.lch[1], 0.005)), item.color))
    compatible = [item for item in context.chromatic if item != anchor and hue_distance(anchor.lch[2], item.lch[2]) <= context.options['harmony_threshold']]
    alternate = max(compatible, key=lambda item: (item.weight, item.lch[1])) if compatible else anchor
    secondary_hue = alternate.lch[2]
    if hue_distance(anchor.lch[2], secondary_hue) < 18 and not context.neutral:
        secondary_hue = anchor.lch[2] + 28
    chroma = min(context.options['target_chroma'], max(0.065, anchor.lch[1] * 0.75))
    canvas = context.dominant
    if canvas.lch[1] < 0.018:
        canvas = anchor
    if context.variant == 'dark':
        context.put('background', canvas, 0.275, 0.02, reason='Dominant-cluster tint, calm designer canvas')
        context.put('surface', canvas, 0.325, 0.025)
        context.put('surface_alt', canvas, 0.375, 0.03)
        context.put('foreground', anchor, 0.91, 0.012)
        context.put('muted', anchor, 0.705, 0.018)
        context.put('accent', anchor, 0.76, chroma, reason='Representative cluster; bounded coherent chroma')
        context.put('accent_alt', alternate, 0.68, chroma * 0.85, secondary_hue, 'Compatible family or related tonal hierarchy')
    else:
        context.put('background', canvas, 0.947, 0.014, reason='Soft light dominant-cluster canvas')
        context.put('surface', canvas, 0.915, 0.018)
        context.put('surface_alt', canvas, 0.88, 0.022)
        context.put('foreground', anchor, 0.275, 0.018)
        context.put('muted', anchor, 0.47, 0.023)
        context.put('accent', anchor, 0.50, chroma, reason='Refined moderate-chroma cluster')
        context.put('accent_alt', alternate, 0.535, chroma * 0.85, secondary_hue, 'Secondary hierarchy within compatible families')


def _median_cut(context: Interpretation):
    total = sum(item.weight for item in context.candidates)
    substantial = [item for item in context.candidates if item.weight / total >= 0.02] or context.candidates
    dark = min(substantial, key=lambda item: (item.lch[0], -item.weight))
    bright = max(substantial, key=lambda item: (item.lch[0], item.weight))
    anchor = max(context.chromatic or substantial, key=lambda item: (item.weight * max(item.lch[1], 0.01), item.color))
    alternatives = [item for item in context.chromatic if item != anchor]
    alternate = max(alternatives, key=lambda item: (item.weight * hue_distance(anchor.lch[2], item.lch[2]), item.color)) if alternatives else anchor
    strength = context.options['fidelity_strength']
    def accent_chroma(item):
        return item.lch[1] - min(context.options['max_chroma_adjustment'], item.lch[1] * (1 - strength))
    if context.variant == 'dark':
        canvas_lightness = max(0.255, min(0.34, dark.lch[0]))
        context.put('background', dark, canvas_lightness, min(0.035, dark.lch[1]), reason='Naturally dark source representative; conservative adaptation')
        context.put('surface', dark, canvas_lightness + 0.04, min(0.038, dark.lch[1]))
        context.put('surface_alt', dark, canvas_lightness + 0.075, min(0.045, dark.lch[1]))
        context.put('foreground', bright, 0.89, min(0.028, bright.lch[1]))
        context.put('muted', bright, 0.70, min(0.035, bright.lch[1]))
        context.put('accent', anchor, max(0.61, min(0.81, anchor.lch[0])), accent_chroma(anchor), reason='Source hue and chroma; luminance changes only for readable adaptation')
        context.put('accent_alt', alternate, max(0.61, min(0.79, alternate.lch[0])), accent_chroma(alternate), reason='Another actual source hue, never synthetic hue rotation')
    else:
        canvas_lightness = max(0.905, min(0.972, bright.lch[0]))
        context.put('background', bright, canvas_lightness, min(0.028, bright.lch[1]), reason='Naturally bright source representative, not generic white')
        context.put('surface', bright, canvas_lightness - 0.033, min(0.03, bright.lch[1]))
        context.put('surface_alt', bright, canvas_lightness - 0.063, min(0.035, bright.lch[1]))
        context.put('foreground', dark, 0.31, min(0.034, dark.lch[1]))
        context.put('muted', dark, 0.46, min(0.035, dark.lch[1]))
        context.put('accent', anchor, min(0.54, max(0.40, anchor.lch[0])), accent_chroma(anchor), reason='Faithful source color, darkened only for a usable light UI')
        context.put('accent_alt', alternate, min(0.54, max(0.40, alternate.lch[0])), accent_chroma(alternate), reason='Original secondary hue and restrained chroma')


def _weighted_regions(context: Interpretation):
    options = context.options
    environment = max(context.candidates, key=lambda item: ((item.edge * options['edge_weight'] + item.weight * 0.1) * (1.5 - item.lch[0]), item.weight, item.color))
    focal = max(context.chromatic or context.candidates, key=lambda item: (
        (item.center * options['center_weight'] + item.focal * options['focal_weight']) * max(item.lch[1], 0.005), item.weight, item.color))
    opposing = [item for item in context.chromatic if hue_distance(item.lch[2], focal.lch[2]) > 45]
    environment_alt = max(opposing, key=lambda item: (item.edge * options['edge_weight'] + item.highlight * options['luminance_weight'], item.weight)) if opposing else environment
    highlight = max(context.chromatic or context.candidates, key=lambda item: (item.highlight, item.lch[0], item.color))
    chroma = min(0.18, max(0.085, focal.lch[1] * 0.95))
    if context.variant == 'dark':
        shadow = 0.155 + 0.065 * environment.lch[0]
        context.put('background', environment, shadow, min(0.035, environment.lch[1] * 0.65), reason='Edge/environment shadow with retained atmospheric hue')
        context.put('surface', environment, shadow + 0.08, min(0.04, environment.lch[1] * 0.75))
        context.put('surface_alt', environment_alt, shadow + 0.16, min(0.05, environment_alt.lch[1] * 0.7))
        context.put('foreground', highlight, 0.965, min(0.025, highlight.lch[1]))
        context.put('muted', environment, 0.72, min(0.04, environment.lch[1]))
        context.put('accent', focal, 0.82, chroma, reason='Spatial focal subject: selective luminous highlight')
        context.put('accent_alt', environment_alt, 0.64, min(0.095, environment_alt.lch[1]), reason='Environmental counter-tone with restrained saturation')
    else:
        ivory = 0.913 + 0.012 * environment.lch[0]
        context.put('background', environment, ivory, min(0.035, environment.lch[1] * 0.5), reason='Editorial environmental ivory/gray-blue, distinct light grading')
        context.put('surface', environment, ivory - 0.055, min(0.04, environment.lch[1] * 0.6))
        context.put('surface_alt', environment_alt, ivory - 0.112, min(0.05, environment_alt.lch[1] * 0.6))
        context.put('foreground', environment, 0.20, min(0.04, environment.lch[1]))
        context.put('muted', environment_alt, 0.40, min(0.05, environment_alt.lch[1]))
        context.put('accent', focal, 0.405, chroma, reason='Focal subject as rich ink, not an inverted luminous accent')
        context.put('accent_alt', environment_alt, 0.425, min(0.10, environment_alt.lch[1]), reason='Structural environmental shadow tone')


INTERPRETERS = {'spectrum': _spectrum, 'clustered': _clustered,
                'median-cut': _median_cut, 'weighted-regions': _weighted_regions}


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
