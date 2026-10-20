#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-dashboard-hover-") as temporary:
    directory = Path(temporary)
    shutil.copytree(root / "configs/spectrum-shell", directory / "configs/spectrum-shell")
    target = directory / "configs/spectrum-shell/DashboardHoverTarget.qml"
    source = target.read_text().replace("    PanelWindow {", "    FloatingWindow {\n        implicitWidth: 1280", 1)
    for line in [
        "        anchors { top: true; left: true; right: true }\n",
        "        exclusionMode: ExclusionMode.Ignore\n",
        "        WlrLayershell.layer: WlrLayer.Overlay\n",
        '        WlrLayershell.namespace: "spectrum-dashboard-hover"\n',
        "        focusable: false\n",
    ]:
        source = source.replace(line, "", 1)
    target.write_text(source)
    source = (root / "tests/qml/DashboardHoverTargetTests.qml").read_text().replace("../../configs/", "configs/")
    (directory / "Test.qml").write_text(source)
    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run(["qs", "--path", str(directory / "Test.qml"), "--no-color"],
                            env=environment, capture_output=True, text=True, timeout=25)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or not re.search(r"Dashboard hover targets: \d+ passed 0 failed", output):
        raise SystemExit(1)
