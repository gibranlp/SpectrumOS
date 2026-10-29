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

SpectrumOS hooks into [GameMode](https://github.com/FeralInteractive/gamemode) (`gamemode`, included in `bootstrap/packages/gaming.txt`). Games and launchers can request it through native integration, a launcher's GameMode option, `gamemoderun`, or `libgamemodeauto`. Steam and Proton do not guarantee that every title requests GameMode automatically.

`appearance-sync`'s `ensure_gamemode_hook()` manages a marked block in `~/.config/gamemode.ini`'s `[custom]` section (self-healing on every `appearance-sync --apply`, the same pattern as its GTK/Vencord integrations — edits outside the block are preserved):

```ini
[custom]
start=/usr/lib/spectrumos/performance-mode --game-start
end=/usr/lib/spectrumos/performance-mode --game-end
```

`--game-start`/`--game-end` maintain idempotent requests in
`.../spectrumos/performance-mode/game-requests.json`. GameMode owns one request for
its overall active session; Spectrum's manual Gaming or detected Steam game owns
a separate `session` request. The first request remembers the previous mode in
`pre-game-mode`, and the final release restores it. `game-count` is a derived
compatibility value, not an accumulating client counter. The shell reconciles
these requests against actual activity on startup and transitions, recovering
stale counts from interrupted older sessions. Hook updates share a file lock;
failed power changes retain their requests for retry. Power notifications appear
only when the selected mode changes. A manual power selection during a session
changes the current mode; the final release still restores the saved mode.

GameMode is now a required desktop dependency for the SpectrumShell Gaming profile. The shell holds a registered client for the duration of that profile, and games can register their own clients independently. Gaming also requests the available Performance power mode and restores its prior mode when no other GameMode clients remain. The Gaming helper verifies the real registration and reports activation failures in Control Center. Hook reference-count updates are serialized to handle concurrent clients. See [SpectrumShell Gaming](spectrum-shell.md#gaming-profile) for profile behavior and validation limits.


## Automatic bar profile

SpectrumShell observes external GameMode clients and running processes owned by
the current user with a nonzero `SteamAppId` or `SteamGameId`. Opening Steam alone
does not activate Gaming. A running Steam game activates the Gaming bar profile,
Performance power mode, and a verified Spectrum GameMode registration, even when
the game does not request GameMode itself. Its own registration is excluded from
external-client detection, so it cannot keep automatic Gaming alive after games
exit. Other GameMode clients keep their session active independently.

Saved global and per-monitor profiles remain unchanged and return when the last
game exits. Manual Gaming remains active until explicitly left. Selecting another
bar profile or Leave Gaming suspends the automatic visual override until the
current game session ends. UKVM reads the same private runtime status.

For games outside Steam that do not request GameMode, enable it in their launcher
or use `gamemoderun`. Native game registration can still provide process-specific
GameMode optimizations in addition to Spectrum's session registration. Inspect
`gamemoded -s` and `$XDG_RUNTIME_DIR/spectrumos/gaming-status.json` when diagnosing
activation. An already selected Performance profile produces no new power toast.

The desktop installs `50-spectrumos-gamemode.rules`, allowing active local members
of `spectrumos` to use GameMode's CPU governor and kernel tuning helpers. This
avoids the authorization failures when the desktop user is not in `gamemode`.
