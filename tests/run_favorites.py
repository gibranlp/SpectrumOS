#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-favorites-test-') as temporary:
    folder=Path(temporary)
    shutil.copytree(ROOT/'configs/spectrum-shell',folder/'configs/spectrum-shell')
    shutil.copy2(ROOT/'scripts/favorites-adapter',folder/'real-adapter')
    wrapper='''#!/usr/bin/env python3
import importlib.machinery,importlib.util,json,os,sys
from pathlib import Path
from unittest.mock import Mock
loader=importlib.machinery.SourceFileLoader('backend',str(Path(__file__).with_name('real-adapter')))
spec=importlib.util.spec_from_loader(loader.name,loader);m=importlib.util.module_from_spec(spec);loader.exec_module(m)
selection=Path(__file__).with_name('browser-selection')
def browsers():
 id=selection.read_text() if selection.exists() else 'browser.desktop'
 return dict(browsers=[dict(id='browser.desktop',name='Test Browser',icon=''),dict(id='second.desktop',name='Second Browser',icon='')],defaultBrowser=id,httpBrowser=id)
def select(id):
 selection.write_text(id);return browsers()
m.browser_catalog=browsers;m.set_browser=select;m.fetch_icon=lambda url:None
m.subprocess.Popen=Mock();m.subprocess.Popen.return_value.wait.return_value=0
try:
 action=sys.argv[1];payload=json.loads(sys.stdin.readline() or '{}')
 if action=='test-reset':
  m.directory().mkdir(parents=True,exist_ok=True);m.atomic(m.directory()/'favorites.json',json.dumps(m.initial()).encode());selection.unlink(missing_ok=True);action='status'
 print(json.dumps(m.main(action,payload)))
except Exception as e:
 print(json.dumps(dict(ok=False,error=str(e))));sys.exit(1)
'''
    (folder/'favorites-adapter').write_text(wrapper);(folder/'favorites-adapter').chmod(0o755)
    (folder/'fixture.json').write_text(json.dumps(dict(personal=dict(links=[dict(title='Most used',url='https://popular.example',category='Work',clickCount=12),dict(title='Less used',url='https://less.example',category='Work',clickCount=1)]))))
    (folder/'browser.html').write_text('<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><DT><H3>Bookmarks bar</H3><DL><DT><A HREF="https://browser.example">Browser portal</A><DT><A HREF="javascript:alert(1)">Skip me</A></DL></DL>')
    source=(ROOT/'tests/qml/FavoritesTests.qml').read_text().replace('../../configs/','configs/')
    (folder/'Test.qml').write_text(source)
    panel=folder/'configs/spectrum-shell/FavoritesPanel.qml'
    text=panel.read_text().replace('PanelWindow {','FloatingWindow {\n    implicitWidth:800;implicitHeight:950',1)
    for line in ['    WlrLayershell.layer:WlrLayer.Top\n','    WlrLayershell.namespace:"spectrum-widget-favorites"\n','    anchors {top:true;bottom:true;left:true;right:true}\n','    exclusionMode:ExclusionMode.Ignore\n','    focusable:expanded && !manager.choosing\n']:
        text=text.replace(line,'',1)
    panel.write_text(text)
    runtime=folder/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,SPECTRUM_FAVORITES_QUESTLINE='disabled',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'),SPECTRUM_FAVORITES_TEST_DIR=str(folder))
    result=subprocess.run(['qs','--path',str(folder/'Test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=45)
    output=result.stdout+result.stderr;print(output,end='')
    if result.returncode or not re.search(r'Favorites checks: \d+ passed 0 failed',output):raise SystemExit(1)

    payload=dict(view=dict(category='uncategorized',search='unfinished',editor='favorite',draft=dict(id='restart-draft',title='A saved idea',url='https://',category='uncategorized')))
    subprocess.run([str(folder/'favorites-adapter'),'view-save'],input=json.dumps(payload),env=env,capture_output=True,text=True,check=True)
    probe="""import QtQuick
import Quickshell
import "configs/spectrum-shell" as Shell
Scope {
    Shell.FavoritesManager {id:manager;theme:({backend:function(name){return Quickshell.env("SPECTRUM_FAVORITES_TEST_DIR")+"/"+name;}})}
    Timer {interval:100;running:manager.ready;onTriggered:{
        if(manager.view.editor === "favorite" && manager.view.draft.title === "A saved idea" && manager.view.draft.url === "https://" && manager.view.search === "unfinished")console.log("Favorites restart: restored");
        Qt.quit();
    }}
}
"""
    (folder/'Restart.qml').write_text(probe)
    restored=subprocess.run(['qs','--path',str(folder/'Restart.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=15)
    assert restored.returncode==0 and 'Favorites restart: restored' in restored.stdout+restored.stderr,restored.stdout+restored.stderr
    print('Fresh process restored the selected category, search, active editor and incomplete draft.')
