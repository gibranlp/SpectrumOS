import errno
import importlib.machinery
import importlib.util
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import wave
import xml.etree.ElementTree as ET

from PIL import Image, ImageCms

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('thunar_productivity', str(ROOT/'scripts/thunar-productivity'))
spec = importlib.util.spec_from_loader(loader.name, loader)
P = importlib.util.module_from_spec(spec)
loader.exec_module(P)


class ThunarProductivityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='spectrum-productivity-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.notify = patch.object(P.core, 'notify').start()
        self.addCleanup(patch.stopall)
        patch.object(P, 'STATE', self.root/'state').start()

    def test_copy_paths_keep_quotes_spaces_unicode_and_urls(self):
        source=self.root/"file '$() ünicode.txt";source.write_text('hello')
        for mode in ['absolute','relative','shell','url']:
            args=[str(source)] if mode!='relative' else [str(self.root),str(source)]
            with patch.object(P,'run') as run:
                P.copy_paths(mode,args)
                actual=run.call_args.kwargs['input']
                if mode=='shell':self.assertEqual(__import__('shlex').split(actual),[str(source)])
                elif mode=='url':self.assertEqual(actual,source.as_uri())
                elif mode=='relative':self.assertEqual(actual,source.name)
                else:self.assertEqual(actual,str(source))

    def test_open_project_sets_the_folder_as_terminal_and_editor_directory(self):
        source=self.root/'code.py';source.write_text('')
        with patch.object(P.subprocess,'Popen') as popen:
            P.open_project(str(source))
            self.assertEqual(popen.call_args.args[0],['xdg-terminal-exec','--dir='+str(self.root),'--','nvim','--',str(self.root)])

    def repository(self):
        repo=self.root/'repo';repo.mkdir()
        subprocess.run(['git','init','-q',str(repo)],check=True)
        return repo

    def test_git_stages_literal_filenames_and_switches_branch_only_after_dialog(self):
        repo=self.repository();source=repo/':(glob)*.txt';source.write_text('selected')
        other=repo/'other.txt';other.write_text('keep untracked')
        with patch.object(P,'dialog',return_value=''):
            P.git_action('stage',[str(source)])
        names=subprocess.check_output(['git','-C',str(repo),'diff','--cached','--name-only'],text=True)
        self.assertEqual(names.strip(),source.name)
        subprocess.run(['git','-C',str(repo),'-c','user.name=Test','-c','user.email=test@example.invalid','-c','commit.gpgsign=false','commit','-qm','fixture'],check=True)
        with patch.object(P,'dialog',return_value='feature/test'):
            P.git_action('branch',[str(repo)])
        self.assertEqual(subprocess.check_output(['git','-C',str(repo),'branch','--show-current'],text=True).strip(),'feature/test')

    def test_git_cancel_and_outside_selection_do_not_stage(self):
        repo=self.repository();source=repo/'file';source.write_text('x')
        with patch.object(P,'dialog',side_effect=P.Cancelled()):
            with self.assertRaises(P.Cancelled):P.git_action('branch',[str(source)])
        self.assertFalse(subprocess.check_output(['git','-C',str(repo),'diff','--cached','--name-only']))
        outside=self.root/'outside';outside.write_text('x')
        with self.assertRaises(ValueError):P.git_context([str(source),str(outside)])

    def test_image_resize_optimize_metadata_and_palette_preserve_original(self):
        source=self.root/"image 'with $().jpg"
        exif=Image.Exif();exif[0x010f]='Test camera'
        profile=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
        Image.new('RGB',(120,60),'#c04020').save(source,exif=exif,icc_profile=profile)
        original=source.read_bytes()
        resized=P.image_operation('resize',source,'40x40')
        with Image.open(resized) as image:self.assertEqual(image.size,(40,20))
        optimized=P.image_operation('optimize',source)
        with Image.open(optimized) as image:self.assertEqual(image.format,'WEBP')
        clean=P.image_operation('metadata',source)
        with Image.open(clean) as image:
            self.assertFalse(image.getexif())
            self.assertTrue(image.info.get('icc_profile'))
        palette=P.image_operation('palette',source)
        colors=json.loads(palette.read_text())['colors'];self.assertTrue(colors)
        self.assertTrue(all(__import__('re').fullmatch('#[0-9a-f]{6}',c) for c in colors))
        ET.parse(source.with_name(source.stem+'-palette.svg'))
        self.assertEqual(source.read_bytes(),original)
        self.assertFalse(list(self.root.glob('.spectrum-tool-*')))

    def test_image_cancellation_and_animation_are_not_silently_flattened(self):
        with patch.object(P,'dialog',side_effect=P.Cancelled()):
            with self.assertRaises(P.Cancelled):P.prepare_images('resize',[])
        source=self.root/'animated.webp'
        Image.new('RGB',(10,10),'red').save(source,save_all=True,append_images=[Image.new('RGB',(10,10),'blue')],duration=100,loop=0)
        with self.assertRaisesRegex(ValueError,'still image'):P.image_operation('optimize',source)

    def pdf(self):
        source=self.root/'three pages.pdf'
        Image.new('RGB',(80,40),'red').save(source,'PDF',save_all=True,append_images=[Image.new('RGB',(80,40),'green'),Image.new('RGB',(80,40),'blue')])
        return source

    def test_real_pdf_extract_rotate_optimize_split_and_duplicate_protection(self):
        source=self.pdf();original=source.read_bytes()
        extracted=P.pdf_operation('extract',source,'1,3')
        self.assertEqual(P.run(['qpdf','--show-npages',extracted]).strip(),'2')
        rotated=P.pdf_operation('rotate',source,'90')
        info=P.run(['pdfinfo','-f','1','-l','1',rotated]);self.assertRegex(info,r'rot:\s+90')
        optimized=P.pdf_operation('optimize',source)
        self.assertEqual(P.run(['qpdf','--show-npages',optimized]).strip(),'3')
        split=P.pdf_operation('split',source)
        self.assertEqual(len(list(split.glob('*.pdf'))),3)
        second=P.pdf_operation('split',source)
        self.assertNotEqual(split,second)
        self.assertEqual(len(list(split.glob('*.pdf'))),3)
        self.assertEqual(source.read_bytes(),original)

    def test_bad_pdf_never_publishes_partial_output(self):
        source=self.root/'broken.pdf';source.write_text('not PDF')
        for action in ['extract','split','rotate','optimize']:
            with self.subTest(action=action),self.assertRaises(ValueError):P.pdf_operation(action,source,'1' if action=='extract' else '90')
        self.assertEqual(list(self.root.iterdir()),[source])

    def audio(self):
        source=self.root/'recording.wav'
        with wave.open(str(source),'wb') as stream:
            stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(44100)
            stream.writeframes(b''.join(int(3000*math.sin(i*2*math.pi*440/44100)).to_bytes(2,'little',signed=True) for i in range(44100)))
        return source

    def test_real_audio_normalization_trimming_and_tag_copy(self):
        source=self.audio();original=source.read_bytes()
        normalized=P.audio_operation('normalize',source)
        self.assertEqual(P.audio_info(normalized)['streams'][0]['codec_name'],'flac')
        self.assertEqual(P.audio_info(normalized)['streams'][0]['sample_rate'],'44100')
        trimmed=P.audio_operation('trim',source,[.2,.6])
        self.assertAlmostEqual(float(P.audio_info(trimmed)['format']['duration']),.4,places=2)
        tagged=P.audio_operation('tags',normalized,{'title':'New title','artist':'Test artist'})
        tags={k.lower():v for k,v in P.audio_info(tagged)['format']['tags'].items()}
        self.assertEqual(tags['title'],'New title');self.assertEqual(tags['artist'],'Test artist')
        summary=P.audio_summary(P.audio_info(tagged),tagged)
        self.assertIn('Title: New title',summary);self.assertIn('Artist: Test artist',summary)
        self.assertEqual(source.read_bytes(),original)
        self.assertFalse(list(self.root.glob('.spectrum-tool-*')))

    def test_timestamps_and_cancelled_trim_are_validated(self):
        self.assertEqual(P.seconds('01:30.5'),90.5)
        self.assertEqual(P.seconds('1:02:03'),3723)
        for value in ['-1','abc','1:90','nan','1;echo']:
            with self.assertRaises(ValueError):P.seconds(value)
        source=self.audio()
        with patch.object(P,'dialog',side_effect=P.Cancelled()):
            with self.assertRaises(P.Cancelled):P.audio_tools('trim',[str(source)])
        self.assertEqual(list(self.root.iterdir()),[source])

    def test_organization_preview_collision_and_complete_undo(self):
        a=self.root/'one.txt';a.write_text('one');b=self.root/'two.txt';b.write_text('two')
        dest=self.root/'sorted';dest.mkdir();(dest/'txt').mkdir();(dest/'txt/one.txt').write_text('existing')
        plan=P.organization_plan([str(a),str(b)],dest,'File type')
        self.assertEqual(Path(plan[0]['target']).name,'one (1).txt')
        with patch.object(P,'dialog',side_effect=['File type',str(dest),'0|1']):
            self.assertEqual(P.organize([str(a),str(b)]),0)
        self.assertFalse(a.exists());self.assertFalse(b.exists())
        with patch.object(P,'dialog',return_value='0|1'):
            self.assertEqual(P.undo_organization(),0)
        self.assertEqual(a.read_text(),'one');self.assertEqual(b.read_text(),'two')
        self.assertEqual((dest/'txt/one.txt').read_text(),'existing')

    def test_organization_cancel_keeps_every_file_and_creates_no_job(self):
        source=self.root/'one.txt';source.write_text('one')
        with patch.object(P,'dialog',side_effect=['File type',str(self.root),P.Cancelled()]):
            with self.assertRaises(P.Cancelled):P.organize([str(source)])
        self.assertEqual(source.read_text(),'one');self.assertFalse((P.STATE/'organization').exists())

    def test_move_refuses_overwrite_modified_file_and_unsafe_project(self):
        source=self.root/'source';source.write_text('source');target=self.root/'target';target.write_text('existing')
        with self.assertRaises(FileExistsError):P.move_file(source,target,P.file_identity(source))
        identity=P.file_identity(source);source.write_text('changed')
        with self.assertRaises(ValueError):P.move_file(source,self.root/'new',identity)
        for project in ['../oops','..','a/b']:
            with self.assertRaises(ValueError):P.organization_plan([str(source)],self.root,'Project folder',project)
        self.assertEqual(target.read_text(),'existing')

    def test_cross_filesystem_move_copies_and_verifies_before_removing_source(self):
        source=self.root/'source';source.write_bytes(os.urandom(8192));original=source.read_bytes();target=self.root/'target'
        real_link=P.os.link
        calls=0
        def link(*args,**kwargs):
            nonlocal calls
            calls+=1
            if calls==1:raise OSError(errno.EXDEV,'Cross-device link')
            return real_link(*args,**kwargs)
        with patch.object(P.os,'link',side_effect=link):P.move_file(source,target,P.file_identity(source))
        self.assertFalse(source.exists());self.assertEqual(target.read_bytes(),original)
        self.assertFalse(list(self.root.glob('.spectrum-move-*')))

    def test_filesystem_without_hardlinks_still_moves_without_overwriting(self):
        source=self.root/'source';source.write_text('data');target=self.root/'target'
        with patch.object(P.os,'link',side_effect=OSError(errno.EOPNOTSUPP,'No hardlinks')):
            P.move_file(source,target,P.file_identity(source))
        self.assertFalse(source.exists());self.assertEqual(target.read_text(),'data')

    def test_share_passes_paths_as_json_and_only_opens_the_existing_widget(self):
        source=self.root/"quote ' $().txt";source.write_text('test')
        with patch.object(P,'run',side_effect=[json.dumps({'ok':True}), '']) as run:
            P.share([str(source)])
            self.assertEqual(json.loads(run.call_args_list[0].kwargs['input'])['paths'],[str(source)])
            self.assertEqual(run.call_args_list[1].args[0][-1],'openSpectrumDropFiles')
        self.assertEqual(source.read_text(),'test')

    def test_custom_action_ids_submenus_and_argument_placeholders_are_unique(self):
        nodes=P.core.definitions();ids=[node.findtext('unique-id') for node in nodes]
        self.assertEqual(len(ids),len(set(ids)))
        menus={node.findtext('submenu') for node in nodes}
        self.assertTrue({'Copy path','Git','Image preparation','PDF tools','Audio tools','Organize files'}<=menus)
        relative=next(n for n in nodes if n.findtext('unique-id')=='spectrumos-tools-copy-relative')
        self.assertTrue(relative.findtext('command').endswith('copy-relative %d %F'))
        share=next(n for n in nodes if n.findtext('unique-id')=='spectrumos-tools-share')
        self.assertIsNone(share.find('directories'))
        recipe=(ROOT/'packages/spectrum-desktop/PKGBUILD').read_text()
        self.assertIn('thunar-actions thunar-productivity',recipe)
        self.assertIn('thunar-actions thunar-productivity',(ROOT/'install.sh').read_text())


if __name__=='__main__':unittest.main()
