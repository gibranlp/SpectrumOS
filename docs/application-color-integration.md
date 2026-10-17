# Integrating Applications with Spectrum Colors

This guide is for application authors, package maintainers, and Spectrum users who want an application to follow the active wallpaper-derived color scheme.

## How Spectrum theming works

Spectrum treats theming as a producer/consumer pipeline:

```text
wallpaper or fixed palette
        ↓
extract and validate ten semantic roles
        ↓
render a complete generation in a private directory
        ↓
atomically replace the `current` symlink
        ↓
reload supported applications
```

The active per-user generation is:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/spectrumos/theme/current/
```

`current` is a symlink to one complete directory under `generations/`. Spectrum never updates individual files in an active generation. A consumer therefore sees either the complete previous theme or the complete new theme, never a partially written theme.

The portable palette contract is `current/palette.json`:

```json
{
  "schema_version": 1,
  "name": "Spectrum · wallpaper.jpg",
  "variant": "dark",
  "source": "native:weighted-regions:wallpaper.jpg",
  "roles": {
    "background": "#101218",
    "surface": "#191c24",
    "surface_alt": "#252a35",
    "foreground": "#e9edf5",
    "muted": "#9ca6b8",
    "accent": "#76b7ff",
    "accent_alt": "#c49aff",
    "success": "#78dba9",
    "warning": "#f2c66d",
    "error": "#ff8c9a"
  }
}
```

Always check `schema_version` before using the roles. Do not depend on a generation directory name or a specific extraction backend.

## Choose the smallest integration

### GTK 3, GTK 4, Qt 5, or Qt 6 applications

Most toolkit-native applications need no Spectrum-specific code. Spectrum installs managed GTK imports and selects its generated Kvantum theme for native Qt applications. Existing user CSS remains authoritative.

Use normal toolkit semantic widgets and states. Avoid hardcoded background, text, selection, or focus colors unless the application provides a user override. New processes receive the current scheme, and supported running applications refresh when the desktop appearance is synchronized.

### Applications that can read a palette at runtime

Read `palette.json` every time the application reloads its appearance. Do not resolve and permanently cache the target of `current`, because the symlink changes when a new generation activates.

Python example:

```python
import json
import os
from pathlib import Path


