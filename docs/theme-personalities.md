# Native palette interpretation

## Audit of the existing pipeline

Before implementation changes, all four native backends followed this path:

1. FFmpeg decoded the image to a PPM sample bounded by 160×160 pixels. The PPM reader discarded image dimensions.
2. Spectrum counted RGB bins with 32-channel quantization. Clustered ran deterministic RGB k-means over those bins. Median Cut split the same bins into population/range boxes. Weighted Regions grouped colors into a 3×3×3 RGB color cube; it did not use image coordinates.
3. Every backend entered the same `palette_from_pixels` interpretation: dominant color → HLS background clamp; a population/chroma cutoff → accent selection; HLS saturation/lightness clamps → accents; RGB blends → surfaces and foregrounds.
4. Shared background limits constrained dark/light canvases to the same narrow range. The same gray foregrounds and neutral accent fallback seeded every mode. Coarse HLS lightness stepping for contrast could wash distinct candidates toward the same extremes.
5. Stable semantic status hues came from the variant fallback. The palette passed the existing consumer contrast contracts, then the independent renderers and atomic generation mechanism activated it.

The old profiles made Clustered more saturated than Spectrum, made Median Cut select a distant secondary hue instead of favoring fidelity, and gave Weighted Regions no spatial information. Although profile numbers varied, the shared normalization, common starting grays, tonal secondary fallback and loss of position restricted visual identity. The evaluation report selected only the automatic variant and did not explain individual role adjustments.

## Proposed change

Preserve the decoder boundary, deterministic frequency/k-means/median-box algorithms, ten-role schema, Matugen adapter, renderer interfaces and atomic activation. Split native processing into raw extraction with source/position evidence and four explicit interpretation functions. Use OKLab/OKLCH for interpretation, gamut mapping and minimum contrast corrections. The only common final processing will be color conversion, hue-preserving accessibility repair and validation; it will not choose accents, backgrounds or stylistic targets.

Spectrum will separate colorful source hues and use the strongest chroma with a rich dark or tinted bright canvas. Clustered will choose compatible families and bounded chroma around its dominant cluster. Median Cut will keep source hues and chroma and adapt natural dark/bright representatives only as necessary for UI contrast. Weighted Regions will retain decoded dimensions, select environment colors from edges and focal/highlight colors from spatial evidence, and grade deliberate dark and cinematic light variants.

A comparison command will export all eight palettes for a wallpaper, a standalone visual dashboard, raw/selected/rejected candidates, role transformations and contrast checks. The acceptance corpus will include colorful, blue, warm, near-neutral, dark, bright, low-saturation, small-focal-object and many-color cases, with real wallpapers alongside controlled fixtures. Visual review will accompany numerical checks.

## Implemented pipeline

`decode_native_image` returns pixels **and dimensions**, sampled within 160×160. `extract_colors` produces source representatives with population and optional spatial evidence. `interpret` dispatches to four separate functions that choose all seven wallpaper-derived roles. Conversion and accessibility repair happen after those choices. Renderers still consume the existing ten-role palette; terminal ANSI colors remain a consumer mapping, not an extraction constraint.

Spectrum groups eight-channel RGB bins but retains their actual source means, avoiding quantization-created hues in gray images. Clustered retains deterministic k-means initialization and population aggregation, using OKLab distance. Median Cut retains the box-splitting algorithm and now uses actual source pixels rather than coarse bins. Weighted Regions accumulates source means and spatial evidence by color bin across the image. These are source discovery operations; none imposes a shared UI style.

