#!/usr/bin/env python3
import os
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-calculator-conversions-") as directory:
    temporary = Path(directory)
    shutil.copytree(root / "configs/spectrum-shell", temporary / "shell")
    source = (root / "tests/qml/CalculatorConversionTests.qml").read_text().replace("../../configs/spectrum-shell", "shell")
    (temporary / "Test.qml").write_text(source)
    wrapper = """#!/usr/bin/env python3
import os
import subprocess
import sys
import time
time.sleep(float(os.environ.get('SPECTRUM_CALCULATOR_DELAY', '0')))
raise SystemExit(subprocess.run([os.environ['SPECTRUM_CALCULATOR_BACKEND'], *sys.argv[1:]]).returncode)
"""
    (temporary / "spectrum-shell-tools").write_text(wrapper)
    (temporary / "spectrum-shell-tools").chmod(0o755)
    slow = temporary / "slow"
    slow.mkdir()
    (slow / "spectrum-shell-tools").write_text(wrapper.replace("os.environ.get('SPECTRUM_CALCULATOR_DELAY', '0')", "'0.5'"))
    (slow / "spectrum-shell-tools").chmod(0o755)
    failed = temporary / "failed"
    failed.mkdir()
    (failed / "spectrum-shell-tools").write_text('#!/usr/bin/env python3\nprint(\'{"ok":false,"error":"fixture conversion failure"}\')\n')
    (failed / "spectrum-shell-tools").chmod(0o755)
    runtime = temporary / "runtime"
    runtime.mkdir(mode=0o700)
    environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
        XDG_RUNTIME_DIR=str(runtime), SPECTRUM_CALCULATOR_TEST_DIR=str(temporary),
        SPECTRUM_CALCULATOR_SLOW_DIR=str(slow), SPECTRUM_CALCULATOR_BACKEND=str(root / "scripts/spectrum-shell-tools"))
    environment["SPECTRUM_CALCULATOR_FAILED_DIR"] = str(failed)
    cache = temporary / "cache/spectrumos"
    cache.mkdir(parents=True)
    (cache / "currency-rates.json").write_text(json.dumps({"schema":1,"date":"2026-10-23",
        "checked_at":time.time()-7200,"retry_after":time.time()+300,
        "rates":{"EUR":"1","USD":"1.1","MXN":"22","GBP":"0.85","CAD":"1.5","JPY":"165","CHF":"0.95"}}))
    environment["XDG_CACHE_HOME"] = str(temporary / "cache")
    result = subprocess.run(["qs", "--path", str(temporary / "Test.qml"), "--no-color"],
                            env=environment, capture_output=True, text=True, timeout=35)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or not re.search(r"Calculator conversions: \d+ passed 0 failed", output):
        raise SystemExit(1)
