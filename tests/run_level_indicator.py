#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-level-indicator-") as temporary:
    directory = Path(temporary)
    shutil.copytree(root / "configs/spectrum-shell", directory / "shell")
    panel = directory / "shell/LevelIndicator.qml"
    source = panel.read_text().replace("PanelWindow {", "FloatingWindow {", 1)
    for line in [
        '    anchors { top: true; bottom: true; left: true; right: true }\n',
        '    exclusionMode: ExclusionMode.Ignore\n',
        '    focusable: false\n',
        '    WlrLayershell.layer: WlrLayer.Top\n',
        '    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None\n',
        '    WlrLayershell.namespace: "spectrum-level-indicator"\n',
    ]:
        source = source.replace(line, "", 1)
    panel.write_text(source)
    (directory / "Test.qml").write_text((root / "tests/qml/LevelIndicatorTests.qml").read_text().replace('"../../configs/spectrum-shell"', '"shell"'))
    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    result = subprocess.run(["qs", "--path", str(directory / "Test.qml"), "--no-color"],
                            env=dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(runtime)),
                            capture_output=True, text=True, timeout=25)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or not re.search(r"Level indicator: \d+ passed 0 failed", output):
        raise SystemExit(1)
