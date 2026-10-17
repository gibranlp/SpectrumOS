import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/questline-widget-state'

class WidgetStateTests(unittest.TestCase):
    def test_roundtrip_keeps_unicode_drafts_and_private_permissions(self):
        with tempfile.TemporaryDirectory() as temporary:
            env = dict(os.environ, XDG_STATE_HOME=temporary)
            state = {'version':1,'activeTab':'Scrolls','views':{'Scrolls':{'editing':True,'body':'Borrador 🐱\ntexto'}}}
            result = subprocess.run([str(SCRIPT),'write'],input=json.dumps(state)+'\n',text=True,capture_output=True,env=env)
            self.assertEqual(result.returncode,0,result.stdout)
            path = Path(temporary)/'spectrumos/questline-widget.json'
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
            result = subprocess.run([str(SCRIPT),'read'],text=True,capture_output=True,env=env)
            self.assertEqual(json.loads(result.stdout)['state'],state)
            self.assertEqual(list(path.parent.glob('.questline-widget-*')),[])
    def test_bad_input_does_not_replace_existing_draft(self):
        with tempfile.TemporaryDirectory() as temporary:
            env = dict(os.environ,XDG_STATE_HOME=temporary)
            path = Path(temporary)/'spectrumos/questline-widget.json'
            path.parent.mkdir();path.write_text('{"version":1,"draft":"precious"}')
            original = path.read_bytes()
            for value in ['not JSON','[]','{"version":2}']:
                result = subprocess.run([str(SCRIPT),'write'],input=value+'\n',text=True,capture_output=True,env=env)
                self.assertNotEqual(result.returncode,0)
                self.assertEqual(path.read_bytes(),original)
    def test_first_open_and_corrupt_file_are_distinct(self):
        with tempfile.TemporaryDirectory() as temporary:
            env = dict(os.environ,XDG_STATE_HOME=temporary)
            result=subprocess.run([str(SCRIPT),'read'],text=True,capture_output=True,env=env)
            self.assertEqual(json.loads(result.stdout),{'state':{'version':1}})
            path=Path(temporary)/'spectrumos/questline-widget.json';path.parent.mkdir();path.write_text('broken')
            result=subprocess.run([str(SCRIPT),'read'],text=True,capture_output=True,env=env)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(path.read_text(),'broken')

if __name__=='__main__':unittest.main()
