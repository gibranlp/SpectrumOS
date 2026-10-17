import json
import os
import pwd
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/spectrum-user-avatar'
FACE = ROOT / 'configs/spectrum-shell/igor/face.svg'


class UserAvatarTests(unittest.TestCase):
    def run_avatar(self, picture, face=FACE):
        return subprocess.run([str(SCRIPT), str(face), str(picture)], capture_output=True, text=True)

    def test_generates_square_transparent_png_and_cleans_staging(self):
        with tempfile.TemporaryDirectory() as directory:
            picture = Path(directory) / 'newuser.png'
            result = self.run_avatar(picture)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(picture.read_bytes()[:8], b'\x89PNG\r\n\x1a\n')
            probe = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(picture)],
                                   capture_output=True, text=True, check=True)
            stream = json.loads(probe.stdout)['streams'][0]
            self.assertEqual((stream['width'], stream['height']), (512, 512))
            self.assertIn(stream['pix_fmt'], ('rgba', 'bgra'))
            self.assertEqual(picture.stat().st_uid, os.getuid())
            self.assertEqual(picture.stat().st_mode & 0o777, 0o644)
            self.assertEqual(list(Path(directory).iterdir()), [picture])

    def test_preserves_existing_custom_picture_on_repeated_setup(self):
        with tempfile.TemporaryDirectory() as directory:
            picture = Path(directory) / 'newuser.png'
            picture.write_bytes(b'custom user picture')
            before = picture.stat().st_mtime_ns
            result = self.run_avatar(picture, Path(directory) / 'missing.svg')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(picture.read_bytes(), b'custom user picture')
            self.assertEqual(picture.stat().st_mtime_ns, before)

    def test_preserves_dangling_user_picture_link(self):
        with tempfile.TemporaryDirectory() as directory:
            picture = Path(directory) / 'newuser.png'
            picture.symlink_to('personal-photo.png')
            result = self.run_avatar(picture)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(picture.is_symlink())
            self.assertEqual(os.readlink(picture), 'personal-photo.png')

    def test_failed_render_does_not_publish_partial_picture(self):
        with tempfile.TemporaryDirectory() as directory:
            picture = Path(directory) / 'newuser.png'
            result = self.run_avatar(picture, Path(directory) / 'missing.svg')
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_full_and_lean_user_setup_generate_avatar_before_theme(self):
        for extra in ([], ['--lean']):
            result = subprocess.run(['bash', str(ROOT / 'install.sh'), '--phase', 'user,theme', '--target-user', pwd.getpwuid(os.getuid()).pw_name, *extra],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('/usr/lib/spectrumos/spectrum-user-avatar', result.stdout)
            self.assertIn('/usr/share/spectrumos/spectrum-shell/igor/face.svg', result.stdout)
            self.assertLess(result.stdout.index('/usr/lib/spectrumos/spectrum-user-avatar'),
                            result.stdout.index('/usr/lib/spectrumos/appearance-stage'))
