"""Opt-in AirDrop protocol dumps; ordinary diagnostics never retain identities."""
import os
import plistlib
import tempfile
from pathlib import Path
from xml.parsers.expat import ExpatError


def _redact(value):
    if isinstance(value, dict):
        return {
            key: (f'<redacted {len(item.encode("utf-8")) if isinstance(item, str) else len(item)} bytes>'
                  if key.endswith(('RecordData', 'Certificate'))
                  and isinstance(item, (bytes, str, list, dict)) else _redact(item))
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [_redact(item) for item in value]
    return value


def dump_protocol(name, data, *, verbose=False, runtime_dir=None):
    """Write only on opt-in, atomically and privately, below the user runtime dir.

    Non-plist bodies (including uploaded archives) are represented only by size
    in ordinary debug mode. Sensitive mode deliberately retains the raw body.
    """
    sensitive = os.environ.get('SPECTRUMDROP_DEBUG_SENSITIVE') == '1'
    if not (verbose or sensitive or os.environ.get('SPECTRUMDROP_DEBUG') == '1'):
        return
    root = runtime_dir or os.environ.get('XDG_RUNTIME_DIR')
    if not root:
        raise OSError('protocol dumps require XDG_RUNTIME_DIR')
    root = Path(root)
    stat = root.stat()
    if not root.is_absolute() or not root.is_dir() or stat.st_uid != os.getuid() or stat.st_mode & 0o077:
        raise OSError('protocol dumps require a private, user-owned runtime directory')
    if Path(name).name != name or name in ('', '.', '..'):
        raise ValueError('invalid protocol dump name')
    if hasattr(data, 'getvalue'):
        data = data.getvalue()
    if data is None:
        data = b''
    if not sensitive:
        try:
            value = plistlib.loads(data)
        except (ValueError, TypeError, OverflowError, ExpatError):
            data = f'<opaque {len(data)} bytes>'.encode('utf-8')
        else:
            data = plistlib.dumps(_redact(value))
    directory = root / 'spectrumdrop' / 'debug'
    for path in (root / 'spectrumdrop', directory):
        path.mkdir(mode=0o700, exist_ok=True)
        stat = path.lstat()
        if path.is_symlink() or not path.is_dir() or stat.st_uid != os.getuid() or stat.st_mode & 0o077:
            raise OSError('protocol dump directory is not private and user-owned')
    fd, temporary = tempfile.mkstemp(prefix='.dump-', dir=directory)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
        os.replace(temporary, directory / name)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
