from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/limine-windows-entry"
SPEC = importlib.util.spec_from_loader("limine_windows_entry", SourceFileLoader("limine_windows_entry", str(SCRIPT)))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class LimineWindowsEntryTests(unittest.TestCase):
    def test_candidates_include_only_other_disks_valid_efi_partitions(self):
        devices = {"blockdevices": [
            {"path": "/dev/sda", "type": "disk", "children": [
                {"path": "/dev/sda1", "type": "part", "parttype": MODULE.EFI_SYSTEM_PARTITION,
                 "partuuid": "11111111-2222-3333-4444-555555555555", "fstype": "vfat"},
            ]},
            {"path": "/dev/nvme0n1", "type": "disk", "children": [
                {"path": "/dev/nvme0n1p1", "type": "part", "parttype": MODULE.EFI_SYSTEM_PARTITION.upper(),
                 "partuuid": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "fstype": "vfat"},
                {"path": "/dev/nvme0n1p2", "type": "part", "parttype": MODULE.EFI_SYSTEM_PARTITION,
                 "partuuid": "99999999-2222-3333-4444-555555555555", "fstype": "ext4"},
            ]},
        ]}
        self.assertEqual(
            MODULE.candidates(devices, "/dev/sda"),
            [("/dev/nvme0n1p1", "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")],
        )

    def test_windows_loader_uses_actual_fat_name_case_and_checks_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            loader = root / "EFI" / "MICROSOFT" / "BOOT" / "BOOTMGFW.EFI"
            loader.parent.mkdir(parents=True)
            loader.write_bytes(b"MZ" + b"\0" * 16)
            self.assertEqual(MODULE.windows_loader(root), "/EFI/MICROSOFT/BOOT/BOOTMGFW.EFI")
            loader.write_bytes(b"not an EFI executable")
            self.assertIsNone(MODULE.windows_loader(root))

    def test_discovery_mounts_other_efi_partition_read_only(self):
        partuuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        with mock.patch.object(MODULE.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run, \
             mock.patch.object(MODULE, "windows_loader", return_value="/EFI/Microsoft/Boot/bootmgfw.efi"):
            self.assertEqual(
                MODULE.discover([("/dev/nvme0n1p1", partuuid)]),
                [(partuuid, "/EFI/Microsoft/Boot/bootmgfw.efi")],
            )
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args_list[0].args[0][:5],
                         ["mount", "-t", "vfat", "-o", "ro,nosuid,nodev,noexec"])
        self.assertEqual(run.call_args_list[1].args[0][0], "umount")

    def test_entry_survives_theme_and_kernel_config_updates(self):
        original = "/SpectrumOS\n    protocol: linux\n    path: boot():/vmlinuz-linux-zen\n    cmdline: root=UUID=abc rw\n"
        partuuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        path = f"guid({partuuid}):/EFI/Microsoft/Boot/bootmgfw.efi"
        updated = MODULE.add_entries(original, [(partuuid, "/EFI/Microsoft/Boot/bootmgfw.efi")])
        self.assertIn(f"/Windows Boot Manager\n    protocol: efi\n    path: {path}", updated)
        self.assertEqual(MODULE.add_entries(updated, [(partuuid, "/EFI/Microsoft/Boot/bootmgfw.efi")]), updated)
        self.assertEqual(
            MODULE.add_entries(updated.replace(path, path.upper()),
                               [(partuuid, "/EFI/Microsoft/Boot/bootmgfw.efi")]).count("/Windows Boot Manager"),
            1,
        )

        appearance_path = ROOT / "scripts/limine-appearance-sync"
        appearance_spec = importlib.util.spec_from_loader(
            "limine_appearance_sync", SourceFileLoader("limine_appearance_sync", str(appearance_path))
        )
        appearance = importlib.util.module_from_spec(appearance_spec)
        appearance_spec.loader.exec_module(appearance)
        plymouth_path = ROOT / "scripts/plymouth-boot-sync"
        plymouth_spec = importlib.util.spec_from_loader(
            "plymouth_boot_sync", SourceFileLoader("plymouth_boot_sync", str(plymouth_path))
        )
        plymouth = importlib.util.module_from_spec(plymouth_spec)
        plymouth_spec.loader.exec_module(plymouth)
        after_theme = appearance.replace_keys(updated, {"wallpaper": "boot():/spectrumos-wallpaper.png"})
        after_kernel = plymouth.with_splash_flags(after_theme)
        self.assertIn(f"/Windows Boot Manager\n    protocol: efi\n    path: {path}", after_kernel)

    def test_installer_discovers_windows_before_package_and_kernel_setup(self):
        backend = (ROOT / "installer/spectrum-installer-backend").read_text(encoding="utf-8")
        self.assertIn('python "$project_root/scripts/limine-windows-entry"', backend)
        self.assertIn('--config "$target/boot/limine.conf" --exclude-disk "$disk"', backend)
        self.assertLess(backend.index('scripts/limine-windows-entry'), backend.index('pacstrap -K "$target"'))


if __name__ == "__main__":
    unittest.main()
