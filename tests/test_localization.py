from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
import shutil
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_loader('spectrum_i18n', SourceFileLoader(
    'spectrum_i18n', str(ROOT / 'scripts/spectrum_i18n.py')))
i18n = importlib.util.module_from_spec(spec)
spec.loader.exec_module(i18n)


class LocalizationTests(unittest.TestCase):
    def test_time_region_static_messages_have_both_translations(self):
        import polib
        source = (ROOT / 'configs/spectrum-shell/TimeRegionWidgetContent.qml').read_text()
        messages = re.findall(r'qsTranslate\("Spectrum", ("(?:[^"\\]|\\.)*")\)', source)
        for locale in ('es_MX', 'pt_BR'):
            catalog = polib.pofile(str(ROOT / 'translations' / (locale + '.po')))
            for encoded in messages:
                message = json.loads(encoded)
                with self.subTest(locale=locale, message=message):
                    entry = catalog.find(message, msgctxt='Spectrum')
                    self.assertIsNotNone(entry)
                    self.assertTrue(entry.msgstr)

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='spectrum-locale-check-')
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.locale = self.directory / 'locale.conf'
        self.locale.write_text('LANG=es_MX.UTF-8\nLC_TIME=pt_BR.UTF-8\n')
        self.preference = self.directory / 'config/spectrumos/language.json'
        self.environment = mock.patch.dict(os.environ, {
            'SPECTRUM_TRANSLATIONS_DIR': str(ROOT / 'translations'),
            'SPECTRUM_LANGUAGE_FILE': str(self.preference),
            'SPECTRUM_SYSTEM_LOCALE_FILE': str(self.locale),
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def test_default_follows_installed_language(self):
        self.assertEqual(i18n.language(), 'es_MX')
        self.locale.write_text('LANG=pt_BR.UTF-8\nLC_MESSAGES=en_US.UTF-8\n')
        self.assertEqual(i18n.language(), 'en_US')

    def test_base_language_fallback_preserves_preference(self):
        self.assertEqual(i18n.normalize('es-AR.UTF-8'), 'es_MX')
        self.assertEqual(i18n.normalize('pt_PT.UTF-8'), 'pt_BR')
        self.assertEqual(i18n.normalize('de_DE.UTF-8'), 'en_US')
        i18n.set_language('pt_BR')
        self.assertEqual(i18n.language(), 'pt_BR')
        self.assertEqual(self.preference.stat().st_mode & 0o777, 0o600)
        i18n.set_language('system')
        self.assertEqual(i18n.language(), 'es_MX')

    def test_invalid_selection_does_not_replace_existing_settings(self):
        i18n.set_language('es_MX')
        original = self.preference.read_bytes()
        with self.assertRaises(ValueError):
            i18n.set_language('../../not-a-locale')
        self.assertEqual(self.preference.read_bytes(), original)

    def test_malformed_settings_fall_back_safely(self):
        self.preference.parent.mkdir(parents=True)
        for content in ('{', '[]', 'null', '1', 'x' * 8193):
            with self.subTest(content=content[:20]):
                self.preference.write_text(content)
                self.assertEqual(i18n.language(), 'es_MX')

    def test_missing_translation_preserves_source_and_parameters(self):
        self.assertEqual(i18n.translate('Open {name}', name='project.json'), 'Open project.json')

    def test_missing_registry_falls_back_to_english(self):
        with mock.patch.dict(os.environ, {'SPECTRUM_TRANSLATIONS_DIR': str(self.directory)}):
            self.assertEqual(i18n.language(), 'en_US')

    def test_compiled_gettext_catalogs_and_plural_forms(self):
        import polib
        compiled = self.directory / 'catalogs'
        compiled.mkdir()
        (compiled / 'languages.json').write_bytes((ROOT / 'translations/languages.json').read_bytes())
        for locale in ('es_MX', 'pt_BR'):
            destination = compiled / locale / 'LC_MESSAGES/spectrum.mo'
            destination.parent.mkdir(parents=True)
            polib.pofile(str(ROOT / 'translations' / (locale + '.po'))).save_as_mofile(str(destination))
        with mock.patch.dict(os.environ, {'SPECTRUM_TRANSLATIONS_DIR': str(compiled)}):
            i18n.set_language('es_MX')
            self.assertEqual(i18n.translate('Save'), 'Guardar')
            self.assertEqual(i18n.plural('%n file', '%n files', 2), '2 archivos')
            i18n.set_language('pt_BR')
            self.assertEqual(i18n.translate('Save'), 'Salvar')
            self.assertEqual(i18n.plural('%n file', '%n files', 0), '0 arquivo')


class CatalogBuildTests(unittest.TestCase):
    def fixture(self, directory, translation='%n jabłko'):
        import polib
        root = Path(directory)
        (root / 'scripts').mkdir()
        shutil.copy2(ROOT / 'scripts/build-localization', root / 'scripts/build-localization')
        catalogs = root / 'translations'
        catalogs.mkdir()
        registry = [
            {'id': 'en_US', 'name': 'English', 'language': 'en', 'locale': 'en_US.UTF-8',
             'plural_forms': 'nplurals=2; plural=(n != 1);'},
            {'id': 'pl_PL', 'name': 'Polski', 'language': 'pl', 'locale': 'pl_PL.UTF-8',
             'plural_forms': 'nplurals=3; plural=(n == 1 ? 0 : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14) ? 1 : 2);'},
        ]
        (catalogs / 'languages.json').write_text(json.dumps(registry))
        catalog = polib.POFile()
        catalog.metadata = {'Language': 'pl_PL', 'Content-Type': 'text/plain; charset=UTF-8'}
        catalog.append(polib.POEntry(msgctxt='Spectrum', msgid='%n apple', msgid_plural='%n apples',
                                    msgstr_plural={0: translation, 1: '%n jabłka', 2: '%n jabłek'}))
        catalog.save(str(catalogs / 'pl_PL.po'))
        return root

    def test_contributed_language_can_use_three_plural_forms(self):
        import gettext
        with tempfile.TemporaryDirectory() as temporary:
            root = self.fixture(temporary)
            result = subprocess.run([str(root / 'scripts/build-localization'), '--catalogs-only',
                                     '--output', str(root / 'build')], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            catalog = gettext.translation('spectrum', root / 'build/translations', languages=['pl_PL'])
            for count, expected in ((1, '%n jabłko'), (2, '%n jabłka'), (5, '%n jabłek'), (12, '%n jabłek')):
                self.assertEqual(catalog.npgettext('Spectrum', '%n apple', '%n apples', count), expected)

    def test_missing_placeholder_rejects_catalog_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = self.fixture(temporary, translation='jabłko')
            result = subprocess.run([str(root / 'scripts/build-localization'), '--catalogs-only',
                                     '--output', str(root / 'build')], text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Translation placeholders differ', result.stderr)


class InstallerLocaleTests(unittest.TestCase):
    def run_function(self, name, language, region='', mode='apply'):
        source = (ROOT / 'installer/spectrum-installer-backend').read_text()
        function = re.search(r'^' + name + r'\(\) \{.*?^\}', source, re.M | re.S).group()
        with tempfile.TemporaryDirectory(prefix='spectrum-target-locale-') as temporary:
            target = Path(temporary)
            (target / 'etc').mkdir()
            script = 'set -euo pipefail\ntarget=$1\nsystem_locale=$2\nregional_locale=$3\nmode=$4\ndie() { echo "$*" >&2; exit 1; }\n'
            script += function + '\n' + name + '\n'
            result = subprocess.run(['bash', '-c', script, 'bash', str(target), language, region, mode],
                                    text=True, capture_output=True)
            files = {path.name: path.read_text() for path in (target / 'etc').iterdir()}
            return result, files

    def test_locale_validation_accepts_all_three_languages(self):
        for locale in ('en_US', 'es_MX', 'pt_BR'):
            result, _ = self.run_function('validate_locales', locale + '.UTF-8')
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_locale_validation_rejects_unavailable_or_injected_values(self):
        for language, region in (('de_DE.UTF-8', ''), ('es_MX.UTF-8', 'xx_XX.UTF-8'),
                                 ('es_MX.UTF-8', 'en_US.UTF-8\nLC_ALL=C'), ('../es_MX', '')):
            result, files = self.run_function('validate_locales', language, region)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(files, {})

    def test_target_settings_separate_interface_language_and_formats(self):
        result, files = self.run_function('configure_locales', 'es_MX.UTF-8', 'pt_BR.UTF-8')
        self.assertEqual(result.returncode, 0, result.stderr)
        values = dict(line.split('=', 1) for line in files['locale.conf'].splitlines())
        self.assertEqual(values['LANG'], 'es_MX.UTF-8')
        self.assertEqual(values['LC_MESSAGES'], 'es_MX.UTF-8')
        self.assertEqual(values['LC_TIME'], 'pt_BR.UTF-8')
        self.assertNotIn('LC_ALL', values)
        self.assertEqual(files['locale.gen'].splitlines(), [
            'en_US.UTF-8 UTF-8', 'es_MX.UTF-8 UTF-8', 'pt_BR.UTF-8 UTF-8'])

    def test_english_generation_is_not_duplicated(self):
        result, files = self.run_function('configure_locales', 'en_US.UTF-8', 'en_US.UTF-8')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files['locale.gen'], 'en_US.UTF-8 UTF-8\n')

    def test_dry_run_does_not_write_target(self):
        result, files = self.run_function('configure_locales', 'pt_BR.UTF-8', 'pt_BR.UTF-8', 'plan')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files, {})
        self.assertIn('pt_BR.UTF-8', result.stdout)
