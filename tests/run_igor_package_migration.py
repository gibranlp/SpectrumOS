#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def run(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def payload(path):
    return {name.removeprefix('./') for name in run(['bsdtar', '-tf', str(path)]).splitlines()
            if name and not name.endswith('/') and not name.startswith('.')}


def metadata(path):
    result = {}
    for line in run(['bsdtar', '-xOf', str(path), '.PKGINFO']).splitlines():
        key, separator, value = line.partition(' = ')
        if separator:
            result.setdefault(key, []).append(value)
    return result


def main():
    parser = argparse.ArgumentParser(description='Test an Igor package ownership upgrade in an isolated temporary Pacman root.')
    parser.add_argument('--old-desktop', required=True, type=Path)
    parser.add_argument('--desktop', required=True, type=Path)
    parser.add_argument('--igor', required=True, type=Path)
    parser.add_argument('--report', type=Path)
    arguments = parser.parse_args()
    old, desktop, igor = [path.resolve() for path in (arguments.old_desktop, arguments.desktop, arguments.igor)]
    desktop_files, igor_files = payload(desktop), payload(igor)
    assert not desktop_files.intersection(igor_files), 'Desktop and Igor packages own the same files'
    legacy = {'usr/share/spectrumos/spectrum-shell/' + name for name in [
        'IgorRoutine.qml', 'IgorIllustration.qml', 'IgorMusicNote.qml', 'IgorNapStage.qml',
        'IgorStage.qml', 'IgorSeasonalOutfit.qml', 'IgorSleeper.qml', 'IgorVisitor.qml', 'IgorOutfits.js']}
    assert not desktop_files.intersection(legacy)
    assert not any(name.startswith('usr/share/spectrumos/spectrum-shell/igor/') for name in desktop_files)
    assert any(value.startswith('spectrum-igor>=') for value in metadata(desktop).get('depend', []))
    with tempfile.TemporaryDirectory(prefix='igor-upgrade-') as temporary:
        directory = Path(temporary)
        root = directory / 'root'
        (root / 'var/lib/pacman').mkdir(parents=True)
        (root / 'var/cache/pacman/pkg').mkdir(parents=True)
        (directory / 'hooks').mkdir()
        config = directory / 'pacman.conf'
        config.write_text('[options]\nArchitecture = auto\nSigLevel = Never\nLocalFileSigLevel = Never\nNoExtract = usr/share/libalpm/hooks/*\n')
        command = ['fakeroot', 'pacman', '--root', str(root), '--dbpath', str(root / 'var/lib/pacman'),
                   '--config', str(config), '--hookdir', str(directory / 'hooks')]
        run([*command, '-Udd', '--noscriptlet', '--noconfirm', str(old)])
        assert (root / 'usr/share/spectrumos/spectrum-shell/igor/face.svg').is_file()
        preferences = root / 'home/test/.config/spectrumos/shell.json'
        preferences.parent.mkdir(parents=True)
        preferences.write_text('{"igor_enabled":false,"custom":"preserve"}\n')
        avatar = root / 'home/test/test.png'
        avatar.write_bytes(b'custom avatar remains untouched')
        run([*command, '-Udd', '--noscriptlet', '--noconfirm', str(igor), str(desktop)])
        assert preferences.read_text() == '{"igor_enabled":false,"custom":"preserve"}\n'
        assert avatar.read_bytes() == b'custom avatar remains untouched'
        assert all(not (root / name).exists() for name in legacy)
        assert not (root / 'usr/share/spectrumos/spectrum-shell/igor/face.svg').exists()
        face = root / 'usr/lib/qt6/qml/Spectrum/Igor/igor/face.svg'
        assert face.is_file()
        run([*command, '-T', 'spectrum-igor>=0.1.0'])
        owner = run([*command, '-Qo', str(face)])
        assert 'spectrum-igor' in owner
    report = {'old_desktop': metadata(old)['pkgver'][0], 'desktop': metadata(desktop)['pkgver'][0],
              'igor': metadata(igor)['pkgver'][0], 'file_conflicts': False,
              'legacy_files_removed': True, 'preferences_preserved': True, 'avatar_preserved': True,
              'runtime_dependency_satisfied': True, 'scope': 'isolated_payload_ownership_upgrade',
              'system_dependency_closure_tested': False, 'package_scriptlets_and_hooks_run': False,
              'artifacts': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in (old, desktop, igor)}}
    if arguments.report:
        arguments.report.parent.mkdir(parents=True, exist_ok=True)
        arguments.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
