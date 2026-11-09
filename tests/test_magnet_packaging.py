import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MagnetPackagingTests(unittest.TestCase):
    def test_vendored_snapshot_matches_provenance(self):
        source = ROOT / 'integrations/magnet'
        provenance = json.loads((source / 'provenance.json').read_text())
        self.assertEqual(provenance['snapshot'], 'maintainer_working_tree')
        self.assertIn('Cargo.lock', provenance['files'])
        self.assertIn('src/daemon.rs', provenance['files'])
        for name, digest in provenance['files'].items():
            self.assertEqual(hashlib.sha256((source / name).read_bytes()).hexdigest(), digest, name)

    def test_desktop_requires_engine_for_updates_and_both_install_profiles(self):
        dependencies = subprocess.check_output(['bash', '-c', 'source packages/spectrum-desktop/PKGBUILD; printf "%s\\n" "${depends[@]}"'], cwd=ROOT, text=True).splitlines()
        self.assertIn('spectrum-magnet>=0.1.0', dependencies)
        self.assertIn('spectrum-magnet', (ROOT / 'bootstrap/packages/desktop.txt').read_text().splitlines())
        self.assertNotIn('spectrum-magnet', (ROOT / 'bootstrap/packages/desktop-lean-exclude.txt').read_text().splitlines())
        self.assertIn('spectrum-magnet', (ROOT / 'iso/spectrumos/packages.x86_64').read_text().splitlines())
        packages = runpy.run_path(str(ROOT / 'scripts/spectrum-repo'))['PACKAGE_NAMES']
        self.assertLess(packages.index('spectrum-magnet'), packages.index('spectrum-desktop'))

    def test_package_installs_binary_license_and_provenance_without_service(self):
        recipe = ROOT / 'packages/spectrum-magnet/PKGBUILD'
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            source = temporary / 'src/spectrumos-source-1.0.0/integrations/magnet'
            source.mkdir(parents=True)
            for name in ('LICENSE', 'README.md', 'provenance.json'):
                (source / name).write_bytes((ROOT / 'integrations/magnet' / name).read_bytes())
            binary = temporary / 'src/target/x86_64-unknown-linux-gnu/release/magnet'
            binary.parent.mkdir(parents=True)
            binary.write_text('#!/bin/sh\nprintf "magnet 0.1.0\\n"\n')
            destination = temporary / 'pkg'
            subprocess.run(['bash', '-c', 'source "$1"; srcdir=$2; pkgdir=$3; package', 'package-test', str(recipe), str(temporary / 'src'), str(destination)], check=True)
            self.assertEqual((destination / 'usr/bin/magnet').stat().st_mode & 0o777, 0o755)
            self.assertEqual((destination / 'usr/bin/magnet').read_bytes(), binary.read_bytes())
            self.assertTrue((destination / 'usr/share/licenses/spectrum-magnet/LICENSE').is_file())
            self.assertTrue((destination / 'usr/share/doc/spectrum-magnet/provenance.json').is_file())
            self.assertFalse((destination / 'usr/lib/systemd').exists())

    def repository_fixture(self, directory, include_engine=True, dependency=True, binary=True, widget=True):
        root = Path(directory)
        def archive(name, files):
            with tarfile.open(root / name, 'w') as output:
                for path, content in files.items():
                    data = content.encode()
                    entry = tarfile.TarInfo(path)
                    entry.size = len(data)
                    output.addfile(entry, io.BytesIO(data))
        desktop_paths = ['usr/bin/stash', 'usr/bin/questline', 'usr/lib/spectrumos/stash-open', 'usr/lib/spectrumos/questline-open', 'usr/share/applications/stash.desktop', 'usr/lib/spectrumos/magnet-open', 'usr/lib/spectrumos/magnet-adapter', 'usr/share/applications/magnet.desktop']
        if widget:
            desktop_paths.append('usr/share/spectrumos/spectrum-shell/MagnetDownloads.qml')
        archive('spectrum-desktop.pkg.tar.zst', dict.fromkeys(desktop_paths, 'fixture'))
        entries = {'spectrum-desktop-1/desc':'%NAME%\nspectrum-desktop\n\n%FILENAME%\nspectrum-desktop.pkg.tar.zst\n\n%DEPENDS%\n' + ('spectrum-magnet>=0.1.0\n' if dependency else 'glibc\n')}
        if include_engine:
            entries['spectrum-magnet-1/desc'] = '%NAME%\nspectrum-magnet\n\n%FILENAME%\nspectrum-magnet.pkg.tar.zst\n'
            payload = {'usr/share/licenses/spectrum-magnet/LICENSE':'MIT'}
            if binary:
                payload['usr/bin/magnet'] = 'fixture'
            archive('spectrum-magnet.pkg.tar.zst', payload)
        archive('spectrumos.db.tar.zst', entries)

    def test_iso_gate_accepts_complete_repository_and_rejects_missing_integration(self):
        for options, expected in [({}, 0), ({'include_engine':False}, 1), ({'dependency':False}, 1), ({'binary':False}, 1), ({'widget':False}, 1)]:
            with self.subTest(options=options), tempfile.TemporaryDirectory() as directory:
                self.repository_fixture(directory, **options)
                result = subprocess.run(['bash', str(ROOT / 'scripts/check-bundled-apps'), directory], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
