#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="spectrum-launcher-test-") as temporary:
    directory = Path(temporary)
    shutil.copytree(root / "configs/spectrum-shell", directory / "shell")
    launcher = directory / "shell/Launcher.qml"
    source = launcher.read_text().replace("PanelWindow {", "FloatingWindow {", 1)
    for line in ("    WlrLayershell.keyboardFocus: panelFocus.mode\n", "    exclusionMode: ExclusionMode.Ignore\n", "    WlrLayershell.layer: WlrLayer.Top\n", '    WlrLayershell.namespace: "spectrum-widget-launcher"\n', "    anchors { top: true; bottom: true; left: true; right: true }\n"):
        source = source.replace(line, "", 1)
    launcher.write_text(source)
    backend = directory / "application-adapter"
    shutil.copyfile(root / "scripts/application-adapter", backend)
    backend.chmod(0o755)
    entry = directory / "data/applications/spectrum-launcher-fixture.desktop"
    entry.parent.mkdir(parents=True)
    entry.write_text("[Desktop Entry]\nType=Application\nName=Launcher Removal Fixture\nExec=/bin/true\n")
    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    test = directory / "LauncherTests.qml"
    test.write_text((root / "tests/qml/LauncherTests.qml").read_text().replace('"../../configs/spectrum-shell"', '"shell"'))
    environment = dict(os.environ, HOME=str(directory), XDG_DATA_HOME=str(directory / "data"),
                       XDG_DATA_DIRS=str(directory / "system"), XDG_RUNTIME_DIR=str(runtime),
                       SPECTRUM_SHELL_BACKEND_DIR=str(directory), SPECTRUM_LAUNCHER_TEST_ENTRY=str(entry))
    result = subprocess.run(["qs", "--path", str(test), "--no-color"], env=environment, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or not re.search(r"\b\d+ passed 0 failed", output):
        raise SystemExit(1)
