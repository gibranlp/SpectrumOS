import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "system" / "initcpio" / "hooks" / "spectrumos-restore"
INSTALL_HOOK = ROOT / "system" / "initcpio" / "install" / "spectrumos-restore"


def select(snapshots_root: Path, requested: str = "") -> str:
    """Runs the hook's pure selection function in isolation via /bin/sh,
    without sourcing run_hook (which needs a real mount and is out of
    scope for a unit test; that half is destructive-VM-only, like the
    rest of the restore machinery)."""
    script = f". '{HOOK}'; spectrumos_select_restore_point '{snapshots_root}' '{requested}'"
    result = subprocess.run(["sh", "-c", script], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def make_restore_point(root: Path, identifier: str, *, complete: bool = True) -> None:
    directory = root / identifier
    directory.mkdir(parents=True)
    (directory / "metadata.json").write_text("{}", encoding="utf-8")
    if complete:
        (directory / "root").mkdir()
        (directory / "boot.tar").touch()


class SpectrumosRestoreHookTests(unittest.TestCase):
    def test_install_hook_includes_the_mountpoint_check_used_at_runtime(self):
        content = INSTALL_HOOK.read_text(encoding="utf-8")
        self.assertIn("add_binary mountpoint", content)
        for module in ("vfat", "fat", "nls_cp437", "nls_ascii"):
            self.assertIn(f"add_module {module}", content)

    def test_selects_the_newest_complete_restore_point_by_default(self):
        with tempfile.TemporaryDirectory() as temporary:
            snapshots_root = Path(temporary)
            make_restore_point(snapshots_root, "20260101T000000Z-a")
            make_restore_point(snapshots_root, "20260201T000000Z-b")
            self.assertEqual(select(snapshots_root, "latest"), "20260201T000000Z-b")
            self.assertEqual(select(snapshots_root, ""), "20260201T000000Z-b")

    def test_skips_incomplete_restore_points(self):
        with tempfile.TemporaryDirectory() as temporary:
            snapshots_root = Path(temporary)
            make_restore_point(snapshots_root, "20260101T000000Z-complete")
            make_restore_point(snapshots_root, "20260201T000000Z-incomplete", complete=False)
            self.assertEqual(select(snapshots_root, "latest"), "20260101T000000Z-complete")

    def test_selects_an_explicit_id_only_if_it_is_complete(self):
        with tempfile.TemporaryDirectory() as temporary:
            snapshots_root = Path(temporary)
            make_restore_point(snapshots_root, "20260101T000000Z-complete")
            make_restore_point(snapshots_root, "20260201T000000Z-incomplete", complete=False)
            self.assertEqual(select(snapshots_root, "20260101T000000Z-complete"), "20260101T000000Z-complete")
            self.assertEqual(select(snapshots_root, "20260201T000000Z-incomplete"), "")
            self.assertEqual(select(snapshots_root, "20260301T000000Z-missing"), "")

    def test_prints_nothing_when_the_snapshots_root_does_not_exist(self):
        missing = Path(tempfile.gettempdir()) / "spectrumos-restore-hook-test-missing"
        self.assertEqual(select(missing, "latest"), "")

    def test_ignores_directories_that_do_not_match_the_restore_point_id_shape(self):
        with tempfile.TemporaryDirectory() as temporary:
            snapshots_root = Path(temporary)
            make_restore_point(snapshots_root, "20260101T000000Z-good")
            (snapshots_root / ".pruning").mkdir()
            self.assertEqual(select(snapshots_root, "latest"), "20260101T000000Z-good")

    def test_run_hook_does_nothing_when_getarg_finds_no_restore_parameter(self):
        # Real getarg prints nothing and still exits 0 when the arg is absent -- it
        # never signals "not found" through its exit code (confirmed against
        # /usr/lib/initcpio/init_functions and every real hook on the system, e.g.
        # resume's `resume="$(getarg resume)"`). A hook that mistakenly treated getarg
        # as boolean-returning would fall through here instead of returning early.
        script = f"""
getarg() {{ :; }}
mount() {{ echo "mount-called"; return 1; }}
mkdir() {{ :; }}
root=/dev/fake
. '{HOOK}'
run_hook
"""
        result = subprocess.run(["sh", "-c", script], capture_output=True, text=True)
        self.assertNotIn("mount-called", result.stdout)

    def test_run_hook_proceeds_when_getarg_finds_the_restore_parameter(self):
        script = f"""
getarg() {{ printf '%s' 'latest'; }}
mount() {{ echo "mount-called"; return 1; }}
mkdir() {{ :; }}
root=/dev/fake
. '{HOOK}'
run_hook
"""
        result = subprocess.run(["sh", "-c", script], capture_output=True, text=True)
        self.assertIn("mount-called", result.stdout)


if __name__ == "__main__":
    unittest.main()
