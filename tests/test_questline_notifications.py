import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import time
import unittest
import uuid
from datetime import datetime,timezone

BINARY=Path(os.environ.get('QUESTLINE_TEST_BINARY',str(Path.home()/'.local/bin/questline')))

class QuestlineNotificationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='questline-notification-test-');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.db=self.root/'questline.db';self.db.touch()
        commands=self.root/'bin';commands.mkdir();self.log=self.root/'notifications.jsonl'
        sender=commands/'notify-send'
        sender.write_text("#!/usr/bin/env python3\nimport json,os,sys\nwith open(os.environ['QUESTLINE_TEST_NOTIFICATIONS_LOG'],'a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')\n")
        sender.chmod(0o755)
        self.env=dict(os.environ,QUESTLINE_STORAGE_DIR=str(self.root),QUESTLINE_TEST_NOTIFICATIONS_LOG=str(self.log),PATH=str(commands)+os.pathsep+os.environ.get('PATH',''))
        subprocess.run([str(BINARY),'shell-action','{"action":"status"}'],env=self.env,capture_output=True,text=True,timeout=20)
        self.campaign=str(uuid.uuid4());self.task=str(uuid.uuid4());now=datetime.now(timezone.utc).isoformat()
        with sqlite3.connect(self.db) as db:
            db.execute('INSERT INTO users (id,username,class,level,xp,created_at) VALUES (?,?,?,?,?,?)',(str(uuid.uuid4()),'Hero','Task Paladin',1,210,now))
            db.execute('INSERT INTO projects (id,name,created_at,updated_at) VALUES (?,?,?,?)',(self.campaign,'Test campaign',now,now))
            db.execute('INSERT INTO tasks (id,project_id,title,created_at,updated_at) VALUES (?,?,?,?,?)',(self.task,self.campaign,'Defeat the backlog',now,now))
    def complete(self):
        return subprocess.run([str(BINARY),'shell-action',json.dumps(dict(action='complete_task',id=self.task))],env=self.env,capture_output=True,text=True,timeout=20)
    def notifications(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
    def test_cli_delivers_actual_xp_and_level_before_exiting(self):
        result=self.complete();self.assertEqual(result.returncode,0,result.stderr);receipt=json.loads(result.stdout)
        with sqlite3.connect(self.db) as db:actual=db.execute('SELECT SUM(xp_gained) FROM xp_events').fetchone()[0]
        self.assertEqual(receipt['reward']['xp_gained'],actual);self.assertGreater(actual,0);self.assertTrue(receipt['reward']['level_up'])
        alerts=self.notifications();self.assertEqual(len(alerts),len(receipt['desktop_notifications']))
        self.assertTrue(any('Defeat the backlog' in alert[-1] and f'+{actual} XP' in alert[-1] for alert in alerts))
        self.assertTrue(any(alert[-2]=='Level up!' for alert in alerts))
    def test_duplicate_completion_does_not_replay_notifications(self):
        self.assertEqual(self.complete().returncode,0);before=self.notifications();self.assertNotEqual(self.complete().returncode,0);self.assertEqual(self.notifications(),before)
    def test_disabled_external_notifications_still_award_xp_without_alerts(self):
        with sqlite3.connect(self.db) as db:db.execute("INSERT OR REPLACE INTO settings VALUES ('external_notifications','false')")
        result=self.complete();self.assertEqual(result.returncode,0,result.stderr);receipt=json.loads(result.stdout)
        self.assertFalse(receipt['notifications_enabled']);self.assertGreater(receipt['reward']['xp_gained'],0);self.assertEqual(self.notifications(),[])
    def test_background_notifier_is_singleton_and_starts_without_old_rewards(self):
        process=subprocess.Popen([str(BINARY),'desktop-notifications'],env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
        try:
            deadline=time.monotonic()+5
            while not (self.root/'desktop-notifications.lock').exists() and time.monotonic()<deadline:time.sleep(0.02)
            self.assertIsNone(process.poll())
            second=subprocess.run([str(BINARY),'desktop-notifications'],env=self.env,capture_output=True,text=True,timeout=5)
            self.assertEqual(second.returncode,0,second.stderr);self.assertEqual(self.notifications(),[])
        finally:
            process.terminate();process.communicate(timeout=5)
    def action(self,action,**payload):
        result=subprocess.run([str(BINARY),'shell-action',json.dumps(dict(action=action,**payload))],env=self.env,capture_output=True,text=True,timeout=20)
        self.assertEqual(result.returncode,0,result.stderr);return json.loads(result.stdout)
    def pending_reminder(self,day=None):
        from datetime import date
        token=str(uuid.uuid4());state=dict(token=token,day=day or date.today().isoformat(),count=0,target=1,pending=True,acknowledged_at=None)
        (self.root/'questline.hydration.json').write_text(json.dumps(state))
        with sqlite3.connect(self.db) as db:
            for key,value in [('hydration_enabled','true'),('hydration_interval_mins','30'),('hydration_target','1')]:db.execute('INSERT OR REPLACE INTO settings VALUES (?,?)',(key,value))
        return token
    def test_drink_button_counts_once_and_awards_the_daily_target_once(self):
        token=self.pending_reminder();receipt=self.action('drink_water',reminder_token=token)
        self.assertTrue(receipt['recorded']);self.assertEqual(receipt['count'],1);self.assertEqual(receipt['target'],1);self.assertGreater(receipt['reward']['xp_gained'],0)
        notices=self.notifications();progress=[args for args in notices if '--hint=string:x-questline-kind:hydration-progress' in args]
        self.assertEqual(len(progress),1);self.assertIn('1/1 today',progress[0][-1]);self.assertIn('--expire-time=8000',progress[0])
        repeated=self.action('drink_water',reminder_token=token);self.assertFalse(repeated['recorded']);self.assertEqual(repeated['reward']['xp_gained'],0);self.assertEqual(self.notifications(),notices)
    def test_dismissing_water_does_not_count_a_drink(self):
        token=self.pending_reminder();receipt=self.action('dismiss_hydration_reminder',reminder_token=token);self.assertTrue(receipt['dismissed'])
        with sqlite3.connect(self.db) as db:self.assertEqual(db.execute('SELECT COALESCE(SUM(count),0) FROM hydration_log').fetchone()[0],0)
        state=json.loads((self.root/'questline.hydration.json').read_text());self.assertFalse(state['pending']);self.assertIsInstance(state['acknowledged_at'],int);self.assertEqual(self.notifications(),[])
    def test_old_reminder_cannot_count_a_drink_on_a_new_day(self):
        token=self.pending_reminder('2000-01-01');receipt=self.action('drink_water',reminder_token=token);self.assertFalse(receipt['recorded']);self.assertEqual(receipt['count'],0);self.assertEqual(self.notifications(),[])
    def test_background_water_is_persistent_and_resumes_the_same_reminder(self):
        from datetime import date
        state=dict(token=str(uuid.uuid4()),day=date.today().isoformat(),count=0,target=12,pending=False,acknowledged_at=int(time.time())-3600)
        (self.root/'questline.hydration.json').write_text(json.dumps(state))
        with sqlite3.connect(self.db) as db:
            for key,value in [('hydration_enabled','true'),('hydration_interval_mins','30'),('hydration_active_from','0'),('hydration_active_to','24'),('hydration_target','12')]:db.execute('INSERT OR REPLACE INTO settings VALUES (?,?)',(key,value))
        tokens=[]
        for iteration in range(2):
            process=subprocess.Popen([str(BINARY),'desktop-notifications'],env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
            try:
                deadline=time.monotonic()+5
                while len(self.notifications())<iteration+1 and time.monotonic()<deadline:time.sleep(0.02)
                alerts=self.notifications();self.assertEqual(len(alerts),iteration+1)
                notice=alerts[-1];self.assertIn('--expire-time=0',notice);self.assertIn('--hint=string:x-questline-kind:hydration',notice);self.assertIn('0/12 today',notice[-1]);tokens.append(next(a for a in notice if a.startswith('--hint=string:x-questline-reminder-token:')))
            finally:
                process.terminate();process.communicate(timeout=5)
        self.assertEqual(tokens[0],tokens[1])
