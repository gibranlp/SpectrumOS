# SPDX-License-Identifier: MIT
from __future__ import annotations

import base64
import hashlib
import hmac
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import socket
import ssl
import stat
import subprocess
import tempfile
import time
import tomllib
import unicodedata

SERVICE = '_spectrumdrop._tcp.local.'
VERSION = 1
PORT = 8857
CHUNK = 4 * 1024 * 1024
BUFFER = 256 * 1024
MAX_JSON = 128 * 1024
MAX_FILES = 128
MAX_TOTAL = 1024 ** 4
CODE_RE = re.compile(r'[A-Z2-7]{16}')
ID_RE = re.compile(r'[0-9a-f]{32}')
TOKEN_RE = re.compile(r'[0-9a-f]{64}')


class TransferError(RuntimeError):
    pass


def atomic_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, name = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            json.dump(value, stream, ensure_ascii=True)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def runtime_dir() -> Path:
    base = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))) / 'spectrumdrop-lan'
    if base.is_symlink():
        raise TransferError('SpectrumDrop private storage cannot be a symbolic link.')
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    if base.stat().st_uid != os.getuid():
        raise TransferError('SpectrumDrop private storage must belong to the current user.')
    base.chmod(0o700)
    return base


def data_dir() -> Path:
    base = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'spectrumdrop/lan'
    if base.is_symlink():
        raise TransferError('SpectrumDrop private storage cannot be a symbolic link.')
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    if base.stat().st_uid != os.getuid():
        raise TransferError('SpectrumDrop private storage must belong to the current user.')
    base.chmod(0o700)
    return base


def configuration() -> dict:
    path = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'spectrumdrop/receiver.toml'
    saved = tomllib.loads(path.read_text()) if path.is_file() else {}
    destination = Path(saved.get('download_dir', str(Path.home() / 'Downloads'))).expanduser().resolve()
    if not destination.is_dir() or destination.stat().st_uid != os.getuid():
        raise TransferError('Choose an existing save folder owned by your user.')
    percent = saved.get('max_receive_percent', 30)
    if not isinstance(percent, int) or isinstance(percent, bool) or not 1 <= percent <= 90:
        raise TransferError('Receive space limit must be between 1 and 90 percent.')
    name = ''.join(c for c in str(saved.get('name', socket.gethostname())) if not unicodedata.category(c).startswith('C'))[:100]
    while len(name.encode('utf-8')) > 128:
        name = name[:-1]
    name = name or 'Spectrum PC'
    return {'name': name, 'directory': str(destination), 'max_receive_percent': percent}


def ensure_identity(directory: Path) -> dict:
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    cert, key, record = (directory / name for name in ('certificate.pem', 'key.pem', 'identity.json'))
    if not cert.is_file() or not key.is_file():
        with tempfile.TemporaryDirectory(prefix='.identity-', dir=directory) as temporary:
            staging = Path(temporary)
            result = subprocess.run(['openssl', 'req', '-x509', '-newkey', 'ec', '-pkeyopt',
                'ec_paramgen_curve:prime256v1', '-nodes', '-days', '3650', '-subj', '/CN=SpectrumDrop LAN',
                '-keyout', str(staging / 'key.pem'), '-out', str(staging / 'certificate.pem')],
                capture_output=True, timeout=15)
            if result.returncode:
                raise TransferError('Could not create the encrypted transfer identity.')
            for filename in ('key.pem', 'certificate.pem'):
                os.chmod(staging / filename, 0o600)
                os.replace(staging / filename, directory / filename)
    if not record.is_file():
        atomic_json(record, {'id': secrets.token_hex(16)})
    identifier = json.loads(record.read_text())['id']
    if not isinstance(identifier, str) or not ID_RE.fullmatch(identifier):
        raise TransferError('Invalid SpectrumDrop network identity.')
    der = ssl.PEM_cert_to_DER_cert(cert.read_text())
    return {'id': identifier, 'certificate': str(cert), 'key': str(key), 'fingerprint': hashlib.sha256(der).hexdigest()}


def access_code() -> str:
    return base64.b32encode(secrets.token_bytes(10)).decode()


