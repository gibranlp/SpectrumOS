#!/usr/bin/env python3
import json
from pathlib import Path
import sys
import time

name = Path(sys.argv[0]).name
time.sleep(0.15)
if name == "ukvm-adapter":
    print(json.dumps(dict(schema_version=1, integration_version=1, installed=True, ok=True, apply_pending=False, data={})))
elif name == "spectrum-shell-tools":
    print("[]" if sys.argv[1] == "colors" else "{}")
elif name == "spectrumdrop-adapter":
    marker = Path(__file__).parent / "mock-send-started"
    phase = "choosing" if sys.argv[1] == "send" else "failed" if marker.exists() else ""
    if sys.argv[1] == "send": marker.write_text("started")
    if sys.argv[1] == "scan":
        print(json.dumps(dict(ok=True, peers=[])))
    else:
        print(json.dumps(dict(ok=True, visible=True, transfer=dict(active=phase == "choosing", phase=phase, message="Send failed: mock recipient unavailable" if phase == "failed" else "Choose files…"))))
else:
    print(json.dumps(dict(ok=True, rules=[dict(id="test", keys="2", interval_ms=50, shortcut="Control+Shift+2", active=False)], diagnostics={})))
