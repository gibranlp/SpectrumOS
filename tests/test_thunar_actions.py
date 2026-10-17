import importlib.machinery
import importlib.util
import os
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('thunar_actions', str(ROOT / 'scripts/thunar-actions'))
spec = importlib.util.spec_from_loader(loader.name, loader)
actions = importlib.util.module_from_spec(spec)
loader.exec_module(actions)


class ThunarActionsTests(unittest.TestCase):
    def test_sync_preserves_personal_actions_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            config = Path(directory) / 'Thunar/uca.xml'
            config.parent.mkdir()
            config.write_text('<actions><action><unique-id>personal</unique-id><command>mine</command></action>'
                              '<action><command>exo-open --working-directory %f --launch TerminalEmulator</command></action></actions>')
            actions.sync()
            first = config.read_bytes()
            actions.sync()
            self.assertEqual(first, config.read_bytes())
            nodes = ET.parse(config).getroot().findall('action')
            self.assertEqual(len(nodes), 10)
            self.assertEqual(nodes[0].findtext('command'), 'mine')

    def test_sync_preserves_additional_spectrum_actions(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            config = Path(directory) / 'Thunar/uca.xml'
            config.parent.mkdir()
            config.write_text('<actions><action><unique-id>spectrumos-my-document-tools</unique-id>'
                              '<name>My document tools</name><command>my-documents %F</command></action></actions>')
            actions.sync()
            self.assertEqual(ET.parse(config).getroot().findtext('action/command'), 'my-documents %F')
            first = config.read_bytes()
            actions.sync()
            self.assertEqual(first, config.read_bytes())

    def test_pdf_merge_menu_accepts_multiple_documents_and_keeps_image_converters(self):
        definitions = actions.definitions()
        merge = next(node for node in definitions if node.findtext('unique-id') == 'spectrumos-merge-pdf')
        self.assertEqual(merge.findtext('command'), '/usr/lib/spectrumos/thunar-actions merge-pdf %F')
        self.assertEqual(merge.findtext('range').split('-')[0], '2')
        self.assertIsNotNone(merge.find('other-files'))
        self.assertIn('*.pdf', merge.findtext('patterns'))
        self.assertIn('*.PDF', merge.findtext('patterns'))
        self.assertIn('*.PdF', merge.findtext('patterns'))
        self.assertEqual(sum(node.findtext('submenu') == 'Convert image' for node in definitions), 6)

    def test_merge_preserves_sources_page_count_order_and_existing_outputs(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(actions, 'notify'):
            first = Path(directory) / "first '$().pdf"
            second = Path(directory) / 'second.PDF'
            Image.new('RGB', (10, 10), 'red').save(first, 'PDF')
            Image.new('RGB', (10, 10), 'green').save(second, 'PDF', save_all=True, append_images=[Image.new('RGB', (10, 10), 'blue')])
            originals = [source.read_bytes() for source in [first, second]]
            merged = actions.merge_pdfs([first, second])
            information = subprocess.check_output(['pdfinfo', str(merged)], text=True)
            self.assertEqual(next(line for line in information.splitlines() if line.startswith('Pages:')).split()[1], '3')
            for page, channel in [(1, 0), (3, 2)]:
                image = subprocess.check_output(['pdftoppm', '-f', str(page), '-l', str(page), '-singlefile', '-scale-to', '10', str(merged)])
                import io
                with Image.open(io.BytesIO(image)) as rendered:
                    pixel = rendered.convert('RGB').getpixel((5, 5))
                    self.assertGreater(pixel[channel], 200)
            saved = merged.read_bytes()
            duplicate = actions.merge_pdfs([first, second])
            self.assertNotEqual(merged, duplicate)
            self.assertEqual(merged.read_bytes(), saved)
            self.assertEqual([source.read_bytes() for source in [first, second]], originals)
            self.assertFalse(list(Path(directory).glob('.spectrum-pdf-merge-*')))

    def test_merge_rejects_invalid_inputs_and_removes_partial_outputs(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(actions, 'notify'):
            first = Path(directory) / 'good.pdf'
            Image.new('RGB', (8, 8), 'white').save(first, 'PDF')
            invalid = Path(directory) / 'broken.pdf'
            invalid.write_bytes(b'not a PDF')
            for files in [[first], [first, invalid], [first, first.with_suffix('.txt')]]:
                with self.assertRaises((OSError, ValueError)):
                    actions.merge_pdfs(files)
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ['broken.pdf', 'good.pdf'])

    def test_conversion_preserves_sources_and_existing_outputs(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(actions, 'notify'):
            source = Path(directory) / "photo 'with spaces $().png"
            Image.new('RGBA', (8, 8), (255, 0, 0, 0)).save(source)
            original = source.read_bytes()
            for fmt in actions.FORMATS:
                self.assertEqual(actions.convert(fmt, [source]), 0)
            self.assertEqual(source.read_bytes(), original)
            self.assertTrue(source.with_suffix('.pdf').read_bytes().startswith(b'%PDF'))
            jpeg = source.with_suffix('.jpg')
            with Image.open(jpeg) as image:
                self.assertGreater(min(image.convert('RGB').getpixel((0, 0))), 240)
            saved = jpeg.read_bytes()
            self.assertEqual(actions.convert('jpeg', [source]), 0)
            self.assertEqual(jpeg.read_bytes(), saved)
            self.assertTrue(jpeg.with_name(f'{jpeg.stem} (1).jpg').exists())

    def test_bad_image_leaves_no_partial_output_and_batch_continues(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(actions, 'notify'):
            bad = Path(directory) / 'bad.png'
            bad.write_bytes(b'bad image')
            good = Path(directory) / 'good.png'
            Image.new('RGB', (4, 4)).save(good)
            self.assertEqual(actions.convert('pdf', [bad, good]), 1)
            self.assertFalse(bad.with_suffix('.pdf').exists())
            self.assertTrue(good.with_suffix('.pdf').exists())
            self.assertEqual(len(list(Path(directory).iterdir())), 3)

    def test_wallpaper_import_preserves_preferences_and_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            library = root / 'library'
            library.mkdir()
            source = root / 'photo.png'
            Image.new('RGB', (4, 4), 'red').save(source)
            (library / source.name).write_bytes(b'existing')
            state = root / 'state/spectrumos/theme'
            state.mkdir(parents=True)
            (state / 'preferences').write_text('mode=median-cut\nvariant=light\nscheme=none\n')
            with patch.object(actions, 'BACKEND', ROOT / 'scripts'), patch.dict(os.environ, {
                    'SPECTRUM_WALLPAPER_DIR': str(library), 'XDG_STATE_HOME': str(root / 'state')}), \
                    patch.object(actions.subprocess, 'run') as run:
                actions.set_wallpaper(source)
            self.assertEqual(run.call_args.args[0][-2:], ['median-cut', 'light'])
            self.assertEqual(Path(run.call_args.args[0][2]).name, 'photo (1).png')
            self.assertEqual((library / source.name).read_bytes(), b'existing')

    def test_kitty_directory_is_passed_as_one_argument(self):
        with tempfile.TemporaryDirectory(prefix='folder space ') as directory, patch.object(actions.subprocess, 'Popen') as popen:
            self.assertEqual(actions.main(['terminal', directory]), 0)
            self.assertEqual(popen.call_args.args[0], ['kitty', '--directory', directory])

    def test_package_installer_and_session_include_actions(self):
        self.assertIn('thunar-actions', (ROOT / 'install.sh').read_text())
        recipe = ROOT / 'packages/spectrum-desktop/PKGBUILD'
        if not recipe.is_file():
            recipe = Path('/startdir/PKGBUILD')
        self.assertIn('thunar-actions', recipe.read_text())
        self.assertIn('ExecStartPre=/usr/lib/spectrumos/thunar-actions sync',
                      (ROOT / 'system/systemd/user/spectrum-shell.service').read_text())
