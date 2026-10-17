import importlib.util
import os
import subprocess
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FORK = ROOT / 'integrations/spectrumdrop'
spec = importlib.util.spec_from_file_location('spectrumdrop_migration', FORK / 'runtime/bin/migrate.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class NativePackagingTests(unittest.TestCase):
    def test_desktop_uses_maintained_source_without_external_drop_packages(self):
        recipe = (ROOT / 'packages/spectrum-desktop/PKGBUILD').read_text()
        self.assertIn('spectrumdrop acl', recipe)
        self.assertNotIn("'omdrop:", recipe)
        self.assertNotIn("'omdrop-owl:", recipe)
        adapter = (ROOT / 'scripts/spectrumdrop-adapter').read_text()
        self.assertIn("CLI = '/usr/bin/spectrumdrop'", adapter)
        self.assertNotIn('/usr/bin/omdrop', adapter)
        native = (ROOT / 'packages/spectrumdrop/PKGBUILD').read_text()
        self.assertNotIn('github.com', native)
        self.assertIn('integrations/spectrumdrop/build', native)
        cli = (FORK / 'runtime/bin/spectrumdrop').read_text()
        self.assertNotIn('git clone', cli)
        self.assertNotIn('pacman -S', cli)
        self.assertNotIn('skills_install()', cli)



class NativeSpectrumDropTests(unittest.TestCase):
    def test_migration_preserves_identity_and_settings_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            config = home / '.config'
            old = home / '.omdrop/keys'
            old.mkdir(parents=True)
            (old / 'key.pem').write_bytes(b'test private key')
            (old / 'certificate.pem').write_bytes(b'test certificate')
            (config / 'omdrop').mkdir(parents=True)
            (config / 'omdrop/settings').write_text('sound=off\n')
            (config / 'airdrop').mkdir()
            (config / 'airdrop/config.toml').write_text('name = "Spectrum"\n')
            migration.migrate(home, config)
            target = home / '.spectrumdrop/keys/key.pem'
            self.assertEqual(target.read_bytes(), (old / 'key.pem').read_bytes())
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            self.assertEqual((config / 'spectrumdrop/receiver.toml').read_text(), 'name = "Spectrum"\n')
            (config / 'spectrumdrop/settings').write_text('sound=on\n')
            migration.migrate(home, config)
            self.assertEqual((config / 'spectrumdrop/settings').read_text(), 'sound=on\n')
            self.assertTrue((old / 'key.pem').exists())

    def test_symlinked_identity_is_rejected_without_publishing_partial_keys(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            old = home / '.omdrop/keys'
            old.mkdir(parents=True)
            (old / 'key.pem').symlink_to(home / 'outside')
            with self.assertRaises(ValueError):
                migration.migrate(home, home / '.config')
            self.assertFalse((home / '.spectrumdrop/keys').exists())

    def test_radio_privilege_targets_only_owned_spectrumdrop_helper(self):
        policy = (FORK / 'packaging/org.spectrumos.spectrumdrop.policy').read_text()
        self.assertIn('/usr/lib/spectrumos/spectrumdrop/radio/spectrumdrop-radio', policy)
        self.assertIn('<allow_inactive>auth_admin</allow_inactive>', policy)
        self.assertIn('<allow_any>auth_admin</allow_any>', policy)
        self.assertIn('<allow_active>yes</allow_active>', policy)
        self.assertNotIn('/usr/lib/omdrop', policy)

    def test_inactive_legacy_state_does_not_touch_radio_interfaces(self):
        source = (FORK / 'runtime/radio/spectrumdrop-radio').read_text()
        body = source.split('  cleanup-legacy)\n', 1)[1].split('  __supervise)', 1)[0].rsplit(';;', 1)[0]
        with tempfile.TemporaryDirectory() as temporary:
            state = Path(temporary)
            body = body.replace('/run/omdrop-owl', str(state))
            prefix = 'need_root() { :; }; stat() { echo 0; }; pid_of() { echo 99999; }; cmd_stop() { echo cleanup; }; '
            for active, residual, expected in ((False, False, ''), (True, False, 'cleanup'), (False, True, 'cleanup')):
                if residual:
                    (state / 'exclusive').write_text('wlan0')
                script = prefix + 'alive() { return ' + ('0' if active else '1') + '; };\n' + body
                result = subprocess.run(['bash', '-c', script], capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout.strip(), expected)

    def test_legacy_link_associations_migrate_without_replacing_custom_choices(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            config = home / '.config'
            config.mkdir()
            path = config / 'mimeapps.list'
            path.write_text('[Default Applications]\napplication/x-mswinurl=netmojo.omdrop-links.desktop;browser.desktop;\n'
                            'application/x-webloc=custom.desktop;\nimage/png=viewer.desktop;\n')
            migration.migrate(home, config)
            self.assertEqual(path.read_text(), '[Default Applications]\n'
                             'application/x-mswinurl=netmojo.spectrumdrop-links.desktop;browser.desktop;\n'
                             'application/x-webloc=custom.desktop;\nimage/png=viewer.desktop;\n')
