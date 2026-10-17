#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


INSTALL_PATH = "/usr/share/spectrumos/hyprland"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate SpectrumOS2 Hyprland defaults without starting a session")
    parser.add_argument("--config-dir", type=Path, default=Path("configs/hyprland"))
    parser.add_argument("--hyprland", default="Hyprland")
    parser.add_argument("--theme", type=Path, help="Generated Hyprland theme fragment to validate")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    executable = shutil.which(arguments.hyprland)
    if executable is None:
        print(f"Error: Hyprland executable not found: {arguments.hyprland}", file=sys.stderr)
        return 1

    config_dir = arguments.config_dir.resolve()
    entrypoint = config_dir / "hyprland.lua"
    if not entrypoint.is_file():
        print(f"Error: Hyprland entrypoint not found: {entrypoint}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="spectrum-hyprland-") as directory:
        preview_root = Path(directory)
        preview = preview_root / "hyprland.lua"
        theme = preview_root / "theme.lua"
        machine = preview_root / "machine.lua"
        user = preview_root / "user.lua"
        theme_content = arguments.theme.read_text(encoding="utf-8") if arguments.theme else ""
        theme.write_text(theme_content, encoding="utf-8")
        machine.write_text("", encoding="utf-8")
        user.write_text("", encoding="utf-8")
        content = entrypoint.read_text(encoding="utf-8")
        content = content.replace(INSTALL_PATH, str(config_dir))
        content = content.replace('home .. "/.cache/spectrumos/theme/current/hyprland.lua"', f'"{theme}"')
        content = content.replace('"/etc/spectrumos/hyprland/machine.lua"', f'"{machine}"')
        content = content.replace('home .. "/.config/spectrumos/hyprland.lua"', f'"{user}"')
        preview.write_text(content, encoding="utf-8")
        environment = os.environ.copy()
        if not environment.get("XDG_RUNTIME_DIR"):
            runtime = preview_root / "runtime"
            runtime.mkdir(mode=0o700)
            environment["XDG_RUNTIME_DIR"] = str(runtime)
        command = [executable, "--verify-config", "-c", str(preview)]
        if os.geteuid() == 0:
            command.append("--i-am-really-stupid")
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )
        output = result.stdout + result.stderr
        print(output, end="")

    # Hyprland puede devolver cero aunque el resumen diga que la configuración falló.
    if result.returncode != 0 or "Config error" in output or "globbing error" in output:
        return 1
    if "config ok" not in output.lower():
        print("Error: Hyprland did not report a successful configuration check", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
