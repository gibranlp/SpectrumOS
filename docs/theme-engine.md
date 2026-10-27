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
- GTK 3 uses a generated `Spectrum-<content hash>` theme built from the native Adwaita base and active `gtk-3.css`. Changing the theme identity refreshes supported running GTK 3 applications. Its managed user import is color-free so it cannot pin older palette values. GTK 4 loads `gtk-4.css` through its managed import; the stylesheet contains both named colors and modern libadwaita CSS variables. Existing personal CSS remains authoritative. The synchronizer publishes the variant through `org.gnome.desktop.interface`. GTK 4 processes that retain their user CSS provider may need reopening to pick up a new palette.
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

## Keychron Q11 lighting

`appearance-sync --apply` also runs `/usr/lib/spectrumos/keychron-rgb-sync`.
It supports the Q11 ANSI Encoder (`3434:01e0`) with VIA protocol 11, verified
on the local keyboard. Detection requires its 32-byte Raw HID descriptor;
keyboard and mouse input interfaces are never written to. Other models and
firmware protocols are skipped or reported as unsupported.

The keyboard follows the active palette's `accent` hue and saturation. Enabled
lighting switches to solid color so rainbow effects cannot override the theme.
Brightness is preserved, and disabled lighting stays disabled. VIA exposes one
shared color for both halves; independent key or half colors are outside this
adapter's scope. Updates use volatile VIA settings without sending the save
command, avoiding EEPROM writes on each theme change. Reconnecting the keyboard
restores its saved settings until the next appearance application.

Wallpaper/theme changes, rollback, and session startup use the existing
appearance synchronization path. Errors are bounded to three seconds without
failing desktop appearance application. Updates are serialized and read the
current palette after acquiring the lock. No additional daemon or firmware
flash is required. The packaged `70-spectrumos-keychron-rgb.rules` grants the
active session access to this model through logind's `uaccess`.

Inspect firmware lighting values with `keychron-rgb-sync --status` and apply with
`keychron-rgb-sync --apply` (both under `/usr/lib/spectrumos/`). Create
`~/.config/spectrumos/keychron-rgb.disabled` to opt out; removing it resumes sync.
Disabling sync leaves the current color in place; use the keyboard's lighting
controls or VIA to select another effect.

