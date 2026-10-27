import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('session_profile', str(ROOT / 'scripts/spectrum-session-profile'))
spec = importlib.util.spec_from_loader(loader.name, loader)
PROFILE = importlib.util.module_from_spec(spec)
loader.exec_module(PROFILE)


class LeanSessionTests(unittest.TestCase):
    def test_fresh_lean_defaults_reduce_background_work(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            PROFILE.seed(home, 'lean')
            settings = json.loads((home / '.config/spectrumos/shell.json').read_text())
            self.assertFalse(settings['igor_enabled'])
            self.assertFalse(settings['widget_bounce_enabled'])
            self.assertEqual(settings['bar_profile'], 'standard')
            self.assertEqual((home / '.config/spectrumos/session-profile').read_text(), 'lean\n')
            self.assertIn('MemoryMax=1G', (home / '.config/systemd/user/spectrum-shell.service.d/50-spectrum-lean.conf').read_text())
            for name in PROFILE.AUTOSTART:
                self.assertIn('Hidden=true', (home / '.config/autostart' / name).read_text())

    def test_existing_personal_preferences_and_overrides_are_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            config = home / '.config'
            (config / 'spectrumos').mkdir(parents=True)
            original = {'bar_profile': 'detailed', 'igor_enabled': True, 'custom': 'keep'}
            (config / 'spectrumos/shell.json').write_text(json.dumps(original))
            (config / 'autostart').mkdir()
            override = config / 'autostart/blueman.desktop'
            override.write_text('[Desktop Entry]\nHidden=false\n')
            PROFILE.seed(home, 'lean')
            saved = json.loads((config / 'spectrumos/shell.json').read_text())
            for key, value in original.items():
                self.assertEqual(saved[key], value)
            self.assertEqual(override.read_text(), '[Desktop Entry]\nHidden=false\n')

    def test_full_reseed_removes_only_unchanged_managed_overrides(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            PROFILE.seed(home, 'lean')
            custom = home / '.config/autostart/blueman.desktop'
            custom.write_text('[Desktop Entry]\nHidden=true\nName=Personal\n')
            PROFILE.seed(home, 'full')
            self.assertTrue(custom.exists())
            self.assertFalse((home / '.config/autostart/baloo_file.desktop').exists())
            self.assertFalse((home / '.config/systemd/user/spectrum-shell.service.d/50-spectrum-lean.conf').exists())
            self.assertEqual((home / '.config/spectrumos/session-profile').read_text(), 'full\n')

    def test_bootstrap_and_live_installer_keep_core_apps_across_hardware_profiles(self):
        source = (ROOT / 'installer/spectrum-installer-backend').read_text()
        function = source.split('collect_packages() {', 1)[1].split('\ninstall_spectrum_repository()', 1)[0]
        excluded = set((ROOT / 'bootstrap/packages/desktop-lean-exclude.txt').read_text().splitlines())
        for cpu in ('amd', 'intel'):
            for gpu in ('amd', 'intel', 'nvidia', 'nvidia-intel', 'nvidia-amd', 'vm'):
                for form in ('laptop', 'desktop'):
                    for lean in ('true', 'false'):
                        with self.subTest(cpu=cpu, gpu=gpu, form=form, lean=lean):
                            result = subprocess.run(['bash', '-c', 'set -euo pipefail\ncollect_packages() {' + function + '\ncollect_packages'],
                                env={**os.environ, 'project_root': str(ROOT), 'cpu_profile': cpu, 'gpu_profile': gpu, 'form_factor': form, 'lean': lean},
                                capture_output=True, text=True, check=True)
                            packages = set(result.stdout.splitlines())
                            self.assertTrue({'hyprland', 'pipewire', 'wireplumber', 'networkmanager', 'evolution', 'kdeconnect', 'gnome-keyring', 'quickshell'} <= packages)
                            if lean == 'true':
                                self.assertFalse(excluded & packages)
                            self.assertNotIn('ukvm', packages)
                            self.assertNotIn('spectrum-xdg-desktop-portal-hyprland', packages)

    def test_failed_package_selection_aborts_before_install_actions(self):
        source = (ROOT / 'installer/spectrum-installer-backend').read_text()
        function = source.split('install_system() {', 1)[1].split('\nif (($# == 0))', 1)[0]
        script = 'set -euo pipefail\nlean=true\nmode=plan\ncpu_profile=amd\ngpu_profile=vm\nform_factor=desktop\ncollect_packages(){ return 1; }\ndie(){ echo "$*"; exit 1; }\nrun(){ echo UNEXPECTED_INSTALL_ACTION; exit 99; }\ninstall_system() {' + function + '\ninstall_system'
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Package selection failed', result.stdout)
        self.assertNotIn('UNEXPECTED_INSTALL_ACTION', result.stdout)

    def test_iso_compression_jobs_are_bounded_without_building_an_image(self):
        command = ['bash', '-c', 'declare -A file_permissions; source "$1"; printf "%s\\n" "${airootfs_image_tool_options[@]}" "${bootstrap_tarball_compression[@]}"', 'bash', str(ROOT / 'iso/spectrumos/profiledef.sh')]
        result = subprocess.run(command, env={**os.environ, 'SPECTRUM_ISO_JOBS': '2'}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('-processors\n2\n', result.stdout)
        self.assertIn('-mem\n512M\n', result.stdout)
        self.assertIn('-T2', result.stdout)
        self.assertNotIn('--long', result.stdout)
        invalid = subprocess.run(command, env={**os.environ, 'SPECTRUM_ISO_JOBS': '0'}, capture_output=True, text=True)
        self.assertEqual(invalid.returncode, 2)

    def package_policy(self, packages):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            archive = folder / 'repository.tar'
            with tarfile.open(archive, 'w') as output:
                for name, dependencies in packages.items():
                    data = ('%NAME%\n' + name + '\n\n%DEPENDS%\n' + '\n'.join(dependencies) + '\n').encode()
                    info = tarfile.TarInfo(name + '-1/desc')
                    info.size = len(data)
                    output.addfile(info, io.BytesIO(data))
            return subprocess.run(['bash', str(ROOT / 'scripts/check-lean-package'), str(archive), str(ROOT / 'bootstrap/packages/desktop-lean-exclude.txt')], capture_output=True, text=True)

    def test_versioned_excluded_dependency_is_rejected(self):
        result = self.package_policy({'spectrum-desktop': ['cups>=2.4']})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('spectrum-desktop -> cups', result.stderr)

    def test_transitive_spectrum_dependency_is_rejected(self):
        result = self.package_policy({'spectrum-desktop': ['spectrum-helper>=1'], 'spectrum-helper': ['tuned=2']})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('spectrum-desktop -> spectrum-helper -> tuned', result.stderr)

    def test_required_core_dependencies_and_cycles_are_allowed(self):
        result = self.package_policy({'spectrum-desktop': ['evolution', 'kdeconnect', 'spectrum-base>=1'], 'spectrum-base': ['spectrum-desktop']})
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
