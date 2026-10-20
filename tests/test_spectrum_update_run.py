import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "spectrum-update-run"
BASH = shutil.which("bash")


def write_stub(directory: Path, name: str, body: str) -> None:
    # An absolute shebang, not `#!/usr/bin/env bash`: PATH is restricted
    # below to just this directory, so `env` could not resolve `bash` either.
    path = directory / name
    path.write_text(f"#!{BASH}\n{body}\n", encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


def run(mode: str, bin_dir: Path, *, stdin_text: str = "y\n", extra_env: dict | None = None):
    # PATH is *replaced*, not extended: this machine has a real paru/sudo,
    # and a test for "paru is not installed" must not find them.
    env = {"PATH": str(bin_dir), "HOME": os.environ.get("HOME", "/tmp"), "XDG_RUNTIME_DIR": str(bin_dir)}
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        [BASH, str(SCRIPT), mode],
        input=stdin_text,
        capture_output=True,
        text=True,
        env=env,
        timeout=10,
    )


class SpectrumUpdateRunTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.bin_dir = Path(self.temporary.name)
        self.log = self.bin_dir / "calls.log"
        for name in ("mkdir", "flock"):
            (self.bin_dir / name).symlink_to(shutil.which(name))
        write_stub(
            self.bin_dir,
            "spectrum",
            f"""
echo "spectrum $*" >> '{self.log}'
if [ "$1" = "update" ] && [ "$2" = "plan" ]; then
    echo "plan output"
    exit "${{SPECTRUM_PLAN_EXIT:-0}}"
fi
if [ "$1" = "doctor" ]; then
    echo "doctor output"
    exit "${{SPECTRUM_DOCTOR_EXIT:-0}}"
fi
if [ "$1" = "migrate" ] && [ "$2" = "apply" ]; then
    echo "migration output"
    exit "${{SPECTRUM_MIGRATE_EXIT:-0}}"
fi
exit 0
""",
        )

    def tearDown(self):
        self.temporary.cleanup()

    def test_rejects_an_unknown_mode_before_doing_anything(self):
        result = run("bogus", self.bin_dir)
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.log.exists())

    def test_stops_without_prompting_when_the_preflight_is_blocked(self):
        result = run("official", self.bin_dir, extra_env={"SPECTRUM_PLAN_EXIT": "1"})
        self.assertEqual(result.returncode, 1)
        self.assertIn("blockers", result.stdout)
        self.assertNotIn("Continue with the update", result.stdout)

    def test_a_declined_confirmation_changes_nothing(self):
        write_stub(self.bin_dir, "sudo", f"echo \"sudo $*\" >> '{self.log}'\n")
        result = run("official", self.bin_dir, stdin_text="n\n")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Cancelled", result.stdout)
        self.assertNotIn("sudo", self.log.read_text(encoding="utf-8"))

    def test_official_mode_runs_pacman_through_sudo_then_doctor(self):
        write_stub(self.bin_dir, "sudo", f"echo \"sudo $*\" >> '{self.log}'\nexit 0\n")
        result = run("official", self.bin_dir)
        self.assertEqual(result.returncode, 0)
        calls = self.log.read_text(encoding="utf-8")
        self.assertIn("sudo pacman -Syu", calls)
        self.assertIn("sudo spectrum migrate apply", calls)
        self.assertIn("spectrum doctor", calls)
        self.assertLess(calls.index("sudo pacman -Syu"), calls.index("sudo spectrum migrate apply"))
        self.assertLess(calls.index("sudo spectrum migrate apply"), calls.index("spectrum doctor"))
        self.assertIn("Update complete and healthy", result.stdout)

    def test_aur_mode_without_paru_installed_fails_clearly(self):
        result = run("aur", self.bin_dir)
        self.assertEqual(result.returncode, 1)
        self.assertIn("paru is not installed", result.stderr)

    def test_all_mode_prefers_paru_when_available(self):
        write_stub(self.bin_dir, "paru", f"echo \"paru $*\" >> '{self.log}'\nexit 0\n")
        write_stub(self.bin_dir, "sudo", f"echo \"sudo $*\" >> '{self.log}'\n")
        result = run("all", self.bin_dir)
        self.assertEqual(result.returncode, 0)
        calls = self.log.read_text(encoding="utf-8")
        self.assertIn("paru -Syu", calls)
        self.assertNotIn("sudo pacman", calls)

    def test_rechecks_preflight_after_confirmation(self):
        marker = self.bin_dir / "checked"
        write_stub(self.bin_dir, "spectrum", f'''
echo "spectrum $*" >> '{self.log}'
if [ "$1 $2" = "update plan" ]; then
    if [ -f '{marker}' ]; then exit 1; fi
    : > '{marker}'
fi
exit 0
''')
        write_stub(self.bin_dir, "sudo", f'echo "sudo $*" >> \'{self.log}\'')
        result = run("official", self.bin_dir)
        self.assertEqual(result.returncode, 1)
        self.assertIn("system changed", result.stdout)
        self.assertNotIn("sudo", self.log.read_text())

    def test_existing_update_lock_stops_before_preflight(self):
        import fcntl
        directory = self.bin_dir / "spectrumos"
        directory.mkdir()
        with (directory / "update.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = run("all", self.bin_dir)
        self.assertEqual(result.returncode, 1)
        self.assertIn("Another SpectrumOS update window", result.stderr)
        self.assertFalse(self.log.exists())

    def test_all_mode_updates_system_and_user_flatpaks_after_migrations(self):
        write_stub(self.bin_dir, "sudo", f'echo "sudo $*" >> \'{self.log}\'')
        write_stub(self.bin_dir, "flatpak", f'echo "flatpak $*" >> \'{self.log}\'')
        result = run("all", self.bin_dir)
        self.assertEqual(result.returncode, 0)
        calls = self.log.read_text()
        self.assertIn("flatpak update --system", calls)
        self.assertIn("flatpak update --user", calls)
        self.assertLess(calls.index("sudo spectrum migrate apply"), calls.index("flatpak update --system"))
        self.assertLess(calls.index("flatpak update --user"), calls.index("spectrum doctor"))

    def test_flatpak_failure_is_reported_and_still_runs_doctor(self):
        write_stub(self.bin_dir, "sudo", f'echo "sudo $*" >> \'{self.log}\'')
        write_stub(self.bin_dir, "flatpak", f'echo "flatpak $*" >> \'{self.log}\'\nif [ "$2" = --system ]; then exit 8; fi\nexit 0')
        result = run("all", self.bin_dir)
        self.assertEqual(result.returncode, 8)
        self.assertIn("Flatpak updates failed", result.stdout)
        self.assertIn("spectrum doctor", self.log.read_text())

    def test_failed_system_update_skips_flatpaks(self):
        write_stub(self.bin_dir, "sudo", f'echo "sudo $*" >> \'{self.log}\'\nexit 7')
        write_stub(self.bin_dir, "flatpak", f'echo "flatpak $*" >> \'{self.log}\'')
        result = run("all", self.bin_dir)
        self.assertEqual(result.returncode, 7)
        self.assertNotIn("flatpak", self.log.read_text())

    def test_aur_mode_keeps_official_packages_in_the_upgrade(self):
        write_stub(self.bin_dir, "paru", f'echo "paru $*" >> \'{self.log}\'')
        write_stub(self.bin_dir, "sudo", f'echo "sudo $*" >> \'{self.log}\'')
        result = run("aur", self.bin_dir)
        self.assertEqual(result.returncode, 0)
        self.assertIn("paru -Syu", self.log.read_text())
        self.assertNotIn("paru -Sua", self.log.read_text())

    def test_native_panel_and_shortcut_use_the_confirmed_runner(self):
        bindings = (ROOT / "configs/hyprland/keybindings.lua").read_text()
        panel = (ROOT / "configs/spectrum-shell/UpdatePanel.qml").read_text()
        shell = (ROOT / "configs/spectrum-shell/shell.qml").read_text()
        self.assertIn('mainMod .. " + U"', bindings)
        self.assertIn('spectrum-shell-open updates', bindings)
        self.assertIn('updatePanel.refresh()', shell)
        self.assertIn('function openUpdates(): void', shell)
        self.assertIn('updatePanel.expanded = true', shell)
        self.assertIn('if (updatePanel.expanded) updatePanel.expanded = false;', shell)
        self.assertIn('openOnFocused("openUpdates")', shell)
        self.assertIn('backendDir + "/spectrum-update-run"', panel)
        self.assertIn('enabled: panel.ready && !planProcess.running', panel)

    def test_a_failed_migration_reports_failure_and_still_runs_doctor(self):
        write_stub(
            self.bin_dir,
            "sudo",
            f'echo "sudo $*" >> \'{self.log}\'\nif [ "$1" = "spectrum" ]; then exit 9; fi\nexit 0\n',
        )
        result = run("official", self.bin_dir)
        self.assertEqual(result.returncode, 9)
        self.assertIn("ordered migrations failed", result.stdout)
        self.assertIn("spectrum doctor", self.log.read_text(encoding="utf-8"))

    def test_a_failed_update_still_runs_doctor_and_reports_its_own_status(self):
        write_stub(self.bin_dir, "sudo", f"echo \"sudo $*\" >> '{self.log}'\nexit 7\n")
        result = run("official", self.bin_dir)
        self.assertEqual(result.returncode, 7)
        self.assertIn("doctor output", result.stdout)
        self.assertIn("did not complete successfully", result.stdout)
        self.assertNotIn("sudo spectrum migrate apply", self.log.read_text(encoding="utf-8"))

    def test_a_failed_doctor_is_the_final_status_after_a_successful_update(self):
        write_stub(self.bin_dir, "sudo", f"echo \"sudo $*\" >> '{self.log}'\nexit 0\n")
        result = run("official", self.bin_dir, extra_env={"SPECTRUM_DOCTOR_EXIT": "1"})
        self.assertEqual(result.returncode, 1)
        self.assertIn("doctor reports problems", result.stdout)


if __name__ == "__main__":
    unittest.main()
