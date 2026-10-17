import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='spectrum-ukvm-theme-') as directory:
        temporary = Path(directory)
        source = (ROOT / 'configs/spectrum-ukvm/UkvmTheme.qml').read_text()
        if os.environ.get('SPECTRUM_UKVM_THEME_BASELINE'):
            source = source.replace('running: theme.active', 'running: false')
        (temporary / 'UkvmTheme.qml').write_text(source)
        shutil.copyfile(ROOT / 'tests/qml/UkvmThemeTests.qml', temporary / 'shell.qml')
        for name, color, family, size in [('first', '#112233', 'monospace', 12),
                                           ('second', '#554433', 'serif', 20),
                                           ('invalid', '#000000', 'monospace', 12)]:
            generation = temporary / name
            generation.mkdir()
            roles = {key: color for key in ('background', 'surface', 'surface_alt', 'foreground', 'muted', 'accent')}
            (generation / 'palette.json').write_text('invalid json' if name == 'invalid' else json.dumps({'roles': roles}))
            (generation / 'kitty.conf').write_text(f'font_family {family}\nfont_size {size}\n')
        (temporary / 'current').symlink_to('first')
        (temporary / 'switch.py').write_text('''from pathlib import Path
import sys
base = Path(__file__).parent
pending = base / 'next'
pending.symlink_to(sys.argv[1])
pending.replace(base / 'current')
''')
        result = subprocess.run(['qs', '--path', str(temporary), '--no-color'],
                                env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                                         XDG_RUNTIME_DIR=directory, SPECTRUM_UKVM_THEME_FIXTURE=directory),
                                capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output, end='')
        return 0 if result.returncode == 0 and 'UKVM theme checks:' in output and '0 failed' in output and 'FAIL!' not in output else 1


if __name__ == '__main__':
    raise SystemExit(main())
