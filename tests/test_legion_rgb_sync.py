from importlib.machinery import SourceFileLoader
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_module():
    loader = SourceFileLoader('legion_rgb_sync', str(ROOT / 'scripts/legion-rgb-sync'))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class LegionRGBTests(unittest.TestCase):
    def test_detection_requires_exact_model_controller_and_usage_page(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            module.DMI = root / 'dmi'
            module.HIDRAW = root / 'hidraw'
            module.DEV = root / 'dev'
            module.DMI.mkdir()
            for name, value in [('sys_vendor', 'LENOVO'), ('product_name', '83F5'),
                                ('product_version', 'Legion Pro 7 16IAX10H')]:
                (module.DMI / name).write_text(value + '\n')
            node = module.HIDRAW / 'hidraw3/device'
            node.mkdir(parents=True)
            (node / 'uevent').write_text('HID_ID=0003:0000048D:0000C197\n')
            (node / 'report_descriptor').write_bytes(b'\x06\x89\xff')
            self.assertEqual(module.device(), module.DEV / 'hidraw3')
            (module.DMI / 'product_name').write_text('83RU')
            self.assertIsNone(module.device())
            (module.DMI / 'product_name').write_text('83F5')
            (node / 'uevent').write_text('HID_ID=0003:0000048D:0000C193\n')
            self.assertIsNone(module.device())
            (node / 'uevent').write_text('HID_ID=0003:0000048D:0000C197\n')
            (node / 'report_descriptor').write_bytes(b'\x06\x00\xff')
            self.assertIsNone(module.device())

    def test_report_decodes_to_three_complete_zones_and_exact_palette(self):
        module = load_module()
        data = module.report(1, bytes.fromhex('39b6ff'), bytes.fromhex('00aaf1'))
        self.assertEqual(len(data), 960)
        self.assertEqual(data[:7], bytes.fromhex('07 cb 45 03 01 01 01'))
        offset = 7
        for number, color, count, expected in [
            (1, '39b6ff', 101, set(module.KEYBOARD)),
            (2, '00aaf1', 28, set(range(1001, 1019)) | set(range(501, 511))),
            (3, '39b6ff', 1, {1501}),
        ]:
            self.assertEqual(data[offset:offset + 15], bytes([number]) + bytes.fromhex('06 01 0b 02 00 03 00 04 00 05 02 06 00 01'))
            self.assertEqual(data[offset + 15:offset + 18].hex(), color)
            self.assertEqual(data[offset + 18], count)
            keys = struct.unpack_from('<' + 'H' * count, data, offset + 19)
            self.assertEqual(set(keys), expected)
            offset += 19 + 2 * count
        self.assertEqual(offset, 324)
        self.assertEqual(data[offset:], bytes(960 - offset))

    def test_apply_reads_latest_palette_under_lock_and_only_changes_effects(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            module.CACHE = root / 'cache'
            module.CONFIG = root / 'config'
            module.CURRENT = root / 'current'
            module.CURRENT.mkdir()
            palette = module.CURRENT / 'palette.json'
            palette.write_text(json.dumps({'roles': {'accent': '#ff0000', 'accent_alt': '#00ff00'}}))
            device = root / 'hidraw3'
            device.touch()
            def locked(*args):
                palette.write_text(json.dumps({'roles': {'accent': '#39b6ff', 'accent_alt': '#00aaf1'}}))
            def ioctl(handle, operation, buffer):
                if operation == (0xC0004807 | (960 << 16)):
                    buffer[4] = 4
            with mock.patch.object(module, 'device', return_value=device), \
                    mock.patch.object(module.fcntl, 'flock', side_effect=locked), \
                    mock.patch.object(module.fcntl, 'ioctl', side_effect=ioctl) as usb:
                self.assertTrue(module.apply())
            writes = [bytes(c.args[2]) for c in usb.call_args_list if c.args[1] == (0xC0004806 | (960 << 16))]
            self.assertEqual([p[1] for p in writes], [0xca, 0xcb])
            self.assertEqual(writes[-1], module.report(4, bytes.fromhex('39b6ff'), bytes.fromhex('00aaf1')))

    def test_non_target_and_opt_out_do_not_read_palette_or_open_hardware(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            module.CONFIG = Path(temporary)
            with mock.patch.object(module, 'device', return_value=None), \
                    mock.patch.object(module, 'palette_colors') as palette:
                self.assertFalse(module.apply())
                palette.assert_not_called()
            disabled = module.CONFIG / 'spectrumos/legion-rgb.disabled'
            disabled.parent.mkdir()
            disabled.touch()
            with mock.patch.object(module, 'device') as device:
                self.assertFalse(module.apply())
                device.assert_not_called()

    def test_invalid_palette_never_writes_to_controller(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            module.CACHE = root
            module.CONFIG = root
            module.CURRENT = root
            (root / 'palette.json').write_text('{"roles":{"accent":"#oops","accent_alt":"#123456"}}')
            with mock.patch.object(module, 'device', return_value=root / 'missing'), \
                    mock.patch.object(module, 'set_feature') as write:
                with self.assertRaises(ValueError):
                    module.apply()
                write.assert_not_called()

    def test_appearance_sync_is_bounded_and_nonfatal(self):
        loader = SourceFileLoader('appearance_rgb_test', str(ROOT / 'scripts/appearance-sync'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        for result in [PermissionError('device inaccessible'), module.subprocess.TimeoutExpired('rgb', 3),
                       mock.Mock(returncode=1, stderr='device failed')]:
            with self.subTest(result=result), mock.patch.object(module.subprocess, 'run') as run, \
                    mock.patch('sys.stderr'):
                if isinstance(result, Exception):
                    run.side_effect = result
                else:
                    run.return_value = result
                module.sync_legion_rgb()
                self.assertEqual(run.call_args.kwargs['timeout'], 3)


if __name__ == '__main__':
    unittest.main()
