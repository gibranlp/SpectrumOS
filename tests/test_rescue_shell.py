from pathlib import Path
import ast
import os
import subprocess
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
GUIDE = ROOT / 'installer/spectrum-rescue-shell'


class RescueShellTests(unittest.TestCase):
    def run_guide(self, *arguments, commands=''):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            marker = target / 'unexpected-action'
            for name in ('sudo', 'mount', 'umount', 'arch-chroot', 'pacman', 'mkinitcpio', 'spectrum-recovery', 'reboot'):
                tool = target / name
                tool.write_text('#!/bin/sh\ntouch "$RESCUE_TEST_ACTION"\nexit 93\n')
                tool.chmod(0o755)
            result = subprocess.run(
                [str(GUIDE), *arguments], input=commands, text=True, capture_output=True,
                timeout=5, env=dict(os.environ, HOME=str(target), PATH=str(target) + os.pathsep + os.environ['PATH'],
                                    RESCUE_TEST_ACTION=str(marker)))
            self.assertFalse(marker.exists(), 'Opening the guide must not run privileged recovery actions')
            return result

    def test_guide_prints_instructions_without_starting_repairs(self):
        result = self.run_guide('--guide')
        self.assertEqual(result.returncode, 0, result.stderr)
        for instruction in ('lsblk -f', 'nmtui', 'spectrum-recovery', 'arch-chroot', 'mkinitcpio -P',
                            'findmnt -R /mnt/spectrumos', 'repartitions the destination'):
            self.assertIn(instruction, result.stdout)
        self.assertEqual(result.stderr, '')

    def test_default_opens_an_ordinary_shell_after_the_guide(self):
        result = self.run_guide(commands="printf 'RESCUE_INTERACTIVE_READY\\n'\nprintf 'RESCUE_UID='; id -u\nexit\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('RESCUE_INTERACTIVE_READY', result.stdout)
        self.assertLess(result.stdout.index('SpectrumOS rescue system'), result.stdout.index('RESCUE_INTERACTIVE_READY'))
        self.assertIn('RESCUE_UID=' + str(os.getuid()) + '\n', result.stdout)

    def test_unknown_options_do_not_open_a_shell(self):
        result = self.run_guide('--repair')
        self.assertEqual(result.returncode, 2)
        self.assertIn('Usage:', result.stderr)

    def test_iso_installs_guide_as_default_live_terminal_shell(self):
        builder = (ROOT / 'scripts/build-iso').read_text()
        profile = (ROOT / 'iso/spectrumos/profiledef.sh').read_text()
        config = (ROOT / 'installer/live-foot.ini').read_text()
        self.assertIn('shell=/usr/local/bin/spectrum-rescue-shell\n', config)
        self.assertIn('[colors-dark]', config)
        self.assertNotIn('[colors]', config)
        self.assertIn('"$project_root/installer/spectrum-rescue-shell"', builder)
        self.assertIn('"$staging/airootfs/usr/local/bin/spectrum-rescue-shell"', builder)
        self.assertIn('"$staging/airootfs/etc/xdg/foot/foot.ini"', builder)
        self.assertIn('["/usr/local/bin/spectrum-rescue-shell"]="0:0:755"', profile)
        self.assertTrue(os.access(GUIDE, os.X_OK))

    def rescue_method(self):
        tree = ast.parse((ROOT / 'installer/spectrum-installer').read_text())
        klass = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == 'SpectrumInstaller')
        method = next(node for node in klass.body if isinstance(node, ast.FunctionDef) and node.name == 'open_rescue')
        dialog = Mock()
        namespace = dict(subprocess=subprocess, Gtk=types.SimpleNamespace(AlertDialog=dialog))
        exec(compile(ast.Module(body=[method], type_ignores=[]), '<installer rescue method>', 'exec'), namespace)
        return namespace['open_rescue'], dialog

    def test_button_launches_terminal_guide_without_installer_backend(self):
        method, dialog = self.rescue_method()
        with patch.object(subprocess, 'Popen') as launch:
            method(types.SimpleNamespace(window=Mock()), None)
        launch.assert_called_once_with(['uwsm', 'app', '--', 'foot', '--title=Rescue system', '-e', '/usr/local/bin/spectrum-rescue-shell'])
        dialog.assert_not_called()

    def test_terminal_launch_error_is_reported(self):
        method, dialog = self.rescue_method()
        window = Mock()
        with patch.object(subprocess, 'Popen', side_effect=FileNotFoundError('terminal launcher unavailable')):
            method(types.SimpleNamespace(window=window), None)
        dialog.assert_called_once_with(message='Could not open the rescue terminal', detail='terminal launcher unavailable')
        dialog.return_value.show.assert_called_once_with(window)


if __name__ == '__main__':
    unittest.main()
