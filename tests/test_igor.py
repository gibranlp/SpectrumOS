import hashlib
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class IgorTests(unittest.TestCase):
    def layout(self, config, *args):
        result = subprocess.run([str(ROOT / "scripts/spectrum-shell-layout"), *args],
                                env={**os.environ, "XDG_CONFIG_HOME": str(config)},
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_mascot_toggle_preserves_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            path = config / "spectrumos/shell.json"
            path.parent.mkdir()
            original = {"bar_position": "top", "bar_profile": "detailed",
                        "bar_profiles": {"DP-1": "multimedia"}, "custom": "preserved"}
            path.write_text(json.dumps(original))
            self.layout(config, "set-mascot", "off")
            saved = json.loads(path.read_text())
            self.assertEqual(saved, {**original, "igor_enabled": False})
            self.assertFalse(json.loads(self.layout(config, "--json"))["igor_enabled"])
            self.layout(config, "set-mascot", "on")
            self.assertEqual(json.loads(path.read_text()), {**original, "igor_enabled": True})
            self.assertTrue(json.loads(self.layout(config, "--json"))["igor_enabled"])

    def test_first_install_enables_igor(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertTrue(json.loads(self.layout(Path(directory), "--json"))["igor_enabled"])

    def test_layers_are_reproducible_and_preserve_original(self):
        loader = importlib.machinery.SourceFileLoader("prepare_igor", str(ROOT / "scripts/prepare-igor-assets"))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        original = (ROOT / "igor.svg").read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            module.ROOT = Path(directory)
            (module.ROOT / "igor.svg").write_bytes(original)
            module.main()
            self.assertEqual(hashlib.sha256((module.ROOT / "igor.svg").read_bytes()).digest(),
                             hashlib.sha256(original).digest())
            for name in ("chin.svg", "head.svg", "head-base.svg", "left-paw.svg", "right-paw.svg", "face.svg"):
                generated = module.ROOT / "configs/spectrum-shell/igor" / name
                self.assertEqual(generated.read_bytes(), (ROOT / "configs/spectrum-shell/igor" / name).read_bytes())
            head = ET.parse(module.ROOT / "configs/spectrum-shell/igor/head.svg").getroot()
            self.assertIsNotNone(head.find("{http://www.w3.org/2000/svg}use"))
            self.assertIsNotNone(head.find("{http://www.w3.org/2000/svg}defs"))


if __name__ == "__main__":
    unittest.main()
