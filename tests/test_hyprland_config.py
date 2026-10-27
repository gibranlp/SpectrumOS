from pathlib import Path
import unittest
import re


ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = ROOT / "configs" / "hyprland"


class HyprlandConfigTests(unittest.TestCase):
    def test_shortcut_widget_is_alphabetical_and_has_unique_chords(self):
        source = (ROOT / "configs/spectrum-shell/UtilityPanel.qml").read_text()
        catalog = source.split("readonly property var shortcuts: [", 1)[1].split("\n    ]", 1)[0]
        rows = re.findall(r'combo: "([^"]+)", action: qsTranslate\("Spectrum", "([^"]+)"\)', catalog)
        self.assertGreater(len(rows), 40)
        labels = [label for _, label in rows]
        self.assertEqual(labels, sorted(labels, key=str.casefold))
        chords = [chord.casefold() for chord, _ in rows]
        self.assertEqual(len(chords), len(set(chords)))

    def test_shell_shortcuts_match_real_bindings_and_keep_menu_only_pages(self):
        wrapper = (ROOT / "scripts/spectrum-shell-open").read_text()
        routes = {}
        for alternatives, method in re.findall(r'^    ([a-z|\-]+)\) method=(\w+)', wrapper, re.M):
            for route in alternatives.split("|"):
                routes[route] = method
        source = (ROOT / "configs/spectrum-shell/UtilityPanel.qml").read_text()
        catalog = source.split("readonly property var shortcuts: [", 1)[1].split("\n    ]", 1)[0]
        represented = {routes[route] for route in re.findall(r'backendDir \+ "/spectrum-shell-open", "([^"]+)"', catalog)}
        if '"/panel", "--capture"' in catalog:
            represented.add(routes["screenshot"])
        menu_only = {routes[name] for name in ("appearance",)}
        self.assertEqual(set(routes.values()) - represented, menu_only)
        bindings = (CONFIG_DIR / "keybindings.lua").read_text()
        actual = {}
        for modifier, chord, command in re.findall(r'hl\.bind\((mainMod \.\. )?"([^"]+)", hl\.dsp\.exec_cmd\("([^"]+)"\)', bindings):
            chord = ("SUPER" if modifier else "") + chord
            actual["".join(chord.upper().split())] = command
        for line in catalog.splitlines():
            route = re.search(r'backendDir \+ "/spectrum-shell-open", "([^"]+)"', line)
            if route:
                chord = re.search(r'combo: "([^"]+)"', line).group(1)
                self.assertEqual(actual.get("".join(chord.upper().split())), "/usr/lib/spectrumos/spectrum-shell-open " + route.group(1))

    def test_user_keyboard_layout_layer_loads_before_personal_override(self):
        entrypoint = (ROOT / "configs/hyprland/hyprland.lua").read_text(encoding="utf-8")
        keyboard = entrypoint.index('keyboard-layout.lua')
        personal = entrypoint.index('hyprland.lua")', keyboard)
        self.assertLess(keyboard, personal)

    def test_validator_supplies_a_private_runtime_directory(self):
        validator = (ROOT / "scripts" / "validate-hyprland.py").read_text(encoding="utf-8")
        self.assertIn('environment.get("XDG_RUNTIME_DIR")', validator)
        self.assertIn('runtime.mkdir(mode=0o700)', validator)
        self.assertIn('if os.geteuid() == 0', validator)
        self.assertIn('command.append("--i-am-really-stupid")', validator)

    def test_packaged_sources_exist(self):
        entrypoint = (CONFIG_DIR / "hyprland.lua").read_text(encoding="utf-8")
        packaged_sources = [
            f'{module}.lua'
            for module in (
                "monitors",
                "environment",
                "input",
                "appearance",
                "animations",
                "layouts",
                "window-rules",
                "autostart",
                "keybindings",
            )
        ]

        self.assertGreater(len(packaged_sources), 0)
        for relative_path in packaged_sources:
            self.assertTrue((CONFIG_DIR / relative_path).is_file(), relative_path)

    def test_legacy_core_bindings_are_preserved(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        expected = (
            'mainMod .. " + Return"',
            'mainMod .. " + Q"',
            'mainMod .. " + M"',
            'mainMod .. " + E"',
            'mainMod .. " + D"',
            'mainMod .. " + P"',
            'mainMod .. " + L"',
            'mainMod .. " + W"',
            'mainMod .. " + R"',
            'mainMod .. " + B"',
            'mainMod .. " + Space"',
            'mainMod .. " + J"',
            'mainMod .. " + F"',
        )
        for binding in expected:
            self.assertIn(binding, bindings)

    def test_qt_platform_theme_is_wired_so_qt5ct_and_qt6ct_are_actually_consulted(self):
        # QT_STYLE_OVERRIDE alone only selects Kvantum's drawing style; without a platform
        # theme plugin selected, Qt apps never read qt5ct.conf/qt6ct.conf at all, so the
        # fonts appearance-sync writes there would have no effect. qt6ct's platform-theme
        # plugin registers under both "qt6ct" and "qt5ct" (confirmed via its embedded Qt
        # plugin metadata), so one value covers both Qt5 and Qt6 apps.
        environment_lua = (ROOT / "configs/hyprland/environment.lua").read_text(encoding="utf-8")
        environment_conf = (ROOT / "configs/environment/90-spectrumos-qt.conf").read_text(encoding="utf-8")
        self.assertIn('hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")', environment_lua)
        self.assertIn("QT_QPA_PLATFORMTHEME=qt5ct", environment_conf)

    def test_active_bindings_do_not_call_legacy_scripts(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        self.assertNotIn("SOS_", bindings)
        self.assertNotIn("/home/", bindings)

    def test_terminal_file_manager_and_audio_choices(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        self.assertIn("uwsm app -- kitty", bindings)
        self.assertNotIn('mainMod .. " + SHIFT + Return"', bindings)
        self.assertIn("uwsm app -- thunar", bindings)
        self.assertIn("/usr/lib/spectrumos/volume up", bindings)
        self.assertIn("/usr/lib/spectrumos/volume down", bindings)
        self.assertIn("/usr/lib/spectrumos/volume mute", bindings)
        self.assertNotIn("pamixer", bindings)

    def test_launch_tracking_allows_slow_startup_without_pinning_children(self):
        appearance = (CONFIG_DIR / "appearance.lua").read_text(encoding="utf-8")
        self.assertIn("initial_workspace_tracking = 1", appearance)
        self.assertIn("initial_workspace_token_timeout = 120", appearance)

    def test_lock_uses_generated_theme(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        self.assertIn("current/hyprlock.conf", bindings)

    def test_wallpaper_actions_use_spectrum_theme_frontend(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        self.assertIn('/usr/lib/spectrumos/spectrum-shell-open wallpapers"', bindings)
        # Super+R only rerolls the wallpaper -- the current palette backend, dark/light
        # variant, and gowall filter keep applying to it. "Surprise me" in the control
        # center (theme-adapter's own `random`, not this keybind) is the one that rerolls
        # every axis at once via theme-menu's plain --random.
        self.assertIn('/usr/lib/spectrumos/theme-menu --random-wallpaper"', bindings)
        self.assertIn('mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("/usr/lib/spectrumos/theme-adapter random")', bindings)

    def test_kill_mode_is_bound_to_super_escape(self):
        # `hyprctl kill` is a standalone request, not a `dispatch` -- it puts the cursor
        # into a crosshair kill mode so clicking a window force-closes it, for one that
        # Super+Q's graceful close dispatcher doesn't affect.
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        self.assertIn('mainMod .. " + Escape", hl.dsp.exec_cmd("hyprctl kill")', bindings)
        self.assertNotIn('hyprctl dispatch kill', bindings)
        # Escape is kill mode's own built-in cancel key -- binding it on a *press* races
        # that cancel handling and can exit kill mode before a click ever lands (confirmed
        # live: the shortcut worked once, then appeared to do nothing every time after --
        # a known Hyprland quirk, hyprwm/Hyprland discussion #14664). `release = true`
        # defers firing until the key is let go, after that race has already resolved.
        kill_bind = bindings.split('hl.dsp.exec_cmd("hyprctl kill")', 1)[1].split("\n", 1)[0]
        self.assertIn("release = true", kill_bind)

    def test_control_panel_uses_shell_with_packaged_fallback(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        wrapper = (ROOT / "scripts" / "spectrum-shell-open").read_text(encoding="utf-8")
        self.assertIn('mainMod .. " + P", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open control")', bindings)
        self.assertIn('exec /usr/lib/spectrumos/panel', wrapper)
        self.assertNotIn('eww-open', wrapper)

    def test_spectrum_shell_is_default_without_retired_recovery(self):
        autostart = (CONFIG_DIR / "autostart.lua").read_text(encoding="utf-8")
        session = (ROOT / "scripts/spectrum-shell-session").read_text(encoding="utf-8")
        self.assertIn("systemctl --user start spectrum-shell.service", autostart)
        self.assertNotIn("systemctl --user start spectrum-waybar.service", autostart)
        self.assertNotIn("systemctl --user start dunst.service", autostart)
        self.assertNotIn("restore_session", session)
        self.assertNotIn("dunst", session)
        self.assertIn('grep -qx "PID=$shell_pid"', session)

    def test_session_starts_one_gtk_polkit_agent(self):
        autostart = (CONFIG_DIR / "autostart.lua").read_text(encoding="utf-8")
        self.assertIn("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1", autostart)
        self.assertNotIn("polkit-kde", autostart)

    def test_workspace_layout_reapplies_on_every_config_reload(self):
        # A `persistent = true` workspace_rule only protects an already-created empty
        # workspace from being destroyed when its last window closes -- confirmed live, a
        # plain `hyprctl reload` (every theme/font/waybar/hyprland-menu change triggers
        # one) still destroys an empty persistent workspace outright regardless of the
        # rule. Re-running --apply on every reload recreates whichever of 1-6 that reload
        # just wiped, which is what actually keeps the split showing in Waybar afterward.
        autostart = (CONFIG_DIR / "autostart.lua").read_text(encoding="utf-8")
        self.assertIn('hl.on("config.reloaded", function()', autostart)
        reload_hook = autostart.split('hl.on("config.reloaded", function()', 1)[1]
        self.assertIn('hl.exec_cmd("/usr/lib/spectrumos/workspace-layout --apply")', reload_hook)

    def test_control_center_layer_has_open_close_animation(self):
        rules = (CONFIG_DIR / "window-rules.lua").read_text(encoding="utf-8")
        self.assertIn('namespace = "^spectrum-panel$"', rules)
        self.assertIn('animation = "fade"', rules)

    def test_native_widget_motion_is_not_animated_twice(self):
        rules = (CONFIG_DIR / "window-rules.lua").read_text(encoding="utf-8")
        rule = rules.split('name = "spectrum-widget-content-motion"', 1)[1].split('})', 1)[0]
        self.assertIn('namespace = "^spectrum-widget-.*$"', rule)
        self.assertIn('no_anim = true', rule)

    def test_file_dialogs_do_not_receive_a_compositor_frame(self):
        rules = (CONFIG_DIR / "window-rules.lua").read_text(encoding="utf-8")
        self.assertIn('fileDialogTitles = "^(Save File|Open File|Select a File|Open Folder|Save As)$"', rules)
        self.assertIn('name = "spectrum-file-dialog-border"', rules)
        self.assertIn('match = { title = fileDialogTitles }, border_size = 0, no_blur = true', rules)

    def test_structural_shell_layers_do_not_receive_compositor_motion(self):
        rules = (CONFIG_DIR / "window-rules.lua").read_text()
        rule = rules.split('name = "spectrum-shell-structural-motion"', 1)[1].split('})', 1)[0]
        pattern = re.search(r'namespace = "([^"]+)"', rule)[1]
        for name in ("bar", "frame", "frame-reservation", "focus-countdown", "level-indicator",
                     "desktop-branding", "igor", "dashboard-hover"):
            self.assertRegex("spectrum-" + name, pattern)
        self.assertNotRegex("quickshell", pattern)
        self.assertIn("no_anim = true", rule)
        frame = (ROOT / "configs/spectrum-shell/ShellFrame.qml").read_text()
        self.assertEqual(frame.count('namespace: "spectrum-frame-reservation"'), 4)
        self.assertIn('namespace: "spectrum-frame"', frame)
        for filename in ("shell.qml", "VerticalBar.qml"):
            self.assertIn('namespace: "spectrum-bar"', (ROOT / "configs/spectrum-shell" / filename).read_text())

    def test_live_shell_layers_keep_their_attachment_geometry(self):
        shell = (ROOT / "installer/live-shell.qml").read_text()
        config = (ROOT / "installer/live-hyprland.lua").read_text()
        self.assertIn('namespace: "spectrum-live-bar"', shell)
        self.assertIn('namespace: "spectrum-live-network"', shell)
        rule = config.split('name = "spectrum-live-shell-motion"', 1)[1].split('})', 1)[0]
        self.assertIn("no_anim = true", rule)
        self.assertIn('namespace = "^spectrum-live-(bar|network)$"', rule)

    def test_portal_file_chooser_does_not_receive_the_global_blur(self):
        # xdg-desktop-portal-gtk draws the file chooser for apps without their own GTK (Electron
        # apps included) as its own long-lived background service, not the requesting app itself.
        # Without an explicit rule it inherits the global blur meant for larger panels, which on
        # a small dialog with a not-fully-opaque background reads as an oversized translucent frame.
        rules = (CONFIG_DIR / "window-rules.lua").read_text(encoding="utf-8")
        self.assertIn('name = "spectrum-portal-file-chooser-blur"', rules)
        self.assertIn('match = { class = "^(xdg-desktop-portal-gtk)$" }, no_blur = true', rules)

    def test_default_motion_is_short_and_limits_workspace_travel(self):
        animations = (CONFIG_DIR / "animations.lua").read_text(encoding="utf-8")
        appearance = (CONFIG_DIR / "appearance.lua").read_text(encoding="utf-8")
        self.assertIn('leaf = "workspaces", enabled = true, speed = 2', animations)
        self.assertIn('style = "slidefade 20%"', animations)
        self.assertIn('leaf = "windowsOut", enabled = true, speed = 1.5', animations)
        self.assertIn("size = 3, passes = 1", appearance)
        self.assertIn("new_optimizations = true", appearance)
        self.assertIn("xray = true", appearance)

    def test_fixed_choice_shortcuts_open_shell_pages(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        expected = (
            'mainMod .. " + A", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open audio")',
            'mainMod .. " + B", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open network")',
            '"Print", hl.dsp.exec_cmd("/usr/lib/spectrumos/panel --capture")',
            '"SHIFT + Print", hl.dsp.exec_cmd("/usr/lib/spectrumos/panel --screenshot-area")',
            'mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open recorder")',
            'mainMod .. " + P", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open control")',
            'mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open questline")',
        )
        for binding in expected:
            self.assertIn(binding, bindings)
        self.assertIn('mainMod .. " + C", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open calculator")', bindings)
        self.assertIn('mainMod .. " + G", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open password")', bindings)
        self.assertIn('mainMod .. " + I", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open color")', bindings)
        self.assertIn('mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open color-history")', bindings)
        self.assertIn('mainMod .. " + S", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open search")', bindings)
        self.assertIn('mainMod .. " + V", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open emoji")', bindings)
        self.assertIn('mainMod .. " + D", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-launcher")', bindings)
        self.assertIn('mainMod .. " + X", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open session")', bindings)
        self.assertNotIn("/usr/lib/spectrumos/wofi", bindings)

    def test_moving_a_window_to_a_workspace_does_not_follow_it_there(self):
        # Super+Shift+<N> used to plainly `hl.dsp.window.move({workspace=N})`, which follows
        # the window to the target workspace (Hyprland's default) -- sends the window away
        # and yanks the view with it. Two dispatcher-level workarounds were tried and both
        # confirmed live to not actually change that behavior (`silent = true` on the same
        # call, then routing through `hyprctl dispatch movetoworkspacesilent`), so this
        # instead captures the currently active workspace and explicitly focuses back to
        # it right after the (still-following) move -- doesn't depend on any dispatcher's
        # own "don't follow" semantics actually doing what its name suggests.
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        move_binding = bindings.split('mainMod .. " + SHIFT + " .. workspace, function()', 1)[1].split("end)", 1)[0]
        self.assertIn("local origin = hl.get_active_workspace()", move_binding)
        self.assertIn("hl.dispatch(hl.dsp.window.move({ workspace = workspace }))", move_binding)
        self.assertIn("hl.dispatch(hl.dsp.focus({ workspace = origin.id }))", move_binding)

    def test_pin_shares_a_key_with_float_toggle(self):
        bindings = (CONFIG_DIR / "keybindings.lua").read_text(encoding="utf-8")
        self.assertIn('mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" })', bindings)
        self.assertIn(
            'mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("/usr/lib/spectrumos/window-pin-toggle")',
            bindings,
        )

    def test_pinned_windows_survive_a_later_fullscreen(self):
        # Without this, fullscreening anything (a game, a video) silently cancels every
        # pinned window's pin -- exactly the case Super+Shift+Space/window-pin-toggle
        # exists for.
        layouts = (CONFIG_DIR / "layouts.lua").read_text(encoding="utf-8")
        self.assertIn("allow_pin_fullscreen = true", layouts)


if __name__ == "__main__":
    unittest.main()
