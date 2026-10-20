#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-app-store-ui-') as temporary:
    folder = Path(temporary)
    shutil.copytree(ROOT/'configs/spectrum-shell', folder/'configs/spectrum-shell')
    source = (ROOT/'tests/qml/AppStoreTests.qml').read_text().replace('../../configs/', 'configs/')
    (folder/'Test.qml').write_text(source)
    panel = folder/'configs/spectrum-shell/AppStorePanel.qml'
    source = panel.read_text().replace('PanelWindow {', 'FloatingWindow {\n    implicitWidth:Number(Quickshell.env("SPECTRUM_APP_STORE_WIDTH"));implicitHeight:950', 1)
    for line in ('    WlrLayershell.layer: WlrLayer.Top\n',
                 '    WlrLayershell.namespace: "spectrum-widget-app-store"\n',
                 '    anchors { top:true; bottom:true; left:true; right:true }\n',
                 '    exclusionMode: ExclusionMode.Ignore\n',
                 '    focusable: expanded && !manager.authenticating\n'):
        source = source.replace(line, '', 1)
    panel.write_text(source)
    helper = folder/'app-store-adapter'
    helper.write_text('''#!/usr/bin/env python3
import json,sys,time
from pathlib import Path
p=json.loads(sys.stdin.readline());a=sys.argv[1];state=Path(__file__).with_name('job.json')
target=dict(source='pacman',repository='extra',name=p.get('query') or 'fixture',title='Fixture app',version='1',description='A fixture application',label='extra',key='fixture',installed=False)
if a=='search':
 if p.get('query')=='slow':time.sleep(.8)
 result=dict(results=[target],backends=dict(pacman=True,paru=True,flatpak=True),warnings=[])
elif a=='details':result=dict(detail='Fixture description and dependencies')
elif a=='start':
 state.write_text(json.dumps(dict(id='fixture',target=p['target'],active=True,phase='terminal',mode='terminal',message='Follow the installation terminal',log='Packages: fixture',prompt=None)));result=dict(jobId='fixture')
elif a=='test-log':
 state.write_text(json.dumps(dict(id='fixture',target=target,active=False,phase='complete',mode='terminal',message='Complete',log=''.join('Progress line '+str(i)+'\\n' for i in range(200)),prompt=None)));result={}
elif a=='test-append':
 job=json.loads(state.read_text());job['log']+='New output\\n';state.write_text(json.dumps(job));result={}
elif a=='test-complete':
 job=json.loads(state.read_text());job.update(active=False,phase='complete');state.write_text(json.dumps(job));result={}
elif a=='answer':
 job=json.loads(state.read_text());job.update(active=False,phase='complete',prompt=None);state.write_text(json.dumps(job));result={}
elif a=='jobs':result=dict(jobs=[json.loads(state.read_text())] if state.exists() else [])
else:result={}
print(json.dumps(dict(result,ok=True)))
''')
    helper.chmod(0o755)
    runtime = folder/'runtime'; runtime.mkdir(mode=0o700)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=str(runtime), SPECTRUM_APP_STORE_TEST=str(folder))
    for width in ('620', '1040'):
        (folder/'job.json').unlink(missing_ok=True)
        result = subprocess.run(['qs', '--path', str(folder/'Test.qml'), '--no-color'],
                                env=dict(env, SPECTRUM_APP_STORE_WIDTH=width), capture_output=True, text=True, timeout=65)
        output = result.stdout+result.stderr
        print('Widget width:', width)
        print(output, end='')
        if result.returncode or not re.search(r'App Store checks: \d+ passed 0 failed', output):
            raise SystemExit(1)