def spectrum_palette() -> dict[str, str] | None:
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    palette_path = cache_home / "spectrumos" / "theme" / "current" / "palette.json"
    try:
        payload = json.loads(palette_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if payload.get("schema_version") != 1 or not isinstance(payload.get("roles"), dict):
        return None
    return payload["roles"]
```

Applications must retain their own accessible fallback theme when the file is absent or invalid. Palette access must never prevent the application from starting.

Shell example for a small desktop widget:

```bash
palette=${XDG_CACHE_HOME:-$HOME/.cache}/spectrumos/theme/current/palette.json
accent=$(python -c 'import json,sys; print(json.load(open(sys.argv[1]))["roles"]["accent"])' "$palette")
```

For a long-running process, reload on focus or provide a normal application reload command. A process may also watch the theme root for replacement of the `current` entry, but it must debounce events and reopen `current/palette.json` after the replacement. Watching a resolved generation directory will not detect later activations.

Spectrum v0.1 does not expose a public D-Bus theme-change event. Do not assume that signals used by existing components are a universal protocol.

### Applications with CSS or configuration includes

If an application supports includes, a Spectrum package integration should generate a small application-specific fragment from semantic roles and have the stable user configuration include the path through `current`.

```text
~/.cache/spectrumos/theme/current/example-app.css
```

Keep geometry, behavior, keybindings, accounts, and secrets outside the generated fragment. The renderer should own only the values it can safely regenerate.

If the application cannot include another file, use an explicit adoption or synchronization step that preserves existing user configuration. Never overwrite an unrelated user configuration during a wallpaper change.

### Bundled application templates

Every generation includes application-specific artifacts under `current/integrations/`:

| Application | Generated file | Activation boundary |
|---|---|---|
| Telegram Desktop | `spectrum.tdesktop-theme` | Import it through Telegram Settings → Chat Settings. Telegram copies imported theme state and has no stable external reload interface, so import the new generated file again after a palette change. |
| Discord (via Vesktop/Vencord) | `vencord-quickcss.css`, plus Vencord's `ClientTheme` plugin | Applied automatically, no manual step. `appearance-sync` embeds the generated CSS directly into `~/.config/vesktop/settings/quickCss.css` (wrapped in markers so anything added outside the block survives regeneration — a relative `@import` silently fails there, since QuickCSS is injected into Discord's own web renderer, which resolves it against Discord's remote origin, not the local file), *and* enables/updates Vencord's `ClientTheme` plugin (`plugins.ClientTheme` in `settings.json`) seeded with the current **background** role. Discord's own "Custom Theme" builder (Settings → Appearance) was removed from the client years ago; `ClientTheme` recreates that former single-color client theme against Discord's current internals (and patches around Discord's own gate on it) and is what actually reaches every screen — confirmed the plain QuickCSS variable overrides alone don't repaint some of Discord's newer redesigned surfaces (the Friends page, in particular), while `ClientTheme` does, verified with a real cold restart. It must be seeded with `background`, not `accent`: ClientTheme derives its whole lightness ramp from the one input color with no separate dark/light flag, and `accent` (lighter and more saturated even in dark palettes) produced a washed-out theme regardless of variant — worse still on light palettes. `background` tracks the palette's actual variant correctly while still carrying that role's hue, confirmed by a real restart. |

These are native Spectrum semantic outputs, not Pywal compatibility files. Walogram is intentionally excluded because it consumes Pywal's numbered palette and mutates Telegram theme state through a separate lifecycle. A future Telegram connector should use the generated `.tdesktop-theme` and an upstream-supported apply/reload interface if Telegram exposes one; it must not recreate `~/.cache/wal` or modify account data.

## Semantic role rules

Use roles by meaning rather than by their current visual appearance:

| Role | Use |
|---|---|
| `background` | Main window or canvas |
| `surface` | Panels, cards, menus, and raised areas |
| `surface_alt` | Secondary surfaces, hover fills, and separators |
| `foreground` | Primary text and icons |
| `muted` | Secondary text and inactive controls |
| `accent` | Focus, selection, and primary actions |
| `accent_alt` | Secondary highlights and decorative gradients |
| `success` | Successful or healthy state only |
| `warning` | Caution state only |
| `error` | Failure, critical, or destructive state only |

Do not use `success`, `warning`, or `error` merely to make a screen more colorful. Decorative combinations should use `accent`, `accent_alt`, and blends or transparent variants of those colors.

The schema validates important contrast pairs, but a consumer is still responsible for contrast in new combinations. Primary text should target at least 4.5:1. Large graphical controls and secondary indicators should target at least 3:1.

## Adding a first-party renderer

A maintained Spectrum integration belongs in the theme engine when an application needs a generated file:

1. Add a renderer that accepts `Palette` and returns the complete application-specific text.
2. Register its output name in `RENDERERS` in `packages/spectrum-theme/src/spectrum_theme/renderers.py`.
3. Add tests for every role and important state the renderer consumes.
4. Add a package-owned default or safe adoption path that references the generated file.
5. Add an application-specific reload adapter to the theme frontend only after generation activates successfully.
6. Document ownership, fallback behavior, and whether existing user settings override Spectrum defaults.

A renderer must be deterministic and side-effect free. It must not restart an application, write outside its supplied generation directory, inspect private user configuration, or make network requests.

Render and inspect a development preview with:

```bash
PYTHONPATH=packages/spectrum-theme/src \
  python -m spectrum_theme.cli render \
  --palette packages/spectrum-theme/src/spectrum_theme/palettes/spectrum-dark.toml \
  --output /tmp/spectrum-theme-preview
```

Run the renderer tests with:

```bash
PYTHONPATH=packages/spectrum-theme/src \
  python -m unittest packages.spectrum-theme.tests.test_renderers
```

## System and login-screen consumers

Per-user applications should prefer `palette.json`. Components that run before login or outside the user session cannot safely read a home directory. Spectrum stages a restricted cross-session subset at:

```text
/var/lib/spectrumos/appearance/colors.conf
/var/lib/spectrumos/appearance/wallpaper.png
```

`colors.conf` currently exports `background`, `surface`, `foreground`, `muted`, `accent`, and `accent_alt`. SDDM and boot appearance integrations use this handoff. It is not a replacement for the complete ten-role per-user schema, and applications must treat missing files as a normal fallback condition.

## What Spectrum users experience

On a supported Spectrum installation:

1. The user selects a wallpaper and extraction mode with `Super+W`, picks a random wallpaper (keeping the current mode/variant/scheme) with `Super+R`, or rerolls everything at once with the control center's "Surprise me".
2. Spectrum extracts and validates the semantic palette.
3. Every registered renderer produces a complete application fragment.
4. Spectrum atomically activates the generation.
5. Built-in reload adapters refresh supported running applications.
6. If generation fails, the previous complete theme remains active.
7. Rollback restores the previous palette, generated files, and associated wallpaper together.

Applications using GTK or Qt integration normally follow automatically. Direct palette consumers follow when they reopen `palette.json` or receive their application-specific reload action. Applications that are not running simply load the current generation the next time they start.

Users can request a fresh rendering of the current palette after installing a new integration:

```bash
spectrum-theme rerender-current
```

Rendering creates the new files but does not define a universal application reload. The integration package should provide its own safe reload action, or tell the user to restart that application once.

## Integration checklist

- Consume semantic roles, not numbered terminal colors.
- Read through `current`; never bind to one generation ID.
- Validate `schema_version` and keep an internal fallback.
- Reopen the palette after activation instead of caching a resolved path.
- Reserve status colors for real status.
- Preserve user configuration and overrides.
- Keep secrets and account data outside generated files.
- Make rendering deterministic and free of side effects.
- Test dark and light palettes, missing files, malformed data, and reload behavior.
- Reload only after a complete generation is active.

For the complete schema and generation internals, see [Spectrum Theme Engine](theme-engine.md) and [ADR 0004](decisions/0004-semantic-palette-and-atomic-generations.md).
