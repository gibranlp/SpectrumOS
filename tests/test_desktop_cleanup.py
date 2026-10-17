from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MIGRATE_KITTY = runpy.run_path(str(ROOT / "scripts/spectrum-desktop-cleanup"))["migrate_kitty_defaults"]


class DesktopCleanupTests(unittest.TestCase):
    def test_kitty_upgrade_updates_legacy_copy_without_losing_settings(self):
        for setting in ("", "remember_window_size yes\n", "  remember_window_size no # old setting\n"):
            with self.subTest(setting=setting), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                path = home / ".config/kitty/spectrum.conf"
                path.parent.mkdir(parents=True)
                path.write_text("include ~/.cache/spectrumos/theme/current/kitty.conf\n" + setting + "font_size 15\nmap ctrl+c copy_to_clipboard\n")
                path.chmod(0o640)
                personal = path.parent / "kitty.conf"
                personal.write_text("include spectrum.conf\nfont_size 17\n")
                self.assertTrue(MIGRATE_KITTY(home))
                self.assertIn("remember_window_size no\n", path.read_text())
                self.assertIn("font_size 15\nmap ctrl+c copy_to_clipboard\n", path.read_text())
                self.assertEqual(path.stat().st_mode & 0o777, 0o640)
                self.assertEqual(personal.read_text(), "include spectrum.conf\nfont_size 17\n")
                self.assertFalse(MIGRATE_KITTY(home))

    def test_kitty_upgrade_skips_missing_custom_linked_and_package_includes(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = home / ".config/kitty/spectrum.conf"
            self.assertFalse(MIGRATE_KITTY(home))
            path.parent.mkdir(parents=True)
            for contents in ("font_size 15\n", "include /usr/share/spectrumos/terminal/kitty-spectrum.conf\n"):
                path.write_text(contents)
                self.assertFalse(MIGRATE_KITTY(home))
                self.assertEqual(path.read_text(), contents)
            path.unlink()
            target = home / "personal.conf"
            target.write_text("include ~/.cache/spectrumos/theme/current/kitty.conf\n")
            path.symlink_to(target)
            self.assertFalse(MIGRATE_KITTY(home))
            self.assertEqual(target.read_text(), "include ~/.cache/spectrumos/theme/current/kitty.conf\n")

    def test_cleanup_removes_retired_assets_and_preserves_shell_helpers(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for name in ("eww", "wofi", "waybar", "dunst", "spectrum-shell"):
                path = target / "usr/share/spectrumos" / name
                path.mkdir(parents=True)
                (path / "config").write_text("test")
            helpers = target / "usr/lib/spectrumos"
            helpers.mkdir(parents=True)
            for name in ("eww-open", "wofi", "waybar", "dunst-reload", "waybar-widgets", "waybar-cava", "waybar-workspace-icons"):
                (helpers / name).write_text("test")
            command = ["python", str(ROOT / "scripts/spectrum-desktop-cleanup"), "--root", str(target)]
            for _ in range(2):
                subprocess.run(command, check=True)
            for name in ("eww", "wofi", "waybar", "dunst"):
                self.assertFalse((target / "usr/share/spectrumos" / name).exists())
            for name in ("eww-open", "wofi", "waybar", "dunst-reload"):
                self.assertFalse((helpers / name).exists())
            for name in ("waybar-widgets", "waybar-cava", "waybar-workspace-icons"):
                self.assertTrue((helpers / name).exists())
            self.assertTrue((target / "usr/share/spectrumos/spectrum-shell/config").exists())
            for name in ("spectrum-eww.service", "spectrum-waybar.service", "dunst.service", "org.knopwob.dunst.service"):
                self.assertEqual((target / "etc/systemd/user" / name).readlink(), Path("/dev/null"))

    def test_updates_install_cleanup_and_replace_retired_apps(self):
        recipe_path = ROOT / "packages/spectrum-desktop/PKGBUILD"
        hook = (ROOT / "system/pacman-hooks/90-spectrumos-desktop-cleanup.hook").read_text()
        if recipe_path.exists():
            recipe = recipe_path.read_text()
            self.assertIn("replaces=(eww eww-git wofi waybar dunst)", recipe)
            self.assertIn("conflicts=(eww eww-git wofi waybar dunst)", recipe)
            self.assertIn("spectrum-desktop-cleanup", recipe)
        self.assertIn("When = PostTransaction", hook)
        self.assertIn("Target = spectrum-desktop", hook)
