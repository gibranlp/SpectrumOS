import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RECOVERY = (ROOT / "installer/spectrum-recovery").read_text()


def function(name):
    return re.search(r"^" + name + r"\(\) \{.*?^\}", RECOVERY, re.M | re.S)[0]


class InstallerRecoveryTests(unittest.TestCase):
    def test_efi_discovery_uses_selected_root_uuid_or_fstab_and_refuses_ambiguous_labels(self):
        for kind in ("owned", "fstab", "ambiguous", "invalid"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                metadata = root / "etc/spectrumos/boot-ownership"
                metadata.parent.mkdir(parents=True)
                if kind in ("owned", "invalid"):
                    metadata.write_text("boot_uuid=" + ("ABCD-1234" if kind == "owned" else "../../wrong") + "\n")
                if kind == "fstab":
                    (root / "etc/fstab").write_text("UUID=1234-ABCD /boot vfat defaults 0 2\n")
                script = '''
set -u
mount() { printf '%s\\n' "$*" >&2; ln -s "$FIXTURE/etc" "${@: -1}/etc"; }
umount() { unlink "$1/etc"; }
blkid() { [ "$*" = '-U ABCD-1234' ] && echo /dev/correct-esp; }
findfs() { [ "$1" = UUID=1234-ABCD ] && echo /dev/fstab-esp; }
lsblk() { printf 'sda1 SPECTRM_EFI\\nsdb1 SPECTRM_EFI\\n'; }
''' + function("detect_esp") + "\ndetect_esp /dev/selected-root\n"
                result = subprocess.run(["bash", "-c", script], text=True, capture_output=True,
                                        env={**os.environ, "FIXTURE": str(root)})
                self.assertIn("ro,nologreplay,subvol=@", result.stderr)
                if kind in ("owned", "fstab"):
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), "/dev/correct-esp" if kind == "owned" else "/dev/fstab-esp")
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, "")

    @unittest.skipUnless(Path("/usr/share/limine/BOOTX64.EFI").exists(), "Limine fixture is required")
    def test_boot_repair_validates_ownership_and_uses_namespaced_loader(self):
        for scenario in ("owned", "no-mount", "wrong-owner", "bios"):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as temporary:
                target = Path(temporary)
                (target / "etc/spectrumos").mkdir(parents=True)
                (target / "etc/spectrumos/boot-ownership").write_text("boot_partuuid=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\n")
                (target / "boot").mkdir()
                (target / "boot/limine.conf").write_text("timeout: 5\n")
                if scenario != "bios":
                    (target / "firmware").mkdir()
                body = function("action_repair_bootloader").replace("/sys/firmware/efi", str(target / "firmware"))
                script = '''
set -u
target=$FIXTURE
choose_root_device() { echo /dev/sda4; }
mount_installed_system() { :; }
unmount_installed_system() { echo UNMOUNT; }
pause() { :; }
mountpoint() { [ "$SCENARIO" != no-mount ]; }
findmnt() { echo /dev/sda2; }
readlink() { echo /dev/sda2; }
spectrum-snapshot() { echo VERIFY "$*"; [ "$SCENARIO" != wrong-owner ]; }
lsblk() { echo sda; }
cat() { echo 2; }
cp() { echo COPY "$*"; }
python() { echo FIRMWARE "$*"; }
''' + body + "\naction_repair_bootloader\n"
                result = subprocess.run(["bash", "-c", script], text=True, capture_output=True,
                                        env={**os.environ, "FIXTURE": str(target), "SCENARIO": scenario})
                self.assertIn("UNMOUNT", result.stdout)
                if scenario == "owned":
                    self.assertIn("VERIFY verify-boot", result.stdout)
                    self.assertIn("EFI/SpectrumOS/limine.efi", result.stdout)
                    self.assertIn("FIRMWARE", result.stdout)
                    self.assertIn("--keep-boot-default", result.stdout)
                    self.assertNotIn("EFI/BOOT/BOOTX64.EFI", result.stdout)
                else:
                    self.assertNotIn("COPY", result.stdout)
                    self.assertNotIn("FIRMWARE", result.stdout)


if __name__ == "__main__":
    unittest.main()