The adapter follows the [QMK VIA implementation](https://github.com/qmk/qmk_firmware/blob/master/quantum/via.c)
and the [VIA Q11 definition](https://github.com/the-via/keyboards/blob/master/v3/keychron/q11/ansi_encoder.json).

## Extractor boundary

Wallpaper extraction is not embedded in the renderer. The first adapter invokes Matugen in dry-run JSON mode and maps its Material roles into schema-v1 TOML. Success and warning deliberately retain Spectrum's stable fallback colors because Matugen does not produce those semantic states. Consumer renderers remain unaware of Matugen.

The Matugen adapter remains available independently. The four native modes now follow the requested Pywal backend families, based on the backend wrappers in the owner's Pywal checkout and the upstream extraction algorithms:

| Spectrum mode | Pywal reference | Extraction and palette behavior |
|---|---|---|
| `spectrum` | `wal` | ImageMagick quantization, at least sixteen representatives when available, brightness ordering, upper-palette accents and Pywal-style background/foreground adjustments |
| `clustered` | `colorz` | Six deterministic RGB clusters of unique colors, HSV value limited to 170–200 before clustering, hue ordering and Pywal generic adjustments |
| `median-cut` | `colorthief` | Eight five-bit modified median-cut representatives; population-first then population×volume splitting, near-white filtering, brightness ordering and ColorThief wrapper adjustments |
| `weighted-regions` | `haishoku` | Three divisions per RGB channel, population-weighted regional means, eight largest color regions, brightness ordering and Haishoku wrapper adjustments |

Weighted Regions refers to regions of **color space**, as in Haishoku; moving a patch without changing its histogram no longer changes its palette. Native modes no longer boost chroma, rotate secondary hues, or impose the previous vivid/curated/cinematic styling. ImageMagick is now an explicit Theme package dependency, alongside Python and FFmpeg. No Pywal checkout, SciPy, or optional Python backend package is needed at runtime.

These are Spectrum adaptations, not byte-identical Pywal output. FFmpeg still samples images within 160×160; Colorz initialization is deterministic; low-color and all-white wallpapers remain supported. Spectrum maps representative colors to its ten semantic roles, derives two surfaces and muted ink, and keeps its existing OKLCH accessibility corrections. Unusable canvas extremes are bounded for contrast. Spectrum status roles stay source-derived with distinct tones, while the other modes retain the existing semantic fallback colors. Terminal ANSI output is still the existing semantic consumer mapping.

Automatic variant selection, the Matugen adapter, renderers and atomic generation activation remain compatible. See [Native palette interpretation](theme-personalities.md) for formulas, intentional differences and tunable parameters. `spectrum-theme compare wallpaper.jpg --output /tmp/spectrum-comparison` exports all eight palettes with source/role diagnostics. `extract native` accepts `--parameters overrides.json` and `--debug decisions.json`.

`/usr/lib/spectrumos/theme-menu` provides the Wofi frontend. `Super+W` selects the previous theme, a specific or random extraction mode, an automatic/dark/light variant, and a specific or random wallpaper from `${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers`. Its `Random Dark` and `Random Light` actions choose both the mode and wallpaper immediately while forcing the requested variant. The wallpaper gallery's "Surprise me" button (`theme-menu --random`) selects a wallpaper, extraction mode, and color scheme all randomly with automatic variant detection, without opening a menu, and excludes the previous wallpaper whenever more than one is available. `Super+R` (`theme-menu --random-wallpaper`) is deliberately narrower: it only rerolls the wallpaper, leaving whatever extraction mode, variant, and color scheme are currently selected applying to it — a quick "next wallpaper" rather than "Surprise me"'s full reroll of every axis at once. Both exclude the previous wallpaper whenever more than one is available, and the color scheme pick (for "Surprise me") includes "none" alongside every installed gowall theme, so a surprise can land on plain Spectrum extraction just as easily as any one filter. The frontend extracts and strictly renders a complete generation before asking Awww to change the wallpaper, reloads Hyprland and active Kitty instances, reloads Dunst with its generated configuration, signals Waybar to reload its generated CSS, and reports the selected variant and mode. The last wallpaper is user state under `${XDG_STATE_HOME:-$HOME/.local/state}/spectrumos/theme/`.

Random wallpaper actions share a shuffled queue under `${XDG_STATE_HOME:-$HOME/.local/state}/spectrumos/theme/`. During consecutive random picks, every image is drawn once per cycle, including across menu invocations and session restarts. The queue resets when the wallpaper collection changes. A manual wallpaper choice can alter the order of pending picks so that the next random pick does not immediately repeat it.

SpectrumShell's wallpaper gallery (`/usr/lib/spectrumos/theme-adapter`) exposes the same mode and variant choices in its inspector. Selecting one immediately re-runs the full pipeline — `theme-menu --apply` — against whichever wallpaper is currently active, so switching between them (or between `Auto`/`Dark`/`Light`) repaints the desktop right away for a side-by-side comparison, rather than only taking effect the next time a wallpaper is applied by hand. The choice is still persisted to the same preferences file `theme-menu` reads, so it also becomes the default for the next wallpaper pick.

Canvas selection follows each corresponding Pywal wrapper: Spectrum uses the darkest/brightest representative, Clustered uses its first hue-ordered cluster, and Median Cut and Weighted Regions use their darkest brightness-ordered representative. Readability repair follows these backend choices.

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


## WIN60 HE lighting and WebHID

`appearance-sync --apply` also runs `/usr/lib/spectrumos/win60-rgb-sync`. The connected WIN60 HE uses USB `2e3c:c365`, vendor interface 02 (usage page `0xff1b`, usage `0x91`) and product `SI2825KZHEARGB`, verified on firmware `V3.13.06`. The helper also recognizes `SI2825HEARGB`; it requires the exact WIN 60 HE HID name and vendor report descriptor and checks firmware identity before lighting writes, because other boards share this USB ID.

The helper applies the active semantic accent as static RGB and preserves brightness, speed, background, direction and on/off state. It reads the result back and skips writes when the requested lighting state already matches. It sends only identity/lighting commands; keymaps, macros, Hall-effect actuation, calibration and firmware are not modified. Disconnected keyboards are a quiet no-op. To opt out, create `~/.config/spectrumos/win60-rgb.disabled`. Inspect with `/usr/lib/spectrumos/win60-rgb-sync --status` or apply with `--apply`.

`70-spectrumos-win60-rgb.rules` grants the active local session access only to this model's vendor configuration HID interface through logind `uaccess`. It does not open the keyboard/mouse input interfaces or make devices world-writable. The rule applies automatically on reconnection; the local installation was activated without unplugging the keyboard. In Chrome, open the [standard WIN60 configurator](https://hed.aulacn.com/), click its Connect control and select WIN 60 HE in the browser's device chooser. The website's per-device permission remains a browser choice. Keychron Q11 permissions/support remain unchanged.

Protocol references: [Omakboard's captured WIN60 protocol](https://github.com/elberacasa/omakboard/blob/main/notes/protocol-aula-ff1b.md) and [Aether-HE protocol implementation](https://github.com/MrWhosNexus/Aether-HE/blob/main/protocol.py). The native helper implements the documented report layout independently with Python's standard library.


Gowall filter and extraction backend changes invoke `appearance-sync --rgb-only` immediately after the new palette is committed, at the start of `theme-menu` generation application. This updates connected Legion, Keychron Q11 and WIN60 lighting before shell/wallpaper/compositor refresh work, so a later desktop consumer failure cannot prevent the color update. Standalone full appearance apply still synchronizes RGB. The wallpaper pipeline follows its immediate RGB pass with `--desktop-only`, so it does not probe and synchronize hardware twice. `--rgb-only` does not alter GTK, Qt, browser styling, wallpaper or saved theme choices.

## Theme pipeline reliability and refresh limits

Wallpaper application and preference changes share the per-user `theme/.apply.lock`. Backend, variant and Gowall controls save their change while holding that lock, then request `theme-menu --refresh`; the queued process reads the latest saved choices and active wallpaper after acquiring the same lock. Font-size and font-family rerenders share this lock too. The generation engine separately serializes render/rollback and pruning with `.generation.lock`, protecting staging directories from concurrent cleanup. `appearance-sync` serializes managed configuration writes, and branding staging has its own shared-directory lock.

New generations retain an `appearance` object containing extraction mode, requested variant (including Auto), Gowall scheme and actual rendered wallpaper path. Typography rerenders preserve this object. Previous theme restores these choices and the exact retained image; it refuses to activate a recorded rendered image that is no longer available. Older generations without this metadata retain the legacy current-scheme fallback. Gowall conversion cache identities include source and binary identity/timestamps, so a replaced image or converter does not silently reuse older output.

Native extraction decodes one frame with bounded decoder/encoder/filter threads and retains the existing 160-pixel sampling bound. This avoids decoding every frame of an animated image. Wallpaper thumbnails honor EXIF orientation. The four extraction algorithms and semantic contrast policy are unchanged.

The wallpaper pipeline performs one immediate RGB pass, asks the shell to refresh, applies the wallpaper, reloads Hyprland configuration, and updates branding and application consumers. A shell acknowledgement failure is reported but no longer skips all remaining consumers. GTK, Qt/Kvantum, icons, cursor, fonts and optional Cava/browser integrations each report failures independently, so an optional integration cannot prevent the others from updating. A partial refresh does not emit the normal success notification. Requests launched by `theme-adapter` append diagnostics to `theme/apply.log`, rotated at 1 MiB. Kitty reload signals are limited to the current user's processes. No obsolete Waybar restart is needed for SpectrumShell.

`appearance-stage` caches wallpaper and branding input signatures independently. Mode/variant changes can retain the already converted login wallpaper while regenerating palette-dependent logo assets. Identical wallpaper, palette, wordmark and avatar inputs skip all FFmpeg work and do not trigger another boot-appearance handoff. Repeated icon refreshes skip the icon cache rebuild/theme toggle when generated icon content is unchanged. The Zen extension archive has deterministic metadata, avoiding a rewrite solely because its ZIP timestamp changed.

Refresh support remains application-dependent. Qt/Kvantum configuration and assets follow the active generation, but open applications can retain style caches and need reopening; Spectrum does not terminate them. The [Kvantum maintainer explains the platform/style-plugin limitation](https://github.com/tsujan/Kvantum/discussions/975). GTK 4 user CSS can also stay cached in an existing process. Modern libadwaita uses [CSS variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/css-variables.html), which the GTK 4 renderer now supplies independently of GTK 3's named-color syntax.

October 24 local audit: all four backends produced dark/light palettes meeting the configured contrast requirements for the current wallpaper. Native GTK 3 and GTK 4 parsers accepted all sixteen generated stylesheets without errors or warnings. An unchanged-asset staging sample fell from 1.0905 s to 0.0325 s; this measures the cached staging path, not fresh extraction or every wallpaper. Current settings were preserved, installed files matched source, the shell acknowledged the active palette, and logo/cursor/GTK/Qt paths agreed. Q11 was connected and readable; WIN60 and Legion lighting were absent. No test suites, synthetic theme-switch/rollback sequences, application restarts, package publication or ISO build were performed. Evidence: `artifacts/theme-pipeline-audit-20261024`.
