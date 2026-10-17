#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-media-test-") as temporary:
    directory = Path(temporary)
    shutil.copytree(root / "configs/spectrum-shell", directory / "shell")
    source = (root / "tests/qml/tst_Media.qml").read_text().replace('"../../configs/spectrum-shell"', '"shell"')
    source = source.replace('if (completed) console.log("Media checks:", qtest_results.passCount, "passed,", qtest_results.failCount, "failed")',
                            'if (completed) { console.log("Media checks:", qtest_results.passCount, "passed,", qtest_results.failCount, "failed"); Qt.quit(); }')
    (directory / "tst_Media.qml").write_text(source)
    (directory / "MediaTests.qml").write_text((root / "tests/qml/MediaTests.qml").read_text())
    result = subprocess.run(["qs", "--path", str(directory / "MediaTests.qml"), "--no-color"],
                            env=dict(os.environ), capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or not re.search(r"Media checks: \d+ passed, 0 failed", output):
        raise SystemExit(1)
