from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class LegacyControlCenterRemovalTests(unittest.TestCase):
    def test_install_and_desktop_package_do_not_ship_eww(self):
        paths = [ROOT / "install.sh"]
        package_recipe = ROOT / "packages/spectrum-desktop/PKGBUILD"
        if package_recipe.is_file():
            paths.append(package_recipe)
        for path in paths:
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("configs/eww", text)
            self.assertNotIn("spectrum-eww.service", text)
            self.assertNotIn("eww-open", text)
            self.assertNotIn("eww-panel", text)
            self.assertNotIn("eww: Spectrum Control Center", text)
        self.assertNotIn("eww\n", (ROOT / "bootstrap/packages/desktop.aur.txt").read_text(encoding="utf-8"))
        self.assertNotIn('vendor/eww', (ROOT / "scripts/build-iso").read_text(encoding="utf-8"))
        self.assertNotIn('vendor/eww', (ROOT / "iso/spectrumos/profiledef.sh").read_text(encoding="utf-8"))

    def test_live_launch_paths_do_not_start_eww(self):
        for name in ("spectrum-shell-open", "session-menu", "weather-adapter", "application-adapter", "control-adapter", "theme-menu", "font-size-menu", "font-family-menu", "keyboard-layout"):
            text = (ROOT / "scripts" / name).read_text(encoding="utf-8")
            self.assertNotIn("/usr/lib/spectrumos/eww-", text, name)
            self.assertNotIn("spectrum-eww.service", text, name)
        for path in (ROOT / "configs/waybar/layouts").glob("*.jsonc"):
            self.assertNotIn("eww-open", path.read_text(encoding="utf-8"), path.name)

    def test_spectrum_shell_fallback_uses_native_picker_menus(self):
        wrapper = (ROOT / "scripts/spectrum-shell-open").read_text(encoding="utf-8")
        self.assertIn("exec /usr/lib/spectrumos/panel", wrapper)
        self.assertIn("appearance) exec /usr/lib/spectrumos/panel --appearance", wrapper)
        self.assertIn("displays) exec /usr/lib/spectrumos/display-menu", wrapper)


if __name__ == "__main__":
    unittest.main()
