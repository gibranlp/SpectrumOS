from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "system-adapter"


class SystemAdapterHyprlandTests(unittest.TestCase):
    def _hyprland_payload(self, state_contents=None):
        with tempfile.TemporaryDirectory() as temporary:
            if state_contents is not None:
                state_dir = Path(temporary) / "spectrumos"
                state_dir.mkdir(parents=True)
                (state_dir / "hyprland-controls.state").write_text(state_contents, encoding="utf-8")
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            environment["SPECTRUM_FONT_FAMILIES_FILE"] = str(
                ROOT / "system" / "spectrumos" / "font-families.conf"
            )
            result = subprocess.run(
                ("python3", str(SCRIPT)), env=environment, check=True,
                capture_output=True, text=True, timeout=10,
            )
        return json.loads(result.stdout)["hyprland"]

    def test_defaults_include_border_and_balanced_animations(self):
        # No state file at all (a fresh install) -- these must match hyprland-menu's own
        # defaults exactly, or the control center's checkmark would land on nothing.
        payload = self._hyprland_payload()
        self.assertEqual(payload["border"], "spectrum")
        self.assertEqual(payload["animations"], "balanced")

    def test_legacy_on_state_reads_as_balanced(self):
        # A state file saved before Smooth/Balanced/Heavy existed only ever had "on" --
        # the control center's checkmark has to keep landing on the tier that actually
        # matches what hyprland-menu itself would apply for that same legacy value.
        payload = self._hyprland_payload(
            "blur=light\ngaps=balanced\nrounding=spectrum\ntransparency=opaque\nlayout=dwindle\nanimations=on\n"
        )
        self.assertEqual(payload["animations"], "balanced")

    def test_persisted_border_and_animation_tier_are_read_through(self):
        payload = self._hyprland_payload(
            "blur=light\ngaps=balanced\nrounding=spectrum\ntransparency=opaque\nlayout=dwindle\nborder=thick\nanimations=heavy\n"
        )
        self.assertEqual(payload["border"], "thick")
        self.assertEqual(payload["animations"], "heavy")

    def test_font_family_labels_come_from_the_shared_registry_not_a_hardcoded_dict(self):
        # font-family-menu (the picker) reads the exact same file, so the two never
        # drift into independent hand-maintained copies again.
        content = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("read_font_family_labels()", content)
        self.assertIn("/usr/share/spectrumos/font-families.conf", content)
        self.assertNotIn('"jetbrains-mono": "JetBrains Mono"', content)


if __name__ == "__main__":
    unittest.main()
