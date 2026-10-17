# Theme Extraction Evaluation

Last run: 2026-08-30

The evaluation harness runs every native extraction mode and the Matugen reference adapter against a wallpaper directory. It writes `report.json` for analysis and `report.html` with wallpaper thumbnails, semantic swatches, extraction timing, explicit pass/fail results for every consumer contrast contract, and representative Kitty, Dunst, Hyprland, and Hyprlock surfaces.

## Reference-machine results

The initial run used four private reference-machine wallpapers, producing 20 valid palettes without extraction or contrast failures. A separate, redistribution-safe four-image corpus now lives under `assets/wallpapers/regression`; future recorded results use that corpus.

| Mode | Mean extraction | Minimum foreground contrast | Minimum muted contrast |
|---|---:|---:|---:|
| Spectrum | 244.8 ms | 13.57:1 | 6.83:1 |
| Clustered | 252.2 ms | 13.19:1 | 6.64:1 |
| Median Cut | 244.5 ms | 13.53:1 | 6.81:1 |
| Weighted Regions | 246.8 ms | 13.93:1 | 7.01:1 |
| Matugen | 264.2 ms | 14.35:1 | 10.85:1 |

These figures describe this small local corpus and are not general performance claims. The generated local dashboard is intentionally ignored by Git under `generated/theme-evaluation/` because it embeds user wallpaper paths.

All 20 dark-corpus palettes pass all nine consumer contrast contracts. A separate light reference image produced five passing palettes across the four native modes and Matugen. Its narrowest passing margin is 0.021:1, which remains visible in the report as a future tuning target. Randomized validation adds 2,000 general RGB cases and 2,000 light-biased cases across the native modes.

## Reproduce

```bash
PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli evaluate assets/wallpapers/regression \
  --output generated/theme-evaluation
```

Open `generated/theme-evaluation/report.html` in a browser. Asset authors, source pages, licenses, and checksums are recorded beside the corpus.
