from importlib.machinery import SourceFileLoader
from contextlib import ExitStack
from pathlib import Path
import importlib.util
import configparser
import json
import os
import subprocess
import tempfile
import unittest
import zipfile
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "appearance-sync"


def load_module():
    loader = SourceFileLoader("appearance_sync", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class AppearanceSyncTests(unittest.TestCase):
    def test_gtk_defaults_work_without_a_session_bus_and_preserve_user_settings(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            module.CONFIG_HOME = Path(temporary)
            for version in ("3", "4"):
                path = module.CONFIG_HOME / f"gtk-{version}.0/settings.ini"
                path.parent.mkdir()
                path.write_text('[Settings]\ngtk-font-name=Custom Sans 15\ngtk-enable-animations=false\n')
                module.ensure_gtk_settings(version, "Spectrum-first", "dark")
                parser = configparser.ConfigParser()
                parser.read(path)
                self.assertEqual(parser['Settings']['gtk-theme-name'], 'Spectrum-first')
                self.assertTrue(parser.getboolean('Settings', 'gtk-application-prefer-dark-theme'))
                self.assertEqual(parser['Settings']['gtk-font-name'], 'Custom Sans 15')
                self.assertFalse(parser.getboolean('Settings', 'gtk-enable-animations'))
                module.ensure_gtk_settings(version, "Spectrum-second", "light")
                parser.read(path)
                self.assertEqual(parser['Settings']['gtk-theme-name'], 'Spectrum-second')
                self.assertFalse(parser.getboolean('Settings', 'gtk-application-prefer-dark-theme'))

    def test_gtk_theme_identity_changes_with_colors_and_variant(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            module.CURRENT = root / "current"
            module.DATA_HOME = root / "data"
            module.CURRENT.mkdir()
            css = module.CURRENT / "gtk-3.css"
            css.write_text("@define-color theme_bg_color #112233;\n")
            first = module.ensure_gtk_theme("dark")
            self.assertEqual(module.ensure_gtk_theme("dark"), first)
            css.write_text("@define-color theme_bg_color #334455;\n")
            second = module.ensure_gtk_theme("dark")
            self.assertNotEqual(first, second)
            self.assertNotEqual(second, module.ensure_gtk_theme("light"))
            theme = module.DATA_HOME / "themes" / second / "gtk-3.0"
            for filename in ("gtk.css", "gtk-dark.css"):
                rendered = (theme / filename).read_text()
                self.assertIn("gtk-contained-dark.css", rendered)
                self.assertIn("#334455", rendered)

    def test_palette_application_notifies_gtk_even_when_dark_mode_is_unchanged(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary, ExitStack() as stack:
            root = Path(temporary)
            module.CURRENT = root / "current"
            module.DATA_HOME = root / "data"
            module.CONFIG_HOME = root / "config"
            module.CURRENT.mkdir()
            (module.CURRENT / "palette.json").write_text('{"variant":"dark"}')
            for name in ("sync_legion_rgb", "ensure_import", "select_kvantum", "ensure_cava", "ensure_vencord", "ensure_zen_browser", "ensure_icon_theme", "ensure_gamemode_hook", "sync_gtk_font_size", "sync_qt_font_size"):
                stack.enter_context(mock.patch.object(module, name))
            stack.enter_context(mock.patch.object(module.subprocess, "run"))
            settings = stack.enter_context(mock.patch.object(module, "setting"))
            for color in ("#112233", "#334455"):
                (module.CURRENT / "gtk-3.css").write_text("@define-color theme_bg_color " + color + ";")
                self.assertEqual(module.apply(), "dark")
            self.assertEqual(module.sync_legion_rgb.call_count, 2)
            names = [call.args[2] for call in settings.call_args_list if call.args[1] == "gtk-theme"]
            self.assertEqual(len(names), 2)
            self.assertNotEqual(names[0], names[1])
            self.assertTrue(all(name.startswith("Spectrum-") for name in names))

    def test_gtk_migration_preserves_user_rules_and_keeps_gtk4_import(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            module.CONFIG_HOME = root / "config"
            module.CURRENT = root / "current"
            module.CURRENT.mkdir()
            for version in ("3", "4"):
                directory = module.CONFIG_HOME / f"gtk-{version}.0"
                directory.mkdir(parents=True)
                (module.CURRENT / f"gtk-{version}.css").write_text("@define-color theme_bg_color #112233;\n")
                (directory / "spectrum.css").symlink_to(module.CURRENT / f"gtk-{version}.css")
                (directory / "gtk.css").write_text(module.IMPORT + "\n.my-custom-rule { padding: 7px; }\n")
                module.ensure_import(version)
                self.assertIn(".my-custom-rule { padding: 7px; }", (directory / "gtk.css").read_text())
                self.assertEqual((directory / "gtk.css").read_text().count(module.IMPORT), 1)
            self.assertNotIn("#112233", (module.CONFIG_HOME / "gtk-3.0/spectrum.css").read_text())
            self.assertFalse((module.CONFIG_HOME / "gtk-3.0/spectrum.css").is_symlink())
            self.assertTrue((module.CONFIG_HOME / "gtk-4.0/spectrum.css").is_symlink())

    def test_gtk_theme_cleanup_is_bounded_and_preserves_unmanaged_directories(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            module.CURRENT = root / "current"
            module.DATA_HOME = root / "data"
            module.CURRENT.mkdir()
            custom = module.DATA_HOME / "themes/Spectrum-personal"
            custom.mkdir(parents=True)
            (custom / "keep.txt").write_text("personal")
            for index in range(12):
                (module.CURRENT / "gtk-3.css").write_text(f"@define-color theme_bg_color #{index:06x};\n")
                name = module.ensure_gtk_theme("dark")
            managed = list((module.DATA_HOME / "themes").glob("*/.spectrum-managed"))
            self.assertEqual(len(managed), 8)
            self.assertTrue((module.DATA_HOME / "themes" / name).exists())
            self.assertEqual((custom / "keep.txt").read_text(), "personal")
            (module.DATA_HOME / "themes" / name / ".spectrum-managed").unlink()
            with self.assertRaises(RuntimeError):
                module.ensure_gtk_theme("dark")

    def test_cava_theme_preserves_existing_audio_settings_and_custom_colors(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            module.CONFIG_HOME = root / "config"
            module.CURRENT = root / "cache/spectrumos/theme/current"
            config = module.CONFIG_HOME / "cava/config"
            config.parent.mkdir(parents=True)
            config.write_text("[input]\nmethod = pipewire\n\n[color]\n; theme = 'none'\n", encoding="utf-8")
            module.ensure_cava()
            self.assertIn("method = pipewire", config.read_text(encoding="utf-8"))
            self.assertEqual(config.read_text(encoding="utf-8").count("theme = 'Spectrum'"), 1)
            module.ensure_cava()
            self.assertEqual(config.read_text(encoding="utf-8").count("theme = 'Spectrum'"), 1)
            theme = module.CONFIG_HOME / "cava/themes/Spectrum"
            self.assertTrue(theme.is_symlink())
            self.assertEqual(theme.resolve(strict=False), module.CURRENT / "cava.theme")
            config.write_text("[color]\nforeground = '#123456'\n", encoding="utf-8")
            module.ensure_cava()
            self.assertEqual(config.read_text(encoding="utf-8"), "[color]\nforeground = '#123456'\n")

    def test_script_compiles(self):
        source = SCRIPT.read_text(encoding="utf-8")
        compile(source, str(SCRIPT), "exec")

    def test_status_is_read_only_and_reports_missing_integration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            current = root / "cache/spectrumos/theme/current"
            current.mkdir(parents=True)
            (current / "palette.json").write_text(json.dumps({"variant": "light"}), encoding="utf-8")
            result = subprocess.run(
                ("python", str(SCRIPT), "--status"),
                env={
                    **os.environ,
                    "XDG_CONFIG_HOME": str(root / "config"),
                    "XDG_CACHE_HOME": str(root / "cache"),
                    "XDG_DATA_HOME": str(root / "data"),
                    "HOME": str(root / "home"),
                },
                check=True,
                capture_output=True,
                text=True,
            )
        self.assertEqual(
            json.loads(result.stdout),
            {"variant": "light", "gtk3": False, "gtk4": False, "qt5": False, "qt6": False, "icons": False, "vencord": False, "zen": False},
        )

    def test_managed_import_precedes_existing_user_css(self):
        content = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('f"{IMPORT}\\n{existing}"', content)
        self.assertIn('CURRENT / f"gtk-{version}.css"', content)
        self.assertIn("timeout=2", content)
        self.assertIn('"theme=Spectrum\\n"', content)
        self.assertIn('DATA_HOME / "icons/Spectrum"', content)
        self.assertIn('"inode-directory": "folder"', content)
        for icon in ("user-desktop", "folder-publicshare", "folder-templates"):
            self.assertIn(f'"{icon}"', content)
        self.assertIn('"gtk-update-icon-cache"', content)
        self.assertIn('"icon-theme", "Spectrum"', content)
        self.assertIn('CONFIG_HOME / "vesktop/settings"', content)
        self.assertIn('CURRENT / "integrations/vencord-quickcss.css"', content)
        # Vencord injects QuickCSS straight into Discord's own web renderer,
        # where a relative @import silently fails to resolve against the
        # local file next to it (confirmed by a real restart showing no
        # theme) -- the generated CSS must be embedded directly, not linked.
        self.assertNotIn('ensure_link(directory / "spectrum.css"', content)
        # Zen's userChrome.css is embedded the same way, for the same reason: whether a
        # chrome-privileged @import resolves a local relative path here is unconfirmed, and
        # the embed pattern is already proven safe for this "third-party app" situation.
        self.assertIn('CURRENT / "integrations/zen-browser.css"', content)
        self.assertIn('chrome_dir / "userChrome.css"', content)
        self.assertIn('toolkit.legacyUserProfileCustomizations.stylesheets', content)
        self.assertIn('installs.ini', content)
        self.assertIn('profiles.ini', content)
        # The sideloaded WebExtension theme (Firefox/Zen's own official theme pipeline,
        # rather than fighting Zen's internal CSS cascade from userChrome.css alone).
        self.assertIn('CURRENT / "integrations/zen-extension-manifest.json"', content)
        self.assertIn('extensions_dir / f"{ZEN_EXTENSION_ID}.xpi"', content)
        self.assertIn('xpinstall.signatures.required', content)
        # Zen ships this true by default, which makes LightweightThemeConsumer skip
        # applying any WebExtension theme regardless of install/enable state -- the
        # sideloaded extension above is inert without flipping it.
        self.assertIn('zen.theme.disable-lightweight', content)
        # The pref Zen's own gradient/accent engine actually reads at render time --
        # CSS variables and the WebExtension theme are both overridden by it otherwise.
        self.assertIn('zen.theme.accent-color', content)

    def test_zen_profile_discovery_prefers_installs_ini_over_profiles_ini(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "zen"
            (root / "installed.default").mkdir(parents=True)
            (root / "other.profile").mkdir(parents=True)
            (root / "installs.ini").write_text(
                "[F00D]\nDefault=installed.default\nLocked=1\n", encoding="utf-8",
            )
            (root / "profiles.ini").write_text(
                "[Profile0]\nName=other\nIsRelative=1\nPath=other.profile\nDefault=1\n", encoding="utf-8",
            )
            self.assertEqual(
                module.zen_default_profile(root), root / "installed.default",
            )

            (root / "installs.ini").unlink()
            self.assertEqual(
                module.zen_default_profile(root), root / "other.profile",
            )

            (root / "profiles.ini").unlink()
            self.assertIsNone(module.zen_default_profile(root))

    def test_zen_profile_roots_checks_both_known_layouts(self):
        # Community/upstream docs describe ~/.zen (the traditional non-XDG layout), but a
        # real zen-browser-bin install was confirmed live to use ~/.config/zen instead (an
        # XDG-style layout) -- ~/.zen never gets created under it at all, which is exactly
        # why relying on only one location silently found nothing and never wrote a single
        # file. ~/.zen is checked first (docs' own stated default), ~/.config/zen second.
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with mock.patch.object(module.Path, "home", return_value=root):
                roots = module.zen_profile_roots()
            self.assertEqual(roots, (root / ".zen", root / ".config/zen"))

    def test_zen_userchrome_finds_a_profile_under_the_xdg_config_layout(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profile = root / ".config/zen/cyfe19o2.Default (release)"
            profile.mkdir(parents=True)
            (profile.parent / "installs.ini").write_text(
                "[F00D]\nDefault=cyfe19o2.Default (release)\n", encoding="utf-8",
            )
            module.CURRENT = root / "cache/spectrumos/theme/current"
            (module.CURRENT / "integrations").mkdir(parents=True)
            (module.CURRENT / "integrations/zen-browser.css").write_text(":root {}\n", encoding="utf-8")
            (module.CURRENT / "integrations/zen-extension-manifest.json").write_text("{}\n", encoding="utf-8")
            (module.CURRENT / "palette.json").write_text(
                '{"roles": {"accent": "#76b7ff"}}\n', encoding="utf-8",
            )

            with mock.patch.object(module.Path, "home", return_value=root):
                module.ensure_zen_browser()
            self.assertTrue((profile / "chrome/userChrome.css").is_file())
            self.assertTrue((profile / f"extensions/{module.ZEN_EXTENSION_ID}.xpi").is_file())

    def test_zen_userchrome_embeds_content_and_preserves_user_additions(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profile = root / ".zen/spectrum.default"
            profile.mkdir(parents=True)
            (profile.parent / "installs.ini").write_text(
                "[F00D]\nDefault=spectrum.default\n", encoding="utf-8",
            )
            module.CURRENT = root / "cache/spectrumos/theme/current"
            (module.CURRENT / "integrations").mkdir(parents=True)
            (module.CURRENT / "integrations/zen-browser.css").write_text(
                ":root {\n  --lwt-accent-color: #101218;\n}\n", encoding="utf-8",
            )
            (module.CURRENT / "integrations/zen-extension-manifest.json").write_text(
                '{"theme": {"colors": {"frame": "#101218"}}}\n', encoding="utf-8",
            )
            (module.CURRENT / "palette.json").write_text(
                '{"roles": {"accent": "#101218"}}\n', encoding="utf-8",
            )

            with mock.patch.object(module.Path, "home", return_value=root):
                module.ensure_zen_browser()
            user_chrome = profile / "chrome/userChrome.css"
            first = user_chrome.read_text(encoding="utf-8")
            self.assertIn("--lwt-accent-color: #101218;", first)
            self.assertNotIn("@import", first)
            user_chrome.write_text(first + "\n.my-custom-rule { color: red; }\n", encoding="utf-8")
            user_js_first = (profile / "user.js").read_text(encoding="utf-8")
            self.assertIn(
                'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);', user_js_first,
            )
            self.assertIn('user_pref("xpinstall.signatures.required", false);', user_js_first)
            self.assertIn('user_pref("zen.theme.disable-lightweight", false);', user_js_first)
            # The single lever that actually reaches Zen's real rendering path (see
            # ensure_zen_browser): ZenGradientGenerator/zenThemeModifier read this pref
            # directly and inline-override anything set via CSS or the extension.
            self.assertIn('user_pref("zen.theme.accent-color", "#101218");', user_js_first)
            xpi_path = profile / f"extensions/{module.ZEN_EXTENSION_ID}.xpi"
            self.assertTrue(xpi_path.is_file())
            with zipfile.ZipFile(xpi_path) as archive:
                self.assertEqual(
                    json.loads(archive.read("manifest.json")),
                    {"theme": {"colors": {"frame": "#101218"}}},
                )

            (module.CURRENT / "integrations/zen-browser.css").write_text(
                ":root {\n  --lwt-accent-color: #ffffff;\n}\n", encoding="utf-8",
            )
            (module.CURRENT / "palette.json").write_text(
                '{"roles": {"accent": "#ffffff"}}\n', encoding="utf-8",
            )
            with mock.patch.object(module.Path, "home", return_value=root):
                module.ensure_zen_browser()
            second = user_chrome.read_text(encoding="utf-8")
            self.assertIn("--lwt-accent-color: #ffffff;", second)
            self.assertNotIn("#101218", second)
            self.assertIn(".my-custom-rule { color: red; }", second)
            # Neither pref must be duplicated on a second run, and a changed accent color
            # must actually replace the old line rather than leave a stale one behind.
            second_user_js = (profile / "user.js").read_text(encoding="utf-8")
            self.assertEqual(second_user_js.count("toolkit.legacyUserProfileCustomizations.stylesheets"), 1)
            self.assertEqual(second_user_js.count("xpinstall.signatures.required"), 1)
            self.assertEqual(second_user_js.count("zen.theme.disable-lightweight"), 1)
            self.assertEqual(second_user_js.count("zen.theme.accent-color"), 1)
            self.assertIn('user_pref("zen.theme.accent-color", "#ffffff");', second_user_js)
            self.assertNotIn('"zen.theme.accent-color", "#101218"', second_user_js)

    def test_ensure_zen_browser_is_a_silent_no_op_without_a_profile(self):
        # Zen not yet launched (no profile exists) is the common case, not an error --
        # every other integration here runs unconditionally, but a browser profile only
        # exists once the browser itself has actually been opened.
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            module.CURRENT = root / "cache/spectrumos/theme/current"
            (module.CURRENT / "integrations").mkdir(parents=True)
            (module.CURRENT / "integrations/zen-browser.css").write_text(":root {}\n", encoding="utf-8")
            with mock.patch.object(module.Path, "home", return_value=root):
                module.ensure_zen_browser()  # must not raise

    def test_vencord_quickcss_embeds_content_and_preserves_user_additions(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            module.CONFIG_HOME = root / "config"
            module.CURRENT = root / "cache/spectrumos/theme/current"
            (module.CURRENT / "integrations").mkdir(parents=True)
            (module.CURRENT / "integrations/vencord-quickcss.css").write_text(
                ":root {\n  --background-primary: #101218;\n}\n", encoding="utf-8"
            )

            module.ensure_vencord()
            quick_css = module.CONFIG_HOME / "vesktop/settings/quickCss.css"
            first = quick_css.read_text(encoding="utf-8")
            self.assertIn("--background-primary: #101218;", first)
            self.assertNotIn("@import", first)

            quick_css.write_text(first + "\n.my-custom-rule { color: red; }\n", encoding="utf-8")

            (module.CURRENT / "integrations/vencord-quickcss.css").write_text(
                ":root {\n  --background-primary: #ffffff;\n}\n", encoding="utf-8"
            )
            module.ensure_vencord()
            second = quick_css.read_text(encoding="utf-8")
            self.assertIn("--background-primary: #ffffff;", second)
            self.assertNotIn("#101218", second)
            self.assertIn(".my-custom-rule { color: red; }", second)

    def test_vencord_enables_client_theme_without_disturbing_other_settings(self):
        # QuickCSS custom-property overrides don't reach every screen --
        # newer redesigned Discord surfaces (the Friends page, in
        # particular) hardcode some chrome instead of reading those
        # variables. ClientTheme recreates Discord's own former single-color
        # client theme using Discord's current internals, and does reach
        # those pages -- confirmed by a real cold restart. It must be seeded
        # with the background role, not accent: ClientTheme derives the
        # whole ramp's lightness from its one input color with no separate
        # dark/light flag, and accent (lighter and more saturated even in
        # dark palettes) produced a washed-out theme regardless of variant --
        # confirmed by a real restart that background produces a properly
        # dark result from a dark palette.
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            module.CONFIG_HOME = root / "config"
            module.CURRENT = root / "cache/spectrumos/theme/current"
            (module.CURRENT / "integrations").mkdir(parents=True)
            (module.CURRENT / "integrations/vencord-quickcss.css").write_text(":root {}\n", encoding="utf-8")
            (module.CURRENT / "palette.json").write_text(
                json.dumps({"roles": {"accent": "#91caca", "background": "#254343"}}), encoding="utf-8"
            )
            settings_dir = module.CONFIG_HOME / "vesktop/settings"
            settings_dir.mkdir(parents=True)
            settings_path = settings_dir / "settings.json"
            settings_path.write_text(
                json.dumps(
                    {
                        "useQuickCss": True,
                        "plugins": {
                            "ClientTheme": {"enabled": False},
                            "CommandsAPI": {"enabled": True},
                        },
                    }
                ),
                encoding="utf-8",
            )

            module.ensure_vencord()

            settings = json.loads(settings_path.read_text(encoding="utf-8"))
            self.assertEqual(settings["plugins"]["ClientTheme"], {"enabled": True, "color": "254343"})
            self.assertEqual(settings["plugins"]["CommandsAPI"], {"enabled": True})
            self.assertIs(settings["useQuickCss"], True)

    def test_gamemode_hook_is_added_and_preserves_user_additions(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            module.CONFIG_HOME = Path(directory)

            module.ensure_gamemode_hook()
            path = module.CONFIG_HOME / "gamemode.ini"
            first = path.read_text(encoding="utf-8")
            self.assertIn("[custom]", first)
            self.assertIn("start=/usr/lib/spectrumos/performance-mode --game-start", first)
            self.assertIn("end=/usr/lib/spectrumos/performance-mode --game-end", first)

            path.write_text(first + "\n[general]\nreaper_freq=5\n", encoding="utf-8")
            module.ensure_gamemode_hook()
            second = path.read_text(encoding="utf-8")
            self.assertIn("reaper_freq=5", second)
            self.assertEqual(second.count("start=/usr/lib/spectrumos/performance-mode --game-start"), 1)

    def test_font_size_falls_back_to_13_when_missing_or_invalid(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with mock.patch.object(module.os, "environ", {"XDG_STATE_HOME": str(root)}):
                self.assertEqual(module.font_size(), 13)

                typography = root / "spectrumos/typography"
                typography.mkdir(parents=True)
                (typography / "font-size").write_text("not-a-number", encoding="utf-8")
                self.assertEqual(module.font_size(), 13)

                (typography / "font-size").write_text("99", encoding="utf-8")
                self.assertEqual(module.font_size(), 13)

                (typography / "font-size").write_text("18", encoding="utf-8")
                self.assertEqual(module.font_size(), 18)

    def test_resized_font_preserves_the_configured_family(self):
        module = load_module()
        with mock.patch.object(module.subprocess, "run") as run:
            run.return_value.stdout = "'Adwaita Sans 11'\n"
            self.assertEqual(
                module.resized_font("org.gnome.desktop.interface", "font-name", 18, "Sans"),
                "Adwaita Sans 18",
            )

    def test_resized_font_falls_back_to_the_default_family_when_gsettings_fails(self):
        module = load_module()
        with mock.patch.object(module.subprocess, "run", side_effect=OSError("gsettings missing")):
            self.assertEqual(
                module.resized_font("org.gnome.desktop.interface", "font-name", 18, "Sans"),
                "Sans 18",
            )

    def test_ensure_qt_font_creates_a_sensible_default_when_missing(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "qt5ct/qt5ct.conf"
            module.ensure_qt_font(path, 18, {"general": "Sans Serif", "fixed": "JetBrains Mono"})
            content = path.read_text(encoding="utf-8")
            self.assertIn('general="Sans Serif,18,-1,5,50,0,0,0,0,0"', content)
            self.assertIn('fixed="JetBrains Mono,18,-1,5,50,0,0,0,0,0"', content)

    def test_ensure_qt_font_only_replaces_the_point_size_field(self):
        # A user's own font family (or a differently-shaped QFont string entirely) must
        # survive every global font-size change untouched -- only field 1 is ours.
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "qt5ct/qt5ct.conf"
            path.parent.mkdir(parents=True)
            path.write_text(
                '[Appearance]\ncustom_palette=true\n\n[Fonts]\ngeneral="Cantarell,14,-1,5,50,0,0,0,0,0"\n',
                encoding="utf-8",
            )

            module.ensure_qt_font(path, 20, {"general": "Sans Serif", "fixed": "JetBrains Mono"})

            content = path.read_text(encoding="utf-8")
            self.assertIn('general="Cantarell,20,-1,5,50,0,0,0,0,0"', content)
            self.assertIn('fixed="JetBrains Mono,20,-1,5,50,0,0,0,0,0"', content)
            self.assertIn("custom_palette=true", content)

    def test_ensure_qt_font_preserves_a_bare_family_with_no_point_size_yet(self):
        # A hand-edited or non-Qt-written Fonts value can be a bare family name with no
        # comma at all -- that family must survive, not get silently replaced by the
        # hardcoded default just because the string doesn't yet have a size field.
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "qt5ct/qt5ct.conf"
            path.parent.mkdir(parents=True)
            path.write_text('[Fonts]\ngeneral="Comic Sans MS"\n', encoding="utf-8")

            module.ensure_qt_font(path, 20, {"general": "Sans Serif", "fixed": "JetBrains Mono"})

            content = path.read_text(encoding="utf-8")
            self.assertIn('general="Comic Sans MS,20,-1,5,50,0,0,0,0,0"', content)
            self.assertIn('fixed="JetBrains Mono,20,-1,5,50,0,0,0,0,0"', content)

    def test_sync_qt_font_size_writes_both_qt5ct_and_qt6ct(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            module.CONFIG_HOME = Path(directory)
            module.sync_qt_font_size(16)
            for tool in ("qt5ct", "qt6ct"):
                content = (module.CONFIG_HOME / tool / f"{tool}.conf").read_text(encoding="utf-8")
                self.assertIn('general="Sans Serif,16,-1,5,50,0,0,0,0,0"', content)


if __name__ == "__main__":
    unittest.main()
