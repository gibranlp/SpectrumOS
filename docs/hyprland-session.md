# Spectrum Hyprland Session 0.1

Status: development defaults deployed on the reference system

## Configuration order

The Lua entrypoint at `configs/hyprland/hyprland.lua` loads:

1. packaged SpectrumOS2 defaults;
2. the current generated theme fragment;
3. installer-generated GPU profile env vars;
4. administrator/machine configuration;
5. user overrides.

The development package paths are `/usr/share/spectrumos/hyprland/`, `/etc/spectrumos/hyprland/gpu.lua`, and `/etc/spectrumos/hyprland/machine.lua`. User overrides remain at `~/.config/spectrumos/hyprland.lua`. Missing administrator or user overrides do not prevent the session from starting, but errors in files that exist remain visible. Hyprland 0.56 selects its native Lua provider from the `.lua` entrypoint and no longer emits the legacy Hyprlang warning.

`gpu.lua` is written by `install.sh`'s `system` phase whenever `--gpu` selects an NVIDIA profile, and is regenerated (not preserved) on every install run, unlike `machine.lua` -- it holds only the rendering env vars that profile needs (see `configs/hyprland/gpu/`), so it stays separate from `machine.lua`'s free-form, installer-untouched local overrides. A discrete-only `nvidia` install sets `GBM_BACKEND`/`__GLX_VENDOR_LIBRARY_NAME`/`LIBVA_DRIVER_NAME` globally, since Hyprland itself is the only GPU there; a hybrid `nvidia-intel`/`nvidia-amd` install deliberately does not, since Hyprland renders on the integrated GPU and forcing those vars would capture the compositor instead of just offloading individual apps -- use `/usr/lib/spectrumos/nvidia-offload <command>` for that instead.

The generic monitor rule uses preferred mode, automatic placement, and scale 1. Hardware-specific monitor names and workspace placement belong in the machine layer; the legacy dual-monitor values were not copied.

## Legacy keybinding compatibility

The implemented bindings preserve the working SpectrumOS assignments for:

- terminal, close, exit, file manager, launcher, and lock;
- floating, split, and fullscreen state;
- Dunst dismissal;
- volume, media transport, and brightness keys;
- directional focus, resizing, and window movement;
- workspaces 1–6 and moving windows to those workspaces;
- mouse move/resize and workspace scrolling.

`Super+Enter` opens the Spectrum-themed Kitty terminal and `Super+E` opens Thunar. The redundant `Super+Shift+Enter` terminal binding was removed. `Super+D` opens the SpectrumShell launcher when SpectrumShell is running and falls back to Wofi otherwise.

PipeWire's `wpctl` is the supported direct media-key control instead of Pamixer. It ships with WirePlumber, already required by the audio stack, talks to PipeWire's native object model, and avoids maintaining an additional PulseAudio-oriented control dependency. Volume bindings call the package-owned `/usr/lib/spectrumos/volume` interface, which updates the default sink and emits replaceable Dunst feedback.

Bindings backed by legacy `SOS_*` scripts are catalogued in `configs/hyprland/deferred-keybindings.md`. Their keys remain reserved, but they do not appear in the active defaults until a working SpectrumOS2 action exists.

## Session lifecycle

Application launches use `uwsm app` so they receive user-systemd lifecycle management. The session starts the GTK-based GNOME polkit authentication agent and Hypridle. Hypridle uses the package-owned policy at `/usr/share/spectrumos/hyprland/hypridle.conf`: lock after ten minutes, turn the display off thirty seconds later, and do not suspend desktops automatically. The Control Center Keep Awake action blocks system sleep and directly defers both Spectrum Hypridle listeners until it is disabled. Dunst supports D-Bus activation and its final composed configuration/lifecycle remains part of the notification slice. The session also starts `spectrum-resource-monitor.service`, which provides rate-limited memory, swap, sustained CPU, and disk-space warnings; see `resource-monitor.md`.

File-selection dialogs remain floating and use their toolkit-provided client-side decoration without an additional Hyprland border. This avoids a detached colored frame around GTK dialogs opened by XWayland applications while preserving Spectrum borders on normal windows.

Hyprlock is launched directly with the active generated `hyprlock.conf`. The lockscreen uses semantic palette roles for its background, prompt, authentication state, time, and date. This path and the physical volume controls passed interactive testing on the reference machine.

Awww owns session wallpaper display. `Super+W` opens the SpectrumShell wallpaper browser when the shell is running and the Wofi wallpaper workflow otherwise. `Super+R` selects a non-repeating random wallpaper while preserving the extraction mode, variant, and color scheme. Palette extraction, atomic rendering, wallpaper display, and consumer reload remain explicit sequential operations. Dunst starts with the active generated configuration in the standard Waybar session; the optional SpectrumShell service stops Dunst before taking over notifications and restores it when the shell stops.

## Validation

The validator rewrites package paths into a temporary preview, supplies empty machine/user layers, and asks the installed Hyprland parser to verify the configuration without starting a compositor:

```bash
python scripts/validate-hyprland.py
```

It can also validate an actual generated theme fragment:

```bash
python scripts/validate-hyprland.py \
  --theme /tmp/spectrum-theme/current/hyprland.lua
```

The validator checks Hyprland's output as well as its exit status because Hyprland 0.56.2 can return success while reporting source errors.

## Deferred before host adoption

- Package recipe and file ownership.
- Nested or VM session smoke test.
- Portal preference and UWSM environment files.
- Launcher, bar, notification, wallpaper, screenshot, and system-action implementations.

## Package update reloads

Base provides `hyprland-update-guard` and Pacman hooks that pause each active user's Hyprland automatic reloads before Spectrum Hyprland defaults are replaced, then reload the complete configuration and restore that user's original `misc:disable_autoreload` setting. This prevents transient missing-module errors while Pacman replaces Lua files. Hooks cover updates through Control Center, Paru, and direct Pacman commands. A transient system service recovers the setting if the transaction exits before its post hook. State is kept under a root-only runtime directory, and inactive sessions require no action.

Hyprland's package upgrade script also starts and completes the guard. Its dependency on Base 40 ensures the helper is installed first, protecting the first upgrade from releases that did not yet have the pre-transaction hook. Manual configuration edits keep their existing automatic-reload behavior.

`Super+Shift+R` runs the wallpaper widget’s Spectrumize me action; `Super+Shift+S` opens the screen recorder. Kitty defaults disable remembered window size so newly opened terminals tile alongside existing windows. Package upgrades migrate the legacy user copy of Spectrum’s Kitty defaults while preserving other settings; new installations include the package-owned defaults directly.

Media Play/Pause, Next, Previous, and Stop keys route through `/usr/lib/spectrumos/media-control` to SpectrumShell’s selected MPRIS app. When multiple players require a choice, the Audio widget opens on the focused monitor. The helper falls back to `media-adapter` if SpectrumShell IPC is unavailable.

Questline Sync and reminders explicitly start after both `graphical-session.target` and SpectrumShell. This prevents the graphical target from adding an opposite implicit ordering through enabled services, which otherwise makes `uwsm stop` reject logout with `TransactionOrderIsCyclic`. The session widget retains the managed UWSM logout action.
