#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import tempfile


def copy_private(source, target):
    if target.exists():
        return
    if source.is_symlink() or not source.is_file() or source.stat().st_uid != os.getuid():
        raise ValueError('Legacy SpectrumDrop settings must be owned regular files.')
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with source.open('rb') as incoming, target.open('xb') as outgoing:
        os.chmod(target, 0o600)
        shutil.copyfileobj(incoming, outgoing)


def migrate_links(config):
    path = config / 'mimeapps.list'
    if not path.exists():
        return
    if path.is_symlink() or path.stat().st_uid != os.getuid():
        raise ValueError('Link associations must be an owned regular file.')
    original = path.read_text()
    lines = []
    for line in original.splitlines(keepends=True):
        key, separator, value = line.partition('=')
        if separator and key.strip() in ('application/x-mswinurl', 'application/x-webloc'):
            entries = value.split(';')
            entries = [entry.replace('netmojo.omdrop-links.desktop', 'netmojo.spectrumdrop-links.desktop')
                       if entry.strip() == 'netmojo.omdrop-links.desktop' else entry for entry in entries]
            line = key + separator + ';'.join(entries)
        lines.append(line)
    updated = ''.join(lines)
    if updated == original:
        return
    with tempfile.NamedTemporaryFile(mode='w', dir=config, prefix='.spectrumdrop-links-', delete=False) as stream:
        temporary = Path(stream.name)
        os.fchmod(stream.fileno(), path.stat().st_mode & 0o777)
        stream.write(updated)
        stream.flush()
        os.fsync(stream.fileno())
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def migrate(home, config):
    migrate_links(config)
    destination = config / 'spectrumdrop'
    legacy = config / 'omdrop'
    for name in ('settings', 'visibility', 'known-senders'):
        source = legacy / name
        if source.exists():
            copy_private(source, destination / name)
    receiver = config / 'airdrop/config.toml'
    if receiver.exists():
        copy_private(receiver, destination / 'receiver.toml')
    old_keys = home / '.omdrop/keys'
    new_base = home / '.spectrumdrop'
    new_keys = new_base / 'keys'
    if not old_keys.exists() or new_keys.exists():
        return
    if old_keys.is_symlink() or old_keys.stat().st_uid != os.getuid():
        raise ValueError('Legacy transfer identity must be an owned directory.')
    new_base.mkdir(mode=0o700, exist_ok=True)
    # Publicamos la identidad completa antes de permitir que se genere otra.
    with tempfile.TemporaryDirectory(prefix='.migration-', dir=new_base) as temporary:
        staged = Path(temporary) / 'keys'
        staged.mkdir(mode=0o700)
        for source in old_keys.iterdir():
            if source.is_symlink() or not source.is_file():
                raise ValueError('Legacy transfer identity contains an unsupported entry.')
            copy_private(source, staged / source.name)
        os.rename(staged, new_keys)


if __name__ == '__main__':
    home = Path.home()
    try:
        migrate(home, Path(os.environ.get('XDG_CONFIG_HOME', home / '.config')))
    except (OSError, ValueError) as error:
        raise SystemExit('SpectrumDrop migration failed: ' + str(error))
