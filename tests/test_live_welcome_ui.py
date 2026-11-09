from importlib.machinery import SourceFileLoader
import importlib.util
import os
from pathlib import Path
import unittest
from unittest import mock


@unittest.skipUnless(os.environ.get("SPECTRUM_INSTALLER_UI_TEST") == "1", "Use scripts/check-installer-ui for an isolated GTK display")
class LiveWelcomeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).resolve().parents[1] / "installer/spectrum-live-welcome"
        spec = importlib.util.spec_from_loader("live_welcome", SourceFileLoader("live_welcome", str(path)))
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        from gi.repository import Gio
        self.module.set_language("en_US")
        self.app = self.module.LiveWelcome()
        self.app.set_flags(Gio.ApplicationFlags.NON_UNIQUE)
        self.app.register(None)
        self.app.activate_window(None)

    def tearDown(self):
        self.app.window.destroy()
        self.app.quit()
        self.module.set_language("en_US")

    def test_language_selection_is_shared_and_retranslates_welcome(self):
        for locale in ("es_MX", "pt_BR", "en_US"):
            index = next(index for index, row in enumerate(self.app.rows) if row["id"] == locale)
            self.app.choice.set_selected(index)
            self.assertEqual(self.module.language(), locale)
            from spectrum_i18n import translate
            self.assertEqual(self.app.window.get_title(), translate("Welcome to SpectrumOS"))

    def test_install_opens_only_the_installer_frontend(self):
        with mock.patch.object(self.module.subprocess, "Popen") as spawn, mock.patch.object(self.app, "quit") as quit:
            self.app.install()
            spawn.assert_called_once_with(["/usr/local/bin/spectrum-installer"], start_new_session=True)
            quit.assert_called_once()

    def test_explore_closes_welcome_without_launching_installer(self):
        with mock.patch.object(self.module.subprocess, "Popen") as spawn, mock.patch.object(self.app, "quit") as quit:
            self.app.window.get_child().get_last_child().get_first_child().emit("clicked")
            spawn.assert_not_called()
            quit.assert_called_once()

    def test_live_selection_updates_new_application_language(self):
        with mock.patch.dict(os.environ, {"SPECTRUM_LIVE_SESSION": "1"}), \
             mock.patch.object(self.module.subprocess, "run") as run:
            self.app.choice.set_selected(next(index for index, row in enumerate(self.app.rows) if row["id"] == "es_MX"))
            arguments = run.call_args.args[0]
            self.assertEqual(arguments[:2], ["dbus-update-activation-environment", "--systemd"])
            self.assertIn("LANG=es_MX.UTF-8", arguments)
            self.assertIn("LC_MESSAGES=es_MX.UTF-8", arguments)

    def test_launch_failure_keeps_welcome_available(self):
        with mock.patch.object(self.module.subprocess, "Popen", side_effect=OSError("unavailable")), \
             mock.patch.object(self.app, "quit") as quit:
            self.app.install()
            self.assertEqual(self.app.error.get_text(), "unavailable")
            quit.assert_not_called()