def normalize_code(value: str) -> str:
    if not isinstance(value, str):
        raise TransferError('Enter the code shown on the receiving Spectrum PC.')
    value = value.upper().replace('-', '').replace(' ', '')
    if not CODE_RE.fullmatch(value):
        raise TransferError('Enter the 16-character code shown on the receiving Spectrum PC.')
    return value


def proof(code: str, fingerprint: str, nonce: str, role: str) -> str:
    message = f'spectrumdrop-lan-v1:{role}:{fingerprint}:{nonce}'.encode('ascii')
    return hmac.new(normalize_code(code).encode('ascii'), message, hashlib.sha256).hexdigest()


def endpoint(value: str) -> str:
    if not isinstance(value, str) or len(value) > 100:
        raise TransferError('Enter a valid IP address.')
    address, _, zone = value.partition('%')
    ip = ipaddress.ip_address(address)
    if ip.is_unspecified or ip.is_multicast or (zone and (ip.version != 6 or not re.fullmatch(r'[A-Za-z0-9_.-]{1,32}', zone))):
        raise TransferError('Enter a valid device IP address.')
    return str(ip) + ('%' + zone if zone else '')


def safe_name(value: str) -> str:
    if not isinstance(value, str) or value in ('', '.', '..') or '/' in value or '\\' in value:
        raise TransferError('Invalid incoming filename.')
    if len(os.fsencode(value)) > 240 or any(unicodedata.category(c).startswith('C') for c in value):
        raise TransferError('Invalid incoming filename.')
    return value


def manifest(value) -> list[dict]:
    if not isinstance(value, list) or not 1 <= len(value) <= MAX_FILES:
        raise TransferError(f'Select between 1 and {MAX_FILES} regular files.')
    result = []
    names = set()
    for item in value:
        if not isinstance(item, dict):
            raise TransferError('Invalid file manifest.')
        name = safe_name(item.get('name'))
        size = item.get('size')
        digest = item.get('sha256')
        if name in names or not isinstance(size, int) or isinstance(size, bool) or size < 0 or not isinstance(digest, str) or not TOKEN_RE.fullmatch(digest):
            raise TransferError('Invalid file size, checksum or duplicate filename.')
        names.add(name)
        result.append({'name': name, 'size': size, 'sha256': digest})
    if sum(item['size'] for item in result) > MAX_TOTAL:
        raise TransferError('The selected transfer exceeds the supported size limit.')
    return result


def file_identity(info) -> tuple:
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def open_source(path: Path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
    stream = os.fdopen(descriptor, 'rb')
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        stream.close()
        raise TransferError('Only regular files can be sent. Archive folders first.')
    return stream


def collect_files(paths: list[str], progress=None) -> tuple[list[dict], list[tuple]]:
    if not isinstance(paths, list) or not 1 <= len(paths) <= MAX_FILES:
        raise TransferError(f'Select between 1 and {MAX_FILES} files.')
    rows, identities = [], []
    used = set()
    last_progress = 0
    for value in paths:
        path = Path(value).absolute()
        name = safe_name(path.name)
        stem, suffix = Path(name).stem, Path(name).suffix
        index = 2
        while name in used:
            name = safe_name(f'{stem} ({index}){suffix}')
            index += 1
        used.add(name)
        with open_source(path) as stream:
            before = file_identity(os.fstat(stream.fileno()))
            if before[2] + sum(row['size'] for row in rows) > MAX_TOTAL:
                raise TransferError('The selected transfer exceeds the supported size limit.')
            digest = hashlib.sha256()
            while chunk := stream.read(BUFFER):
                digest.update(chunk)
                if progress and time.monotonic() - last_progress >= 0.2:
                    progress({'phase': 'preparing', 'message': 'Preparing ' + name})
                    last_progress = time.monotonic()
            if before != file_identity(os.fstat(stream.fileno())):
                raise TransferError('A selected file changed while preparing. Select it again.')
        rows.append({'name': name, 'size': before[2], 'sha256': digest.hexdigest()})
        identities.append((str(path), before))
    return manifest(rows), identities
