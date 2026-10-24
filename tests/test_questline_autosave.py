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
        result=subprocess.run([str(BINARY),'shell-action','{"action":"status"}'],env=self.env,capture_output=True,text=True,timeout=20)
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
    def treasury_choices(self):
        self.action({'action':'create_entry','project_id':self.campaign,'title':'Seed','amount_minor':100,'entry_type':'Expense','status':'Planned'})
        with sqlite3.connect(self.db) as db:
            accounts=dict(db.execute('SELECT name,id FROM treasury_accounts WHERE campaign_id=?',(self.campaign,)))
            categories=dict(db.execute('SELECT name,id FROM ledger_categories WHERE campaign_id=?',(self.campaign,)))
        return accounts,categories
    def test_treasury_full_transfer_roundtrip_and_clear_optional_fields(self):
        accounts,categories=self.treasury_choices()
        task=self.action({'action':'create_task','project_id':self.campaign,'title':'Linked task','priority':'Medium'})
        request={'action':'create_entry','project_id':self.campaign,'title':'Move savings','amount_minor':4500,
                 'entry_type':'Transfer','status':'Paid','account_id':accounts['Spending'],
                 'transfer_account_id':accounts['Savings'],'category_id':categories['Internal Transfer'],
                 'description':'Monthly reserve','entry_date':'2026-09-05','due_date':'2026-09-07',
                 'payment_date':'2026-09-06','vendor_source':'Bank','notes':'Keep receipt',
                 'attachment_ref':'receipts/transfer.pdf','recurrence':'Custom','custom_recurrence':'Every 6 weeks',
                 'related_task_id':task['id'],'autosave':True,'autosave_id':str(uuid.uuid4())}
        first=self.action(request);second=self.action(request)
        self.assertEqual(first['id'],second['id'])
        with sqlite3.connect(self.db) as db:
            db.row_factory=sqlite3.Row
            entry=dict(db.execute('SELECT * FROM ledger_entries WHERE id=?',(first['id'],)).fetchone())
        for name in ('account_id','transfer_account_id','category_id','description','vendor_source','notes','attachment_ref','recurrence','custom_recurrence','related_task_id'):
            self.assertEqual(entry[name],request[name],name)
        self.assertTrue(entry['created_at'].startswith('2026-09-05'))
        self.assertTrue(entry['due_date'].startswith('2026-09-07'))
        self.assertTrue(entry['payment_date'].startswith('2026-09-06'))
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM ledger_entries'),2)
        request.update(action='update_entry',id=first['id'],entry_type='Expense',category_id=categories['Food'],
                       account_id=accounts['Cash'],transfer_account_id='',due_date='',payment_date='',
                       notes='',attachment_ref='',vendor_source='',related_task_id='',recurrence='None',custom_recurrence='')
        self.action(request)
        with sqlite3.connect(self.db) as db:
            db.row_factory=sqlite3.Row
            updated=dict(db.execute('SELECT * FROM ledger_entries WHERE id=?',(first['id'],)).fetchone())
        self.assertEqual(updated['category_id'],categories['Food'])
        self.assertEqual(updated['account_id'],accounts['Cash'])
        for name in ('transfer_account_id','due_date','notes','attachment_ref','vendor_source','related_task_id','custom_recurrence'):
            self.assertIsNone(updated[name],name)
        self.assertIsNotNone(updated['payment_date'])
        self.assertEqual(updated['recurrence'],'None')
        self.assertGreater(self.scalar("SELECT COUNT(*) FROM sync_log WHERE entity_type='ledger_entry'"),0)
    def test_treasury_rejects_mismatched_fields_without_changing_entry(self):
        accounts,categories=self.treasury_choices()
        request={'action':'create_entry','project_id':self.campaign,'title':'Valid','amount_minor':400,
                 'entry_type':'Expense','status':'Planned','account_id':accounts['Cash'],'category_id':categories['Food']}
        entry=self.action(request)
        base=dict(request,action='update_entry',id=entry['id'],title='Invalid')
        for override in ({'category_id':categories['Salary']},{'category_id':str(uuid.uuid4())},
                         {'account_id':str(uuid.uuid4())},{'transfer_account_id':accounts['Savings']},
                         {'entry_type':'Transfer','category_id':categories['Internal Transfer'],'transfer_account_id':accounts['Cash']},
                         {'entry_type':'Transfer','category_id':categories['Internal Transfer'],'transfer_account_id':''},
                         {'due_date':'2026-02-31'},{'entry_date':''},{'recurrence':'Custom','custom_recurrence':''},
                         {'related_task_id':str(uuid.uuid4())},{'profile_key':'stale'}):
            result=subprocess.run([str(BINARY),'shell-action',json.dumps(dict(base,**override))],env=self.env,capture_output=True,text=True,timeout=20)
            self.assertNotEqual(result.returncode,0,override)
        with sqlite3.connect(self.db) as db:
            self.assertEqual(db.execute('SELECT title,category_id,account_id FROM ledger_entries WHERE id=?',(entry['id'],)).fetchone(),('Valid',categories['Food'],accounts['Cash']))
    def test_treasury_partial_updates_keep_existing_metadata_and_timestamp(self):
        accounts,categories=self.treasury_choices()
        request={'action':'create_entry','project_id':self.campaign,'title':'Initial','amount_minor':400,
                 'entry_type':'Expense','status':'Planned','account_id':accounts['Cash'],'category_id':categories['Food'],
                 'description':'Keep this','notes':'Original notes'}
        entry=self.action(request)
        with sqlite3.connect(self.db) as db:
            before=db.execute('SELECT created_at,category_id,account_id,notes,description FROM ledger_entries WHERE id=?',(entry['id'],)).fetchone()
        self.action({'action':'update_entry','id':entry['id'],'title':'Retitled','amount_minor':450,'entry_type':'Expense','status':'Planned'})
        with sqlite3.connect(self.db) as db:
            after=db.execute('SELECT created_at,category_id,account_id,notes,description FROM ledger_entries WHERE id=?',(entry['id'],)).fetchone()
        self.assertEqual(before,after)

    def custom_account(self,name,kind):
        identity=str(uuid.uuid4());now=datetime.now(timezone.utc).isoformat()
        with sqlite3.connect(self.db) as db:
            db.execute("INSERT INTO treasury_accounts (id,campaign_id,name,kind,is_default,version,created_at,updated_at) VALUES (?,?,?,?,0,1,?,?)",(identity,self.campaign,name,kind,now,now))
        return identity
    def test_savings_configuration_estimates_and_separate_available_totals(self):
        accounts,categories=self.treasury_choices()
        checking=self.custom_account('My checking','Spending');saving=self.custom_account('My savings','Savings')
        self.action({'action':'create_entry','project_id':self.campaign,'title':'Income','amount_minor':100000,'entry_type':'Income','status':'Paid','account_id':checking,'category_id':categories['Salary'],'custom_accounts_only':True})
        self.action({'action':'create_entry','project_id':self.campaign,'title':'Save','amount_minor':40000,'entry_type':'Transfer','status':'Paid','account_id':checking,'transfer_account_id':saving,'category_id':categories['Internal Transfer'],'custom_accounts_only':True})
        count=self.scalar('SELECT COUNT(*) FROM ledger_entries')
        self.action({'action':'configure_savings','id':saving,'version':1,'savings_status':'Invested','interest_rate':'12.50','interest_period':'Annual'})
        snapshot=self.action({'action':'treasury_snapshot','project_id':self.campaign})
        totals=snapshot['totals'];self.assertEqual((totals['available_minor'],totals['saved_minor'],totals['invested_minor'],totals['liquid_savings_minor']),(60000,40000,40000,0))
        row=next(item for item in snapshot['accounts'] if item['account']['id']==saving)
        self.assertEqual(row['balance_minor'],40000)
        self.assertEqual(row['account']['interest_rate_bps'],1250)
        self.assertEqual(row['account']['interest_period'],'Annual')
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM ledger_entries'),count)
        self.action({'action':'configure_savings','id':saving,'version':2,'savings_status':'Available','interest_rate':'1.25','interest_period':'Monthly'})
        snapshot=self.action({'action':'treasury_snapshot','project_id':self.campaign})
        self.assertEqual(snapshot['totals']['invested_minor'],0)
        self.assertEqual(snapshot['totals']['liquid_savings_minor'],40000)
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM ledger_entries'),count)
        for override in ({'version':1},{'interest_rate':'1.234'},{'interest_rate':'-1'},{'savings_status':'Unknown'},{'interest_period':'Daily'},{'id':checking}):
            request=dict(action='configure_savings',id=saving,version=3,savings_status='Available',interest_rate='1.25',interest_period='Monthly')
            request.update(override)
            result=subprocess.run([str(BINARY),'shell-action',json.dumps(request)],env=self.env,capture_output=True,text=True,timeout=20)
            self.assertNotEqual(result.returncode,0,override)
    def test_widget_custom_account_policy_rejects_new_defaults_but_keeps_existing_links(self):
        accounts,categories=self.treasury_choices()
        base={'action':'create_entry','project_id':self.campaign,'title':'Default rejected','amount_minor':100,'entry_type':'Expense','status':'Planned','account_id':accounts['Spending'],'category_id':categories['Food'],'custom_accounts_only':True}
        result=subprocess.run([str(BINARY),'shell-action',json.dumps(base)],env=self.env,capture_output=True,text=True,timeout=20)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM ledger_entries'),1)
        legacy=self.action(dict(base,custom_accounts_only=False))
        self.action(dict(base,action='update_entry',id=legacy['id'],title='Existing link kept'))
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM ledger_entries'),2)
    def test_old_account_schema_migrates_without_replacing_accounts(self):
        self.treasury_choices();saving=self.custom_account('Original savings','Savings')
        with sqlite3.connect(self.db) as db:
            for column in ('savings_status','interest_rate_bps','interest_period'):
                db.execute('ALTER TABLE treasury_accounts DROP COLUMN '+column)
            db.execute('PRAGMA user_version=4')
        snapshot=self.action({'action':'treasury_snapshot','project_id':self.campaign})
        row=next(item['account'] for item in snapshot['accounts'] if item['account']['id']==saving)
        self.assertEqual(row['name'],'Original savings')
        self.assertFalse(row['is_default'])
        self.assertEqual((row['savings_status'],row['interest_rate_bps'],row['interest_period']),('Available',0,'Annual'))

    def test_chronicle_retry_keeps_one_entry_and_rewards_once(self):
        request={'action':'create_chronicle','project_id':self.campaign,'content':'First daily log','autosave':True,'autosave_id':str(uuid.uuid4())}
        first=self.action(request)
        xp=self.scalar('SELECT xp FROM users')
        request['content']='Updated daily log'
        second=self.action(request)
        self.assertEqual(first['id'],second['id'])
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM journal_entries'),1)
        self.assertEqual(self.scalar('SELECT content FROM journal_entries'),'Updated daily log')
        self.assertEqual(self.scalar('SELECT author_username FROM journal_entries'),'Widget Test')
        self.assertEqual(self.scalar('SELECT visibility FROM journal_entries'),'Private')
        self.assertEqual(self.scalar('SELECT xp FROM users'),xp)
        request.update(action='update_chronicle',id=first['id'],content='Edited again')
        self.action(request)
        self.assertEqual(self.scalar('SELECT content FROM journal_entries'),'Edited again')
        self.assertEqual(self.scalar('SELECT xp FROM users'),xp)
        self.assertGreater(self.scalar("SELECT COUNT(*) FROM sync_log WHERE entity_type='journal_entry'"),0)
    def test_chronicle_rejects_invalid_content_campaign_and_stale_profile(self):
        base={'action':'create_chronicle','project_id':self.campaign,'content':'A valid log'}
        for override in ({'content':''},{'content':'x'*256},{'project_id':str(uuid.uuid4())},{'profile_key':'another-profile'}):
            result=subprocess.run([str(BINARY),'shell-action',json.dumps(dict(base,**override))],env=self.env,capture_output=True,text=True,timeout=20)
            self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM journal_entries'),0)
        with sqlite3.connect(self.db) as db:db.execute('UPDATE projects SET is_shared=1')
        result=subprocess.run([str(BINARY),'shell-action',json.dumps(base)],env=self.env,capture_output=True,text=True,timeout=20)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM journal_entries'),0)

if __name__=='__main__':unittest.main()
