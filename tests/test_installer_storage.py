from copy import deepcopy
from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import stat
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_loader("installer_storage", SourceFileLoader(
    "installer_storage", str(ROOT / "installer/spectrum-installer-storage")))
STORAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STORAGE)


def layout_fixture(sector=512, disk="/dev/nvme0n1"):
    parts = [{"node": STORAGE.partition_path(disk, 1), "start": 1024**2 // sector,
              "size": 512 * 1024**2 // sector, "type": STORAGE.ESP_TYPE,
              "uuid": "11111111-2222-3333-4444-555555555555", "name": "Existing EFI"},
             {"node": STORAGE.partition_path(disk, 3), "start": 1024**3 // sector,
              "size": 20 * 1024**3 // sector, "type": STORAGE.ROOT_TYPE,
              "uuid": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "name": "Windows/data"}]
    table = {"label": "gpt", "unit": "sectors", "sectorsize": sector,
             "firstlba": 34 if sector == 512 else 6,
             "lastlba": 80 * 1024**3 // sector - 34,
             "id": "12345678-1234-5678-1234-567812345678", "partitions": parts}
    layout = {"schema": 1, "disk": disk, "disk_guid": table["id"], "bytes": 80 * 1024**3,
              "sector_size": sector, "blockers": [], "partitions": [],
              "free_extents": STORAGE.aligned_extents(table)}
    for number, item in zip((1, 3), parts):
        layout["partitions"].append({"number": number, "path": item["node"], "start": item["start"],
            "size": item["size"], "type": item["type"], "partuuid": item["uuid"],
            "name": item["name"], "attributes": "", "fstype": "vfat" if number == 1 else "ntfs",
            "uuid": "1234-5678" if number == 1 else "1122334455667788", "label": None})
    layout["fingerprint"] = STORAGE.digest(layout)
    return table, layout


def planned(layout=None):
    layout = layout or layout_fixture()[1]
    return STORAGE.make_plan(layout, layout["free_extents"][-1]["start"], 40)


def after_layout(plan):
    layout = layout_fixture()[1]
    layout["partitions"] = deepcopy(plan["preserve"])
    for created in plan["create"]:
        layout["partitions"].append({
            "number": created["number"], "path": created["path"], "start": created["start"],
            "size": created["end"] - created["start"] + 1, "type": created["type"],
            "partuuid": created["partuuid"], "name": "", "attributes": "", "fstype": None,
            "uuid": None, "label": None,
        })
    return layout


