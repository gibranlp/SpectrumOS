#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-questline-widget-') as temporary:
    directory=Path(temporary)
    shutil.copytree(root/'configs/spectrum-shell',directory/'configs/spectrum-shell')
    for name in ['questline-adapter','questline-action','spectrum-shell-tools','hotkey-adapter','spectrumdrop-adapter']:
        shutil.copy2(root/'tests/fixtures/questline-widget-backend.py',directory/name)
        (directory/name).chmod(0o755)
    shutil.copy2(root/'scripts/questline-widget-state',directory/'questline-widget-state')
    catalog={'available':True,'installed':True,'actions_available':True,'sidequests_available':True,'chronicles_available':True,
      'campaigns':[{'id':'campaign-a','name':'Alpha','is_shared':False},{'id':'campaign-b','name':'Beta','is_shared':False},{'id':'shared','name':'Shared','is_shared':True}],
      'tasks':[{'id':'task-a','project_id':'campaign-a','title':'Task','description':'original task','priority':'Medium','campaign':'Alpha','completed':False}],
      'scrolls':[{'id':'scroll-a','project_id':'campaign-a','title':'Scroll','markdown_content':'original scroll','campaign':'Alpha'}],
      'steps':[{'id':'step-a','parent_task_id':'task-a','title':'Step','description':'original step','priority':'Medium','campaign':'Alpha','completed':False}],
      'sidequests':[{'id':'side-a','title':'Routine','frequency':'Daily','reward_xp':20,'completion_count':0,'daily_target':1}],
      'entries':[],'accounts':[]}
    (directory/'catalog.json').write_text(json.dumps(catalog))
    source=(root/'tests/qml/QuestlineWorkspaceTests.qml').read_text().replace('../../configs/','configs/')
    (directory/'Test.qml').write_text(source)
    panel=directory/'configs/spectrum-shell/UtilityPanel.qml'
    source=panel.read_text().replace('PanelWindow {','FloatingWindow {\n    implicitWidth:1280;implicitHeight:900',1)
    for line in ['    focusable: expanded\n','    exclusionMode: ExclusionMode.Ignore\n','    WlrLayershell.layer: WlrLayer.Top\n','    WlrLayershell.namespace: "spectrum-widget-utilitypanel"\n','    anchors { top: true; bottom: true; left: true; right: true }\n']:
        source=source.replace(line,'',1)
    panel.write_text(source)
    dashboard=directory/'configs/spectrum-shell/Dashboard.qml'
    source=dashboard.read_text().replace('PanelWindow {','FloatingWindow {\n    implicitWidth:800;implicitHeight:1000',1)
    for line in ['    focusable: expanded\n','    exclusionMode: ExclusionMode.Ignore\n','    WlrLayershell.layer: WlrLayer.Top\n','    WlrLayershell.namespace: "spectrum-widget-dashboard"\n','    anchors { top: true; bottom: true; left: true; right: true }\n']:
        source=source.replace(line,'',1)
    dashboard.write_text(source)
    runtime=directory/'runtime';runtime.mkdir(mode=0o700)
    environment=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(directory/'state'),SPECTRUM_QUESTLINE_TEST_DIR=str(directory))
    result=subprocess.run(['qs','--path',str(directory/'Test.qml'),'--no-color'],env=environment,capture_output=True,text=True,timeout=45)
    output=result.stdout+result.stderr
    print(output,end='')
    if result.returncode or not re.search(r'Questline workspace: \d+ passed 0 failed',output):raise SystemExit(1)
    payloads=[json.loads(line) for line in (directory/'actions.jsonl').read_text().splitlines()]
    creates=[p for p in payloads if p['action']=='create_scroll' and not p['title'].startswith('Quick note')]
    assert len(creates)==1,payloads
    assert not any(p['action']=='create_entry' for p in payloads),payloads
    state=json.loads((directory/'state/spectrumos/questline-widget.json').read_text())
    assert state['version']==1 and state['views']
    print('Verified one scroll creation, no incomplete treasury entries, and durable workspace state.')

    probe = """import QtQuick
import Quickshell
import "configs/spectrum-shell" as Shell
Scope {
    Shell.QuestlineWorkspace { id: store; backendDir: Quickshell.env("SPECTRUM_QUESTLINE_TEST_DIR") }
    Timer { interval:200; running:store.ready; onTriggered: {
        console.log("Restart restored:",JSON.stringify(store.snapshot())); Qt.quit();
    } }
}
"""
    (directory/'Restart.qml').write_text(probe)
    restored=subprocess.run(['qs','--path',str(directory/'Restart.qml'),'--no-color'],env=environment,capture_output=True,text=True,timeout=10)
    output=restored.stdout+restored.stderr
    match=re.search(r'Restart restored: (\{.*\})',output)
    assert restored.returncode==0 and match,output
    state=json.loads(match.group(1))
    assert state['activeTab']=='Tasks' and state['views']['Tasks']['stepSelected']['id']=='step-a'
    assert state['views']['Tasks']['title']=='Step work in progress'
    assert state['views']['Treasury']['amount']=='12.'
    print('Fresh process restored the active task/step editor and the unfinished treasury draft.')
