#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-notification-test-') as temporary:
    directory=Path(temporary);shutil.copytree(root/'configs/spectrum-shell',directory/'shell')
    backend=directory/'questline-action'
    backend.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
request=json.loads(sys.argv[1]);folder=Path(__file__).parent
with (folder/'actions.jsonl').open('a') as f:f.write(json.dumps(request)+'\\n')
if request.get('reminder_token')=='force-error' and request['action']=='drink_water':
 print(json.dumps({'error':'Try again'}));sys.exit(1)
print(json.dumps({'recorded':request['action']=='drink_water'}))
''');backend.chmod(0o755)
    center=directory/'shell/NotificationCenter.qml'
    text=center.read_text().replace('PanelWindow {','FloatingWindow {\n    implicitWidth:420;implicitHeight:900',1)
    for line in ['    WlrLayershell.layer: WlrLayer.Top\n','    WlrLayershell.namespace: "spectrum-widget-notificationcenter"\n','    anchors { top: true; bottom: true; left: true; right: true }\n','    margins.bottom: 8\n','    exclusionMode: ExclusionMode.Ignore\n','    WlrLayershell.keyboardFocus: panelFocus.mode\n']:
        text=text.replace(line,'',1)
    center.write_text(text)
    shell=(root/'configs/spectrum-shell/shell.qml').read_text();methods=[]
    for name in ['setNotificationBusy','removeNotificationToasts','invokeNotificationAction','acceptNotification','removeToast','dismissLatestNotification','clearNotifications']:
        match=re.search(r'(?m)^( {4}| {8})function '+name+r'\([^\n]*\): void \{.*?\n\1}',shell,re.S)
        if not match:raise RuntimeError('Missing production notification function: '+name)
        methods.append(match.group())
    start=shell.index('    QuestlineNotificationActions {');end=shell.index('    function setNotificationBusy',start)
    methods.append(shell[start:end].replace('QuestlineNotificationActions {','Shell.QuestlineNotificationActions {',1))
    test=(root/'tests/qml/QuestlineNotificationTests.qml').read_text().replace('../../configs/spectrum-shell','shell').replace('// SHELL_NOTIFICATION_METHODS','\n'.join(methods))
    path=directory/'Test.qml';path.write_text(test);runtime=directory/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),SPECTRUM_NOTIFICATION_TEST_DIR=str(directory))
    result=subprocess.run(['dbus-run-session','--','qs','--path',str(path),'--no-color'],env=env,capture_output=True,text=True,timeout=25)
    output=result.stdout+result.stderr;print(output,end='')
    if result.returncode or not re.search(r'Questline notifications: \d+ passed 0 failed',output):raise SystemExit(1)
    calls=[json.loads(line) for line in (directory/'actions.jsonl').read_text().splitlines()]
    assert len([call for call in calls if call['action']=='drink_water' and call.get('reminder_token')=='reminder'])==1,calls
    assert len([call for call in calls if call['action']=='drink_water' and call.get('reminder_token')=='native-drink'])==1,calls
    assert not any(call['action']=='drink_water' and call.get('reminder_token')=='native-dismiss' for call in calls),calls
    print('Verified a single drink request, persistent reminder dismissal, and fixed Questline notification palettes.')
