#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-screensaver-idle-') as directory:
    target = Path(directory)
    shutil.copy2(root / 'tests/quickshell/screensaver-idle.qml', target / 'shell.qml')
    shutil.copy2(root / 'configs/spectrum-shell/ScreensaverIdleMonitor.qml', target)
    raise SystemExit(subprocess.run(['qs', '--path', str(target)], timeout=20).returncode)
