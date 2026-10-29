from pathlib import Path
import json
import importlib.machinery
import importlib.util
import os
import subprocess
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "system-adapter"


class SystemAdapterResourceTests(unittest.TestCase):
    def setUp(self):
        loader = importlib.machinery.SourceFileLoader("system_adapter", str(SCRIPT))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.adapter = importlib.util.module_from_spec(spec)
        loader.exec_module(self.adapter)

    def test_fans_include_stopped_and_running_sensors_only(self):
        with tempfile.TemporaryDirectory() as directory:
            device = Path(directory) / "hwmon0"
            device.mkdir()
            (device / "name").write_text("amdgpu")
            for number, value in [(1, "0"), (2, "1250"), (3, "invalid"), (4, "-1")]:
                (device / f"fan{number}_input").write_text(value)
            (device / "fan2_label").write_text("GPU fan")
            fans = self.adapter.fan_state(Path(directory))
            self.assertEqual([item["rpm"] for item in fans], [0, 1250])
            self.assertEqual(fans[1]["label"], "GPU fan")
        self.assertEqual(self.adapter.fan_state(Path(directory)), [])

    def test_storage_deduplicates_subvolumes_and_skips_virtual_boot_and_unavailable_mounts(self):
        root = SimpleNamespace(used=120_000_000_000, total=980_000_000_000)
        other = SimpleNamespace(used=20_000_000_000, total=500_000_000_000)
        with tempfile.TemporaryDirectory() as directory:
            mountinfo = Path(directory) / "mountinfo"
            mountinfo.write_text("\n".join([
                "1 0 0:1 /@ / rw - btrfs /dev/nvme0n1p2 rw",
                "2 0 0:1 /@home /home rw - btrfs /dev/nvme0n1p2 rw",
                "3 0 8:1 / /boot rw - vfat /dev/nvme0n1p1 rw",
                r"4 0 8:2 / /run/media/Test\040Drive rw - ext4 /dev/sda1 rw",
                "5 0 8:2 / /mnt/duplicate rw - ext4 /dev/sda1 rw",
                "6 0 8:3 / /mnt/unavailable rw - ext4 /dev/sdb1 rw",
                "7 0 0:2 / /tmp rw - tmpfs tmpfs rw",
                "8 0 7:0 / /mnt/image rw - ext4 /dev/loop0 rw",
            ]))
            def usage(path):
                if path == "/mnt/unavailable":
                    raise OSError("unmounted")
                return other
            with mock.patch.object(self.adapter.shutil, "disk_usage", side_effect=usage):
                disks = self.adapter.storage_state(root, mountinfo)
            self.assertEqual([item["mount"] for item in disks], ["/", "/run/media/Test Drive"])
            self.assertEqual(disks[0]["used"], root.used)
            self.assertEqual(disks[1]["total"], other.total)
        self.assertEqual(self.adapter.storage_state(root, mountinfo), [{"mount":"/", "used":root.used, "total":root.total}])


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
