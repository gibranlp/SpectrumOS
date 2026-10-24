from importlib.machinery import SourceFileLoader
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_module():
    loader = SourceFileLoader('keychron_rgb_sync', str(ROOT / 'scripts/keychron-rgb-sync'))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class KeychronRGBTests(unittest.TestCase):
    def test_detection_excludes_keyboard_input_and_other_models(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            module.HIDRAW = Path(temporary)
            for index, pid, descriptor in [(0, '01E0', b'keyboard'), (1, '01E0', module.RAW_DESCRIPTOR), (2, '01E1', module.RAW_DESCRIPTOR)]:
                device = module.HIDRAW / f'hidraw{index}' / 'device'
                device.mkdir(parents=True)
                (device / 'uevent').write_text(f'HID_ID=0003:00003434:0000{pid}\n')
                (device / 'report_descriptor').write_bytes(descriptor)
            self.assertEqual(module.devices(), [Path('/dev/hidraw1')])

    def test_apply_preserves_brightness_and_off_state_without_saving(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            module.CACHE = module.CONFIG = Path(temporary)
            module.CURRENT = Path(temporary) / 'current'
            module.CURRENT.mkdir()
            (module.CURRENT / 'palette.json').write_text(json.dumps({'roles': {'accent': '#00ff00'}}))
            for effect in (0, 1, 4):
                with self.subTest(effect=effect), mock.patch.object(module, 'devices', return_value=[Path('/dev/fake')]), mock.patch.object(module.os, 'open', return_value=42), mock.patch.object(module.os, 'close'), mock.patch.object(module, 'state', return_value={'effect': effect, 'hue': 0, 'saturation': 0}), mock.patch.object(module, 'command') as command:
                    self.assertTrue(module.apply())
                    payloads = [call.args[1] for call in command.call_args_list]
                    self.assertEqual(payloads, [bytes([7, 3, 4, 85, 255])] + ([bytes([7, 3, 2, 1])] if effect == 4 else []))
            (module.CONFIG / 'spectrumos').mkdir(exist_ok=True)
            (module.CONFIG / 'spectrumos/keychron-rgb.disabled').touch()
            with mock.patch.object(module, 'devices') as devices:
                self.assertFalse(module.apply())
                devices.assert_not_called()

    def test_protocol_validation_precedes_lighting_queries(self):
        module = load_module()
        with mock.patch.object(module, 'command', return_value=bytes([1, 0, 9]) + bytes(29)) as command:
            with self.assertRaisesRegex(ValueError, 'protocol'):
                module.state(42)
            command.assert_called_once_with(42, b'\x01')

    def test_hid_framing_and_response_validation(self):
        module = load_module()
        payload = bytes([8, 3, 4])
        response = payload + bytes([85, 255]) + bytes(27)
        with mock.patch.object(module.os, 'write') as write, mock.patch.object(module.select, 'select', return_value=([42], [], [])), mock.patch.object(module.os, 'read', return_value=response):
            self.assertEqual(module.command(42, payload), response)
            write.assert_called_once_with(42, b'\0' + payload + bytes(29))
        with mock.patch.object(module.os, 'write'), mock.patch.object(module.select, 'select', return_value=([], [], [])):
            with self.assertRaises(TimeoutError):
                module.command(42, payload)
        with mock.patch.object(module.os, 'write'), mock.patch.object(module.select, 'select', return_value=([42], [], [])), mock.patch.object(module.os, 'read', return_value=b'\xff' + bytes(31)):
            with self.assertRaisesRegex(ValueError, 'does not support'):
                module.command(42, payload)


if __name__ == '__main__':
    unittest.main()
