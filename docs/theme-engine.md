# Spectrum Theme Engine

Status: Desktop Integration Slice 0.1 reference implementation

## Objective

SpectrumOS2 applications consume semantic colors through independent generated files. They do not read pywal caches or share one giant generated configuration.

## Palette schema v1

A palette is TOML with metadata and exactly ten semantic roles:

| Role | Intended use |
|---|---|
| `background` | Primary application and desktop background |
| `surface` | Panels, notifications, and raised containers |
| `surface_alt` | Secondary surfaces and separators |
| `foreground` | Primary readable text |
| `muted` | Secondary text and inactive elements |
| `accent` | Primary interaction and focus color |
| `accent_alt` | Secondary accent and gradients |
| `success` | Positive state |
| `warning` | Caution state |
| `error` | Critical or destructive state |

Colors use `#RRGGBB`. Schema v1 validates the pairings used by current consumers:

| Pairing | Minimum |
|---|---:|
| Foreground on background | 4.5:1 |
| Muted text on background | 3:1 |
| Foreground on surface | 4.5:1 |
| Muted text on surface | 3:1 |
| Background text on accent selection | 4.5:1 |
| Alternate accent on background | 3:1 |
| Success, warning, and error on background | 3:1 each |

The 3:1 status/accent requirements cover graphical state indicators and secondary text, while primary and selection text use 4.5:1. Native extraction corrects accent and muted lightness deterministically when a candidate misses its required ratio.

Packaged fallbacks are `spectrum-dark.toml` and `spectrum-light.toml`. Native extraction automatically chooses the matching semantic status roles; Matugen accepts an explicit dark or light variant. A generated palette must use this schema regardless of whether its extractor is native, Matugen, pywal-compatible, or fixed.

## Generation protocol

The reference command renders into:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/spectrumos/theme/
├── current -> generations/<generation-id>
└── generations/
    └── <generation-id>/
        ├── palette.json
        ├── generation.json
        ├── hyprland.lua
        ├── hyprlock.conf
        ├── kitty.conf
        ├── dunstrc
        ├── waybar-spectrum-{unified,tonal,prism}.css
        ├── waybar-square-{unified,tonal,prism}.css
        ├── wofi.css
        └── wofi-wallpaper.css
```

Every file is written and synchronized inside a private staging directory. The completed directory is renamed into place, then `current` is switched with one atomic replacement. Existing consumers therefore continue using the previous complete generation if rendering fails.

Invalid user palettes fall back to the packaged palette unless strict mode is requested. Every generation records its palette identity and associated wallpaper in `generation.json`. The newest 12 complete generations are retained by default. Cleanup occurs before activation, removes inactive legacy generations that lack rollback metadata, and never removes the active generation. Rollback validates the previous generation and wallpaper before atomically changing `current`.

## Reference commands

The prototype uses only Python's standard library and does not install itself or touch the live desktop:

```bash
PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli validate path/to/palette.toml

PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli render \
  --palette path/to/palette.toml \
  --output /tmp/spectrum-theme-preview

PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli extract matugen wallpaper.png \
  --output /tmp/spectrum-wallpaper.toml

PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli extract native wallpaper.ppm \
  --mode spectrum \
  --output /tmp/spectrum-native.toml

PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli evaluate ~/Pictures/Wallpapers \
  --output /tmp/spectrum-theme-evaluation

PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli rollback
```

The Python implementation exists to stabilize behavior while the reference host lacks Rust tooling. It is not the final packaging decision. Porting to Rust should preserve schema compatibility, deterministic rendering, failure behavior, and the atomic generation layout.

## Consumer integration

For a practical guide aimed at application authors, package maintainers, and Spectrum users, see [Integrating Applications with Spectrum Colors](application-color-integration.md).

- Hyprland sources the generated color fragment after its static fallback values.
- Kitty includes its generated theme file independently from normal user settings.
- Cava uses a generated `cava.theme` with the active background and accent gradient. Appearance sync links it as `~/.config/cava/themes/Spectrum`, selects it when no custom colors are active, and signals running Cava windows to reload their colors. Existing audio and visualization settings remain available.
- Hyprlock starts with the generated `hyprlock.conf`, keeping its lock UI synchronized with the active semantic generation. It shows the shared wallpaper, a larger transparent Spectrum logo, the same circular user photo as SDDM, a large clock/date, and a permanently visible password field with unlock guidance and keyboard-layout/Caps Lock feedback. Weather reads the desktop's existing cache without network requests; missing, mismatched, or older-than-one-day forecasts are hidden, and older cached readings show their update time.
- Dunst uses a complete generated configuration because it lacks a general include mechanism. Spectrum supplies geometry, icons, progress bars, semantic urgency states, and safe application identity rules without overwriting a user's unrelated `dunstrc` or executing per-application scripts.
- Waybar independently selects a package-owned layout, a rounded Spectrum or Square geometry style, and a semantic color composition. The bar itself is always a solid, opaque surface — no module or container falls back to a semi-transparent fill, so the bar stays legible over any window underneath it regardless of that window's own background. Unified keeps every module on one calm shared surface, Tonal lifts every functional group onto a slightly elevated surface tone with accent-colored icons, and Prism alternates solid saturated accent blocks with a more muted secondary surface for telemetry. `Super+Shift+B` controls every axis. Choices persist under `${XDG_STATE_HOME:-$HOME/.local/state}/spectrumos/waybar/`, and all twelve visible style/theme combinations are generated atomically from the current palette.
  - Minimal keeps only workspaces, clock, and tray.
  - Multimedia adds native MPRIS metadata and transport controls, a PipeWire Cava visualization whose columns form a gradient between the current wallpaper accents, audio, Bluetooth, brightness, and battery.
  - Productivity centers a persistent Pomodoro/task widget whose task editor uses Wofi.
  - Detailed exposes disk, CPU, memory, auto-discovered GPU load/temperature, CPU temperature, network throughput, audio, brightness, battery, idle inhibition, weather, and tray.
  - Gaming emphasizes CPU, memory, GPU, temperatures, actual monitor refresh rate, network throughput, audio, and idle inhibition. Refresh rate is deliberately labeled Hz rather than FPS.
  - Hidden stops Waybar without losing the selected style or theme.

Weather is disabled by default to avoid implicit IP geolocation. Add a location string to `${XDG_CONFIG_HOME:-$HOME/.config}/spectrumos/weather-location` to opt in; results are cached for 30 minutes. Hardware-specific modules and weather collapse cleanly when unavailable.
- Every visible Waybar layout includes a typography widget backed by `/usr/lib/spectrumos/font-size-menu`. It stores a validated base size from 8px through 24px under `${XDG_STATE_HOME:-$HOME/.local/state}/spectrumos/typography/font-size`, then atomically rerenders the active palette and runs `appearance-sync --apply`. Waybar, Wofi, Kitty, and Dunst use the base directly; Hyprlock derives proportionate clock and date sizes. The current wallpaper and semantic colors are preserved. The Eww control center's grid buttons (`eww-font-size`/`eww-font-family`) call the menu script directly, not detached with `setsid -f` — that was tried first and, like the same pattern in `performance-mode` (see `docs/performance-mode.md`), a detached run of the whole reload/reload/notify pipeline could finish unpredictably late and clobber whatever size or family was picked in the meantime (confirmed live: a size change appeared to apply, then silently reverted to an older value moments later with no script still running). Picking several sizes/families back to back also has no wofi prompt serializing the clicks for it (the grid calls `--set` directly), so both scripts take a lock (`flock`) around their whole apply step and re-check the persisted value right after acquiring it, skipping the heavy steps entirely if a newer click has already superseded this one — otherwise concurrent runs raced on the same `hyprctl`/waybar/eww steps and one could abort mid-pipeline (under `set -e`) before ever reaching the dunst reload. Both also restart dunst outright rather than only `dunstctl reload`-ing it: reload re-parses the config and dunst logs it happening, but a font change specifically was found to not visibly take effect through reload alone, only through a later, unrelated full restart — a known class of dunst behavior (e.g. dunst-project/dunst#1058) where geometry tied to font metrics isn't reliably recomputed by a settings reload. `dunstctl reload` (then a fresh launch) remains a fallback if `systemctl --user restart dunst.service` itself isn't available. Both scripts (and `theme-menu`'s own `apply_generation`) also call `eww-refresh` *last*, after every one of these steps including the dunst restart and the confirmation toast: when the Eww grid (not a Hyprland keybind) is what triggered the script, the script itself is a child of the Eww daemon's own `spectrum-eww.service` cgroup, and `eww-refresh`'s `systemctl --user restart spectrum-eww.service` uses systemd's default `KillMode=control-group` — it kills every process in that cgroup, including the very script that called it, if anything is still running at that moment. With `eww-refresh` earlier in the sequence, that self-inflicted kill could (and reliably did, for a font-size/family change picked from the grid) cut the script off before it ever reached its own dunst reload, while the exact same script invoked directly (or from a keybind, outside Eww's cgroup) always completed fine — which is why only a wallpaper change triggered via keybind, not the grid, looked like it "worked."
- The monospace family alongside it works the same way through `/usr/lib/spectrumos/font-family-menu`, offered as a fixed, verified-installed set rather than free text: JetBrains Mono (default), Fira Code, Source Code Pro, Cascadia Code, Hack, and IBM Plex Mono — each a Nerd Font variant already in `bootstrap/packages/desktop.txt`. The choice persists as a short slug under `.../spectrumos/typography/font-family`; `FONT_FAMILIES` in `spectrum_theme.cli` is the single source of truth mapping each slug to its actual font name (e.g. `fira-code` → `FiraCode Nerd Font`), consumed identically by the Eww control center (Appearance → Monospace font) and the `font-family-menu` Wofi picker. It reaches Kitty, Alacritty, Waybar, Wofi, the Eww control center itself, and Dunst's notification font.
- `appearance-sync` extends the same base size to third-party GTK and Qt applications, not just Spectrum's own generated chrome: it sets `org.gnome.desktop.interface font-name`/`monospace-font-name` via `gsettings` (preserving whichever font family is already configured — only the trailing point-size field changes), and updates the `[Fonts]` section of `~/.config/qt5ct/qt5ct.conf` and `~/.config/qt6ct/qt6ct.conf` the same way. Qt only reads those files at all once a platform-theme plugin is selected — `QT_QPA_PLATFORMTHEME=qt5ct` is set both in Hyprland's own environment and in the session's `environment.d`, and works for Qt6 apps too because qt6ct's platform-theme plugin registers under both `qt6ct` and `qt5ct`. Changing font size (or reapplying appearance) is what applies this — Qt's environment variable specifically takes effect on the next login/session start, matching every other `environment.d` value SpectrumOS sets.
- GTK 3 and GTK 4 load `gtk-3.css` and `gtk-4.css` from the active generation through one managed import installed by `/usr/lib/spectrumos/appearance-sync`. The import precedes existing user CSS, so personal rules remain authoritative. The synchronizer also publishes the palette variant through `org.gnome.desktop.interface`, triggering supported running applications to refresh without restarting them.
- Native Qt 5 and Qt 6 use Kvantum as a shared drawing backend selected through the session environment. Spectrum generates the compact `Spectrum.kvconfig` widget palette and matching `Spectrum.colors` semantic color scheme inside every atomic generation; the appearance synchronizer links them into `${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum/Spectrum/` and selects that theme without copying third-party visual assets. New Qt processes pick up activated and rolled-back generations. Qt retains Wayland's per-monitor scaling instead of forcing unsupported global DPI overrides.
- Wofi uses five package-owned geometry profiles—left, right, calculator, recorder, and wallpaper—through `/usr/lib/spectrumos/wofi`. Standard surfaces use generated `wofi.css`; the searchable two-column thumbnail gallery uses `wofi-wallpaper.css`. See `docs/wofi.md` for workflow mappings.
- Later consumers receive their own renderers and may fail independently without invalidating the palette.

Renderers do not restart applications. The theme frontend reloads Hyprland, Kitty, Dunst, and Waybar only after a complete generation has activated.

## Legion Pro 7 lighting

`appearance-sync --apply` also runs `/usr/lib/spectrumos/legion-rgb-sync`.
It detects Lenovo machine type `83F5`, product `Legion Pro 7 16IAX10H`, and
USB HID controller `048d:c197` with usage page `ff89`. Other machines are skipped.
Keyboard and lid use `accent`; the 28 perimeter LEDs use `accent_alt` from the
active `palette.json`. Brightness, the selected lighting profile, and the logo
on/off setting are preserved, including lights deliberately left off.

All wallpaper frontends converge on `theme-menu` and its `apply_generation`
step: the gallery, mode/variant/scheme selection, Super+W, Super+R, random theme,
previous theme, panel actions, and Thunar's wallpaper action. That step calls
`appearance-sync`; session startup and explicit appearance reapplication call it
as well. Generation/render previews alone do not change hardware. Failed theme
extraction never reaches the lighting apply step. Lighting errors are bounded
to three seconds and reported on stderr without failing desktop appearance sync.
Concurrent lighting updates are serialized and read the active palette after
acquiring the lock so an older invocation cannot restore stale colors.

The packaged `70-spectrumos-legion-rgb.rules` grants the active local session
access through logind's `uaccess`; no root process, sudo prompt, extra group, or
external checkout is needed during theme changes. After installing the rule on
an existing session, run `sudo udevadm control --reload-rules` and
`sudo udevadm trigger --subsystem-match=hidraw --action=change`.

Check detection/access with `/usr/lib/spectrumos/legion-rgb-sync --status` and
reapply with `/usr/lib/spectrumos/legion-rgb-sync --apply`. To opt out, create
`~/.config/spectrumos/legion-rgb.disabled`; removing it re-enables synchronization.
The minimal stdlib HID implementation follows the Spectrum effect format in
[LenovoLegionToolkit's Native.cs](https://github.com/BartoszCichecki/LenovoLegionToolkit/blob/master/LenovoLegionToolkit.Lib/Native.cs),
including the unpadded effect report length modulo 255. Zone addresses match the
[Legion Spectrum Control](https://github.com/alstergee/legion-spectrum-control)
layout tested on this model.

## Extractor boundary

Wallpaper extraction is not embedded in the renderer. The first adapter invokes Matugen in dry-run JSON mode and maps its Material roles into schema-v1 TOML. Success and warning deliberately retain Spectrum's stable fallback colors because Matugen does not produce those semantic states. Consumer renderers remain unaware of Matugen.

The Matugen adapter provides a reference for comparison. Native processing separates raw source evidence (`extractors.py`) from four explicit palette interpretations (`interpretation.py`). OKLab/OKLCH conversion, hue-preserving gamut mapping and minimum accessibility repairs live in `color.py`; shared helpers do not select palette roles or stylistic targets.

| Mode | Extraction | Interpretation |
|---|---|---|
| `spectrum` | Frequency bins retaining actual mean source colors | Vivid chroma, source-only hue families (including status roles), colorful dark/bright canvases |
| `clustered` | Deterministic clusters with OKLab distance | Compatible families, coherent chroma, a polished dominant-cluster canvas |
| `median-cut` | Population/range splitting of actual source colors | Original hue relationships, restrained chroma changes, natural dark/bright representatives |
| `weighted-regions` | Color populations with decoded coordinates and spatial grid evidence | Edge-derived environment, focal accents, selective highlights, distinct cinematic dark/light grading |

Stable sorting, fixed cluster initialization and explicit interpretation rules make repeated extraction reproducible. Automatic variant selection retains the existing average image-luminance threshold. Both forced variants have their own rules; light palettes are not inverted dark palettes. Fully neutral sources keep neutral families, while meaningful low-chroma sources can be amplified by Spectrum. Spectrum status roles select the wallpaper families nearest their conventional hues without adding absent colors; the other backends retain fixed semantic status hues with accessibility correction. The ten-role schema, Matugen mapping, application renderers and atomic activation remain compatible.

See [Native palette interpretation](theme-personalities.md) for the pre-change audit, every role's selection rules, tunable defaults, exact spatial weighting, limitations and validation evidence. `spectrum-theme compare wallpaper.jpg --output /tmp/spectrum-comparison` exports all eight palettes and an HTML comparison with source/role diagnostics. `extract native` also accepts `--parameters overrides.json` and `--debug decisions.json`. FFmpeg remains the explicit image decoder dependency and now preserves sample dimensions at the PPM boundary.

`/usr/lib/spectrumos/theme-menu` provides the Wofi frontend. `Super+W` selects the previous theme, a specific or random extraction mode, an automatic/dark/light variant, and a specific or random wallpaper from `${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers`. Its `Random Dark` and `Random Light` actions choose both the mode and wallpaper immediately while forcing the requested variant. The wallpaper gallery's "Surprise me" button (`theme-menu --random`) selects a wallpaper, extraction mode, and color scheme all randomly with automatic variant detection, without opening a menu, and excludes the previous wallpaper whenever more than one is available. `Super+R` (`theme-menu --random-wallpaper`) is deliberately narrower: it only rerolls the wallpaper, leaving whatever extraction mode, variant, and color scheme are currently selected applying to it — a quick "next wallpaper" rather than "Surprise me"'s full reroll of every axis at once. Both exclude the previous wallpaper whenever more than one is available, and the color scheme pick (for "Surprise me") includes "none" alongside every installed gowall theme, so a surprise can land on plain Spectrum extraction just as easily as any one filter. The frontend extracts and strictly renders a complete generation before asking Awww to change the wallpaper, reloads Hyprland and active Kitty instances, reloads Dunst with its generated configuration, signals Waybar to reload its generated CSS, and reports the selected variant and mode. The last wallpaper is user state under `${XDG_STATE_HOME:-$HOME/.local/state}/spectrumos/theme/`.

Random wallpaper actions share a shuffled queue under `${XDG_STATE_HOME:-$HOME/.local/state}/spectrumos/theme/`. During consecutive random picks, every image is drawn once per cycle, including across menu invocations and session restarts. The queue resets when the wallpaper collection changes. A manual wallpaper choice can alter the order of pending picks so that the next random pick does not immediately repeat it.

SpectrumShell's wallpaper gallery (`/usr/lib/spectrumos/theme-adapter`) exposes the same mode and variant choices in its inspector. Selecting one immediately re-runs the full pipeline — `theme-menu --apply` — against whichever wallpaper is currently active, so switching between them (or between `Auto`/`Dark`/`Light`) repaints the desktop right away for a side-by-side comparison, rather than only taking effect the next time a wallpaper is applied by hand. The choice is still persisted to the same preferences file `theme-menu` reads, so it also becomes the default for the next wallpaper pick.

Canvas selection belongs to each backend: Spectrum may tint from a vivid source, Clustered from its dominant family, Median Cut from a natural dark/bright representative, and Weighted Regions from spatial environment evidence. There is no shared background normalization that forces them to converge.

## Color scheme conversion (gowall)

The Eww control center's wallpaper gallery inspector (Palette controls, directly under Variant) lets a user pin every wallpaper to a fixed external palette instead of letting Spectrum's native extractor pick its own colors — the same inline, scrollable list of choice-buttons as Extraction and Variant, no separate page. "None" always leads the list. It wraps [gowall](https://github.com/Achno/gowall) (packaged as `gowall-bin`), which recolors an image to one of its ~34 bundled themes (Catppuccin, Nord, Gruvbox, Dracula, and so on) through a HALD CLUT built from the theme's own palette. Selecting a scheme sets it as the standing default: `theme-menu` recolors whichever wallpaper is being applied — through the gallery, `Super+W`, `Super+R`, or a mode/variant change — *before* it's handed to Awww and *before* Spectrum's native extractor reads it, so the desktop background and its extracted semantic palette are both derived from the same converted image. Choosing "None" restores extraction from the original, unconverted wallpaper.

Converted images are cached per `(scheme, wallpaper)` pair under `${XDG_CACHE_HOME:-$HOME/.cache}/spectrumos/theme/converted/`, reusing the cached file as long as the source wallpaper hasn't changed since — gowall's own CLUT generation is the slow part of an apply, and every mode/variant tweak re-runs the same wallpaper through it. The scheme preference lives in the same `preferences` file as the extraction mode and variant. If gowall isn't installed, or a conversion fails, `theme-menu` falls back to the original wallpaper and notifies rather than failing the apply.

This only changes *what's shown and extracted from* — it deliberately does not change what `render`'s `--wallpaper` metadata (and therefore `rollback`) points at, which stays the original file under `Wallpapers/` so the gallery's "current" badge and a later `theme-adapter apply` keep resolving a real file. A separate `last-rendered-wallpaper` state file (distinct from the existing `last-wallpaper`) records whichever image — original or converted — was actually shown last, so `wallpaper-restore` reapplies the same one at session start instead of reverting to the untouched original.

The native extractor design addresses:

- dark/light variant selection;
- semantic role assignment;
- contrast correction;
- saturated-accent limits;
- deterministic output;
- neutral or low-color wallpapers;
- fallback behavior;
- performance and cache identity.

## Deferred work

- Representative licensed wallpaper corpus and visual comparison snapshots for every mode.
- Schema migration rules.
- Per-consumer health reporting.
- Package recipes and installation paths.
- SDDM and Plymouth renderers.
