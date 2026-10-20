import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch,Mock

ROOT=Path(__file__).resolve().parents[1]
loader=importlib.machinery.SourceFileLoader('favorites_adapter',str(ROOT/'scripts/favorites-adapter'))
spec=importlib.util.spec_from_loader(loader.name,loader);backend=importlib.util.module_from_spec(spec);loader.exec_module(backend)

class FavoritesTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.root=Path(self.temporary.name)
        self.environment=patch.dict(os.environ,SPECTRUM_FAVORITES_QUESTLINE='disabled',XDG_STATE_HOME=str(self.root/'state'),XDG_CACHE_HOME=str(self.root/'cache'))
        self.environment.start()
    def tearDown(self):self.environment.stop();self.temporary.cleanup()
    def action(self,action,**payload):return backend.main(action,payload)
    def view(self,editor,draft,category='top',search=''):
        return self.action('view-save',view=dict(editor=editor,draft=draft,category=category,search=search))
    def favorite(self,id='favorite',title='Portal',url='https://example.com/',category='uncategorized'):
        return self.view('favorite',dict(id=id,title=title,url=url,category=category))
    def fixture(self,links):
        p=self.root/'backup.json';p.write_text(json.dumps(dict(personal=dict(links=links,notes=['DO NOT IMPORT']),shared_projects=[{'url':'https://ignore.invalid'}])));return str(p)
    def test_new_state_has_top_view_and_uncategorized(self):
        state=self.action('status')['state'];self.assertEqual(state['view']['category'],'top');self.assertEqual(state['categories'],[dict(id='uncategorized',name='Uncategorized')])
    def test_autosave_creates_then_updates_without_duplicates(self):
        self.favorite();state=self.favorite(title='Edited')['state'];self.assertEqual(len(state['favorites']),1);self.assertEqual(state['favorites'][0]['title'],'Edited')
    def test_incomplete_draft_survives_new_read_without_creating_link(self):
        result=self.favorite(url='https://');self.assertTrue(result['draftError']);state=self.action('status')['state'];self.assertEqual(state['view']['draft']['url'],'https://');self.assertFalse(state['favorites'])
    def test_category_create_rename_and_favorite_assignment(self):
        self.view('category',dict(id='games',name='Games'));self.favorite(category='games');state=self.view('category',dict(id='games',name='Play'))['state'];self.assertEqual(state['categories'][1]['name'],'Play');self.assertEqual(state['favorites'][0]['category'],'games')
    def test_duplicate_category_rejected_but_draft_kept(self):
        self.view('category',dict(id='a',name='Games'));result=self.view('category',dict(id='b',name='games'));self.assertTrue(result['draftError']);self.assertEqual(len(result['state']['categories']),2)
    def test_nonempty_category_cannot_be_deleted(self):
        self.view('category',dict(id='games',name='Games'));self.favorite(category='games')
        before=self.action('status')['state']
        with self.assertRaisesRegex(ValueError,'Move or delete all favorites'):self.action('category-delete',id='games')
        self.assertEqual(self.action('status')['state'],before)
    def test_empty_category_deletes_after_last_favorite_removed(self):
        self.view('category',dict(id='games',name='Games'));self.favorite(category='games')
        self.action('favorite-delete',id='favorite');state=self.action('category-delete',id='games')['state']
        self.assertEqual([c['id'] for c in state['categories']],['uncategorized']);self.assertEqual(state['view']['category'],'uncategorized')
    def test_reserved_categories_cannot_be_deleted(self):
        for id in ('top','uncategorized'):
            with self.assertRaises(ValueError):self.action('category-delete',id=id)
    def test_duplicate_url_rejected_without_overwriting_existing(self):
        self.favorite();result=self.favorite(id='duplicate',title='Other');self.assertTrue(result['draftError']);self.assertEqual(len(result['state']['favorites']),1);self.assertEqual(result['state']['favorites'][0]['title'],'Portal')
    def test_favorite_delete_keeps_other_links(self):
        self.favorite();self.favorite(id='second',url='https://other.example');state=self.action('favorite-delete',id='favorite')['state'];self.assertEqual([x['id'] for x in state['favorites']],['second'])
    def test_launch_uses_default_browser_and_increments_counter(self):
        self.favorite()
        with patch.object(backend.subprocess,'Popen') as popen:
            popen.return_value.wait.return_value=0
            state=self.action('open',id='favorite')['state'];self.assertEqual(state['favorites'][0]['clickCount'],1);self.assertEqual(popen.call_args.args[0],['uwsm','app','--','gio','open','https://example.com/'])
    def test_launch_clears_browser_override_and_detaches_from_adapter(self):
        self.favorite(url='https://example.com/path?next=a&value=b#anchor')
        with patch.dict(os.environ,BROWSER='other-browser'),patch.object(backend.subprocess,'Popen') as popen:
            popen.return_value.wait.return_value=0
            self.action('open',id='favorite')
            self.assertEqual(popen.call_args.args[0],['uwsm','app','--','gio','open','https://example.com/path?next=a&value=b#anchor'])
            options=popen.call_args.kwargs
            self.assertNotIn('BROWSER',options['env'])
            self.assertTrue(options['start_new_session'])
            for stream in ('stdin','stdout','stderr'):self.assertEqual(options[stream],subprocess.DEVNULL)
    def test_failed_launch_does_not_increment(self):
        self.favorite()
        with patch.object(backend.subprocess,'Popen') as popen:
            popen.return_value.wait.return_value=1
            with self.assertRaises(ValueError):self.action('open',id='favorite')
        self.assertEqual(self.action('status')['state']['favorites'][0]['clickCount'],0)
    def test_long_running_browser_is_not_killed(self):
        self.favorite()
        with patch.object(backend.subprocess,'Popen') as popen:
            popen.return_value.wait.side_effect=subprocess.TimeoutExpired('uwsm',2)
            self.assertEqual(self.action('open',id='favorite')['state']['favorites'][0]['clickCount'],1);popen.return_value.kill.assert_not_called()
    def test_dangerous_urls_and_credentials_rejected(self):
        for url in ['javascript:alert(1)','file:///etc/passwd','data:text/html,hi','https://u:p@example.com','https://exa mple.com','https://example.com:99999','--help','https://example.com\\evil']:
            self.assertTrue(self.favorite(url=url)['draftError'])
    def test_url_normalization_preserves_query_and_fragment(self):
        self.assertEqual(backend.valid_url('https://EXAMPLE.com/path?token=a&next=b#anchor'),'https://example.com/path?token=a&next=b#anchor')
    def test_import_preview_reads_only_personal_links(self):
        path=self.fixture([dict(title='One',url='https://one.example',category='Work',clickCount=8),dict(title='Bad',url='file:///etc/passwd')])
        p=self.action('import-preview',path=path)['preview'];self.assertEqual((p['valid'],p['invalid'],p['added']),(1,1,1));self.assertFalse(self.action('status')['state']['favorites'])
    def test_import_preserves_counts_categories_and_reimport_is_idempotent(self):
        path=self.fixture([dict(title='One',url='https://one.example',category='Work',clickCount=8)])
        self.action('import-apply',path=path);state=self.action('import-apply',path=path)['state'];self.assertEqual(len(state['favorites']),1);self.assertEqual(state['favorites'][0]['clickCount'],8);self.assertEqual(state['categories'][1]['name'],'Work')
    def test_import_does_not_replace_higher_local_counts(self):
        self.favorite();path=self.fixture([dict(title='Other',url='https://example.com',clickCount=10)])
        self.action('import-apply',path=path)
        p=self.fixture([dict(title='Other',url='https://example.com',clickCount=2)])
        item=self.action('import-apply',path=p)['state']['favorites'][0];self.assertEqual(item['clickCount'],10);self.assertEqual(item['title'],'Portal')
    def test_import_top_is_an_ordinary_renamed_category(self):
        state=self.action('import-apply',path=self.fixture([dict(title='One',url='https://one.example',category='TOP')]))['state'];self.assertEqual(state['categories'][1]['name'],'Imported TOP')
    def test_export_only_links_and_round_trip(self):
        self.favorite();path=self.root/'export.json';self.action('export',path=str(path));doc=json.loads(path.read_text());self.assertEqual(set(doc),{'format','version','links'});links,invalid=backend.load_import(path);self.assertEqual(invalid,0);self.assertEqual(links[0]['title'],'Portal')
    def test_export_cannot_replace_live_state(self):
        with self.assertRaises(ValueError):self.action('export',path=str(backend.directory()/'favorites.json'))
    def test_private_permissions(self):
        self.favorite();self.assertEqual(stat.S_IMODE((backend.directory()/'favorites.json').stat().st_mode),0o600);self.assertEqual(stat.S_IMODE(backend.directory().stat().st_mode),0o700)
    def test_corrupt_state_not_overwritten(self):
        backend.directory().mkdir(parents=True);path=backend.directory()/'favorites.json';path.write_text('{broken')
        with self.assertRaises(ValueError):self.favorite()
        self.assertEqual(path.read_text(),'{broken')
    def test_favicon_cache_is_local_and_bad_download_uses_fallback(self):
        self.favorite()
        with patch.object(backend,'urlopen',side_effect=OSError('offline')):backend.fetch_icon('https://example.com/')
        self.assertEqual(backend.icon_path('https://example.com/'),'');self.assertTrue(list(backend.cache_directory().glob('*.checked')))
    def test_invalid_counters_are_zero(self):
        for value in (-1,True,'123',float('inf'),float('nan')):self.assertEqual(backend.counter(value),0)
    def test_browser_set_validates_against_installed_list(self):
        with patch.object(backend,'browser_catalog',return_value=dict(browsers=[],defaultBrowser='',httpBrowser='')):
            with self.assertRaises(ValueError):backend.set_browser('injected.desktop')
    def test_browser_set_changes_http_https_and_html(self):
        old=dict(browsers=[dict(id='browser.desktop')],defaultBrowser='old.desktop',httpBrowser='old.desktop')
        new=dict(old,defaultBrowser='browser.desktop',httpBrowser='browser.desktop')
        with patch.object(backend,'browser_catalog',side_effect=[old,new]),patch.object(backend.subprocess,'run',return_value=Mock(returncode=0)) as run:
            result=backend.set_browser('browser.desktop');self.assertEqual(result['defaultBrowser'],'browser.desktop')
            commands=[c.args[0] for c in run.call_args_list]
            for mime in ['x-scheme-handler/http','x-scheme-handler/https','text/html']:self.assertIn(['xdg-mime','default','browser.desktop',mime],commands)

    def html_fixture(self,body,name='bookmarks.html'):
        path=self.root/name;path.write_text('<!DOCTYPE NETSCAPE-Bookmark-file-1><META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8"><TITLE>Bookmarks</TITLE><H1>Bookmarks</H1>'+body)
        return str(path)
    def test_brave_chrome_firefox_html_exports_use_same_import(self):
        for browser,attrs in [('Brave','PERSONAL_TOOLBAR_FOLDER="true"'),('Chrome','ADD_DATE="1234"'),('Firefox','LAST_MODIFIED="4567"')]:
            with self.subTest(browser=browser):
                path=self.html_fixture('<DL><p><DT><H3 '+attrs+'>Bookmarks bar</H3><DL><p><DT><A HREF="https://example.com/'+browser+'" ADD_DATE="1" ICON="data:image/png;base64,ignored">A &amp; B</A></DL><p></DL>')
                links,invalid=backend.load_import(path);self.assertEqual(invalid,0);self.assertEqual(links[0]['title'],'A & B');self.assertEqual(links[0]['category'],'Bookmarks bar');self.assertEqual(links[0]['clickCount'],0)
    def test_nested_html_folder_paths_do_not_flatten_same_named_folders(self):
        path=self.html_fixture('<DL><DT><H3>Work</H3><DL><DT><H3>Research</H3><DL><DT><A HREF="https://one.example">One</A></DL></DL><DT><H3>Home</H3><DL><DT><H3>Research</H3><DL><DT><A HREF="https://two.example">Two</A></DL></DL></DL>')
        links,invalid=backend.load_import(path);self.assertEqual([x['category'] for x in links],['Work / Research','Home / Research'])
    def test_html_top_level_links_and_empty_folders(self):
        path=self.html_fixture('<DL><DT><A HREF="https://one.example">One</A><DT><H3>Empty</H3><DL></DL><DT><A HREF="https://two.example">Two</A></DL>')
        state=self.action('import-apply',path=path)['state'];self.assertEqual(len(state['categories']),1);self.assertEqual(len(state['favorites']),2)
    def test_html_bookmarklets_and_local_files_are_skipped(self):
        path=self.html_fixture('<DL><DT><A HREF="javascript:alert(1)">Bookmarklet</A><DT><A HREF="file:///etc/passwd">File</A><DT><A HREF="https://example.com/?a=1&amp;b=2#part">Site</A></DL>')
        links,invalid=backend.load_import(path);self.assertEqual(invalid,2);self.assertEqual(links[0]['url'],'https://example.com/?a=1&b=2#part')
    def test_html_import_merges_existing_url_and_keeps_local_counter(self):
        self.favorite();state=backend.read();state['favorites'][0]['clickCount']=9;backend.atomic(backend.directory()/'favorites.json',json.dumps(state).encode())
        path=self.html_fixture('<DL><DT><H3>Browser</H3><DL><DT><A HREF="https://example.com">Other title</A></DL></DL>')
        result=self.action('import-apply',path=path)['state'];self.assertEqual(len(result['favorites']),1);self.assertEqual(result['favorites'][0]['clickCount'],9);self.assertEqual(result['favorites'][0]['title'],'Portal')
    def test_regular_webpage_is_not_accepted_as_bookmark_export(self):
        path=self.html_fixture('<main><a href="https://one.example">One</a></main>')
        with self.assertRaises(ValueError):backend.load_import(path)
    def test_firefox_json_backup_folder_and_separators(self):
        path=self.root/'firefox.json';path.write_text(json.dumps({'root':'placesRoot','type':'text/x-moz-place-container','children':[{'title':'Bookmarks Menu','children':[{'title':'Research','children':[{'type':'text/x-moz-place','title':'One','uri':'https://one.example'},{'type':'text/x-moz-place-separator','title':''}]}]}]}))
        links,invalid=backend.load_import(path);self.assertEqual(len(links),1);self.assertEqual(links[0]['category'],'Bookmarks Menu / Research');self.assertEqual(invalid,0)
    def test_chromium_json_bookmarks_tree(self):
        path=self.root/'chrome.json';path.write_text(json.dumps({'roots':{'bookmark_bar':{'type':'folder','name':'Bookmarks bar','children':[{'type':'url','name':'One','url':'https://one.example'}]}}}))
        links,invalid=backend.load_import(path);self.assertEqual(links[0]['category'],'Bookmarks bar');self.assertEqual(invalid,0)
    def test_compressed_firefox_backup_has_actionable_error(self):
        path=self.root/'backup.jsonlz4';path.write_bytes(b'mozLz40\0compressed')
        with self.assertRaisesRegex(ValueError,'Export Bookmarks to HTML'):backend.load_import(path)
    def test_long_category_paths_are_bounded_and_distinct(self):
        first=backend.folder_category(['a'*79,'First']);second=backend.folder_category(['a'*79,'Second'])
        self.assertLessEqual(len(first),80);self.assertNotEqual(first,second)
    def test_excessive_html_folder_depth_is_rejected(self):
        path=self.html_fixture('<DL>'*66+'<A HREF="https://one.example">One</A>'+'</DL>'*66)
        with self.assertRaisesRegex(ValueError,'nesting'):backend.load_import(path)
    def test_move_changes_only_category_and_preserves_counters(self):
        self.favorite();self.view('category',dict(id='work',name='Work'))
        old=self.action('status')['state']['favorites'][0];new=self.action('favorite-move',id='favorite',category='work')['state']['favorites'][0]
        self.assertEqual(new,dict(old,category='work'))
    def test_move_rejects_top_and_missing_category(self):
        self.favorite()
        for category in ['top','missing']:
            with self.assertRaises(ValueError):self.action('favorite-move',id='favorite',category=category)
        self.assertEqual(self.action('status')['state']['favorites'][0]['category'],'uncategorized')
    def test_move_updates_active_editor_draft(self):
        self.view('category',dict(id='work',name='Work'));self.favorite()
        state=self.action('favorite-move',id='favorite',category='work')['state'];self.assertEqual(state['view']['draft']['category'],'work')
    def test_move_unknown_favorite_is_rejected(self):
        with self.assertRaises(ValueError):self.action('favorite-move',id='missing',category='uncategorized')

if __name__=='__main__':unittest.main()
