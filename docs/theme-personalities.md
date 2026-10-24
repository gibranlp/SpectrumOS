# Pywal-inspired native palettes

The four existing mode identifiers remain stable, with the following references:

| Mode | Reference | Default control |
|---|---|---|
| Spectrum (`spectrum`) | Pywal `wal` / ImageMagick | `color_count=16` |
| Clustered (`clustered`) | Pywal `colorz` | `cluster_count=6` |
| Median Cut (`median-cut`) | Pywal `colorthief` | `color_count=8` |
| Weighted Regions (`weighted-regions`) | Pywal `haishoku` | No parameters |

This replaces the previous frequency-bin, OKLab-cluster, source-box and spatial/cinematic personalities. Historical comparison artifacts describe that earlier implementation, not the current algorithms.

## Extraction

FFmpeg decodes images within 160×160 pixels and retains dimensions. Spectrum sends that RGB sample to ImageMagick without dithering, requests sixteen colors, and retries up to nineteen larger quantizations if fewer representatives are returned. Solid/low-color sources are accepted rather than rejected. Representatives are ordered by YIQ brightness. This follows [Pywal's wal backend](https://github.com/dylanaraps/pywal/blob/master/pywal/backends/wal.py), with fixed sampling and no spatial dithering for reproducibility.

Clustered follows [Colorz](https://github.com/metakirby5/colorz/blob/master/colorz.py): unique source colors get equal influence, HSV value is limited to 170–200, RGB k-means produces six representatives, and output is hue-ordered. Deterministic farthest-point initialization and bounded convergence replace SciPy's random initialization. Duplicate source pixels do not change the cluster fitting. This deliberately differs from a population-weighted dominant-color algorithm.

Median Cut follows [ColorThief's MMCQ](https://github.com/fengsp/color-thief-py/blob/master/colorthief.py): five bits per channel, near-white exclusion, population-prioritized splitting for the first 75% of boxes, then population×RGB-volume priority. Each box splits along its longest RGB axis around a population median with a range-based cut adjustment. Representatives use weighted five-bit cell centers. Spectrum directly processes the bounded sample instead of ColorThief's quality-stride subsampling, retains nonempty boxes for low-color sources, and falls back to the source for all-white images. Its compact box implementation tightens bounds to occupied colors, so it is not a byte-for-byte port of the upstream quantizer.

Weighted Regions follows [Haishoku](https://github.com/LanceGin/haishoku/blob/master/haishoku/alg.py): divide each observed channel range into three equal intervals, group colors into the resulting 27 color-space regions, calculate population-weighted RGB means with integer truncation, and retain the eight largest populations. Output is brightness-ordered for the Pywal wrapper. These are color regions, not positional regions; edge/center/focal controls have been removed. Source means and region boundaries match the upstream calculation.

## Interpretation and accessibility

Let `lighten(c,a)=c+(255-c)×a` and `darken(c,a)=c×(1-a)`, truncating each RGB channel as Pywal does. Color ordering is preserved from extraction.

| Mode | Dark background | Light background | Foreground |
|---|---|---|---|
| Spectrum | First color darkened 40%, unless its red channel already begins with hexadecimal zero | Last color lightened 85% | Last color blended equally with #eeeeee in dark mode; first color in light mode |
| Clustered | First hue-ordered color darkened 80% | First hue-ordered color lightened 95% | Dark background lightened 75%; light background darkened 75% |
| Median Cut | First color darkened 80% | First color lightened 90% | First color lightened 60% in dark mode or darkened 75% in light mode |
| Weighted Regions | First color lightened 40%, then darkened 80% | First color lightened 40%, then lightened 95% | Same generic foreground adjustment as Clustered |

Accents retain extracted chroma and hue before accessibility repair. Spectrum favors the upper half of a full palette, matching wal's palette selection; other modes use their chromatic representatives. The primary is the most chromatic qualifying representative and the secondary favors a distant extracted family. There is no synthetic hue rotation or chroma boost. Existing area/chroma checks prevent weak noise from coloring neutral wallpapers.

Spectrum derives surface/surface_alt by blending background 6%/12% toward the intended foreground and muted ink by blending 68%. Unusable background extremes are bounded to OKLCH L≤.32 dark or L≥.94 light. Hue-preserving minimum contrast repair then enforces all existing text, selection and control contracts. These adaptations and the ten-role mapping mean the final desktop colors need not equal Pywal's sixteen ANSI slots. Terminal renderers keep their existing semantic mapping. Pywal's ineffective loop-local saturation adjustments are not reproduced as real saturation changes.

Spectrum status hues still come from source families nearest conventional green/amber/red, with distinct tones. Other modes retain the variant's fixed semantic status colors. Auto variant detection and atomic rendering/activation are unchanged.

## Parameters and comparison

`color_count` accepts integers 4–35; `cluster_count` accepts integers 4–16. Unknown or removed styling/spatial parameters return a clear error instead of silently doing nothing. `extract native --parameters` accepts that mode's controls; comparison accepts an object keyed by mode:

```json
{"spectrum": {"color_count": 16}, "clustered": {"cluster_count": 6}, "median-cut": {"color_count": 8}}
```

```sh
spectrum-theme compare wallpaper.png --output /tmp/spectrum-comparison
```

This exports eight dark/light palettes, an HTML preview and source/final-role diagnostics, including contrast checks. RGB dark/light blends can shift perceived OKLCH hue slightly; accessibility changes are reported separately. Dimensions remain available for decoding and diagnostics, but no backend uses focal/edge image-position weighting.

Regression coverage includes Colorz value clamping, equal unique-color influence and deterministic ordering; MMCQ five-bit cells, white handling and population conservation; Haishoku exact-third boundaries, means and top-eight populations; ImageMagick quantization/retries and failures; known Pywal background formulas; neutral/low-color cases; the nine-image fixture corpus; renderers, CLI and atomic generation behavior.
