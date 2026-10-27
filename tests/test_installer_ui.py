from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shutil
import unittest
from unittest import mock

from tests.test_installer_storage import layout_fixture, planned


@unittest.skipUnless(os.environ.get("SPECTRUM_INSTALLER_UI_TEST") == "1", "Use scripts/check-installer-ui for an isolated GTK display")
class InstallerUITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).resolve().parents[1] / "installer/spectrum-installer"
        spec = importlib.util.spec_from_loader("installer_ui", SourceFileLoader("installer_ui", str(path)))
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        module = self.module
        module.set_language('en_US')
        self.patchers = [
            mock.patch.object(module.SpectrumInstaller, "load_disks", lambda app: setattr(app, "disks", [
                {"path": "/dev/nvme0n1", "size": 80 * 1024**3, "model": "Disposable fixture"} ])),
            mock.patch.object(module.SpectrumInstaller, "connected", return_value=True),
            mock.patch.object(module.SpectrumInstaller, "detect_gpu", return_value=5),
        ]
        for patcher in self.patchers:
            patcher.start()
        self.app = module.SpectrumInstaller()
        from gi.repository import Gio
        self.app.set_flags(Gio.ApplicationFlags.NON_UNIQUE)
        self.app.register(None)
        self.app.on_activate(None)
        self.app.password.set_text("fixture-password")
        self.app.password_confirm.set_text("fixture-password")

    def tearDown(self):
        self.app.on_shutdown()
        if self.app.log_window is not None:
            self.app.log_window.destroy()
        self.app.window.destroy()
        for patcher in reversed(self.patchers):
            patcher.stop()

    def start_fixture_install(self):
        self.ready()
        with mock.patch.object(self.module.threading, "Thread"):
            self.app.start_install(None)
        self.addCleanup(shutil.rmtree, self.app.install_log_path.parent)

    def test_progress_is_compact_and_private_log_is_available_on_demand(self):
        self.start_fixture_install()
        self.assertIsNone(self.app.log.get_parent())
        self.assertEqual(self.app.install_status.get_text(), "Getting ready")
        self.assertTrue(self.app.terminal_log_button.get_sensitive())
        self.assertTrue(self.app.done_log_button.get_sensitive())
        self.assertEqual(self.app.install_log_path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.app.install_log_path.parent.stat().st_mode & 0o777, 0o700)

    def test_backend_milestones_and_package_output_drive_simple_status(self):
        self.start_fixture_install()
        for percent, expected in ((2, "Checking package mirrors"), (5, "Preparing the selected disk"),
                                  (15, "Preparing boot files")):
            self.app.handle_line(f"##PROGRESS {percent}\n")
            self.assertEqual(self.app.install_status.get_text(), expected)
        self.app.handle_line("##PACKAGES 2 65\n")
        self.app.handle_line("##PROGRESS 20\n")
        self.app.handle_line("Packages (4) base linux-zen example another\n")
        self.app.handle_line("downloading linux-zen...\n")
        self.assertEqual(self.app.install_status.get_text(), "Downloading packages")
        self.app.handle_line("installing linux-zen...\n")
        self.assertEqual(self.app.install_status.get_text(), "Installing the base system")
        self.assertAlmostEqual(self.app.progress.get_fraction(), .3125)
        self.app.handle_line("##PROGRESS 75\n")
        self.assertEqual(self.app.install_status.get_text(), "Applying desktop settings")
        self.app.handle_line("installing another optional package...\n")
        self.assertEqual(self.app.install_status.get_text(), "Applying desktop settings")
        log = self.app.install_log_path.read_text()
        self.assertIn("downloading linux-zen", log)
        self.assertNotIn("##PROGRESS", log)

    def test_tips_rotate_and_stop_when_installation_finishes(self):
        self.start_fixture_install()
        first = self.app.tip_body.get_text()
        self.assertIn("Super + K", first)
        self.assertIn("Planning Council", first)
        self.assertTrue(self.app.rotate_tip())
        self.assertNotEqual(self.app.tip_body.get_text(), first)
        for _ in range(len(self.module.INSTALL_TIPS) - 1):
            self.app.rotate_tip()
        self.assertEqual(self.app.tip_body.get_text(), first)
        self.app.finish_install(0)
        self.assertEqual(self.app.tip_timer, 0)
        self.assertFalse(self.app.rotate_tip())
        self.assertEqual(self.app.stack.get_visible_child_name(), "done")
        self.assertIsNone(self.app.install_log_stream)

    def test_failure_keeps_progress_and_replaces_tips_with_actionable_status(self):
        self.start_fixture_install()
        self.app.handle_line("##PROGRESS 70\n")
        self.app.append_log("Error: example package unavailable\n")
        self.app.finish_install(1)
        self.assertEqual(self.app.stack.get_visible_child_name(), "progress")
        self.assertEqual(self.app.install_status.get_text(), "Installation stopped")
        self.assertAlmostEqual(self.app.progress.get_fraction(), .7)
        self.assertIn("terminal log", self.app.install_note.get_text())
        self.assertFalse(self.app.tip_card.get_visible())
        self.assertEqual(self.app.tip_timer, 0)
        self.assertIn("example package unavailable", self.app.install_log_path.read_text())

    def test_terminal_opens_read_only_tail_without_running_installer(self):
        self.start_fixture_install()
        with mock.patch.object(self.module.threading, "Thread"), \
             mock.patch.object(self.module.subprocess, "Popen") as popen:
            self.app.open_install_log(None)
        arguments = popen.call_args.args[0]
        self.assertEqual(arguments[:2], ["foot", "--title=SpectrumOS installation log"])
        self.assertIn("tail", arguments)
        self.assertEqual(arguments[-1], str(self.app.install_log_path))
        self.assertNotIn("--apply", arguments)
        self.assertTrue(self.app.install_running)

    def test_missing_terminal_falls_back_to_a_separate_log_window(self):
        self.start_fixture_install()
        self.app.append_log("Visible only when requested\n")
        with mock.patch.object(self.module.subprocess, "Popen", side_effect=FileNotFoundError):
            self.app.open_install_log(None)
        self.assertTrue(self.app.log_window.get_visible())
        self.assertEqual(self.app.stack.get_visible_child_name(), "progress")
        self.assertTrue(self.app.install_running)

    def test_failed_terminal_launch_falls_back_without_affecting_installation(self):
        self.start_fixture_install()
        class ImmediateThread:
            def __init__(self, *, target, **_arguments):
                self.target = target
            def start(self):
                self.target()
        process = mock.Mock()
        process.wait.return_value = 1
        with mock.patch.object(self.module.threading, "Thread", ImmediateThread), \
             mock.patch.object(self.module.GLib, "idle_add", side_effect=lambda callback, *args: callback(*args)), \
             mock.patch.object(self.module.subprocess, "Popen", return_value=process):
            self.app.open_install_log(None)
        self.assertTrue(self.app.log_window.get_visible())
        self.assertTrue(self.app.install_running)

    def test_log_buffer_is_bounded_while_disk_log_retains_previous_lines(self):
        self.start_fixture_install()
        self.app.append_log("earlier output\n")
        self.app.append_log("x" * (self.module.LOG_BUFFER_CHARS + 100) + "\n")
        self.assertLessEqual(self.app.log.get_buffer().get_char_count(), self.module.LOG_BUFFER_CHARS)
        self.assertIn("earlier output", self.app.install_log_path.read_text())

    def test_log_write_failure_does_not_interrupt_the_installer(self):
        self.start_fixture_install()
        self.app.close_install_log()
        self.app.install_log_stream = mock.Mock()
        self.app.install_log_stream.write.side_effect = OSError("Disk full")
        with mock.patch.object(self.app, "show_log_window") as show:
            self.app.append_log("Installation continues\n")
        show.assert_called_once()
        self.assertIsNone(self.app.install_log_stream)
        self.assertTrue(self.app.install_running)

    def test_log_preparation_failure_does_not_start_installation(self):
        self.ready()
        with mock.patch.object(self.module.tempfile, "mkdtemp", side_effect=OSError("No space")), \
             mock.patch.object(self.module.threading, "Thread") as thread:
            self.app.start_install(None)
        thread.assert_not_called()
        self.assertFalse(self.app.install_running)
        self.assertEqual(self.app.stack.get_visible_child_name(), "confirm")
        self.assertIn("Could not prepare", self.app.confirm_warning.get_text())

    def ready(self, *, default_boot=True):
        layout = layout_fixture()[1]
        self.app.finish_storage_probe(layout, "")
        plan = planned(layout)
        if not default_boot:
            from tests.test_installer_storage import STORAGE
            plan = STORAGE.make_plan(layout, plan["extent_start"], plan["size_gib"], False)
        self.app.finish_storage_plan(plan, "")
        return plan

    def test_wizard_opens_on_language_with_separate_pages_and_fixed_navigation(self):
        self.assertEqual(self.app.stack.get_visible_child_name(), "language")
        self.assertTrue(self.app.keyboard.is_ancestor(self.app.stack.get_child_by_name("language")))
        self.assertTrue(self.app.disk_dropdown.is_ancestor(self.app.stack.get_child_by_name("disk")))
        self.assertTrue(self.app.username.is_ancestor(self.app.stack.get_child_by_name("account")))
        self.assertTrue(self.app.gpu.is_ancestor(self.app.stack.get_child_by_name("preferences")))
        self.assertFalse(self.app.navigation.is_ancestor(self.app.stack))
        self.assertFalse(self.app.back_button.get_visible())
        self.assertIn("Step 1 of 5", self.app.step_indicator.get_text())

    def test_disk_and_account_steps_validate_before_advancing(self):
        self.app.password.set_text("")
        self.app.next_step(None)
        self.assertEqual(self.app.stack.get_visible_child_name(), "disk")
        self.app.next_step(None)
        self.assertEqual(self.app.stack.get_visible_child_name(), "disk")
        self.assertTrue(self.app.error.get_visible())
        self.app.finish_storage_probe(layout_fixture()[1], "")
        self.app.next_step(None)
        self.assertEqual(self.app.stack.get_visible_child_name(), "account")
        self.app.next_step(None)
        self.assertEqual(self.app.stack.get_visible_child_name(), "account")
        self.assertIn("8 characters", self.app.error.get_text())
        self.app.password.set_text("fixture-password")
        self.app.next_step(None)
        self.assertEqual(self.app.stack.get_visible_child_name(), "preferences")

    def test_back_preserves_fields_and_review_never_starts_installation(self):
        self.app.username.set_text("wizarduser")
        self.app.browser_brave.set_active(True)
        self.app.lean.set_active(True)
        self.app.install_mode.set_selected(1)
        with mock.patch.object(self.module.subprocess, "Popen") as process:
            for _ in range(4):
                self.app.next_step(None)
            self.assertEqual(self.app.stack.get_visible_child_name(), "confirm")
            self.assertTrue(self.app.confirm_actions.get_visible())
            self.assertFalse(self.app.next_button.get_visible())
            self.assertFalse(self.app.install_running)
            process.assert_not_called()
        self.app.show_step("preferences")
        self.app.previous_step(None)
        self.assertEqual(self.app.stack.get_visible_child_name(), "account")
        self.assertEqual(self.app.username.get_text(), "wizarduser")
        self.assertEqual(self.app.password.get_text(), "fixture-password")
        self.assertTrue(self.app.browser_brave.get_active())
        self.assertTrue(self.app.lean.get_active())

    def test_wizard_navigation_is_locked_during_storage_work_and_installation(self):
        self.app.show_step("disk")
        self.app.set_storage_busy(True)
        self.assertFalse(self.app.navigation.get_sensitive())
        self.app.previous_step(None)
        self.app.next_step(None)
        self.assertEqual(self.app.stack.get_visible_child_name(), "disk")
        self.app.set_storage_busy(False)
        self.start_fixture_install()
        self.assertFalse(self.app.navigation.get_visible())
        self.app.show_step("language")
        self.assertEqual(self.app.stack.get_visible_child_name(), "progress")

    def test_wizard_step_titles_follow_language_without_resetting_fields(self):
        self.app.language_choice.set_selected(1)
        self.assertIn("Paso 1 de 5", self.app.step_indicator.get_text())
        self.app.next_step(None)
        self.assertIn("Disco", self.app.step_indicator.get_text())
        self.app.previous_step(None)
        self.app.language_choice.set_selected(2)
        self.assertIn("Etapa 1 de 5", self.app.step_indicator.get_text())

    def test_reactivation_keeps_existing_window_and_inputs(self):
        window = self.app.window
        self.app.username.set_text("keepme")
        self.app.show_step("account")
        self.app.on_activate(None)
        self.assertIs(self.app.window, window)
        self.assertEqual(self.app.username.get_text(), "keepme")
        self.assertEqual(self.app.stack.get_visible_child_name(), "account")

    def test_all_wizard_pages_fit_narrow_windows_with_long_disk_labels(self):
        self.app.disk_dropdown.set_model(self.module.Gtk.StringList.new([
            "Very long external drive model " * 8 + " · /dev/nvme0n1"
        ]))
        for language in (0, 1, 2):
            self.app.language_choice.set_selected(language)
            for name in self.app.wizard_steps:
                self.app.show_step(name)
                minimum = self.app.window.measure(self.module.Gtk.Orientation.HORIZONTAL, -1)[0]
                self.assertLessEqual(minimum, 480, (language, name, minimum))

    def test_alongside_is_default_and_cannot_continue_without_reading_disk(self):
        self.assertEqual(self.app.install_mode.get_selected(), 0)
        self.app.review(None)
        self.assertTrue(self.app.error.get_visible())
        self.assertEqual(self.app.stack.get_visible_child_name(), "disk")

    def test_language_switch_preserves_disk_plan_account_and_keyboard(self):
        import gc
        plan = self.ready()
        self.app.username.set_text('myuser')
        keyboard = self.app.keyboard_profiles[self.app.keyboard.get_selected()]
        self.app.language_choice.set_selected(1)
        gc.collect()
        self.assertEqual(self.app.window.get_title(), 'Instalar SpectrumOS')
        self.assertEqual(self.app.username.get_text(), 'myuser')
        self.assertEqual(self.app.storage_plan, plan)
        self.assertEqual(self.app.keyboard_profiles[self.app.keyboard.get_selected()], keyboard)
        self.assertIn('Solo se formatearán', self.app.confirm_warning.get_text())
        labels = []
        def collect(widget):
            if isinstance(widget, self.module.Gtk.Label):
                labels.append(widget.get_text())
            child = widget.get_first_child()
            while child is not None:
                collect(child)
                child = child.get_next_sibling()
        collect(self.app.window)
        self.assertIn('Idioma de instalación y del sistema', labels)
        self.app.language_choice.set_selected(2)
        self.assertEqual(self.app.window.get_title(), 'Instalar SpectrumOS')
        self.assertIn('Apenas as duas novas', self.app.confirm_warning.get_text())
        self.assertEqual(self.app.storage_plan, plan)

    def test_target_language_and_explicit_region_are_forwarded_to_backend(self):
        self.app.language_choice.set_selected(1)
        self.app.region_choice.set_selected(2)
        self.app.language_choice.set_selected(0)
        self.app.language_choice.set_selected(1)
        self.assertEqual(self.app.region_choice.get_selected(), 2)
        plan = self.ready()
        process = mock.Mock(stdout=iter([]))
        process.wait.return_value = 0
        self.app.detect_cpu = lambda: 'intel'
        class ImmediateThread:
            def __init__(self, *, target, **_arguments):
                self.target = target
            def start(self):
                self.target()
        with mock.patch.object(self.module.threading, 'Thread', ImmediateThread), \
                mock.patch.object(self.module.GLib, 'idle_add', side_effect=lambda callback, *args: callback(*args)), \
                mock.patch.object(self.module.subprocess, 'Popen', return_value=process) as popen:
            self.app.start_install(None)
        self.addCleanup(shutil.rmtree, self.app.install_log_path.parent)
        arguments = popen.call_args.args[0]
        self.assertEqual(arguments[arguments.index('--locale') + 1], 'es_MX.UTF-8')
        self.assertEqual(arguments[arguments.index('--region') + 1], 'pt_BR.UTF-8')
        self.assertIn(plan['confirmation'], arguments)

    def test_partition_choices_and_before_after_summary(self):
        plan = self.ready()
        self.assertTrue(self.app.extent_dropdown.get_sensitive())
        self.assertGreaterEqual(self.app.allocation.get_value_as_int(), 34)
        self.assertEqual(self.app.install_button.get_label(), "Install alongside")
        text = self.app.summary.get_text()
        for expected in ("Before (all preserved)", "Existing partitions unchanged", "/dev/nvme0n1p1", "/dev/nvme0n1p4"):
            self.assertIn(expected, text)
        self.assertEqual(self.app.storage_plan, plan)

    def test_blocked_firmware_and_missing_space_disable_allocation(self):
        for blocked in (True, False):
            layout = layout_fixture()[1]
            if blocked:
                layout["blockers"] = ["Secure Boot is enabled"]
            else:
                layout["free_extents"] = []
            self.app.finish_storage_probe(layout, "")
            self.assertFalse(self.app.allocation.get_sensitive())
            self.app.review(None)
            self.assertTrue(self.app.error.get_visible())

    def test_disk_change_invalidates_previous_plan(self):
        self.ready()
        self.app.storage_disk_changed()
        self.assertIsNone(self.app.storage_plan)
        self.assertIsNone(self.app.storage_layout)
        self.assertFalse(self.app.extent_dropdown.get_sensitive())

    def test_erase_requires_explicit_mode_and_shows_erase_confirmation(self):
        self.ready()
        self.app.install_mode.set_selected(1)
        self.app.review(None)
        self.assertIsNone(self.app.storage_plan)
        self.assertEqual(self.app.install_button.get_label(), "Erase disk and install")
        self.assertIn("permanently erased", self.app.confirm_warning.get_text())

    def test_failed_plan_returns_error_without_an_installable_plan(self):
        self.app.finish_storage_plan(None, "The disk changed; rescan")
        self.assertTrue(self.app.error.get_visible())
        self.assertEqual(self.app.stack.get_visible_child_name(), "disk")

    def test_apply_passes_only_the_reviewed_mode_confirmation(self):
        for alongside in (True, False):
            plan = self.ready(default_boot=False)
            if not alongside:
                self.app.install_mode.set_selected(1)
                self.app.review(None)
            fake_process = mock.Mock(stdout=iter(["##PROGRESS 100\n"]))
            fake_process.wait.return_value = 0
            class ImmediateThread:
                def __init__(self, *, target, **_arguments):
                    self.target = target
                def start(self):
                    self.target()
            with mock.patch.object(self.module.threading, "Thread", ImmediateThread), \
                 mock.patch.object(self.module.GLib, "idle_add", side_effect=lambda callback, *args: callback(*args)), \
                 mock.patch.object(self.module.subprocess, "Popen", return_value=fake_process) as popen:
                self.app.start_install(None)
            self.addCleanup(shutil.rmtree, self.app.install_log_path.parent)
            arguments = popen.call_args.args[0]
            if alongside:
                self.assertNotIn("--confirm-erase", arguments)
                self.assertIn(plan["confirmation"], arguments)
                self.assertIn("--keep-boot-default", arguments)
            else:
                self.assertNotIn("--confirm-plan", arguments)
                self.assertIn("--confirm-erase", arguments)


if __name__ == "__main__":
    unittest.main()
