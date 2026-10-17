#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-capture-notifications-") as temporary:
    directory = Path(temporary)
    shutil.copytree(root / "configs/spectrum-shell", directory / "shell")
    panel = directory / "shell/ScreenshotPanel.qml"
    source = panel.read_text().replace("PanelWindow {", "FloatingWindow {", 1)
    for line in ('    WlrLayershell.layer: WlrLayer.Top\n',
                 '    WlrLayershell.namespace: "spectrum-widget-screenshotpanel"\n',
                 '    anchors { top: true; left: true; right: true; bottom: true }\n',
                 '    exclusionMode: ExclusionMode.Ignore\n', '    focusable: expanded\n'):
        source = source.replace(line, "", 1)
    source = source.replace('        id: card\n', '        id: card\n        objectName: "captureCard"\n', 1)
    panel.write_text(source)
    shell = (root / "configs/spectrum-shell/shell.qml").read_text()
    methods = []
    for name in ("dismissLatestNotification", "clearNotifications"):
        match = re.search(r"        function " + name + r"\(\): void \{.*?\n        }", shell, re.S)
        if not match:
            raise RuntimeError(f"Missing {name}")
        methods.append(match.group())
    test = (root / "tests/qml/CaptureNotificationTests.qml").read_text()
    test = test.replace("// NOTIFICATION_METHODS", "\n".join(methods))
    test = test.replace('"../../configs/spectrum-shell"', '"shell"')
    path = directory / "CaptureNotificationTests.qml"
    path.write_text(test)
    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    result = subprocess.run(["qs", "--path", str(path), "--no-color"],
                            env=dict(os.environ, XDG_RUNTIME_DIR=str(runtime)),
                            capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or not re.search(r"\b\d+ passed 0 failed", output):
        raise SystemExit(1)
