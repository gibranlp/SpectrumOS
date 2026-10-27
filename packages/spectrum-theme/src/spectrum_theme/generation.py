from __future__ import annotations

from contextlib import contextmanager
from datetime import UTC, datetime
import fcntl
import json
import os
from pathlib import Path
import secrets
import shutil

from .palette import Palette
from .renderers import DEFAULT_FONT_FAMILY, RENDERERS


class GenerationError(RuntimeError):
    pass


DEFAULT_RETENTION = 12


@contextmanager
def _generation_lock(output_root: Path):
    output_root.mkdir(parents=True, exist_ok=True)
    with (output_root / ".generation.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def generate(
    palette: Palette,
    output_root: Path,
    wallpaper: Path | None = None,
    retention: int = DEFAULT_RETENTION,
    font_size: int = 13,
    font_family: str = DEFAULT_FONT_FAMILY,
    appearance: dict | None = None,
) -> Path:
    with _generation_lock(output_root):
        if retention < 2:
            raise GenerationError("Generation retention must be at least 2")
        if not 8 <= font_size <= 24:
            raise GenerationError("Font size must be between 8 and 24")
        generations = output_root / "generations"
        generations.mkdir(parents=True, exist_ok=True)
        try:
            previous_generation = (output_root / "current").resolve(strict=True).name
        except OSError:
            previous_generation = None
        generation_id = f"{datetime.now(UTC).strftime('%Y%m%dT%H%M%S.%fZ')}-{secrets.token_hex(4)}"
        staging = generations / f".{generation_id}.tmp"
        completed = generations / generation_id

        try:
            staging.mkdir(mode=0o700)
            for filename, renderer in RENDERERS.items():
                _write_file(staging / filename, renderer(palette, font_size, font_family))
            _write_file(
                staging / "generation.json",
                _generation_metadata(palette, wallpaper, previous_generation, font_size, font_family, appearance),
            )
            os.replace(staging, completed)
            _prune_generations(output_root, retention)
            _activate(output_root, completed)
        except OSError as error:
            shutil.rmtree(staging, ignore_errors=True)
            raise GenerationError(f"Cannot generate theme: {error}") from error

        return completed


def rollback(output_root: Path) -> tuple[Path, Path]:
    with _generation_lock(output_root):
        current_link = output_root / "current"
        try:
            current = current_link.resolve(strict=True)
        except OSError as error:
            raise GenerationError(f"Cannot resolve the active generation: {error}") from error
        current_metadata = _read_metadata(current)
        previous_name = current_metadata.get("previous_generation")
        if isinstance(previous_name, str) and previous_name:
            previous = output_root / "generations" / previous_name
        else:
            generations = sorted(path for path in (output_root / "generations").iterdir() if path.is_dir())
            try:
                current_index = generations.index(current)
            except ValueError as error:
                raise GenerationError("Active generation is outside the generation history") from error
            if current_index == 0:
                raise GenerationError("No previous theme generation is available")
            previous = generations[current_index - 1]
        if not previous.is_dir():
            raise GenerationError("Previous theme generation is no longer retained")
        metadata = _read_metadata(previous)
        wallpaper_value = metadata.get("wallpaper")
        if not isinstance(wallpaper_value, str) or not wallpaper_value:
            raise GenerationError("Previous generation has no wallpaper metadata")
        wallpaper = Path(wallpaper_value)
        if not wallpaper.is_file():
            raise GenerationError(f"Previous wallpaper is unavailable: {wallpaper}")
        appearance = metadata.get("appearance")
        if isinstance(appearance, dict):
            rendered = appearance.get("rendered_wallpaper")
            if not isinstance(rendered, str) or not Path(rendered).is_file():
                raise GenerationError("Previous rendered wallpaper is unavailable")
        _activate(output_root, previous)
        return previous, wallpaper


def _write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as target:
        target.write(content)
        target.flush()
        os.fsync(target.fileno())


def _generation_metadata(
    palette: Palette,
    wallpaper: Path | None,
    previous_generation: str | None,
    font_size: int,
    font_family: str = DEFAULT_FONT_FAMILY,
    appearance: dict | None = None,
) -> str:
    payload = {
        "palette_name": palette.name,
        "palette_source": palette.source,
        "previous_generation": previous_generation,
        "wallpaper": str(wallpaper.resolve()) if wallpaper is not None else None,
        "font_size": font_size,
        "font_family": font_family,
    }
    if appearance is not None:
        payload["appearance"] = appearance
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def _read_metadata(generation: Path) -> dict:
    try:
        return json.loads((generation / "generation.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise GenerationError(f"Cannot read generation metadata: {error}") from error


def _prune_generations(output_root: Path, retention: int) -> None:
    generations = sorted(path for path in (output_root / "generations").iterdir() if path.is_dir())
    try:
        current = (output_root / "current").resolve(strict=True)
    except OSError:
        current = None
    for generation in generations:
        if generation != current and not (generation / "generation.json").is_file():
            shutil.rmtree(generation)
    generations = sorted(path for path in (output_root / "generations").iterdir() if path.is_dir())
    removable = [path for path in generations if path != current]
    for generation in removable[: max(0, len(generations) - retention)]:
        shutil.rmtree(generation)


def _activate(output_root: Path, generation: Path) -> None:
    temporary_link = output_root / f".current-{secrets.token_hex(4)}"
    current_link = output_root / "current"
    relative_target = generation.relative_to(output_root)

    # El enlace cambia en una sola operación para que las apps nunca vean una generación incompleta.
    os.symlink(relative_target, temporary_link)
    try:
        os.replace(temporary_link, current_link)
    except OSError:
        temporary_link.unlink(missing_ok=True)
        raise
