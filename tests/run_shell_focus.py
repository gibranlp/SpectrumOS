#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-shell-focus-") as directory:
    temporary = Path(directory)
    (temporary / "shell").mkdir()
    shutil.copy2(root / "configs/spectrum-shell/ShellFocus.qml", temporary / "shell/ShellFocus.qml")
    test = temporary / "ShellFocusTests.qml"
    test.write_text((root / "tests/qml/ShellFocusTests.qml").read_text().replace("../../configs/spectrum-shell", "shell"))
    environment = dict(os.environ, XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM="offscreen",
                       QT_QUICK_BACKEND="software")
    result = subprocess.run(["qs", "--path", str(test), "--no-color"],
                            env=environment, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or not re.search(r"Shell focus: \d+ passed 0 failed", output):
        raise SystemExit(1)
