import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest
import uuid
from datetime import datetime, timezone

BINARY=Path(os.environ.get('QUESTLINE_TEST_BINARY',str(Path.home()/'.local/bin/questline')))

class QuestlineAutosaveTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(prefix='questline-autosave-test-')
        self.addCleanup(self.temporary.cleanup)
        self.storage=Path(self.temporary.name)
        self.env=dict(os.environ,QUESTLINE_STORAGE_DIR=str(self.storage))
        self.db=self.storage/'questline.db';self.db.touch()
        result=subprocess.run([str(BINARY),'shell-action','{}'],env=self.env,capture_output=True,text=True,timeout=20)
        self.assertNotEqual(result.returncode,0)
        self.campaign=str(uuid.uuid4());now=datetime.now(timezone.utc).isoformat()
        with sqlite3.connect(self.db) as db:
            db.execute('INSERT INTO users (id,username,class,level,xp,created_at) VALUES (?,?,?,?,?,?)',(str(uuid.uuid4()),'Widget Test','Task Paladin',1,0,now))
            db.execute('INSERT INTO projects (id,name,created_at,updated_at,archived,completed,is_shared) VALUES (?,?,?,?,0,0,0)',(self.campaign,'Autosave Test',now,now))
    def action(self,request):
        result=subprocess.run([str(BINARY),'shell-action',json.dumps(request)],env=self.env,capture_output=True,text=True,timeout=20)
        self.assertEqual(result.returncode,0,result.stderr)
        return json.loads(result.stdout)
    def scalar(self,query):
        with sqlite3.connect(self.db) as db:return db.execute(query).fetchone()[0]
    def test_scroll_retry_updates_same_row_and_autosave_does_not_farm_xp(self):
        request={'action':'create_scroll','project_id':self.campaign,'title':'Scroll','content':'First','autosave':True,'autosave_id':str(uuid.uuid4())}
        first=self.action(request);xp=self.scalar('SELECT xp FROM users')
        request['content']='Second'
        second=self.action(request)
        self.assertEqual(first['id'],second['id'])
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM notes'),1)
        self.assertEqual(self.scalar('SELECT markdown_content FROM notes'),'Second')
        self.assertEqual(self.scalar('SELECT xp FROM users'),xp)
        request.update(action='update_scroll',id=first['id'],content='Third')
        self.action(request)
        self.assertEqual(self.scalar('SELECT xp FROM users'),xp)
        request['autosave']=False;request['content']='Explicit edit'
        self.action(request)
        self.assertEqual(self.scalar('SELECT xp FROM users'),xp+2)
    def test_task_step_and_sidequest_creation_retries_do_not_duplicate(self):
        task={'action':'create_task','title':'Quest','description':'One','project_id':self.campaign,'priority':'Medium','autosave':True,'autosave_id':str(uuid.uuid4())}
        result=self.action(task);xp=self.scalar('SELECT xp FROM users')
        task['description']='Two';self.action(task)
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM tasks'),1)
        self.assertEqual(self.scalar('SELECT description FROM tasks'),'Two')
        self.assertEqual(self.scalar('SELECT xp FROM users'),xp)
        step={'action':'create_step','parent_id':result['id'],'title':'Step','description':'One','autosave':True,'autosave_id':str(uuid.uuid4())}
        first=self.action(step);step['description']='Two';second=self.action(step)
        self.assertEqual(first['id'],second['id']);self.assertEqual(self.scalar('SELECT COUNT(*) FROM tasks'),2)
        side={'action':'create_sidequest','title':'Routine','description':'One','frequency':'Daily','reward_xp':20,'autosave':True,'autosave_id':str(uuid.uuid4())}
        before=self.scalar('SELECT COUNT(*) FROM rituals')
        first=self.action(side);side['frequency']='Weekly';second=self.action(side)
        self.assertEqual(first['id'],second['id']);self.assertEqual(self.scalar('SELECT COUNT(*) FROM rituals'),before+1)
        self.assertEqual(self.scalar("SELECT frequency FROM rituals WHERE name='Routine'"),'Weekly')
    def test_treasury_retry_uses_canonical_updates_and_can_change_new_entry_type(self):
        entry={'action':'create_entry','project_id':self.campaign,'title':'Expense','amount_minor':1200,'entry_type':'Expense','status':'Planned','autosave':True,'autosave_id':str(uuid.uuid4())}
        first=self.action(entry);entry.update(title='Income',amount_minor=1500,entry_type='Income')
        second=self.action(entry)
        self.assertEqual(first['id'],second['id'])
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM ledger_entries'),1)
        self.assertEqual(self.scalar('SELECT amount_minor FROM ledger_entries'),1500)
        self.assertEqual(self.scalar('SELECT entry_type FROM ledger_entries'),'Income')

if __name__=='__main__':unittest.main()
