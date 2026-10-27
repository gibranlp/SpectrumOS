from __future__ import annotations

import gettext
import json
import os
from pathlib import Path
import tempfile


def directory() -> Path:
    override = os.environ.get('SPECTRUM_TRANSLATIONS_DIR')
    if override:
        return Path(override)
    source = Path(__file__).resolve().parent.parent / 'translations'
    installed = Path('/usr/share/spectrumos/translations')
    return installed if (installed / 'languages.json').is_file() else source


def languages() -> list[dict]:
    try:
        rows = json.loads((directory() / 'languages.json').read_text())
        return [row for row in rows if isinstance(row, dict)
                and all(isinstance(row.get(key), str) for key in ('id', 'language', 'locale', 'name'))]
    except (OSError, ValueError, TypeError):
        return []


def preference_file() -> Path:
    return Path(os.environ.get('SPECTRUM_LANGUAGE_FILE') or
                (Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'spectrumos/language.json'))


def normalize(value: str) -> str:
    value = str(value).split('.')[0].split('@')[0].replace('-', '_')
    rows = languages()
    return next((row['id'] for row in rows if row['id'] == value),
                next((row['id'] for row in rows if row['language'] == value.split('_')[0]), 'en_US'))


def system_language() -> str:
    value = os.environ.get('LC_MESSAGES') or os.environ.get('LANG', 'en_US')
    path = Path(os.environ.get('SPECTRUM_SYSTEM_LOCALE_FILE', '/etc/locale.conf'))
    if path.exists():
        values = dict(line.split('=', 1) for line in path.read_text().splitlines() if '=' in line and not line.startswith('#'))
        value = values.get('LC_MESSAGES', values.get('LANG', value)).strip('"\'')
    return normalize(value)


def language() -> str:
    try:
        with preference_file().open() as stream:
            content = stream.read(8193)
        settings = json.loads(content) if len(content) <= 8192 else {}
        value = settings.get('language', 'system') if isinstance(settings, dict) else 'system'
    except (OSError, ValueError, TypeError):
        value = 'system'
    return system_language() if value == 'system' else normalize(value)


def set_language(value: str) -> None:
    if value not in {'system', *[row['id'] for row in languages()]}:
        raise ValueError('Choose a supported interface language')
    path = preference_file()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            json.dump({'schema': 1, 'language': value}, stream)
            stream.flush()
            os.fsync(stream.fileno())
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


_catalogs = {}


def catalog(locale=None):
    locale = normalize(locale or language())
    path = directory() / locale / 'LC_MESSAGES/spectrum.mo'
    key = (str(path), path.stat().st_mtime_ns if path.exists() else 0)
    if key not in _catalogs:
        _catalogs.clear()
        _catalogs[key] = gettext.translation('spectrum', directory(), languages=[locale], fallback=True)
    return _catalogs[key]


def translate(message, **values):
    result = catalog().pgettext('Spectrum', message)
    return result.format(**values) if values else result


def plural(single, multiple, count, **values):
    result = catalog().npgettext('Spectrum', single, multiple, count)
    return result.replace('%n', str(count)).format(count=count, **values)


class Message:
    def __init__(self, source, **values):
        self.source, self.values = source, values

    def render(self):
        return translate(self.source, **self.values)


def msg(source, **values):
    return Message(source, **values)


# Gtk retiene el objeto nativo, pero puede soltar su wrapper de Python.
# Conserva los enlaces hasta que cierre la aplicación para poder traducirlos.
_bindings = {}


def clear_widget_bindings():
    _bindings.clear()


def tr_widget(factory, *args, **kwargs):
    bindings = {key: value for key, value in kwargs.items() if isinstance(value, Message)}
    widget = factory(*args, **{key: value.render() if isinstance(value, Message) else value for key, value in kwargs.items()})
    if bindings:
        _bindings[widget] = bindings
    return widget


def tr_set(widget, setter, message):
    message = message if isinstance(message, Message) else msg(message)
    getattr(widget, setter)(message.render())
    _bindings.setdefault(widget, {})[setter] = message


def retranslate_widgets():
    for widget, bindings in list(_bindings.items()):
        for key, message in bindings.items():
            if key.startswith('set_'):
                getattr(widget, key)(message.render())
            else:
                widget.set_property(key.replace('_', '-'), message.render())
