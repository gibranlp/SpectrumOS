import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT / "scripts" / "workspace-layout"))


class WorkspaceLayoutTests(unittest.TestCase):
    def test_fallback_and_disabled_outputs_are_not_workspace_targets(self):
        query = MODULE["monitors"]
        output = '[{"name":"FALLBACK"},{"name":"DP-1"},{"name":"DP-2","disabled":true}]'
        with patch.dict(query.__globals__, {"run": lambda *args: subprocess.CompletedProcess(args, 0, output, "")}):
            self.assertEqual(query(), [{"name": "DP-1"}])

    def test_failed_monitor_query_does_not_look_like_a_display_outage(self):
        query = MODULE["monitors"]
        with patch.dict(query.__globals__, {"run": lambda *args: subprocess.CompletedProcess(args, 1, "", "unavailable")}):
            with self.assertRaises(ConnectionError):
                query()

    def test_all_outputs_off_preserves_rules_and_windows(self):
        apply = MODULE["apply"]
        calls = []
        def fake_run(*args):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, '[{"name":"FALLBACK"}]', "")
        with patch.dict(apply.__globals__, {"run": fake_run,
                "write_workspace_rules": lambda commands: self.fail("Fallback overwrote saved rules")}), patch("time.sleep"):
            self.assertEqual(apply(), {})
        self.assertTrue(all(call == ("hyprctl", "-j", "monitors") for call in calls))

    def test_equal_monitor_counts_do_not_hide_a_connector_change(self):
        stable = MODULE["stable_monitors"]
        readings = iter([[{"name": "FALLBACK"}], [{"name": "DP-1"}], [{"name": "DP-1"}]])
        with patch.dict(stable.__globals__, {"monitors": lambda: next(readings)}), patch("time.sleep"):
            self.assertEqual(stable(), [{"name": "DP-1"}])

    def test_shell_stops_without_displays_and_restarts_after_stable_return(self):
        recovery = MODULE["ShellRecovery"]()
        calls = []
        def fake_run(*args):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, "inactive\n", "")
        with patch.dict(recovery.update.__globals__, {"run": fake_run}), patch("time.monotonic") as clock:
            for now, rows in ((0, []), (2, []), (3, []), (4, []), (5, [{"name": "HDMI-A-1"}]),
                              (6, [{"name": "DP-1"}, {"name": "HDMI-A-1"}]),
                              (8, [{"name": "DP-1"}, {"name": "HDMI-A-1"}])):
                clock.return_value = now
                self.assertFalse(recovery.update(rows))
            clock.return_value = 9
            self.assertTrue(recovery.update(rows))
            clock.return_value = 10
            self.assertFalse(recovery.update(rows))
        self.assertEqual(sum("stop" in call for call in calls), 1)
        self.assertEqual(sum("start" in call for call in calls), 1)

    def test_short_output_blip_does_not_restart_shell(self):
        recovery = MODULE["ShellRecovery"]()
        with patch.dict(recovery.update.__globals__, {"run": lambda *args: self.fail("Short outage restarted shell")}), patch("time.monotonic") as clock:
            for now, rows in ((0, []), (2, [{"name": "DP-1"}]), (5, [{"name": "DP-1"}])):
                clock.return_value = now
                self.assertFalse(recovery.update(rows))

    def test_intentionally_inactive_shell_stays_inactive(self):
        recovery = MODULE["ShellRecovery"]()
        calls = []
        def fake_run(*args):
            calls.append(args)
            return subprocess.CompletedProcess(args, 3, "", "")
        with patch.dict(recovery.update.__globals__, {"run": fake_run}), patch("time.monotonic") as clock:
            for now, rows in ((0, []), (3, []), (4, [{"name": "DP-1"}]), (8, [{"name": "DP-1"}])):
                clock.return_value = now
                recovery.update(rows)
        self.assertFalse(any("start" in call or "stop" in call for call in calls))

    def test_shell_waits_for_stuck_process_to_be_stopped(self):
        recovery = MODULE["ShellRecovery"]()
        recovery.paused = True
        recovery.topology = frozenset({"DP-1"})
        recovery.present_since = 0
        calls = []
        def fake_run(*args):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, "deactivating\n", "")
        with patch.dict(recovery.update.__globals__, {"run": fake_run}), patch("time.monotonic", return_value=4):
            self.assertFalse(recovery.update([{"name": "DP-1"}]))
        self.assertTrue(recovery.paused)
        self.assertFalse(any("start" in call for call in calls))

    def test_monitor_events_are_bounded(self):
        is_monitor_event = MODULE["is_monitor_event"]
        for event in ("monitoradded>>DP-2", "monitoraddedv2>>2,DP-2,Display", "monitorremoved>>DP-2"):
            self.assertTrue(is_monitor_event(event))
        for event in ("workspace>>2", "openwindow>>abc", "focusedmon>>DP-1,1"):
            self.assertFalse(is_monitor_event(event))

    def test_extra_workspace_events_trigger_recovery(self):
        is_extra_workspace_event = MODULE["is_extra_workspace_event"]
        for event in (
            "createworkspace>>7",
            "createworkspacev2>>7,7",
            "movewindow>>abc,7",
            "movewindowv2>>abc,7,renamed",
        ):
            self.assertTrue(is_extra_workspace_event(event))
        for event in (
            "createworkspace>>6",
            "movewindowv2>>abc,6,6",
            "movewindowv2>>abc,-98,special:scratchpad",
            "monitoradded>>DP-1",
        ):
            self.assertFalse(is_extra_workspace_event(event))

    def test_secondary_monitor_receives_workspace_six(self):
        apply = MODULE["apply"]
        calls = []
        rows = [
            {"name": "DP-1", "focused": True, "activeWorkspace": {"id": 1}},
            {"name": "HDMI-A-1", "focused": False, "activeWorkspace": {"id": 2}},
        ]

        def fake_run(*arguments):
            calls.append(arguments)
            return subprocess.CompletedProcess(arguments, 0, "", "")

        written = []
        with patch.dict(apply.__globals__, {
            "monitors": lambda: rows,
            "stored_primary": lambda available: "",
            "run": fake_run,
            "write_workspace_rules": lambda commands: written.append(commands),
        }), patch("time.sleep"):
            assignments = apply()

        self.assertEqual(assignments, {"DP-1": "1, 2, 3, 4, 5", "HDMI-A-1": "6"})
        eval_call = next(call for call in calls if call[:2] == ("hyprctl", "eval"))
        lua = eval_call[2]
        self.assertIn('workspace = "6", monitor = "HDMI-A-1", persistent = true', lua)
        # The same rules eval-applies immediately must also be durably written -- a plain
        # `hyprctl eval` only ever applies at runtime and is wiped by the next reload.
        self.assertEqual(len(written), 1)
        self.assertIn('workspace = "6", monitor = "HDMI-A-1", persistent = true', "\n".join(written[0]))
        self.assertIn('workspace = "1", monitor = "DP-1", persistent = true', "\n".join(written[0]))
        self.assertIn(("hyprctl", "dispatch", "hl.dsp.focus({ workspace = 6 })"), calls)
        self.assertIn(("hyprctl", "dispatch", "hl.dsp.focus({ workspace = 1 })"), calls)

    def test_never_visited_workspaces_are_created_so_they_stay_persistent(self):
        # `persistent = true` only stops an *existing* workspace from being destroyed once
        # empty -- it never creates one that has never existed. Confirmed live: 3/4/5
        # stayed completely absent from `hyprctl -j workspaces` (and so invisible in
        # Waybar) even with the rules above already loaded, until something actually
        # visited them. apply() now briefly focuses each missing one of 1-6 (creating it)
        # and returns to whatever was actually focused, so persistence has something to
        # hold onto for every one of them, not just whichever the user happened to visit.
        apply = MODULE["apply"]
        calls = []
        rows = [
            {"name": "DP-1", "focused": True, "activeWorkspace": {"id": 2}},
            {"name": "HDMI-A-1", "focused": False, "activeWorkspace": {"id": 6}},
        ]
        # Only 1, 2, and 6 have ever actually been visited/used -- 3, 4, 5 don't exist yet.
        existing = [{"id": 1}, {"id": 2}, {"id": 6}]

        def fake_run(*arguments):
            calls.append(arguments)
            return subprocess.CompletedProcess(arguments, 0, "", "")

        with patch.dict(apply.__globals__, {
            "monitors": lambda: rows,
            "workspaces": lambda: existing,
            "clients": lambda: [],
            "stored_primary": lambda available: "",
            "run": fake_run,
            "write_workspace_rules": lambda commands: None,
        }), patch("time.sleep"):
            apply()

        for missing in (3, 4, 5):
            self.assertIn(("hyprctl", "dispatch", f"hl.dsp.focus({{ workspace = {missing} }})"), calls)
        # Already-existing workspaces are left alone -- no need to touch them again.
        self.assertNotIn(("hyprctl", "dispatch", "hl.dsp.focus({ workspace = 1 })"), calls)
        # The view ends up back on whatever was actually focused (workspace 2 here), not on
        # whichever missing workspace happened to be created last.
        self.assertEqual(calls[-1], ("hyprctl", "dispatch", "hl.dsp.focus({ workspace = 2 })"))

    def test_single_monitor_owns_all_six_workspaces_and_folds_extra_workspace(self):
        apply = MODULE["apply"]
        calls = []
        rows = [{"name": "DP-1", "focused": True, "activeWorkspace": {"id": 7}}]
        clients = [{"address": "0xabc", "workspace": {"id": 7}}]

        def fake_run(*arguments):
            calls.append(arguments)
            return subprocess.CompletedProcess(arguments, 0, "", "")

        with patch.dict(apply.__globals__, {
            "monitors": lambda: rows,
            "clients": lambda: clients,
            "stored_primary": lambda available: "",
            "run": fake_run,
            "write_workspace_rules": lambda commands: None,
        }), patch("time.sleep"):
            assignments = apply()

        self.assertEqual(assignments, {"DP-1": "1, 2, 3, 4, 5, 6"})
        eval_call = next(call for call in calls if call[:2] == ("hyprctl", "eval"))
        self.assertIn('workspace = "6", monitor = "DP-1", persistent = true', eval_call[2])
        self.assertIn(
            ("hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = 6, window = "address:0xabc", silent = true })'),
            calls,
        )
        self.assertIn(("hyprctl", "dispatch", "hl.dsp.focus({ workspace = 6 })"), calls)

    def test_reconnected_monitor_recovers_existing_workspaces_and_windows(self):
        apply = MODULE["apply"]
        calls = []
        rows = [
            {"name": "DP-1", "focused": True, "activeWorkspace": {"id": 1}},
            {"name": "HDMI-A-1", "focused": False, "activeWorkspace": {"id": 7}},
        ]
        existing = [
            {"id": 1, "monitor": "DP-1"},
            {"id": 2, "monitor": "HDMI-A-1"},
            {"id": 6, "monitor": "DP-1"},
            {"id": 7, "monitor": "HDMI-A-1"},
        ]
        clients = [
            {"address": "0xabc", "workspace": {"id": 6}},
            {"address": "0xdef", "workspace": {"id": 7}},
            {"address": "0x123", "workspace": {"id": 0}},
            {"address": "0x456", "workspace": {"id": -98}},
        ]

        def fake_run(*arguments):
            calls.append(arguments)
            return subprocess.CompletedProcess(arguments, 0, "", "")

        with patch.dict(apply.__globals__, {
            "stable_monitors": lambda: rows,
            "workspaces": lambda: existing,
            "clients": lambda: clients,
            "stored_primary": lambda available: "",
            "run": fake_run,
            "write_workspace_rules": lambda commands: None,
        }):
            apply()

        self.assertIn(("hyprctl", "dispatch", "moveworkspacetomonitor", "6 HDMI-A-1"), calls)
        self.assertIn(("hyprctl", "dispatch", "moveworkspacetomonitor", "2 DP-1"), calls)
        self.assertNotIn(("hyprctl", "dispatch", "moveworkspacetomonitor", "1 DP-1"), calls)
        self.assertIn(
            ("hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = 6, window = "address:0xdef", silent = true })'),
            calls,
        )
        self.assertIn(
            ("hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = 1, window = "address:0x123", silent = true })'),
            calls,
        )
        self.assertFalse(any("0x456" in argument for call in calls for argument in call))

    def test_zero_monitors_does_not_replace_rules_or_move_windows(self):
        apply = MODULE["apply"]
        calls = []
        with patch.dict(apply.__globals__, {
            "stable_monitors": lambda: [],
            "run": lambda *arguments: calls.append(arguments),
            "write_workspace_rules": lambda commands: calls.append(("write",)),
        }):
            self.assertEqual(apply(), {})
        self.assertEqual(calls, [])

    def test_three_and_four_displays_each_receive_a_workspace(self):
        assign = MODULE["workspace_monitors"]
        rows = [{"name": name} for name in ("DP-1", "HDMI-A-1", "DP-2", "DP-3")]
        with patch.dict(assign.__globals__, {"read_state": lambda: {}}):
            three = assign(rows[:3], "DP-1")
            four = assign(rows, "DP-1")
        self.assertEqual([three[index] for index in range(1, 7)], ["DP-1"] * 4 + ["DP-2", "HDMI-A-1"])
        self.assertEqual([four[index] for index in range(1, 7)], ["DP-1"] * 3 + ["DP-3", "DP-2", "HDMI-A-1"])

    def test_apply_moves_existing_workspace_to_new_third_display(self):
        apply = MODULE["apply"]
        calls = []
        rows = [
            {"name": "DP-1", "focused": True, "activeWorkspace": {"id": 1}},
            {"name": "HDMI-A-1", "focused": False, "activeWorkspace": {"id": 6}},
            {"name": "DP-2", "focused": False, "activeWorkspace": {"id": 7}},
        ]

        def fake_run(*arguments):
            calls.append(arguments)
            return subprocess.CompletedProcess(arguments, 0, "", "")

        with patch.dict(apply.__globals__, {
            "stable_monitors": lambda: rows,
            "stored_primary": lambda available: "DP-1",
            "read_state": lambda: {},
            "workspaces": lambda: [{"id": workspace, "monitor": "DP-1"} for workspace in range(1, 7)],
            "clients": lambda: [],
            "run": fake_run,
            "write_workspace_rules": lambda commands: None,
        }):
            assignments = apply()

        self.assertEqual(assignments, {"DP-1": "1, 2, 3, 4", "HDMI-A-1": "6", "DP-2": "5"})
        self.assertIn(("hyprctl", "dispatch", "moveworkspacetomonitor", "5 DP-2"), calls)
        self.assertIn(("hyprctl", "dispatch", "moveworkspacetomonitor", "6 HDMI-A-1"), calls)
        self.assertIn(("hyprctl", "dispatch", "hl.dsp.focus({ workspace = 5 })"), calls)

    def test_saved_assignment_returns_after_display_reconnects(self):
        assign = MODULE["workspace_monitors"]
        state = {"workspace_monitors": {"2": "DP-2"}}
        connected = [{"name": name} for name in ("DP-1", "HDMI-A-1", "DP-2")]
        with patch.dict(assign.__globals__, {"read_state": lambda: state}):
            self.assertEqual(assign(connected, "DP-1")[2], "DP-2")
            self.assertEqual(assign(connected[:2], "DP-1")[2], "DP-1")
            self.assertEqual(assign(connected, "DP-1")[2], "DP-2")

    def test_cannot_remove_the_only_workspace_on_a_display(self):
        save = MODULE["save_workspace"]
        rows = [{"name": "DP-1"}, {"name": "HDMI-A-1"}]
        with patch.dict(save.__globals__, {
            "monitors": lambda: rows,
            "choose_primary": lambda current: "DP-1",
            "read_state": lambda: {},
            "write_state": lambda value: self.fail("Invalid assignment was saved"),
            "apply": lambda: self.fail("Invalid assignment was applied"),
        }):
            with self.assertRaisesRegex(SystemExit, "Assign another workspace"):
                save(6, "DP-1")

    def test_stable_monitors_waits_out_a_transient_incomplete_enumeration(self):
        # Confirmed live: right after Hyprland (re)starts, `hyprctl -j monitors` can report
        # only the first-enumerated output for a moment even with a second physically
        # connected. apply() durably writes whatever it sees (write_workspace_rules), so
        # acting on that transient single-monitor snapshot wrongly binds workspace 6 to the
        # lone monitor seen at that instant -- permanently, since no monitor-added event
        # ever fires afterward for an output that was there the whole time.
        stable_monitors = MODULE["stable_monitors"]
        readings = [
            [{"name": "DP-1"}],  # mid-enumeration: HDMI-A-1 not visible yet
            [{"name": "DP-1"}, {"name": "HDMI-A-1"}],  # count changed since the last read
            [{"name": "DP-1"}, {"name": "HDMI-A-1"}],  # matches the previous read -> stable
        ]

        def fake_monitors():
            return readings.pop(0)

        with patch.dict(stable_monitors.__globals__, {"monitors": fake_monitors}), patch("time.sleep"):
            result = stable_monitors()

        self.assertEqual(result, [{"name": "DP-1"}, {"name": "HDMI-A-1"}])

    def test_stable_monitors_gives_up_after_the_attempt_budget(self):
        stable_monitors = MODULE["stable_monitors"]
        counter = iter(range(20))

        def fake_monitors():
            return [{"name": f"DP-{next(counter)}"}]

        with patch.dict(stable_monitors.__globals__, {"monitors": fake_monitors}), patch("time.sleep"):
            result = stable_monitors(attempts=3)

        self.assertEqual(len(result), 1)

    def test_write_workspace_rules_persists_to_the_file_hyprland_lua_loads_on_reload(self):
        # A plain `hyprctl eval` only ever applies at runtime; any later `hyprctl reload`
        # (every theme, font, or waybar-setting change triggers one) re-reads Hyprland's
        # config from disk and forgets it -- confirmed live: an eval-only persistent empty
        # workspace vanished from `hyprctl -j workspaces` right after a plain reload. This
        # file is what makes the assignment survive that, since hyprland.lua already
        # `load_optional`s it on every reload.
        write_workspace_rules = MODULE["write_workspace_rules"]
        commands = [
            'hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true })',
            'hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1", persistent = true })',
        ]
        with tempfile.TemporaryDirectory() as directory:
            config_dir = Path(directory) / "spectrumos"
            target = config_dir / "hyprland-workspaces.lua"
            with patch.dict(write_workspace_rules.__globals__, {"CONFIG_DIR": config_dir, "HYPRLAND_WORKSPACES_FILE": target}):
                write_workspace_rules(commands)
            content = target.read_text(encoding="utf-8")
        self.assertEqual(content, "\n".join(commands) + "\n")

    def test_workspace_rules_have_their_own_file_separate_from_display_menus_monitor_rules(self):
        # hyprland-workspaces.lua (this feature) and hyprland-monitors.lua (scripts/display-menu's
        # own hl.monitor({...}) position/mode/scale/transform rules) used to share one path --
        # two unrelated features each rewriting the whole file with only their own content, so
        # whichever ran last silently wiped the other's out. Confirmed live: display-menu's
        # rules were the only thing left in the file, meaning the persistent 1-5/6 workspace
        # split had stopped applying entirely. Each now has its own dedicated file, and
        # hyprland.lua load_optional's both on every reload.
        script = (ROOT / "scripts" / "workspace-layout").read_text(encoding="utf-8")
        self.assertIn('HYPRLAND_WORKSPACES_FILE = CONFIG_DIR / "hyprland-workspaces.lua"', script)
        display_menu = (ROOT / "scripts" / "display-menu").read_text(encoding="utf-8")
        self.assertIn('LUA_FILE = CONFIG_DIR / "hyprland-monitors.lua"', display_menu)
        hyprland_lua = (ROOT / "configs" / "hyprland" / "hyprland.lua").read_text(encoding="utf-8")
        self.assertIn('load_optional(home .. "/.config/spectrumos/hyprland-monitors.lua")', hyprland_lua)
        self.assertIn('load_optional(home .. "/.config/spectrumos/hyprland-workspaces.lua")', hyprland_lua)

    def test_event_socket_prefers_current_hyprland_instance(self):
        event_socket = MODULE["event_socket"]
        runtime = "/run/user/1000-test"
        expected = Path(runtime) / "hypr" / "test-instance" / ".socket2.sock"
        with patch.dict(os.environ, {"XDG_RUNTIME_DIR": runtime, "HYPRLAND_INSTANCE_SIGNATURE": "test-instance"}):
            with patch.object(Path, "is_socket", return_value=True):
                self.assertEqual(event_socket(), expected)

    def test_user_service_runs_persistent_watcher(self):
        service = (ROOT / "system" / "systemd" / "user" / "spectrum-workspace-layout.service").read_text(encoding="utf-8")
        self.assertIn("PartOf=graphical-session.target", service)
        self.assertIn("ExecStart=/usr/lib/spectrumos/workspace-layout --watch", service)
        self.assertIn("Restart=on-failure", service)


if __name__ == "__main__":
    unittest.main()
