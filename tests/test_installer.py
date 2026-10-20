from pathlib import Path
import io
import os
import re
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "install.sh"


class InstallerTests(unittest.TestCase):
    def run_installer(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["SPECTRUM_PACMAN_CONFIG"] = str(
            ROOT / "tests" / "fixtures" / "pacman-multilib.conf"
        )
        return subprocess.run(
            ("bash", str(INSTALLER), *arguments),
            cwd=ROOT,
            env=environment,
            check=False,
            text=True,
            capture_output=True,
        )

    def run_hotkey_install(self, directory, *, owner="", apply=True, existing=True, fail=False):
        target = Path(directory)
        helper = target / "helper"
        if existing:
            helper.write_text("#!/bin/sh\nexit 0\n")
            helper.chmod(0o755)
        builder = target / "project/integrations/hotkey/build"
        builder.parent.mkdir(parents=True)
        builder.write_text('#!/bin/sh\ntouch "$BUILD_LOG"\n[ "$BUILD_FAILURE" = 0 ] || exit 1\nprintf "packaged fixture\\n" > "$2"\n')
        builder.chmod(0o755)
        function = re.search(r"^install_hotkey_keyboard\(\) \{.*?^\}", INSTALLER.read_text(), re.M | re.S).group()
        script = '''set -euo pipefail
PROJECT_ROOT=$1
APPLY=$2
log() { printf '%s\\n' "$*"; }
die() { printf '%s\\n' "$*" >&2; exit 1; }
run() { "$@"; }
sudo() { "$@"; }
pacman() { printf '%s\\n' "$TEST_OWNER"; }
''' + function + '\ninstall_hotkey_keyboard "$3"\n'
        result = subprocess.run(
            ["bash", "-c", script, "bash", str(target / "project"), str(apply).lower(), str(helper)],
            env=dict(os.environ, TEST_OWNER=owner, BUILD_LOG=str(target / "build-log"),
                     BUILD_FAILURE="1" if fail else "0"), text=True, capture_output=True)
        return result, helper, target / "build-log"

    def test_package_owned_hotkey_is_reused_without_build_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            result, helper, log = self.run_hotkey_install(directory, owner="spectrum-desktop", fail=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("package-owned", result.stdout)
            self.assertFalse(log.exists())
            self.assertEqual(helper.read_text(), "#!/bin/sh\nexit 0\n")

    def test_unowned_hotkey_keeps_source_install_path(self):
        with tempfile.TemporaryDirectory() as directory:
            result, helper, log = self.run_hotkey_install(directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(log.exists())
            self.assertEqual(helper.read_text(), "packaged fixture\n")
            self.assertTrue(os.access(helper, os.X_OK))

    def test_hotkey_dry_run_does_not_compile_or_create_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            result, helper, log = self.run_hotkey_install(directory, apply=False, existing=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(helper.exists())
            self.assertFalse(log.exists())

    def test_hotkey_build_failure_preserves_existing_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            result, helper, log = self.run_hotkey_install(directory, fail=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("check pkgconf, Wayland and xkbcommon", result.stderr)
            self.assertTrue(log.exists())
            self.assertEqual(helper.read_text(), "#!/bin/sh\nexit 0\n")

    def test_help_documents_safe_default_and_phases(self):
        result = self.run_installer("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("dry-run by default", result.stdout)
        self.assertIn("packages", result.stdout)
        self.assertIn("validate", result.stdout)

    def test_phases_are_machine_readable(self):
        result = self.run_installer("--list-phases")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            ["preflight", "packages", "system", "user", "theme", "validate", "reload"],
        )

    def test_unknown_phase_is_rejected(self):
        result = self.run_installer("--phase", "destructive")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown phase", result.stderr)

    def test_explicit_hardware_profiles_resolve_independently(self):
        result = self.run_installer(
            "--phase", "packages", "--profile", "base", "--cpu", "amd", "--gpu", "nvidia",
            "--form-factor", "laptop",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        for package in ("amd-ucode", "linux-zen-headers", "nvidia-open-dkms", "lib32-nvidia-utils", "power-profiles-daemon"):
            self.assertIn(package, result.stdout)
        self.assertNotIn("vulkan-radeon", result.stdout)

    def test_vm_profile_has_virtio_graphics_and_guest_agents(self):
        result = self.run_installer("--phase", "packages", "--profile", "base", "--gpu", "vm")
        self.assertEqual(result.returncode, 0, result.stderr)
        for package in ("vulkan-virtio", "lib32-vulkan-virtio", "qemu-guest-agent", "spice-vdagent"):
            self.assertIn(package, result.stdout)

    def test_intel_profiles_include_legacy_video_acceleration(self):
        for gpu in ("intel", "nvidia-intel"):
            with self.subTest(gpu=gpu):
                result = self.run_installer("--phase", "packages", "--gpu", gpu, "--form-factor", "laptop")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("libva-intel-driver", result.stdout.split())
                self.assertIn("intel-media-driver", result.stdout.split())

    def test_hybrid_nvidia_profiles_include_both_graphics_stacks(self):
        intel = self.run_installer("--phase", "packages,system", "--profile", "base", "--gpu", "nvidia-intel")
        self.assertEqual(intel.returncode, 0, intel.stderr)
        for package in ("vulkan-intel", "lib32-vulkan-intel", "linux-zen-headers", "nvidia-open-dkms", "lib32-nvidia-utils", "switcheroo-control"):
            self.assertIn(package, intel.stdout)
        self.assertIn("switcheroo-control.service", intel.stdout)

        amd = self.run_installer("--phase", "packages", "--profile", "base", "--gpu", "nvidia-amd")
        self.assertEqual(amd.returncode, 0, amd.stderr)
        for package in ("vulkan-radeon", "lib32-vulkan-radeon", "nvidia-open-dkms", "lib32-nvidia-utils", "switcheroo-control"):
            self.assertIn(package, amd.stdout)

    def test_nvidia_profiles_get_modeset_suspend_and_hyprland_fixes(self):
        discrete = self.run_installer("--phase", "system", "--gpu", "nvidia")
        self.assertEqual(discrete.returncode, 0, discrete.stderr)
        self.assertIn("spectrumos-nvidia-power.conf", discrete.stdout)
        self.assertIn("nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service", discrete.stdout)
        self.assertIn("nvidia-offload", discrete.stdout)
        self.assertIn("configs/hyprland/gpu/nvidia.lua", discrete.stdout)
        self.assertIn("plymouth-boot-sync --nvidia", discrete.stdout)
        # `install` (unlike `install -D`) never creates missing parent
        # directories -- a fresh pacstrap target has no /usr/lib/spectrumos
        # yet at this point in phase_system, so installing nvidia-offload
        # before creating it failed live with "install: cannot create
        # regular file /usr/lib/spectrumos/nvidia-offload: No such file or
        # directory" partway through a real disk install.
        self.assertLess(
            discrete.stdout.index("install -d -m 0755 /usr/lib/spectrumos"),
            discrete.stdout.index("nvidia-offload"),
            "nvidia-offload must be installed after /usr/lib/spectrumos is created",
        )

        hybrid = self.run_installer("--phase", "system", "--gpu", "nvidia-intel")
        self.assertEqual(hybrid.returncode, 0, hybrid.stderr)
        self.assertIn("spectrumos-nvidia-power.conf", hybrid.stdout)
        self.assertIn("configs/hyprland/gpu/hybrid-nvidia.lua", hybrid.stdout)
        self.assertNotIn("configs/hyprland/gpu/nvidia.lua ", hybrid.stdout)
        self.assertIn("plymouth-boot-sync --nvidia", hybrid.stdout)

        intel = self.run_installer("--phase", "system", "--gpu", "intel")
        self.assertEqual(intel.returncode, 0, intel.stderr)
        self.assertNotIn("nvidia-power.conf", intel.stdout)
        self.assertNotIn("nvidia-suspend.service", intel.stdout)
        self.assertNotIn("nvidia-offload", intel.stdout)
        self.assertNotIn("gpu/nvidia.lua", intel.stdout)
        self.assertNotIn("gpu/hybrid-nvidia.lua", intel.stdout)
        self.assertIn("plymouth-boot-sync ", intel.stdout)
        self.assertNotIn("plymouth-boot-sync --nvidia", intel.stdout)

    def test_empty_aur_profile_does_not_invoke_paru(self):
        result = self.run_installer("--phase", "packages", "--profile", "base", "--gpu", "vm")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("paru -S", result.stdout)

    def test_form_factor_and_vm_services_have_explicit_lifecycle(self):
        laptop = self.run_installer("--phase", "system", "--form-factor", "laptop")
        self.assertEqual(laptop.returncode, 0, laptop.stderr)
        self.assertIn("systemctl enable --now power-profiles-daemon.service", laptop.stdout)
        vm = self.run_installer("--phase", "system", "--gpu", "vm")
        self.assertEqual(vm.returncode, 0, vm.stderr)
        self.assertIn("systemctl enable qemu-guest-agent.service", vm.stdout)

    def test_laptop_full_and_lean_use_only_power_profiles_daemon(self):
        for options in ((), ("--lean",)):
            with self.subTest(options=options):
                result = self.run_installer("--phase", "packages,system", "--form-factor", "laptop", *options)
                self.assertEqual(result.returncode, 0, result.stderr)
                package_line = next(line for line in result.stdout.splitlines() if "pacman -Syu" in line)
                self.assertIn("power-profiles-daemon", package_line.split())
                self.assertNotIn("tuned", package_line.split())
                self.assertNotIn("tlp", package_line.split())
                self.assertIn("systemctl mask --now tuned.service", result.stdout)
                self.assertIn("systemctl unmask power-profiles-daemon.service", result.stdout)
                self.assertIn("systemctl enable --now power-profiles-daemon.service", result.stdout)
                self.assertNotIn("systemctl enable tuned.service", result.stdout)

    def test_installed_system_does_not_stall_boot_waiting_for_network(self):
        # Same fix as the live ISO profile's masked NetworkManager-wait-online
        # unit: without it, network-online.target (and anything ordered
        # after it) blocks for up to that service's NM_ONLINE_TIMEOUT=60s
        # default whenever nothing is connected yet at boot.
        result = self.run_installer("--phase", "system")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("systemctl mask NetworkManager-wait-online.service", result.stdout)

    def test_installed_system_gets_explicit_zram_policy(self):
        result = self.run_installer("--phase", "system")
        self.assertEqual(result.returncode, 0, result.stderr)
        policy = ROOT / "system/zram-generator.conf.d/60-spectrumos.conf"
        content = policy.read_text(encoding="utf-8")
        self.assertIn("[zram0]", content)
        self.assertIn("zram-size = min(ram, 8192)", content)
        self.assertIn("compression-algorithm = zstd", content)
        self.assertIn("swap-priority = 100", content)
        self.assertIn("/usr/lib/systemd/zram-generator.conf.d/60-spectrumos.conf", result.stdout)

    def test_legacy_hardware_alias_remains_compatible(self):
        result = self.run_installer("--phase", "packages", "--profile", "base", "--hardware", "amd")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("amd-ucode", result.stdout)
        self.assertIn("vulkan-radeon", result.stdout)

    def test_invalid_or_conflicting_hardware_profiles_fail_closed(self):
        invalid = self.run_installer("--cpu", "arm")
        self.assertNotEqual(invalid.returncode, 0)
        self.assertIn("CPU must be", invalid.stderr)
        conflict = self.run_installer("--hardware", "amd", "--gpu", "intel")
        self.assertNotEqual(conflict.returncode, 0)
        self.assertIn("conflicts with GPU", conflict.stderr)

    def test_dry_run_system_phase_does_not_require_root(self):
        result = self.run_installer("--phase", "system")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("sudo install", result.stdout)
        self.assertIn("Dry-run only", result.stdout)

    def test_every_looped_desktop_script_install_exists(self):
        # phase_system installs each name in this for-loop with
        # "$PROJECT_ROOT/scripts/$desktop_script" -- a name left behind after
        # its script was deleted (eww-record, removed when recording moved
        # fully to Wofi, but never dropped from this loop) doesn't fail dry
        # run at all, since `run` only prints the command; it fails a real
        # --apply with "install: cannot stat .../scripts/eww-record: No such
        # file or directory" partway through a live install. Confirmed live.
        installer = INSTALLER.read_text(encoding="utf-8")
        match = re.search(
            r"for desktop_script in \\\n(.*?); do\n", installer, re.DOTALL,
        )
        self.assertIsNotNone(match, "could not find the desktop_script loop in install.sh")
        names = match.group(1).replace("\\", " ").split()
        self.assertGreaterEqual(len(names), 20, "sanity check: the loop should list many scripts")
        for name in names:
            with self.subTest(script=name):
                self.assertTrue((ROOT / "scripts" / name).is_file(), f"scripts/{name} is missing")

    def test_fresh_install_includes_current_desktop_and_recovery_runtime(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        match = re.search(
            r"for desktop_script in \\\n(.*?); do\n", installer, re.DOTALL,
        )
        self.assertIsNotNone(match)
        installed_scripts = set(match.group(1).replace("\\", " ").split())
        for script in (
            "font-family-menu",
            "performance-mode",
            "resource-monitor",
            "session-menu",
            "spectrum-update-run",
            "waybar-workspace-icons",
            "window-pin-toggle",
        ):
            with self.subTest(script=script):
                self.assertIn(script, installed_scripts)
        for path in (
            "system/spectrumos/font-families.conf",
            "system/release/release.toml",
            "migrations/manifest.toml",
            "system/initcpio/install/spectrumos-restore",
            "system/initcpio/hooks/spectrumos-restore",
            "system/pacman-hooks/05-spectrumos-pre-upgrade-snapshot.hook",
        ):
            with self.subTest(path=path):
                self.assertIn(f'$PROJECT_ROOT/{path}', installer)

    def test_validation_includes_theme_engine_tests(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn('packages/spectrum-theme/tests', installer)
        self.assertIn('PYTHONPATH=$PROJECT_ROOT/packages/spectrum-theme/src', installer)

    def test_standalone_apply_validation_resolves_target_home(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        validation = installer.split("phase_validate() {", 1)[1].split("\n}", 1)[0]
        self.assertIn("resolve_target", validation)

    def test_user_adoption_replaces_managed_entrypoints_without_backups(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn('wallpaper_dir="$TARGET_HOME/Pictures/Wallpapers"', installer)
        self.assertIn('rm -f -- "$hypr_dir/hyprland.lua" "$hypr_dir/hyprland.conf"', installer)
        self.assertIn(
            'install -m 0644 /usr/share/spectrumos/hyprland/hyprland.lua "$hypr_dir/hyprland.lua"',
            installer,
        )
        self.assertNotIn('ln -s /usr/share/spectrumos/hyprland/hyprland.lua', installer)
        self.assertNotIn("spectrum-backup", installer)
        self.assertNotIn("read -r -p", installer)

    def test_user_adoption_initializes_standard_home_directories(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        self.assertIn("\nxdg-user-dirs\n", f"\n{desktop}\n")
        self.assertIn("run_as_target xdg-user-dirs-update", installer)
        self.assertIn('projects_dir="$TARGET_HOME/Projects"', installer)

    def test_entrypoint_migration_does_not_hot_reload_old_lua_path(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertNotIn("hyprctl reload", installer)
        self.assertIn("config entrypoint changed from Hyprlang to Lua", installer)
        self.assertIn("HYPRLAND_CONFIG=%s", installer)
        self.assertIn("hyprctl seterror disable", installer)

    def test_hypridle_uses_installed_spectrum_configuration(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        autostart = (ROOT / "configs/hyprland/autostart.lua").read_text(encoding="utf-8")
        idle_config = ROOT / "configs/hyprland/hypridle.conf"
        self.assertTrue(idle_config.is_file())
        self.assertIn(
            "hypridle -c /usr/share/spectrumos/hyprland/hypridle.conf",
            autostart,
        )
        idle_policy = idle_config.read_text(encoding="utf-8")
        self.assertIn("ignore_systemd_inhibit = false", idle_policy)
        self.assertEqual(idle_policy.count("condition_cmd = /usr/lib/spectrumos/idle-adapter check"), 2)
        self.assertEqual(idle_policy.count("condition_retry = 5"), 2)
        self.assertIn('scripts/idle-adapter" /usr/lib/spectrumos/idle-adapter', installer)
        self.assertIn("systemctl --user start spectrum-shell.service", autostart)

    def test_system_phase_installs_volume_control(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn('scripts/volume" /usr/lib/spectrumos/volume', installer)

    def test_system_phase_installs_theme_engine_and_menu(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn('scripts/theme-menu" /usr/lib/spectrumos/theme-menu', installer)

    def test_default_wallpaper_is_installed_and_drives_the_initial_theme(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        autostart = (ROOT / "configs/hyprland/autostart.lua").read_text(encoding="utf-8")

        wallpapers = ROOT / "assets/wallpapers/default"
        self.assertEqual({path.name for path in wallpapers.glob("*.png")},
                         {f"S{number}.png" for number in range(1, 31)})
        self.assertIn("/usr/share/backgrounds/spectrumos/S30.png", installer)
        self.assertIn("Pictures/Wallpapers/S30.png", installer)
        self.assertIn('for wallpaper_number in {1..30}; do', installer)
        self.assertIn('target_wallpaper="$wallpaper_dir/S$wallpaper_number.png"', installer)
        self.assertIn("extract native", installer)
        self.assertIn("--mode clustered", installer)
        self.assertIn('--wallpaper "$wallpaper"', installer)
        self.assertIn("run_as_target /usr/lib/spectrumos/appearance-sync --apply", installer)
        self.assertIn("/usr/lib/spectrumos/wallpaper-restore", autostart)

    def test_user_adoption_copies_all_new_wallpapers_and_preserves_existing_files(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        start = installer.index("    local wallpaper_number system_wallpaper target_wallpaper")
        stop = installer.index("    local oh_my_zsh_dir=", start)
        block = installer[start:stop].replace("    local ", "    declare ", 1)
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            source = base / "system"
            target = base / "user"
            source.mkdir()
            target.mkdir()
            for number in range(1, 31):
                (source / f"S{number}.png").write_bytes(f"frame {number}".encode())
            (target / "S2.png").write_bytes(b"user override")
            (target / "personal.jpg").write_bytes(b"personal wallpaper")
            block = block.replace("/usr/share/backgrounds/spectrumos", str(source))
            subprocess.run(
                ["bash", "-c", 'set -e; run_as_target() { "$@"; }; log() { :; }; '
                 'wallpaper_dir=$1; ' + block, "adopt", str(target)], check=True,
            )
            for number in range(1, 31):
                expected = b"user override" if number == 2 else f"frame {number}".encode()
                self.assertEqual((target / f"S{number}.png").read_bytes(), expected)
            self.assertEqual((target / "personal.jpg").read_bytes(), b"personal wallpaper")

    def test_system_phase_installs_boot_and_login_appearance(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("configs/sddm/themes/spectrumos", installer)
        self.assertIn("configs/plymouth/themes/spectrumos", installer)
        self.assertIn("plymouth-set-default-theme spectrumos", installer)
        self.assertIn('scripts/plymouth-boot-sync" /usr/lib/spectrumos/plymouth-boot-sync', installer)
        self.assertIn('plymouth_check_flags=(--check)', installer)
        self.assertIn('/usr/lib/spectrumos/plymouth-boot-sync "${plymouth_check_flags[@]}"', installer)
        self.assertIn("mkinitcpio -P", installer)
        self.assertIn('scripts/uki-branding-sync"', installer)
        self.assertIn("spectrumos-limine-appearance.path", installer)
        self.assertIn('usermod -aG spectrumos "$TARGET_USER"', installer)
        self.assertIn('/usr/share/spectrumos/theme-engine/spectrum_theme', installer)
        self.assertIn('palettes/*.toml', installer)
        self.assertIn("systemctl enable sddm.service", installer)

    def test_system_phase_restarts_pipewire_after_package_upgrades(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        hook = (ROOT / "system/pacman-hooks/60-spectrumos-pipewire-restart.hook").read_text(encoding="utf-8")
        script = (ROOT / "scripts/pipewire-restart").read_text(encoding="utf-8")

        self.assertIn('scripts/pipewire-restart" /usr/lib/spectrumos/pipewire-restart', installer)
        self.assertIn('system/pacman-hooks/60-spectrumos-pipewire-restart.hook"', installer)
        self.assertIn("/usr/share/libalpm/hooks/60-spectrumos-pipewire-restart.hook", installer)
        self.assertIn("-x /usr/lib/spectrumos/pipewire-restart", installer)
        for target in ("pipewire", "pipewire-alsa", "pipewire-jack", "pipewire-pulse", "wireplumber"):
            self.assertIn(f"\nTarget = {target}\n", f"\n{hook}\n")
        self.assertIn("Operation = Upgrade", hook)
        self.assertIn("systemctl --user try-restart", script)

    def test_system_phase_installs_shell(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        autostart = (ROOT / "configs/hyprland/autostart.lua").read_text(encoding="utf-8")
        menu = (ROOT / "scripts/theme-menu").read_text(encoding="utf-8")

        self.assertNotIn("configs/waybar/layouts/*.jsonc", installer)
        self.assertIn("systemctl --user start spectrum-shell.service", autostart)
        self.assertNotIn("spectrum-dock", installer)
        self.assertIn("waybar-menu --restart", menu)
        self.assertIn('scripts/waybar-menu" /usr/lib/spectrumos/waybar-menu', installer)
        self.assertIn('scripts/waybar-widgets" /usr/lib/spectrumos/waybar-widgets', installer)
        self.assertIn('scripts/waybar-cava" /usr/lib/spectrumos/waybar-cava', installer)

    def test_system_phase_installs_snapshot_tool(self):
        installer = INSTALLER.read_text(encoding="utf-8")

        self.assertIn('scripts/snapshot" /usr/bin/spectrum-snapshot', installer)
        self.assertIn('[[ -x /usr/bin/spectrum-snapshot ]]', installer)

    def test_system_phase_installs_shell_picker(self):
        installer = INSTALLER.read_text(encoding="utf-8")

        self.assertNotIn("configs/wofi/profiles/*.conf", installer)
        self.assertIn('scripts/spectrum-shell-picker" /usr/lib/spectrumos/spectrum-shell-picker', installer)

    def test_system_phase_installs_control_panel(self):
        installer = INSTALLER.read_text(encoding="utf-8")

        self.assertIn('scripts/panel" /usr/lib/spectrumos/panel', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/panel ]]', installer)
        self.assertIn('scripts/hyprland-menu" /usr/lib/spectrumos/hyprland-menu', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/hyprland-menu ]]', installer)
        self.assertIn('scripts/font-size-menu" /usr/lib/spectrumos/font-size-menu', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/font-size-menu ]]', installer)
        self.assertIn('scripts/network-menu" /usr/lib/spectrumos/network-menu', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/network-menu ]]', installer)
        self.assertIn('scripts/bluetooth-menu" /usr/lib/spectrumos/bluetooth-menu', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/bluetooth-menu ]]', installer)
        self.assertIn('scripts/recorder-menu" /usr/lib/spectrumos/recorder-menu', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/recorder-menu ]]', installer)
        self.assertIn('scripts/display-menu" /usr/lib/spectrumos/display-menu', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/display-menu ]]', installer)
        self.assertIn('scripts/weather-adapter" /usr/lib/spectrumos/weather-adapter', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/weather-adapter ]]', installer)
        self.assertIn('scripts/appearance-sync" /usr/lib/spectrumos/appearance-sync', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/appearance-sync ]]', installer)
        self.assertIn('scripts/brightness" /usr/lib/spectrumos/brightness', installer)
        self.assertIn('[[ -x /usr/lib/spectrumos/brightness ]]', installer)

    def test_system_phase_installs_networkmanager_policy(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        policy = ROOT / "configs" / "networkmanager" / "20-spectrumos.conf"

        self.assertTrue(policy.is_file())
        self.assertIn("dns=systemd-resolved", policy.read_text(encoding="utf-8"))
        self.assertIn("/etc/NetworkManager/conf.d/20-spectrumos.conf", installer)
        self.assertIn("systemctl enable --now systemd-resolved.service", installer)
        self.assertIn("ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf", installer)
        self.assertIn("systemd-resolved is not enabled", installer)

    def test_resolv_conf_symlink_is_skipped_when_already_in_place(self):
        # arch-chroot bind-mounts /run and /etc/resolv.conf itself from the live
        # medium into the target for DNS while chrooted, and the live medium's
        # own systemd-resolved already manages /etc/resolv.conf the same way --
        # so inside an arch-chroot install, both paths can already resolve to
        # the identical file. `ln -sfn` refuses that even with -f ("are the
        # same file"), which under set -e previously aborted the whole install
        # here even though resolv.conf already pointed at the stub correctly.
        installer = INSTALLER.read_text(encoding="utf-8")
        guard, _, rest = installer.partition(
            "if [[ $(stat -c '%d:%i' /run/systemd/resolve/stub-resolv.conf 2>/dev/null) "
            '!= "$(stat -c \'%d:%i\' /etc/resolv.conf 2>/dev/null)" ]]; then'
        )
        self.assertTrue(guard, "resolv.conf same-file guard is missing")
        body = rest.split("fi\n", 1)[0]
        self.assertIn("run sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf", body)
        self.assertIn("else", body)
        self.assertIn("already points at the systemd-resolved stub", body)

    def test_resolv_conf_guard_catches_a_bind_mount_not_just_a_symlink(self):
        # `readlink -f` was the original guard, and it's the wrong check: it
        # only follows symlinks, but arch-chroot turns /etc/resolv.conf into a
        # plain regular file bind-mounted onto the same underlying file as the
        # stub (bind-mounting a path that is itself a symlink bind-mounts its
        # resolved target) -- not a symlink itself. So `readlink -f` on it just
        # returns the path unchanged and never notices the two are the same
        # file, the guard wrongly decides they differ, `ln` runs anyway, and
        # fails with the exact "are the same file" the guard exists to avoid --
        # confirmed live via a real install. A hardlink reproduces the same
        # blind spot without needing an actual mount namespace: two distinct,
        # non-symlink paths sharing one inode. `stat`'s device:inode pair (what
        # `ln` itself checks) catches it; `readlink -f` does not.
        with tempfile.TemporaryDirectory() as tmp:
            stub = Path(tmp) / "stub-resolv.conf"
            resolv = Path(tmp) / "resolv.conf"
            stub.write_text("nameserver 127.0.0.53\n", encoding="utf-8")
            os.link(stub, resolv)

            self.assertNotEqual(
                subprocess.run(["readlink", "-f", str(stub)], capture_output=True, text=True).stdout,
                subprocess.run(["readlink", "-f", str(resolv)], capture_output=True, text=True).stdout,
                "sanity check: readlink -f must NOT see the hardlink as the same path",
            )

            script = (
                f"if [[ $(stat -c '%d:%i' {stub} 2>/dev/null) != "
                f"\"$(stat -c '%d:%i' {resolv} 2>/dev/null)\" ]]; then "
                'echo would-relink; else echo already-in-place; fi'
            )
            result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.strip(), "already-in-place")

    def test_qt_appearance_environment_is_installed(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("configs/environment/90-spectrumos-qt.conf", installer)
        self.assertIn('"$environment_dir/90-spectrumos-qt.conf"', installer)
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        for package in ("kvantum", "kvantum-qt5", "qt5ct", "qt6ct"):
            self.assertIn(f"\n{package}\n", f"\n{desktop}")
        self.assertIn("awww kvantummanager", installer)

    def test_desktop_manifest_resolves_noninteractive_providers(self):
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        self.assertIn("\npipewire-jack\n", f"\n{desktop}")
        self.assertIn("\nnoto-fonts\n", f"\n{desktop}")
        self.assertIn("\npython-pillow\n", f"\n{desktop}")

    def test_future_installs_do_not_install_or_enable_docker(self):
        for manifest in (*sorted((ROOT / "bootstrap/packages").rglob("*.txt")), ROOT / "iso/spectrumos/packages.x86_64"):
            if manifest.name == "desktop-lean-exclude.txt":
                continue
            with self.subTest(manifest=manifest):
                packages = set(manifest.read_text().splitlines())
                self.assertFalse(packages & {"docker", "docker-compose", "containerd", "podman"})
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertNotIn("docker", installer)
        shell = (ROOT / "configs/zsh/defaults.zsh").read_text()
        self.assertNotIn("docker", shell)
        result = self.run_installer("--phase", "packages,system")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("docker", result.stdout)

    def test_lean_install_omits_optional_packages_and_services(self):
        result = self.run_installer("--phase", "packages,system", "--lean")
        self.assertEqual(result.returncode, 0, result.stderr)
        for package in ("docker", "docker-compose", "transmission-cli", "cups-browsed", "avahi", "tuned"):
            self.assertNotIn(f" {package} ", result.stdout)
        for service in ("docker.service", "cups.socket", "cups-browsed.service", "avahi-daemon.service", "tuned.service"):
            self.assertNotIn(service, result.stdout)
        for package in ("hyprland", "quickshell", "pipewire", "networkmanager", "zram-generator", "evolution", "kdeconnect"):
            self.assertIn(f" {package} ", result.stdout)

    def test_iso_lean_choice_reaches_backend_and_package_boundary(self):
        frontend = (ROOT / "installer/spectrum-installer").read_text(encoding="utf-8")
        backend = (ROOT / "installer/spectrum-installer-backend").read_text(encoding="utf-8")
        self.assertIn('Gtk.CheckButton(label="Install lean SpectrumOS")', frontend)
        self.assertIn('command.append("--lean")', frontend)
        self.assertIn('profile_args+=(--lean)', backend)
        self.assertIn('desktop-lean-exclude.txt', backend)
        self.assertIn('bash "$project_root/scripts/check-lean-package"', backend)
        self.assertIn('if [[ $lean == false ]]; then\n        aur_packages=(gowall-bin vesktop-bin)', backend)
        dependency_query = subprocess.run(
            ("bash", "-c", 'source packages/spectrum-desktop/PKGBUILD; printf "%s\\n" "${depends[@]}"'),
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        dependencies = set(dependency_query.stdout.splitlines())
        excluded = {
            line for line in (ROOT / "bootstrap/packages/desktop-lean-exclude.txt").read_text().splitlines()
            if line and not line.startswith("#")
        }
        self.assertFalse(dependencies & excluded)

    def test_signed_desktop_dependency_check_rejects_lean_exclusions(self):
        checker = ROOT / "scripts/check-lean-package"
        exclusions = ROOT / "bootstrap/packages/desktop-lean-exclude.txt"
        with tempfile.TemporaryDirectory() as directory:
            staged_checker = Path(directory) / "check-lean-package"
            staged_checker.write_bytes(checker.read_bytes())
            staged_checker.chmod(0o644)
            database = Path(directory) / "spectrumos.db.tar.zst"
            for dependencies, expected_code in (("docker\nwaybar\n", 1), ("waybar\npipewire\n", 0)):
                payload = f"%NAME%\nspectrum-desktop\n\n%DEPENDS%\n{dependencies}\n".encode()
                with tarfile.open(database, "w") as archive:
                    entry = tarfile.TarInfo("spectrum-desktop-0.1.0-124/desc")
                    entry.size = len(payload)
                    archive.addfile(entry, io.BytesIO(payload))
                result = subprocess.run(("bash", str(staged_checker), str(database), str(exclusions)), capture_output=True, text=True)
                self.assertEqual(result.returncode, expected_code, result.stderr)

    def test_large_hardware_support_is_optional_for_installed_system(self):
        # Same hardware gap as the live ISO's own package list: some real
        # acceptance-testing hardware (~2011-era MacBooks) has a Broadcom
        # Wi-Fi chip whose in-tree brcmsmac/brcmfmac support is weak-to-
        # absent -- confirmed live as no Wi-Fi device showing up at all.
        # broadcom-wl-dkms (official extra repo, not AUR) is the standard
        # fix; as a DKMS package it needs linux-headers to build (base-devel,
        # already in base.txt, covers the rest of the toolchain dkms itself
        # depends on).
        optional = (ROOT / "bootstrap/packages/optional.txt").read_text(encoding="utf-8")
        for package in ("broadcom-wl-dkms", "linux-headers", "linux-firmware-qcom"):
            self.assertIn(f"\n{package}\n", f"\n{optional}\n")

    def test_desktop_manifest_ships_a_cjk_font_for_the_kanji_workspace_icon_set(self):
        # None of the Latin/Nerd Font families Waybar's font-family control offers cover
        # CJK; without this, the Kanji Numbers workspace icon set renders as blank/tofu
        # boxes instead of the actual characters.
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        self.assertIn("\nnoto-fonts-cjk\n", f"\n{desktop}")

    def test_desktop_manifest_guarantees_every_selectable_monospace_font(self):
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        optional = (ROOT / "bootstrap/packages/optional.txt").read_text(encoding="utf-8")
        for package in (
            "ttf-jetbrains-mono-nerd", "ttf-firacode-nerd", "ttf-sourcecodepro-nerd",
            "ttf-cascadia-code-nerd", "ttf-hack-nerd", "ttf-ibmplex-mono-nerd",
            "ttf-iosevka-nerd", "ttf-victor-mono-nerd", "ttf-ubuntu-mono-nerd", "ttf-meslo-nerd",
        ):
            self.assertIn(f"\n{package}\n", f"\n{desktop}\n")
            self.assertNotIn(f"\n{package}\n", f"\n{optional}\n")

    def test_desktop_installs_a_wayland_image_viewer_and_defaults(self):
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        defaults = (ROOT / "configs/xdg/mimeapps.list").read_text(encoding="utf-8")
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("\nswayimg\n", f"\n{desktop}\n")
        for mime in ("image/jpeg", "image/png", "image/webp", "image/svg+xml"):
            self.assertIn(f"{mime}=swayimg.desktop", defaults)
        self.assertIn('configs/xdg/mimeapps.list', installer)
        self.assertIn('for executable in Hyprland uwsm alacritty kitty nvim thunar swayimg', installer)
        self.assertIn('[[ -r /etc/xdg/mimeapps.list ]]', installer)

    def test_desktop_manifest_includes_transfer_printing_and_samba_support(self):
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        for package in (
            "transmission-cli", "cups", "cups-browsed", "cups-filters", "cups-pk-helper",
            "system-config-printer", "ipp-usb", "gutenprint", "avahi",
            "ghostscript", "python-pysmbc", "nss-mdns", "samba", "gvfs-smb",
        ):
            self.assertIn(f"\n{package}\n", f"\n{desktop}\n")
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("systemctl enable --now cups.socket", installer)
        self.assertIn("systemctl enable --now cups-browsed.service", installer)
        self.assertIn("systemctl enable --now avahi-daemon.service", installer)
        self.assertNotIn("systemctl enable --now smb.service", installer)
        self.assertIn("configs/samba/smb.conf", installer)
        self.assertIn('usermod -aG sambashare "$TARGET_USER"', installer)
        samba = (ROOT / "configs" / "samba" / "smb.conf").read_text(encoding="utf-8")
        self.assertIn("security = user", samba)
        self.assertIn("usershare allow guests = no", samba)
        self.assertNotIn("guest ok = yes", samba)

    def test_package_transaction_is_noninteractive(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("local -a pacman_args=(-Syu --needed --noconfirm)", installer)

    def test_installed_system_bootstraps_from_the_embedded_signed_repository(self):
        installer = (ROOT / "installer" / "spectrum-installer-backend").read_text(encoding="utf-8")

        self.assertIn("install_spectrum_repository()", installer)
        self.assertIn("/var/lib/spectrumos/repository/edge/x86_64", installer)
        self.assertIn("pacman-key --add", installer)
        self.assertIn("pacman-key --lsign-key", installer)
        self.assertIn("Required DatabaseRequired TrustedOnly", installer)
        self.assertIn("pacman -Syu --needed --noconfirm spectrum-desktop", installer)
        self.assertIn("https://spectrum.gibranlp.dev/repo/stable/$arch", installer)
        self.assertLess(
            installer.index("pacman -Syu --needed --noconfirm spectrum-desktop"),
            installer.index("https://spectrum.gibranlp.dev/repo/stable/$arch"),
        )
        self.assertNotIn("TrustAll", installer)

    def test_desktop_and_gaming_catalogs_are_explicitly_split_by_origin(self):
        desktop = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8")
        gaming = (ROOT / "bootstrap/packages/gaming.txt").read_text(encoding="utf-8")
        desktop_aur = (ROOT / "bootstrap/packages/desktop.aur.txt").read_text(encoding="utf-8")
        gaming_aur = (ROOT / "bootstrap/packages/gaming.aur.txt").read_text(encoding="utf-8")

        for package in ("thunar-volman", "thunar-archive-plugin", "tumbler", "ffmpegthumbnailer", "gst-thumbnailers", "gst-libav", "gst-plugins-bad", "gst-plugins-ugly", "gnome-epub-thumbnailer", "poppler-glib", "libgsf", "libgepub", "libopenraw", "webp-pixbuf-loader", "libheif", "ntfs-3g", "gnome-disk-utility", "vlc", "gnome-keyring"):
            self.assertIn(f"\n{package}\n", f"\n{desktop}\n")
        optional = (ROOT / "bootstrap/packages/optional.txt").read_text(encoding="utf-8")
        for package in ("vlc-plugins-all", "hugo", "python-pip", "telegram-desktop"):
            self.assertIn(f"\n{package}\n", f"\n{optional}\n")
        self.assertNotIn("\ndiscord\n", f"\n{desktop}\n")
        self.assertIn("\nvesktop-bin\n", f"\n{desktop_aur}\n")
        for package in ("steam", "lutris", "wine-staging", "winetricks", "gamemode", "lib32-gamemode", "mangohud", "lib32-mangohud", "gamescope", "goverlay", "lib32-libcurl-gnutls", "lib32-libcurl-compat", "lib32-gnutls"):
            self.assertIn(f"\n{package}\n", f"\n{gaming}\n")
        for package in ("brave-bin", "google-chrome", "whatsie", "gowall-bin"):
            self.assertIn(f"\n{package}\n", f"\n{desktop_aur}\n")
        self.assertNotIn("visual-studio-code-bin", desktop_aur)
        self.assertIn("\npolkit-gnome\n", f"\n{desktop}\n")
        self.assertNotIn("polkit-kde-agent", desktop)
        self.assertNotIn("walogram", desktop_aur)
        for package in ("vkbasalt", "proton-ge-custom-bin"):
            self.assertIn(f"\n{package}\n", f"\n{gaming_aur}\n")

    def test_archive_tools_are_required_in_full_and_lean_installations(self):
        required = {"thunar-archive-plugin", "file-roller", "7zip", "unrar", "unzip", "zip",
                    "libarchive", "tar", "gzip", "bzip2", "xz", "zstd", "lzip", "lz4",
                    "cpio", "arj", "lhasa", "bzip3"}
        for options in ((), ("--lean",)):
            with self.subTest(options=options):
                result = self.run_installer("--phase", "packages", *options)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(required.issubset(result.stdout.split()), result.stdout)
        recipe = ROOT / "packages/spectrum-desktop/PKGBUILD"
        if not recipe.exists():
            recipe = Path("/startdir/PKGBUILD")
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; printf "%s\\n" "${depends[@]}"', "bash", str(recipe)],
            check=True, text=True, capture_output=True)
        self.assertTrue(required.issubset(result.stdout.split()))

    def test_aur_packages_use_paru_as_the_target_user(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("collect_aur_packages", installer)
        self.assertIn('run_as_target paru -S --needed --noconfirm -- "${aur_packages[@]}"', installer)
        self.assertIn("install Paru before applying them", installer)

    def test_zsh_adoption_is_non_destructive_and_shell_change_is_explicit(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        entrypoint = (ROOT / "configs" / "zsh" / "zshrc").read_text(encoding="utf-8")
        defaults = (ROOT / "configs" / "zsh" / "defaults.zsh").read_text(encoding="utf-8")

        self.assertIn("--set-default-shell", installer)
        self.assertIn('if [[ ! -e $zshrc ]]', installer)
        self.assertIn('command transmission-cli -w "$HOME/Downloads" "$@"', defaults)
        self.assertIn('"download-dir": "%s"', installer)
        self.assertIn('$TARGET_HOME/.config/transmission', installer)
        self.assertIn('setfacl -m "u:transmission:--x" "$TARGET_HOME"', installer)
        self.assertIn('setfacl -m "u:transmission:rwx,d:u:transmission:rwx,d:u:$TARGET_USER:rwx" "$transmission_download_dir"', installer)
        self.assertIn('-user transmission -type d', installer)
        self.assertIn('setfacl -m "u:$TARGET_USER:rwx,d:u:$TARGET_USER:rwx,d:u:transmission:rwx"', installer)
        self.assertIn('-user transmission -type f', installer)
        self.assertIn('setfacl -m "u:$TARGET_USER:rw"', installer)
        self.assertIn('/etc/systemd/system/transmission-daemon.service.d', installer)
        self.assertIn('10-spectrumos-download-dir.conf', installer)
        self.assertIn('20-spectrumos-start-timeout.conf', installer)
        self.assertIn('ExecStart=/usr/bin/transmission-daemon -f --log-level=error -w', installer)
        self.assertIn('ExecStartPre=+/usr/bin/setfacl', installer)
        self.assertIn('systemctl daemon-reload', installer)
        self.assertIn('systemctl enable --now transmission-daemon.service', installer)
        self.assertIn('transmission-remote --download-dir "$transmission_download_dir"', installer)
        self.assertNotIn('/usr/share/spectrumos/eww', installer)
        service_loop = next(line for line in installer.splitlines() if 'for user_service in ' in line)
        for service in ('spectrum-resource-monitor.service', 'spectrum-shell.service',
                        'spectrum-questline-notifications.service', 'spectrum-workspace-layout.service'):
            self.assertIn(service, service_loop)
        self.assertNotIn("spectrum-network-ui.service", installer)
        self.assertNotIn('$PROJECT_ROOT/vendor/eww', installer)
        self.assertIn('Preserving existing zsh entrypoint', installer)
        self.assertIn('zsh -n /usr/share/spectrumos/zsh/defaults.zsh', installer)
        self.assertIn('usermod --shell /usr/bin/zsh', installer)
        self.assertIn('/usr/share/spectrumos/zsh/defaults.zsh', entrypoint)
        self.assertIn('spectrumos-personal', entrypoint)
        theme = (ROOT / "configs" / "zsh" / "themes" / "spectrum.zsh-theme").read_text(encoding="utf-8")
        self.assertIn('ZSH_THEME=""', defaults)
        self.assertIn("themes/spectrum.zsh-theme", defaults)
        self.assertIn("SPECTRUM_PROMPT_SEPARATOR", theme)
        self.assertIn("spectrum_prompt_git", theme)
        self.assertIn('spectrum_prompt_segment 4 0 "%~"', theme)
        self.assertIn('spectrum_prompt_segment 5 0 "$SPECTRUM_PROMPT_BRANCH', theme)
        self.assertIn('spectrum_prompt_segment 8 7 "%F{5}󰣇%F{7} %n@%m"', theme)
        self.assertIn('archlinux', defaults)
        self.assertIn('zsh-autosuggestions', defaults)
        self.assertIn('zsh-syntax-highlighting', defaults)
        self.assertIn('source "$ZSH/oh-my-zsh.sh"', defaults)
        self.assertIn('OH_MY_ZSH_COMMIT=', installer)
        self.assertIn('install_pinned_git_tree', installer)
        self.assertIn('Oh My Zsh is missing', installer)

        base = (ROOT / "bootstrap" / "packages" / "base.txt").read_text(encoding="utf-8")
        for package in ("thefuck", "zsh", "zsh-autosuggestions", "zsh-completions", "zsh-syntax-highlighting"):
            self.assertIn(f"\n{package}\n", f"\n{base}")
        self.assertIn('eval "$(thefuck --alias)"', defaults)
        self.assertIn("\nneovim\n", f"\n{base}")

    def test_neovim_is_adopted_and_uses_generated_spectrum_theme(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        init = (ROOT / "configs" / "nvim" / "init.lua").read_text(encoding="utf-8")
        plugins = (ROOT / "configs" / "nvim" / "lua" / "plugins" / "init.lua").read_text(encoding="utf-8")
        colors = (ROOT / "configs" / "nvim" / "colors" / "spectrum.lua").read_text(encoding="utf-8")

        self.assertIn("/usr/share/spectrumos/nvim", installer)
        self.assertIn("Preserving existing Neovim configuration", installer)
        self.assertIn("colors/spectrum.lua", installer)
        self.assertIn("spectrumos/theme/current", init)
        self.assertIn('colorscheme = "spectrum"', plugins)
        self.assertIn("spectrumos/theme/current/colors/spectrum.lua", colors)
        self.assertNotIn("lushwal", plugins.lower())


if __name__ == "__main__":
    unittest.main()
