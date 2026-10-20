from pathlib import Path
import subprocess
import re
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def test_source_archive_excludes_package_build_outputs(self):
        builder = (ROOT / "scripts/build-source-archive").read_text(encoding="utf-8")
        self.assertIn("packages/*/pkg/*", builder)
        self.assertIn("packages/*/src/spectrumos-source-*/*", builder)

    def test_source_archive_omits_downloads_but_keeps_project_sources(self):
        if not shutil.which("zstd"):
            self.skipTest("zstd is required for source export")
        packages=("spectrum-base","spectrum-desktop","spectrum-hyprland","spectrum-plymouth","spectrum-sddm","spectrum-theme","spectrumdrop")
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/"scripts").mkdir()
            shutil.copy2(ROOT/"scripts/build-source-archive",root/"scripts/build-source-archive")
            (root/"system/release").mkdir(parents=True)
            (root/"system/release/release.toml").write_text('version = "1.0.0"\n')
            for name in packages: (root/"packages"/name).mkdir(parents=True)
            (root/"packages/spectrum-theme/src").mkdir()
            (root/"packages/spectrum-theme/src/engine.py").write_text("source = True\n")
            for name in ("questline-2.0.1-linux-x86_64","stash-0.7.0-linux-x86_64","cached.tar.gz"):
                (root/"packages/spectrum-desktop"/name).write_text("download")
            subprocess.run(["git","init","-q",str(root)],check=True,capture_output=True)
            subprocess.run([str(root/"scripts/build-source-archive"),"--build"],check=True,capture_output=True)
            archive=next((root/"repo/sources").glob("*.tar.zst"))
            self.assertEqual(archive.stat().st_mode & 0o777,0o644)
            files=subprocess.check_output(["bsdtar","-tf",str(archive)],text=True).splitlines()
            self.assertIn("spectrumos-source-1.0.0/packages/spectrum-theme/src/engine.py",files)
            self.assertFalse(any("linux-x86_64" in name or "cached.tar.gz" in name for name in files))
            repeated=subprocess.run([str(root/"scripts/build-source-archive"),"--build"],capture_output=True,text=True)
            self.assertEqual(repeated.returncode,0,repeated.stderr)
            archive.write_bytes(b"different immutable bytes")
            rejected=subprocess.run([str(root/"scripts/build-source-archive"),"--build"],capture_output=True,text=True)
            self.assertNotEqual(rejected.returncode,0)
            self.assertIn("Refusing to overwrite",rejected.stderr)
            self.assertEqual(archive.read_bytes(),b"different immutable bytes")

    def test_spectrum_theme_has_a_narrow_arch_package_boundary(self):
        package_root = ROOT / "packages" / "spectrum-theme"
        pkgbuild = (package_root / "PKGBUILD").read_text(encoding="utf-8")
        launcher = (package_root / "spectrum-theme").read_text(encoding="utf-8")

        self.assertIn("pkgname=spectrum-theme", pkgbuild)
        self.assertIn("depends=(python ffmpeg)", pkgbuild)
        self.assertIn("optdepends=('matugen:", pkgbuild)
        self.assertIn("options=(!strip !debug)", pkgbuild)
        self.assertIn("/usr/share/spectrumos/theme-engine", pkgbuild)
        self.assertIn("/usr/bin/spectrum-theme", pkgbuild)
        self.assertIn("python -m unittest discover", pkgbuild)
        self.assertNotIn("sudo", pkgbuild)
        self.assertNotIn("paru", pkgbuild)
        self.assertEqual(launcher.splitlines()[0], "#!/usr/bin/env bash")
        self.assertIn("exec python -m spectrum_theme.cli", launcher)
        self.assertTrue((package_root / "LICENSE").is_file())
        self.assertTrue((package_root / ".SRCINFO").is_file())

    def test_package_tracks_no_generated_python_cache(self):
        if not (ROOT / ".git").is_dir():
            self.skipTest("Git metadata is unavailable in an exported source tree")
        tracked = subprocess.run(
            ["git", "ls-files", "packages/spectrum-theme"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        self.assertFalse(any("__pycache__" in path or path.endswith(".pyc") for path in tracked))

    def test_spectrum_hyprland_packages_only_immutable_defaults(self):
        package_root = ROOT / "packages" / "spectrum-hyprland"
        pkgbuild = (package_root / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn("pkgname=spectrum-hyprland", pkgbuild)
        self.assertIn(
            "depends=('spectrum-base>=1.0.0' hyprland hypridle hyprlock polkit-gnome uwsm spectrum-theme "
            "xdg-desktop-portal-hyprland xdg-desktop-portal-gtk)",
            pkgbuild,
        )
        self.assertIn("scripts/validate-hyprland.py", pkgbuild)
        self.assertIn("/usr/share/spectrumos/hyprland", pkgbuild)
        self.assertNotIn("/etc/spectrumos", pkgbuild)
        self.assertNotIn("$HOME", pkgbuild)
        self.assertNotIn("sudo", pkgbuild)
        self.assertTrue((package_root / "LICENSE").is_file())
        self.assertTrue((package_root / ".SRCINFO").is_file())

    def test_spectrum_desktop_owns_visual_frontends_and_static_defaults(self):
        package_root = ROOT / "packages" / "spectrum-desktop"
        pkgbuild = (package_root / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn("pkgname=spectrum-desktop", pkgbuild)
        for dependency in ("spectrum-hyprland", "spectrum-plymouth", "spectrum-sddm", "spectrum-theme"):
            self.assertIn(dependency, pkgbuild)
        self.assertNotIn("configs/waybar/layouts/*.jsonc", pkgbuild)
        self.assertNotIn("configs/wofi/profiles/*.conf", pkgbuild)
        self.assertIn("configs/terminal/*", pkgbuild)
        self.assertIn("scripts/$script", pkgbuild)
        for frontend in (
            "theme-menu", "spectrum-shell", "spectrum-shell-picker", "panel", "appearance-sync", "waybar-cava"
        ):
            self.assertIn(frontend, pkgbuild)
        self.assertNotIn("configs/eww/*", pkgbuild)
        self.assertNotIn("spectrum-eww.service", pkgbuild)
        self.assertNotIn("spectrum-network-ui.service", pkgbuild)
        self.assertIn("swayimg", pkgbuild)
        self.assertIn("configs/xdg/mimeapps.list", pkgbuild)
        self.assertIn("configs/networkmanager/20-spectrumos.conf", pkgbuild)
        self.assertIn("configs/vlc/vlcrc", pkgbuild)
        self.assertIn("scripts/pipewire-restart", pkgbuild)
        self.assertIn("60-spectrumos-pipewire-restart.hook", pkgbuild)
        self.assertIn("60-spectrumos-desktop.preset", pkgbuild)
        for dependency in ("htop", "noto-fonts-cjk", "xdg-user-dirs"):
            self.assertIn(dependency, pkgbuild)
        self.assertNotIn("'docker: Container development", pkgbuild)
        self.assertNotIn("'kdeconnect: Phone integration", pkgbuild)
        for dependency in ("evolution", "kdeconnect"):
            self.assertIn(dependency, pkgbuild.split("makedepends=")[0])
        self.assertIn('etc/xdg/autostart/spectrum-kdeconnect-indicator.desktop', pkgbuild)
        for dependency in (
            "ttf-jetbrains-mono-nerd", "ttf-firacode-nerd", "ttf-sourcecodepro-nerd",
            "ttf-cascadia-code-nerd", "ttf-hack-nerd", "ttf-ibmplex-mono-nerd",
            "ttf-iosevka-nerd", "ttf-victor-mono-nerd", "ttf-ubuntu-mono-nerd", "ttf-meslo-nerd",
        ):
            self.assertIn(dependency, pkgbuild)
        self.assertNotIn("$HOME", pkgbuild)
        self.assertNotIn("sudo", pkgbuild)
        self.assertTrue((package_root / "LICENSE").is_file())
        self.assertTrue((package_root / ".SRCINFO").is_file())

    def test_spectrum_base_owns_the_default_wallpaper(self):
        package_root = ROOT / "packages" / "spectrum-base"
        pkgbuild = (package_root / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn("assets/wallpapers/default/*.png", pkgbuild)
        self.assertIn("/usr/share/backgrounds/spectrumos/", pkgbuild)

    def test_spectrum_base_owns_the_zram_policy(self):
        pkgbuild = (ROOT / "packages" / "spectrum-base" / "PKGBUILD").read_text(encoding="utf-8")
        self.assertIn("zram-generator", pkgbuild)
        self.assertIn("system/zram-generator.conf.d/60-spectrumos.conf", pkgbuild)
        self.assertIn("usr/lib/systemd/zram-generator.conf.d/60-spectrumos.conf", pkgbuild)

    def test_spectrum_base_packages_snapshot_prototype(self):
        pkgbuild = (ROOT / "packages" / "spectrum-base" / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn("btrfs-progs", pkgbuild)
        self.assertIn("libarchive", pkgbuild)
        self.assertIn("usr/lib/initcpio/install/spectrumos-restore", pkgbuild)
        self.assertIn("usr/lib/initcpio/hooks/spectrumos-restore", pkgbuild)
        self.assertIn('scripts/snapshot"', pkgbuild)
        self.assertIn('"$pkgdir/usr/bin/spectrum-snapshot"', pkgbuild)
        self.assertIn("test_snapshot.py", pkgbuild)

    def test_spectrum_base_packages_release_foundation(self):
        pkgbuild = (ROOT / "packages" / "spectrum-base" / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn('scripts/spectrum"', pkgbuild)
        self.assertIn('"$pkgdir/usr/bin/spectrum"', pkgbuild)
        self.assertIn("system/release/release.toml", pkgbuild)
        self.assertIn("migrations/manifest.toml", pkgbuild)
        self.assertIn("test_spectrum_info.py", pkgbuild)
        self.assertIn("test_spectrum_doctor.py", pkgbuild)
        self.assertIn("test_update_plan.py", pkgbuild)

    def test_spectrum_base_packages_shell_and_editor_defaults(self):
        pkgbuild = (ROOT / "packages" / "spectrum-base" / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn("configs/zsh/zshrc", pkgbuild)
        self.assertIn("configs/zsh/defaults.zsh", pkgbuild)
        self.assertIn("configs/zsh/themes/spectrum.zsh-theme", pkgbuild)
        self.assertIn("configs/nvim/{init.lua,lazy-lock.json,lazyvim.json,stylua.toml}", pkgbuild)
        self.assertIn("configs/nvim/colors/spectrum.lua", pkgbuild)

    def test_desktop_frontend_install_loop_ships_app_store_helpers(self):
        recipe = (ROOT / "packages/spectrum-desktop/PKGBUILD").read_text()
        body = recipe.split("package() {", 1)[1]
        loop = re.search(r"    for script in .*?    done", body, re.S)
        self.assertIsNotNone(loop)
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            script = 'set -eu\n_project=$1\npkgdir=$2\ninstall -d "$pkgdir/usr/lib/spectrumos"\n' + loop.group()
            subprocess.run(["bash", "-c", script, "package-frontends", str(ROOT), str(package)], check=True)
            for name in ("app-store-adapter", "app-store-privileged", "app-store-paru-bridge"):
                installed = package / "usr/lib/spectrumos" / name
                self.assertTrue(installed.is_file(), name)
                self.assertEqual(installed.read_bytes(), (ROOT / "scripts" / name).read_bytes())
                self.assertTrue(installed.stat().st_mode & 0o111)

    def test_hyprland_package_contains_hardware_profile_assets(self):
        pkgbuild = (ROOT / "packages" / "spectrum-hyprland" / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn("configs/hyprland/gpu/*.lua", pkgbuild)
        self.assertIn("scripts/nvidia-offload", pkgbuild)
        self.assertIn("spectrumos-nvidia-power.conf", pkgbuild)

    def test_plymouth_package_uses_only_the_bounded_quit_dropin(self):
        pkgbuild = (ROOT / "packages" / "spectrum-plymouth" / "PKGBUILD").read_text(encoding="utf-8")

        self.assertNotIn("etc/plymouth/plymouthd.conf", pkgbuild)
        self.assertNotIn("plymouth-start.service", pkgbuild)
        self.assertIn("plymouth-quit.service.d", pkgbuild)

    def test_all_packages_use_a_checksummed_immutable_source_snapshot(self):
        recipes = [
            (ROOT / "packages" / name / "PKGBUILD").read_text(encoding="utf-8")
            for name in (
                "spectrum-base", "spectrum-desktop", "spectrum-hyprland",
                "spectrum-plymouth", "spectrum-sddm", "spectrum-theme",
            )
        ]
        for recipe in recipes:
            self.assertIn("_source_revision=", recipe)
            self.assertIn('source=("spectrumos-source-$pkgver-$_source_revision.tar.zst"', recipe)
            self.assertRegex(recipe, r"sha256sums=\('[0-9a-f]{64}'")
            self.assertNotIn("$startdir/../..", recipe)

        desktop = recipes[1]
        self.assertRegex(desktop, r'questline-[0-9.]+-spectrum-[^:\s"]+\.tar\.zst::https://spectrum\.gibranlp\.dev/sources/')
        self.assertNotIn("'SKIP'", desktop)
        self.assertIn('usr/bin/questline', desktop)

    def test_desktop_packages_shared_font_registry_without_dunst_override(self):
        pkgbuild = (ROOT / "packages" / "spectrum-desktop" / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn("font-families.conf", pkgbuild)
        self.assertNotIn('"$pkgdir/usr/lib/systemd/user/dunst.service.d"', pkgbuild)
        self.assertNotIn("system/systemd/user/dunst.service.d/spectrumos-config.conf", pkgbuild)
        self.assertNotIn("usr/lib/systemd/user/dunst.service.d/spectrumos-config.conf", pkgbuild)

    def test_desktop_packages_resource_monitor(self):
        pkgbuild = (ROOT / "packages" / "spectrum-desktop" / "PKGBUILD").read_text(encoding="utf-8")

        self.assertIn('"$_project/scripts/resource-monitor"', pkgbuild)
        self.assertIn("tests.test_resource_monitor", pkgbuild)
        self.assertIn("system/systemd/user/spectrum-resource-monitor.service", pkgbuild)
        self.assertIn("usr/lib/systemd/user/spectrum-resource-monitor.service", pkgbuild)


if __name__ == "__main__":
    unittest.main()
