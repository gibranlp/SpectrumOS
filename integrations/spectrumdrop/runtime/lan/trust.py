# SPDX-License-Identifier: MIT
from __future__ import annotations

import fcntl
import hashlib
import hmac
import json
from pathlib import Path

from .common import ID_RE, MAX_JSON, TOKEN_RE, TransferError, atomic_json


def paired_proof(secret, server, client, nonce, role):
    message = f'spectrumdrop-pair-v1:{role}:{server}:{client}:{nonce}'.encode('ascii')
    return hmac.new(bytes.fromhex(secret), message, hashlib.sha256).hexdigest()


class TrustStore:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.path = self.directory / 'paired.json'

    def read(self):
        if not self.path.exists():
            return {}
        if self.path.stat().st_size > MAX_JSON:
            raise TransferError('The paired PC store is too large.')
        value = json.loads(self.path.read_text())
        if not isinstance(value, dict) or len(value) > 64:
            raise TransferError('Invalid paired PC store.')
        for identifier, row in value.items():
            if not ID_RE.fullmatch(identifier) or not isinstance(row, dict) or any(
                    not isinstance(row.get(key), str) or not TOKEN_RE.fullmatch(row[key])
                    for key in ('fingerprint', 'secret')):
                raise TransferError('Invalid paired PC identity.')
        return value

    def update(self, identifier, row=None):
        if not isinstance(identifier, str) or not ID_RE.fullmatch(identifier):
            raise TransferError('Invalid paired PC identity.')
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        with (self.directory / 'paired.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            values = self.read()
            if row is None:
                values.pop(identifier, None)
            else:
                if identifier not in values and len(values) >= 64:
                    raise TransferError('Forget a paired PC before adding another.')
                values[identifier] = row
            atomic_json(self.path, values)

    def public(self):
        return [{'id': identifier, **{key: row[key] for key in ('name', 'fingerprint', 'addresses', 'port') if key in row},
                 'paired': True} for identifier, row in self.read().items()]

    def peers(self, discovered):
        saved = {row['id']: row for row in self.public()}
        result = []
        for peer in discovered:
            trusted = saved.pop(peer['id'], None)
            changed = bool(trusted and trusted['fingerprint'] != peer['fingerprint'])
            result.append({**peer, 'paired': bool(trusted), 'identity_changed': changed})
        return result + [{**row, 'offline': True} for row in saved.values()]
