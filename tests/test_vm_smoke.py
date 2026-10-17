from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "scripts" / "vm-smoke"


class VmSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if shutil.which("qemu-system-x86_64") is None or shutil.which("qemu-img") is None:
            raise unittest.SkipTest("QEMU is unavailable on this test host")
        if not Path("/usr/share/edk2/x64/OVMF_CODE.4m.fd").is_file():
            raise unittest.SkipTest("OVMF is unavailable on this test host")

    def run_harness(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ("bash", str(HARNESS), *arguments),
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

    def test_default_is_a_non_mutating_plan(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory) / "vm"
            result = self.run_harness("--workspace", str(workspace))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Mode: dry-run", result.stdout)
            self.assertIn("qemu-system-x86_64", result.stdout)
            self.assertFalse(workspace.exists())

    def test_prepare_creates_bounded_disposable_state(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory) / "vm"
            result = self.run_harness(
                "--prepare", "--workspace", str(workspace), "--disk-size", "64M"
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((workspace / "spectrumos.qcow2").is_file())
            self.assertTrue((workspace / "OVMF_VARS.4m.fd").is_file())

    def test_run_requires_prepared_state(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_harness("--run", "--workspace", directory, "--headless")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("run --prepare first", result.stderr)


if __name__ == "__main__":
    unittest.main()
