#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-magnet-widget-') as directory:
    temporary = Path(directory)
    shutil.copytree(root / 'configs/spectrum-shell', temporary / 'shell')
    source = (root / 'tests/qml/MagnetWidgetTests.qml').read_text().replace('../../configs/spectrum-shell', 'shell')
    (temporary / 'Test.qml').write_text(source)
    fixture = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
import time
state = Path(os.environ['SPECTRUM_MAGNET_TEST_DIR']) / 'state.json'
log = state.with_suffix('.jsonl')
args = sys.argv[1:]
with log.open('a') as output:
    output.write(json.dumps(args) + '\\n')
if args[0] == 'search':
    if args[1] == 'fail':
        print(json.dumps({'ok': False, 'error': 'fixture search failed'}))
        sys.exit(1)
    time.sleep(2.3)
    print(json.dumps({'ok': True, 'results': [{'name': 'Example Linux', 'sizeBytes': 4096, 'seeders': 3, 'source': 'fixture', 'magnet': 'magnet:?xt=urn:btih:' + 'a' * 40}], 'sources': [{'source': 'fixture', 'ok': True}, {'source': 'offline', 'ok': False}]}))
elif args[0] == 'status':
    rows = json.loads(state.read_text()) if state.exists() else []
    print(json.dumps({'ok': True, 'installed': True, 'running': bool(rows), 'rows': rows}))
elif args[0] == 'add':
    state.write_text(json.dumps([{'id': 1 << 40, 'info_hash': args[1][-40:], 'name': args[2] or 'Pasted magnet', 'state': 'Starting', 'done': 0, 'total': 0, 'down': 0, 'eta': None, 'folder': '/tmp'}]))
    print(json.dumps({'ok': True, 'id': 1 << 40}))
elif args[0] in ('remove', 'delete'):
    state.write_text('[]')
    print('{"ok":true}')
else:
    raise SystemExit('unexpected fixture command')
'''
    adapter = temporary / 'magnet-adapter'
    adapter.write_text(fixture)
    adapter.chmod(0o755)
    runtime = temporary / 'runtime'
    runtime.mkdir(mode=0o700)
    environment = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       SPECTRUM_MAGNET_TEST_DIR=str(temporary))
    result = subprocess.run(['qs', '--path', str(temporary / 'Test.qml'), '--no-color'],
                            env=environment, capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode or not re.search(r'Magnet widget: \d+ passed 0 failed', output):
        raise SystemExit(1)
    commands = [json.loads(line) for line in (temporary / 'state.jsonl').read_text().splitlines()]
    assert ['search', 'top100', 'all'] in commands
    assert ['delete', str(1 << 40)] in commands
    assert sum(command[0] == 'add' for command in commands) == 2
    assert any(command[0] == 'status' for command in commands[1:commands.index(['add', 'magnet:?xt=urn:btih:' + 'a' * 40, 'Example Linux'])])
    print('Widget search, concurrent status, result download, removal, search error, and pasted magnet verified.')
