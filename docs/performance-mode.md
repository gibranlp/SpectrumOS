# Performance/Balanced mode

A single toggle, exposed as a header icon in the Eww control center right next to the lock button (md-speedometer for Performance, fa-scale_balanced for Balanced — hidden entirely if no supported backend is present) and as a `custom/performance` module on every Waybar layout, including Minimal, backed by `/usr/lib/spectrumos/performance-mode`.

## Backend

SpectrumOS never installs both power-profile daemons on the same machine, so the script auto-detects whichever one the active form factor actually provides rather than assuming one:

- **`power-profiles-daemon`** — laptop form factor (`bootstrap/packages/form-factor/laptop.txt`). `powerprofilesctl set performance|balanced` / `get`.
- **`tuned`** — every install (`bootstrap/packages/desktop.txt`, enabled by `install.sh`). "Performance" maps to the `throughput-performance` profile; "Balanced" maps to tuned's own `balanced` profile. Any other active tuned profile (a user's own manual pick) reads as "Balanced" for the icon's two-state purposes. `com.redhat.tuned.switch_profile` is `allow_active: yes` in tuned's own polkit policy, so switching never prompts for a password from an active local session.

`power-profiles-daemon` is checked first; if it's absent or its service isn't running, `tuned` is used. If neither is available, `--json` reports `"available": false` and the header icon hides itself (`:visible {system.performance_mode.available}`).

- `performance-mode --json` — `{"available": bool, "backend": "power-profiles-daemon"|"tuned"|"none", "mode": "performance"|"balanced"}`, polled by `system-adapter` into `system.performance_mode` for the Eww icon.
- `performance-mode --toggle` — flips the current mode and sends a `notify-send`. What the header icon's `onclick` calls directly (**not** detached with `setsid -f` — tried that here first, and it made the trailing `notify-send` arrive many seconds late or not at all, even though the tuned-adm/powerprofilesctl switch itself still applied instantly; direct invocation delivers the notification reliably within about a second, confirmed via `dunstctl history`. `eww-font-size`/`eww-font-family` used the same `setsid -f` pattern and were later found to have the same problem plus a worse one — a detached run finishing very late could clobber a font size/family picked after it — so both were switched to direct invocation too; see `docs/theme-engine.md`).
- `performance-mode --set MODE` — sets a specific mode directly.
- `performance-mode --status` — `{"text": glyph|"", "tooltip": str, "class": "performance"|"balanced"|"unavailable"}`, Waybar's own custom-module shape (distinct from `--json` above). Empty text plus the module's `hide-empty-text` is what collapses it entirely when unavailable, rather than showing a dead button. Its `on-click` is `--toggle` directly, the same as the Eww header icon.

Every notification names only the mode that just turned on ("Performance mode activated" / "Balanced mode activated") — there is deliberately no matching "deactivated" toast for the one it replaced, since a single "activated" notification per switch is already unambiguous about what changed.

## Auto-enable for games

Rather than SpectrumOS trying to recognize individual games itself, this hooks into [GameMode](https://github.com/FeralInteractive/gamemode) (`gamemode`, already in `bootstrap/packages/gaming.txt`) — the de facto standard Linux mechanism games (most Steam/Proton titles out of the box, `gamemoderun` launch wrapper, or `libgamemodeauto` preload for others) already request when they start and release when they exit.

`appearance-sync`'s `ensure_gamemode_hook()` manages a marked block in `~/.config/gamemode.ini`'s `[custom]` section (self-healing on every `appearance-sync --apply`, the same pattern as its GTK/Vencord integrations — edits outside the block are preserved):

```ini
[custom]
start=/usr/lib/spectrumos/performance-mode --game-start
end=/usr/lib/spectrumos/performance-mode --game-end
```

`--game-start`/`--game-end` use a reference count (`.../spectrumos/performance-mode/game-count`), not a flag: GameMode's hooks fire per client process, so two overlapping games (or a game plus another GameMode-aware app) are handled correctly — only the *first* arrival remembers whatever mode was active (`.../spectrumos/performance-mode/pre-game-mode`) and switches to Performance; only the *last* departure restores it. A manual toggle mid-game is respected the same way a manual pick always is — it just becomes what gets restored once every game has exited. Each notifies only when it actually changes the mode: a game starting while Performance is already active (or ending back into whatever mode is already current) is a no-op and stays silent rather than repeating a toast for nothing.

GameMode is now a required desktop dependency for the SpectrumShell Gaming profile. The shell holds a registered client for the duration of that profile, and games can register their own clients independently. Gaming also requests the available Performance power mode and restores its prior mode when no other GameMode clients remain. The Gaming helper verifies the real registration and reports activation failures in Control Center. Hook reference-count updates are serialized to handle concurrent clients. See [SpectrumShell Gaming](spectrum-shell.md#gaming-profile) for profile behavior and validation limits.