class InstallerStorageTests(unittest.TestCase):
    def test_json_command_identifies_empty_or_invalid_disk_tool_output(self):
        for tool in ("lsblk", "sfdisk"):
            for output, message in (("", "empty output"), ("\n ", "empty output"),
                                    ("not JSON", "invalid disk-layout JSON"),
                                    ("[]", "an unexpected disk-layout JSON structure")):
                with self.subTest(tool=tool, output=output), \
                     mock.patch.object(STORAGE, "command", return_value=output):
                    with self.assertRaisesRegex(STORAGE.StorageError, f"{tool} returned {message}"):
                        STORAGE.command_json([tool, "--json", "/dev/testdisk"])

    def inspect_fixture(self, *, mounted=False, swap=False, read_only=False, label="gpt", verified=True):
        table, _ = layout_fixture(disk="/dev/testdisk")
        table["device"] = "/dev/testdisk"
        tree = {"path": "/dev/testdisk", "type": "disk", "ro": read_only, "size": 80 * STORAGE.GIB,
                "serial": "fixture-serial", "wwn": "fixture-wwn", "mountpoints": [], "children": []}
        for item in table["partitions"]:
            tree["children"].append({"path": item["node"], "type": "part", "fstype": "vfat",
                                     "uuid": "1234-5678", "label": "Test", "mountpoints": ["/live"] if mounted else []})
        table["label"] = label
        commands = []
        def run(arguments):
            commands.append(arguments)
            if arguments[0] == "lsblk":
                if "--tree" in arguments:
                    return json.dumps({"blockdevices": [tree]})
                disk = {key: value for key, value in tree.items() if key != "children"}
                return json.dumps({"blockdevices": [disk, *tree["children"]]})
            if arguments[0] == "sfdisk":
                return json.dumps({"partitiontable": table})
            if arguments[0] == "sgdisk":
                return "No problems found." if verified else "Problem: damaged backup GPT"
            raise AssertionError(arguments)
        original_stat = STORAGE.os.stat
        original_read = Path.read_text
        def fake_stat(path, *args, **kwargs):
            if str(path) == "/dev/testdisk":
                return mock.Mock(st_mode=stat.S_IFBLK)
            return original_stat(path, *args, **kwargs)
        def read(path, *args, **kwargs):
            if str(path) == "/proc/swaps":
                return "Filename Type Size Used Priority\n" + ("/dev/testdisk1 partition 100 0 -2\n" if swap else "")
            return original_read(path, *args, **kwargs)
        with mock.patch.object(STORAGE, "command", side_effect=run), \
             mock.patch.object(STORAGE.os, "stat", side_effect=fake_stat), \
             mock.patch.object(Path, "read_text", read), \
             mock.patch.object(STORAGE, "partition_slots", return_value=128), \
             mock.patch.object(STORAGE, "firmware_state", return_value={"mode": "uefi", "secure_boot": False, "variables_writable": True}):
            return STORAGE.inspect("/dev/testdisk"), commands

    def test_discovery_is_read_only_and_records_stable_identity(self):
        layout, commands = self.inspect_fixture()
        self.assertEqual(layout["serial"], "fixture-serial")
        self.assertEqual(layout["blockers"], [])
        self.assertEqual(layout["fingerprint"], self.inspect_fixture()[0]["fingerprint"])
        self.assertEqual([item[:2] for item in commands], [["lsblk", "--json"], ["sfdisk", "--json"], ["sgdisk", "--verify"]])

    def test_discovery_requests_partition_hierarchy_without_name_column(self):
        layout, commands = self.inspect_fixture()
        self.assertIn("--tree", commands[0])
        self.assertEqual([part["number"] for part in layout["partitions"]], [1, 3])
        self.assertEqual(layout["free_extents"][-1]["start"], 44040192)

    def test_discovery_refuses_live_mounted_swap_readonly_and_bad_gpt_disks(self):
        for arguments in ({"mounted": True}, {"swap": True}, {"read_only": True},
                          {"label": "dos"}, {"verified": False}):
            with self.subTest(arguments=arguments), self.assertRaises(STORAGE.StorageError):
                self.inspect_fixture(**arguments)

    def test_backend_alongside_dry_run_never_calls_erase_commands(self):
        import re
        backend = (ROOT / "installer/spectrum-installer-backend").read_text()
        functions = "\n".join(re.search(r"^" + name + r"\(\) \{.*?^\}", backend, re.M | re.S)[0]
                              for name in ("partition_path", "install_system"))
        prelude = '''
set -eu
mode=plan
disk=/dev/nvme0n1
target=/tmp/spectrum-installer-dry-run-unused
install_mode=alongside
cpu_profile=intel
gpu_profile=vm
form_factor=desktop
lean=false
extent_start=44040192
size_gib=40
confirm_plan=
keep_boot_default=false
timezone=UTC
username=fixture
storage_plan=$TEST_STORAGE_PLAN
progress() { :; }
run() { printf '%s ' "$@"; printf '\\n'; }
collect_packages() { echo base; }
install_spectrum_repository() { :; }
install_aur_desktop_apps() { :; }
configure_keyboard() { :; }
configure_locales() { :; }
die() { echo "$*" >&2; exit 1; }
'''
        result = subprocess.run(["bash", "-c", prelude + functions + "\ninstall_system\n"],
                                env={**os.environ, "TEST_STORAGE_PLAN": json.dumps(planned())},
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("wipefs", result.stdout)
        self.assertNotIn("zap-all", result.stdout)
        self.assertIn("mkfs.btrfs --force --label SPECTRUM_ROOT /dev/nvme0n1p4", result.stdout)
        self.assertNotIn("mkfs.btrfs --force --label SPECTRUM_ROOT /dev/nvme0n1p3", result.stdout)

    def test_free_extents_exclude_partitions_and_gpt(self):
        for sector in (512, 4096):
            table, layout = layout_fixture(sector)
            for gap in layout["free_extents"]:
                self.assertEqual(gap["start"] * sector % STORAGE.MIB, 0)
                self.assertEqual((gap["end"] + 1) * sector % STORAGE.MIB, 0)
                self.assertGreaterEqual(gap["start"], table["firstlba"])
                self.assertLessEqual(gap["end"], table["lastlba"])
                for part in table["partitions"]:
                    self.assertTrue(gap["end"] < part["start"] or gap["start"] >= part["start"] + part["size"])

    def test_overlapping_or_out_of_bounds_tables_are_rejected(self):
        table, _ = layout_fixture()
        for start, size in ((100, -1), (2048, 100), (table["lastlba"], 100)):
            invalid = deepcopy(table)
            invalid["partitions"].append({"start": start, "size": size})
            with self.assertRaises(STORAGE.StorageError):
                STORAGE.aligned_extents(invalid)

    def test_unsupported_sector_size_is_rejected(self):
        table, _ = layout_fixture()
        table["sectorsize"] = 1024
        with self.assertRaises(STORAGE.StorageError):
            STORAGE.aligned_extents(table)

    def test_plan_uses_unused_numbers_and_preserves_original_records(self):
        _, layout = layout_fixture()
        plan = planned(layout)
        self.assertEqual([item["number"] for item in plan["create"]], [2, 4])
        self.assertEqual(plan["preserve"], layout["partitions"])
        self.assertEqual(plan["create"][0]["path"], "/dev/nvme0n1p2")
        self.assertEqual(plan["create"][1]["start"], plan["create"][0]["end"] + 1)
        self.assertEqual((plan["create"][0]["end"] - plan["create"][0]["start"] + 1) * 512, 2 * STORAGE.GIB)

    def test_plan_alignment_on_4kn_and_sata_names(self):
        plan = planned(layout_fixture(4096, "/dev/sda")[1])
        self.assertEqual(plan["create"][0]["path"], "/dev/sda2")
        for item in plan["create"]:
            self.assertEqual(item["start"] * 4096 % STORAGE.MIB, 0)
            self.assertEqual((item["end"] + 1) * 4096 % STORAGE.MIB, 0)

    def test_insufficient_space_and_unknown_extent_are_rejected(self):
        _, layout = layout_fixture()
        for start, amount in ((layout["free_extents"][-1]["start"], 33),
                              (layout["free_extents"][-1]["start"], 100), (123, 40)):
            with self.assertRaises(STORAGE.StorageError):
                STORAGE.make_plan(layout, start, amount)

    def test_firmware_blockers_prevent_planning(self):
        for blocker in ("BIOS", "Secure Boot", "firmware read-only", "partition slots"):
            _, layout = layout_fixture()
            layout["blockers"] = [blocker]
            with self.assertRaisesRegex(STORAGE.StorageError, blocker):
                planned(layout)

    def test_limited_partition_table_cannot_allocate_nonexistent_slots(self):
        _, layout = layout_fixture()
        layout["partition_slots"] = 3
        with self.assertRaisesRegex(STORAGE.StorageError, "slots"):
            planned(layout)

    def test_confirmation_changes_with_geometry_identity_and_boot_choice(self):
        _, layout = layout_fixture()
        plan = planned(layout)
        self.assertEqual(plan, planned(layout))
        changed = STORAGE.make_plan(layout, plan["extent_start"], 41)
        self.assertNotEqual(plan["confirmation"], changed["confirmation"])
        changed = STORAGE.make_plan(layout, plan["extent_start"], 40, False)
        self.assertNotEqual(plan["confirmation"], changed["confirmation"])
        layout["fingerprint"] = "different disk identity"
        self.assertNotEqual(plan["confirmation"], planned(layout)["confirmation"])

    def test_commands_never_erase_the_disk_or_existing_partitions(self):
        plan = planned()
        commands = STORAGE.partition_commands(plan)
        self.assertEqual([item[0] for item in commands], ["sgdisk", "partprobe"])
        rendered = " ".join(" ".join(item) for item in commands)
        self.assertNotIn("zap", rendered)
        self.assertNotIn("wipefs", rendered)
        self.assertNotIn("--delete", rendered)
        self.assertNotIn("--new=1:", rendered)
        self.assertNotIn("--new=3:", rendered)

    def test_wait_targets_only_planned_partition_identities(self):
        plan = planned()
        paths = {f"/dev/disk/by-partuuid/{part['partuuid']}": part['path'] for part in plan['create']}
        with mock.patch.object(STORAGE, "command", return_value="") as command, \
             mock.patch.object(Path, "is_block_device", return_value=True), \
             mock.patch.object(STORAGE.os.path, "realpath", side_effect=lambda path: paths.get(path, path)):
            STORAGE.wait_for_partitions(plan)
        command.assert_called_once_with(
            ["udevadm", "wait", "--initialized=yes", "--timeout=60", *paths], timeout=65)

    def test_wait_timeout_keeps_formatting_blocked_and_explains_partial_allocation(self):
        for error in (subprocess.TimeoutExpired(["udevadm", "wait"], 65),
                      STORAGE.StorageError("Device initialization timed out")):
            with self.subTest(error=error), \
                 mock.patch.object(STORAGE, "command", side_effect=error):
                with self.assertRaisesRegex(STORAGE.StorageError, "may already exist.*No filesystems were formatted"):
                    STORAGE.wait_for_partitions(planned())

    def test_wait_rejects_missing_or_misdirected_partition_links(self):
        for exists in (False, True):
            with self.subTest(exists=exists), \
                 mock.patch.object(STORAGE, "command", return_value=""), \
                 mock.patch.object(Path, "is_block_device", return_value=exists), \
                 mock.patch.object(STORAGE.os.path, "realpath", side_effect=lambda path: path):
                with self.assertRaisesRegex(STORAGE.StorageError, "identity.*refusing to format"):
                    STORAGE.wait_for_partitions(planned())

    def test_partition_apply_waits_before_verifying_preservation(self):
        plan = planned()
        backup = mock.MagicMock(spec=Path)
        backup.is_symlink.return_value = False
        backup.is_dir.return_value = True
        backup.stat.return_value = mock.Mock(st_uid=0, st_mode=0o40700)
        order = []
        opened = mock.mock_open()
        opened.return_value.__exit__.side_effect = lambda *_: order.append("close")
        def inspect(disk):
            order.append("inspect")
            return layout_fixture()[1] if len(order) == 1 else after_layout(plan)
        with mock.patch.object(STORAGE.os, "geteuid", return_value=0), \
             mock.patch("builtins.open", opened), \
             mock.patch.object(STORAGE.fcntl, "flock"), \
             mock.patch.object(STORAGE, "inspect", side_effect=inspect), \
             mock.patch.object(STORAGE, "command", return_value=""), \
             mock.patch.object(STORAGE, "wait_for_partitions", side_effect=lambda value: order.append("wait")), \
             mock.patch.object(STORAGE, "assert_created", wraps=STORAGE.assert_created) as verify:
            STORAGE.apply_partitions(plan, backup)
        self.assertEqual(order, ["inspect", "close", "wait", "inspect"])
        opened.assert_called_once_with(plan["disk"], "r+b")
        verify.assert_called_once()

    def test_partition_apply_cannot_continue_after_wait_failure(self):
        plan = planned()
        backup = mock.MagicMock(spec=Path)
        backup.is_symlink.return_value = False
        backup.is_dir.return_value = True
        backup.stat.return_value = mock.Mock(st_uid=0, st_mode=0o40700)
        with mock.patch.object(STORAGE.os, "geteuid", return_value=0), \
             mock.patch("builtins.open", mock.mock_open()), \
             mock.patch.object(STORAGE.fcntl, "flock"), \
             mock.patch.object(STORAGE, "inspect", return_value=layout_fixture()[1]) as inspect, \
             mock.patch.object(STORAGE, "command", return_value=""), \
             mock.patch.object(STORAGE, "wait_for_partitions", side_effect=STORAGE.StorageError("not ready")), \
             mock.patch.object(STORAGE, "assert_created") as verify:
            with self.assertRaisesRegex(STORAGE.StorageError, "not ready"):
                STORAGE.apply_partitions(plan, backup)
        self.assertEqual(inspect.call_count, 1)
        verify.assert_not_called()

    def test_verification_rejects_changes_to_preserved_partitions(self):
        plan = planned()
        STORAGE.assert_created(plan, after_layout(plan))
        for key, value in (("start", 999), ("size", 999), ("uuid", "changed"),
                           ("partuuid", "changed"), ("attributes", "changed"), ("type", "changed")):
            after = after_layout(plan)
            after["partitions"][0][key] = value
            with self.assertRaises(STORAGE.StorageError):
                STORAGE.assert_created(plan, after)

    def test_verification_rejects_extra_missing_or_wrong_new_partitions(self):
        plan = planned()
        for change in ("missing", "extra", "geometry"):
            after = after_layout(plan)
            if change == "missing":
                after["partitions"].pop()
            elif change == "extra":
                after["partitions"].append({"number": 99})
            else:
                after["partitions"][-1]["start"] += 1
            with self.assertRaises(STORAGE.StorageError):
                STORAGE.assert_created(plan, after)

    def test_stale_plan_is_rejected_before_any_write(self):
        plan = planned()
        changed = layout_fixture()[1]
        changed["fingerprint"] = "changed"
        with mock.patch.object(STORAGE.os, "geteuid", return_value=0), \
             mock.patch("builtins.open", mock.mock_open()), \
             mock.patch.object(STORAGE.fcntl, "flock"), \
             mock.patch.object(STORAGE, "inspect", return_value=changed), \
             mock.patch.object(STORAGE, "command") as command:
            with self.assertRaisesRegex(STORAGE.StorageError, "changed"):
                STORAGE.apply_partitions(plan, Path("/tmp"))
            command.assert_not_called()

    def test_partition_action_needs_exact_confirmation_and_backup(self):
        layout = layout_fixture()[1]
        args = ["storage", "partition", "--disk", layout["disk"], "--extent-start",
                str(layout["free_extents"][-1]["start"]), "--size-gib", "40"]
        with mock.patch.object(STORAGE, "inspect", return_value=layout), \
             mock.patch.object(STORAGE, "apply_partitions") as apply:
            for suffix in ([], ["--confirm-plan", "wrong", "--backup", "/tmp"]):
                with mock.patch.object(STORAGE.sys, "argv", args + suffix):
                    self.assertEqual(STORAGE.main(), 1)
            apply.assert_not_called()

    def test_boot_registration_preserves_entries_and_order(self):
        for default, expected in ((True, "000A,0001,0002"), (False, "0001,0002,000A")):
            before = "BootOrder: 0001,0002\nBoot0001* Windows\nBoot0002* Linux\n"
            after = before + "Boot000A* SpectrumOS\n"
            final = after.replace("BootOrder: 0001,0002", "BootOrder: " + expected)
            with mock.patch.object(STORAGE.os, "geteuid", return_value=0), \
                 mock.patch.object(STORAGE, "command", side_effect=["aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\n", before, "", after, "", final]) as command:
                STORAGE.register_boot("/dev/sda", 4, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", default)
            calls = [item.args[0] for item in command.call_args_list]
            self.assertIn(["efibootmgr", "--bootorder", expected], calls)
            self.assertIn("--create-only", calls[2])
            self.assertFalse(any("--delete-bootnum" in item for item in calls))

    def test_wrong_boot_partition_prevents_firmware_writes(self):
        with mock.patch.object(STORAGE.os, "geteuid", return_value=0), \
             mock.patch.object(STORAGE, "command", return_value="wrong") as command:
            with self.assertRaises(STORAGE.StorageError):
                STORAGE.register_boot("/dev/sda", 4, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", True)
            self.assertEqual(command.call_count, 1)

    def test_boot_repair_reuses_the_same_partition_entry_without_reordering(self):
        partuuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        firmware = ("BootOrder: 0001,000A\nBoot0001* Windows\n"
                    f"Boot000A* SpectrumOS HD(4,GPT,{partuuid},0x1000,0x2000)/\\EFI\\SpectrumOS\\limine.efi\n")
        with mock.patch.object(STORAGE.os, "geteuid", return_value=0), \
             mock.patch.object(STORAGE, "command", side_effect=[partuuid, firmware, firmware]) as command:
            STORAGE.register_boot("/dev/sda", 4, partuuid, False)
        self.assertEqual(command.call_count, 3)
        self.assertFalse(any("--create-only" in call.args[0] or "--bootorder" in call.args[0] for call in command.call_args_list))

    def test_real_gpt_image_preserves_windows_linux_partition_records_and_data(self):
        with tempfile.TemporaryDirectory(prefix="spectrum-gpt-test-") as temporary:
            image = Path(temporary) / "disposable.img"
            with image.open("wb") as handle:
                handle.truncate(80 * STORAGE.GIB)
            subprocess.run(["sgdisk", "--clear", "--new=1:2048:+512MiB", "--typecode=1:ef00",
                            "--new=3:0:+20GiB", "--typecode=3:0700", "--attributes=3:set:62",
                            "--new=6:0:+4GiB", "--typecode=6:8300", str(image)],
                           check=True, capture_output=True)
            table = json.loads(subprocess.check_output(["sfdisk", "--json", str(image)], text=True))["partitiontable"]
            self.assertEqual(STORAGE.partition_slots(str(image), 512), 128)
            _, layout = layout_fixture(disk=str(image))
            layout["disk_guid"] = table["id"]
            layout["free_extents"] = STORAGE.aligned_extents(table)
            layout["partitions"] = [{"number": int(item["node"].removeprefix(str(image))), **item} for item in table["partitions"]]
            samples = []
            with image.open("r+b") as handle:
                for part in table["partitions"]:
                    position = part["start"] * 512
                    value = os.urandom(4096)
                    handle.seek(position)
                    handle.write(value)
                    samples.append((position, value))
            plan = planned(layout)
            subprocess.run(STORAGE.partition_commands(plan)[0], check=True, capture_output=True)
            after = json.loads(subprocess.check_output(["sfdisk", "--json", str(image)], text=True))["partitiontable"]
            self.assertEqual(table["id"], after["id"])
            for part in table["partitions"]:
                self.assertIn(part, after["partitions"])
            self.assertEqual(len(after["partitions"]), len(table["partitions"]) + 2)
            with image.open("rb") as handle:
                for position, value in samples:
                    handle.seek(position)
                    self.assertEqual(handle.read(len(value)), value)
            self.assertIn("No problems found.", subprocess.check_output(["sgdisk", "--verify", str(image)], text=True))


if __name__ == "__main__":
    unittest.main()
