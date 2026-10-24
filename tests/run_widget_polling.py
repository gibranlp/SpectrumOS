#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-widget-polling-") as temporary:
    directory = Path(temporary)
    for name in ("spectrum-shell", "spectrum-ukvm"):
        shutil.copytree(root / "configs" / name, directory / "configs" / name)
    for name in ("ukvm-adapter", "hotkey-adapter", "spectrumdrop-adapter", "spectrum-shell-tools"):
        destination = directory / name
        shutil.copyfile(root / "tests/fixtures/widget-polling-adapter.py", destination)
        destination.chmod(0o755)
    if os.environ.get("QT_QPA_PLATFORM") == "offscreen":
        panel = directory / "configs/spectrum-shell/UtilityPanel.qml"
        source = panel.read_text().replace("PanelWindow {", "FloatingWindow {", 1)
        for line in ("    WlrLayershell.keyboardFocus: panelFocus.mode\n", "    exclusionMode: ExclusionMode.Ignore\n", "    WlrLayershell.layer: WlrLayer.Top\n", '    WlrLayershell.namespace: "spectrum-widget-utilitypanel"\n', "    anchors { top: true; bottom: true; left: true; right: true }\n"):
            source = source.replace(line, "", 1)
        panel.write_text(source)
    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    environment = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), SPECTRUM_UKVM_TEST_ADAPTER=str(directory / "ukvm-adapter"), SPECTRUM_POLLING_DIR=str(directory))
    for name in ("UkvmPollingTests", "UtilityPollingTests"):
        test_path = directory / (name + ".qml")
        source = (root / "tests/qml" / (name + ".qml")).read_text().replace('../../configs/', 'configs/')
        test_path.write_text(source)
        result = subprocess.run(["qs", "--path", str(test_path), "--no-color"], env=environment, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output, end="")
        if result.returncode or not re.search(r"\b\d+ passed 0 failed", output):
            raise SystemExit(1)
