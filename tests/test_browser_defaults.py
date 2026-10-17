from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import json
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class BrowserDefaultsTests(unittest.TestCase):
    def setUp(self):
        loader = SourceFileLoader("browser_defaults", str(ROOT / "scripts/spectrum-browser-defaults"))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.module = importlib.util.module_from_spec(spec)
        loader.exec_module(self.module)
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def browser(self, relative):
        binary = self.root / relative
        binary.parent.mkdir(parents=True)
        binary.touch()
        return binary.parent

    def test_fresh_browsers_get_gtk_without_creating_absent_browsers_or_profiles(self):
        self.module.configure(self.root)
        self.assertFalse((self.root / 'opt').exists())
        for relative in self.module.BROWSERS:
            directory = self.browser(relative)
            self.module.configure(self.root)
            path = directory / 'initial_preferences'
            self.assertEqual(json.loads(path.read_text())['extensions']['theme']['system_theme'], 1)
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)
            before = path.read_bytes()
            self.module.configure(self.root)
            self.assertEqual(path.read_bytes(), before)
        self.assertFalse((self.root / 'home').exists())

    def test_existing_distribution_preferences_are_preserved(self):
        directory = self.browser(self.module.BROWSERS[0])
        path = directory / 'master_preferences'
        path.write_text(json.dumps({'homepage': 'https://example.test', 'extensions': {'theme': {'custom': True}}}))
        self.module.configure(self.root)
        data = json.loads(path.read_text())
        self.assertEqual(data['homepage'], 'https://example.test')
        self.assertTrue(data['extensions']['theme']['custom'])
        self.assertEqual(data['extensions']['theme']['system_theme'], 1)
        self.assertFalse((directory / 'initial_preferences').exists())

    def test_explicit_theme_defaults_are_not_overridden(self):
        directory = self.browser(self.module.BROWSERS[0])
        path = directory / 'initial_preferences'
        contents = '{"extensions":{"theme":{"system_theme":2}}}'
        path.write_text(contents)
        self.module.configure(self.root)
        self.assertEqual(path.read_text(), contents)

    def test_symlinked_defaults_are_not_modified(self):
        directory = self.browser(self.module.BROWSERS[0])
        target = self.root / 'private.json'
        target.write_text('{}')
        (directory / 'initial_preferences').symlink_to(target)
        with self.assertRaises(RuntimeError):
            self.module.configure(self.root)
        self.assertEqual(target.read_text(), '{}')