Perceptual operations use the [original OKLab conversion](https://bottosson.github.io/posts/oklab/). Colors outside sRGB lose the minimum chroma necessary to preserve lightness and hue, rather than clipping RGB channels; this follows the constant-lightness/hue approach described in [gamut mapping](https://bottosson.github.io/posts/gamutclipping/). Contrast is checked on the final quantized sRGB colors using actual relative luminance. Repairs search from the intended color toward lighter ink in dark mode or darker ink in light mode, preserving hue and reducing chroma only when gamut requires it. Repairs do not change canvases or select new sources.

## Role selection

`accent` is the primary interaction color and `accent_alt` the secondary color. Each backend deliberately controls hue hierarchy, canvas tint, foreground tint and surface elevation. OKLCH lightness below is normalized to 0–1; actual sRGB gamut and minimum contrast can change final chroma/lightness.

| Roles | Spectrum | Clustered | Median Cut | Weighted Regions |
|---|---|---|---|---|
| `background` | Dominant chromatic source, otherwise the vivid source; L=.23 dark/.968 light | Dominant cluster, chromatic anchor if dominant is neutral; L=.275/.947 | Darkest/brightest representative covering at least 2%; source L bounded to .255–.34/.905–.972 | Strongest edge/environment source; dark L=.155+.065×source L; light L=.913+.012×source L |
| `surface` | Primary family, distinct tint and L=.30/.925 | Dominant family, controlled C=.025/.018 and L=.325/.915 | Canvas family, dark L+ .04/light L− .033, minimal source chroma | Environment family, dark L+ .08/light L− .055, retained shadow/ivory tint |
| `surface_alt` | Actual secondary source family; L=.365/.875 | Dominant family, C=.03/.022 and L=.375/.88 | Canvas family, dark L+ .075/light L− .063 | Environmental counter-tone, dark L+ .16/light L− .112 |
| `foreground` | Primary-tinted readable ink, L=.94/.24 | Lightly anchor-tinted ink, L=.91/.275 | Naturally bright/dark source, L=.89/.31; subdued source chroma | Highlight-tinted dark-mode text at L=.965; environment-derived light-mode ink at L=.20 |
| `muted` | Secondary-tinted ink, L=.74/.43 | Restrained primary-family ink, L=.705/.47 | Same natural text family at L=.70/.46 | Environment/counter-tone at L=.72/.40 |
| `accent` | Strongest meaningful source chroma; desired C≥.22; L=.74/.48 | Population×√chroma anchor; coherent C≤.12; L=.76/.50 | Population×chroma source; preserve hue and nearly all C; dark source L bounded .61–.81/light .40–.54 | Spatial focal score; selective C=.085–.18; luminous L=.82 dark/rich ink L=.405 light |
| `accent_alt` | Distant chromatic source; retain its hue even when source hues crowd; L=.70/.46 | Strongest compatible cluster within 65°; if too close, a related 28° hierarchy; L=.68/.535 | Actual source family ranked by population×hue distance; no rotation; source C with restrained correction | Environmental source at least 45° from focal when available; otherwise environment itself; quieter C≤.095/.10 and L=.64/.425 |

For Spectrum, `success`, `warning`, and `error` use the meaningful wallpaper families nearest the usual green, amber and red hues, with vivid chroma and distinct readable tones (success/warning/error use dark lightness .84/.74/.64 and light lightness .32/.43/.54 before contrast repair). A single-family wallpaper keeps that family across all roles, and a neutral wallpaper stays neutral. Spectrum never rotates a source hue or injects fallback status colors. The other backends retain variant-matched semantic green, amber and red from Spectrum's existing fallback palette. They are independent of wallpaper fashion and receive only minimum contrast correction. Every backend chooses the other seven roles independently; shared semantic status hues do not flatten canvas/accent identity.

Primary and selection text maintain 4.5:1 against their registered consumers. Muted text, secondary accents and semantic states maintain the existing 3:1 contract; both accent fills also maintain 3:1 against both surfaces. The contract remains in `palette.py`. This does not assert 4.5:1 for every use of colored secondary text. Accessibility and sRGB gamut take priority over exact source luminance/chroma, particularly for bright source colors used as light-theme ink. Diagnostics distinguish intended grading, gamut reduction and accessibility corrections.

Pure gray sources do not acquire arbitrary hue. Their personalities remain distinct through canvas depth, surface spacing and accent hierarchy. A weak colored noise candidate is not amplified unless chroma and area evidence support it; a genuinely vivid focal color covering 0.1% or more of the sample can qualify. A broadly tinted low-chroma image can also qualify, allowing expressive interpretation without using a random seed or a generic fallback hue.

## Spatial weighting

The default grid is 5×5. Each sampled pixel uses its grid cell's normalized center `(x,y)`. Define `r=max(abs(2x−1),abs(2y−1))`, center evidence `(1−r)²`, and edge evidence `r²`. Salience is its OKLab distance from the mean image color. Highlight evidence is `L³×(.02+C)`.

For each color bin, accumulate population `n`, center, edge, salience×(.25+center), and highlight. Center, focal and highlight sums are divided by √n, retaining population influence while letting a small vivid object compete. Edge evidence keeps its full sum to favor large environmental areas.

- Environment score: `(edge×edge_weight + .1×n)×(1.5−L)`.
- Primary score: `(center×center_weight + focal×focal_weight)×max(C,.005)` among meaningful chromatic candidates, or all candidates for a neutral source.
- Secondary score: `edge×edge_weight + highlight×luminance_weight` among source families at least 45° from the focal hue; fall back to environment when none exists.
- Foreground highlight family: strongest accumulated highlight evidence, used as a restrained tint rather than another saturated accent.

This is deterministic composition weighting, not semantic object recognition. Moving a subject without changing the color histogram can change the primary accent. Center/focal controls influence the primary; edge controls influence canvas and counter-tone; luminance controls influence counter-tone highlights. Grid size changes positional resolution. The image/PPM entrypoints and comparison command always retain coordinates. Legacy library calls to `palette_from_pixels` without `image_size` remain supported through nonspatial representative grouping; diagnostics explicitly flag missing coordinates. Callers requiring spatial interpretation must supply matching dimensions.

## Parameters and comparison

Defaults are defined in `interpretation.BACKEND_DEFAULTS`. All overrides are validated and deterministic. They do not change persistent desktop preferences automatically.

| Backend | Parameter defaults | Purpose |
|---|---|---|
| Spectrum | `target_chroma=.22`, `hue_separation=95`, `saturation_boost=1.4` | Desired chroma floor, preferred source accent separation (selection only; never rotates hues), source chroma amplification; desired C capped at .27 before gamut |
| Clustered | `cluster_count=8`, `harmony_threshold=65`, `target_chroma=.12` | Raw representative count, maximum compatible source hue distance, coherent accent chroma ceiling |
| Median Cut | `color_count=12`, `fidelity_strength=.92`, `max_chroma_adjustment=.012` | Box count, retained source chroma fraction, maximum intentional chroma reduction; gamut can require further reduction |
| Weighted Regions | `center_weight=2.8`, `edge_weight=2`, `focal_weight=4`, `luminance_weight=1.5`, `spatial_grid_size=5` | Exact positional/hierarchy controls described above |

```bash
spectrum-theme compare wallpaper.jpg --output /tmp/spectrum-comparison
spectrum-theme compare ~/Pictures/Wallpapers --output /tmp/spectrum-comparison
spectrum-theme extract native wallpaper.jpg --mode weighted-regions --variant light \
  --parameters spatial.json --debug decisions.json --output cinematic-light.toml
```

For `extract`, `spatial.json` contains a flat object such as `{"center_weight":4,"edge_weight":1.5}`. For `compare`, overrides are keyed by backend, such as `{"weighted-regions":{"center_weight":4},"spectrum":{"hue_separation":110}}`. Unknown names, invalid types, nonfinite values, out-of-range values and fractional counts are rejected.

Comparison decodes each image once and extracts candidates once per backend, then interprets both variants. It writes eight validated TOML palettes per image, `report.html` and `report.json`. The HTML embeds wallpaper thumbnails and puts four UI interpretations side by side for each variant; it requires no network or JavaScript. Expand a card for raw colors, selections, role transformations and contrast ratios. JSON retains every raw candidate, rejected candidates, weights/spatial scores, role source and intended/final OKLCH, ΔL/ΔC/Δh, separate accessibility ΔL, parameters, timings and pairwise perceptual distances. Hue shift is zero when a source or result is achromatic, with `hue_defined=false`. HTML shows selected candidates first and then the most populous other colors, limited to 96 swatches for readability. Exported palette downloads require the adjacent TOML files; the visual report itself is standalone.

Reproduce the controlled acceptance images with `python scripts/theme-personality-fixtures /tmp/personality-wallpapers`, then compare that directory. The fixture generator uses only Python's standard library.

## Acceptance review

The reviewed corpus contains the nine requested controlled image types, four real repository wallpapers (color orbits, amber orchard, azure balloons and violet horizon), and the active user wallpaper: 14 images × 8 palettes = 112 valid palettes. UI contact sheets were visually inspected for every image in both variants. Spectrum shows multiple confident color families, Clustered preserves coherent hierarchy, Median Cut retains original families with modest processing, and Weighted Regions creates environmental shadows or editorial light structure with selective focal accents.

The small vivid focal fixture gives Clustered the broad blue-gray environment and Weighted Regions the small warm focal subject. A test swaps a warm patch between center and edge while preserving the histogram: all nonspatial backends remain identical, while Weighted Regions changes its primary accent. Nearly monochrome and low-saturation cases distinguish expressive grading from source fidelity. Color science reference/roundtrip/gamut tests, semantic role validation, all nine corpus cases, CLI diagnostics/comparison tests and 4,000 seeded randomized dark/light contrast cases and 1,120 parameter-boundary cases accompany the visual review.

Across the same 14-image corpus, mean nearest-backend distance averaged over background, foreground and both accents rose from .0416 to .0690 in OKLab (0–1 scale). This supports the audit but is not the visual acceptance criterion. The generated review artifacts live under `generated/theme-personalities/review/` and are intentionally not source/package assets.
