# SPDX-License-Identifier: MIT
from __future__ import annotations

import hashlib
import hmac
from http.client import HTTPSConnection, HTTPException
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import threading
import time

from .common import CHUNK, ID_RE, MAX_JSON, TOKEN_RE, TransferError, collect_files, endpoint, file_identity, normalize_code, open_source, proof
from .trust import TrustStore, paired_proof


class NetworkError(TransferError):
    pass


class Client:
    def __init__(self, peer, code='', progress=None, cancel=None, timeout=15, identity=None):
        self.peer = peer
        self.code = normalize_code(code) if code else ''
        self.identity = identity
        self.trust = TrustStore(Path(identity['certificate']).parent) if identity else None
        self.paired = self.trust.read().get(peer.get('id')) if self.trust and not code else None
        if not self.code and not self.paired:
            raise TransferError('Pair this PC first or enter its receiver code.')
        self.progress = progress or (lambda value: None)
        self.cancelled = cancel or threading.Event()
        self.timeout = timeout
        self.connection = None
        self.fingerprint = self.paired['fingerprint'] if self.paired else peer.get('fingerprint', '')
        self.addresses = [endpoint(value) for value in peer.get('addresses', [])][:8]
        self.port = peer.get('port', 8857)
        if not self.addresses or not isinstance(self.port, int) or not 1 <= self.port <= 65535:
            raise TransferError('This device has no usable network address. Search again or enter its IP address.')
        self.ticket = None
        self.pair_ticket = None
        self.session = ''
        self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        self.context.minimum_version = ssl.TLSVersion.TLSv1_2
        # El código autentica el primer canal; las reconexiones fijan el certificado del receptor.
        self.context.check_hostname = False
        self.context.verify_mode = ssl.CERT_NONE

    def close(self):
        if self.connection:
            self.connection.close()
            self.connection = None

    def connect(self):
        self.close()
        for host in self.addresses:
            if self.cancelled.is_set():
                raise InterruptedError('Transfer cancelled.')
            connection = HTTPSConnection(host, self.port, timeout=min(4, self.timeout), context=self.context)
            try:
                connection.connect()
                actual = hashlib.sha256(connection.sock.getpeercert(binary_form=True)).hexdigest()
                if self.fingerprint and not hmac.compare_digest(actual, self.fingerprint):
                    raise TransferError('The device identity changed. Search again and verify the receiver code.')
                self.fingerprint = actual
                connection.sock.settimeout(self.timeout)
                self.connection = connection
                self.selected_address = host
                return
            except (OSError, HTTPException):
                connection.close()
                continue
            except BaseException:
                connection.close()
                raise
        raise NetworkError('Cannot reach this Spectrum PC. Check the network, receive window and firewall (TCP 8857).')

    def request(self, method, path, value=None, token='', body=None, offset=None):
        if self.cancelled.is_set():
            raise InterruptedError('Transfer cancelled.')
        if self.connection is None:
            self.connect()
        payload = json.dumps(value or {}).encode() if body is None and method == 'POST' else body
        headers = {'Authorization': token, 'Content-Type': 'application/json' if body is None else 'application/octet-stream'}
        if offset is not None:
            headers['X-SpectrumDrop-Offset'] = str(offset)
        try:
            self.connection.request(method, path, body=payload, headers=headers)
            response = self.connection.getresponse()
            length = response.getheader('Content-Length')
            if length is None or not 0 <= int(length) <= MAX_JSON:
                raise TransferError('The receiver returned an invalid response size.')
            data = response.read(int(length))
            if len(data) != int(length):
                raise NetworkError("The receiver response was interrupted.")
            result = json.loads(data)
            if not isinstance(result, dict):
                raise TransferError('The receiver returned an invalid response.')
            if not result.get('ok'):
                if response.status == 409 and isinstance(result.get('offset'), int):
                    return result
                self.close()
                raise TransferError(str(result.get('error', 'The receiver rejected the transfer.'))[:300])
            return result
        except (OSError, HTTPException) as error:
            self.close()
            raise NetworkError('The network connection was interrupted.') from error
        except (ValueError, TypeError) as error:
            self.close()
            raise TransferError('The receiver returned an invalid response.') from error

    def authenticate(self):
        self.connect()
        if self.paired:
            nonce = self.request('POST', '/v1/pair-challenge', {'id': self.identity['id']}).get('nonce')
            if not isinstance(nonce, str) or not TOKEN_RE.fullmatch(nonce):
                raise TransferError('Invalid paired authentication challenge.')
            signature = paired_proof(self.paired['secret'], self.fingerprint, self.identity['fingerprint'], nonce, 'request')
            response = self.request('POST', '/v1/auth-paired', {'nonce': nonce, 'proof': signature})
            expected = paired_proof(self.paired['secret'], self.fingerprint, self.identity['fingerprint'], nonce, 'response')
        else:
            nonce = secrets.token_hex(32)
            response = self.request('POST', '/v1/auth', {'nonce': nonce, 'proof': proof(self.code, self.fingerprint, nonce, 'request')})
            expected = proof(self.code, self.fingerprint, nonce, 'response')
        if not hmac.compare_digest(str(response.get('proof', '')), expected):
            self.close()
            raise TransferError('The receiver could not prove its identity. Check the code on the receiving PC.')
        self.session = response.get('session', '')
        if not isinstance(self.session, str) or not TOKEN_RE.fullmatch(self.session):
            raise TransferError('The receiver returned an invalid session.')

    def pair(self, name='Spectrum PC'):
        if not self.identity or not self.code:
            raise TransferError('Enter the receiver code to pair this PC.')
        self.authenticate()
        secret = secrets.token_hex(32)
        value = self.request('POST', '/v1/pair', {'id': self.identity['id'], 'name': name,
                             'fingerprint': self.identity['fingerprint'], 'secret': secret}, token=self.session)
        identifier = value.get('id')
        if not isinstance(identifier, str) or not ID_RE.fullmatch(identifier):
            raise TransferError('Invalid pairing request identity.')
        self.pair_ticket = identifier
        self.progress({'phase': 'waiting', 'message': 'Waiting for the other PC to approve pairing…'})
        deadline = time.monotonic() + 125
        while True:
            response = self.request('GET', '/v1/pair/' + identifier, token=self.session)
            if response.get('phase') == 'accepted':
                peer = response.get('peer', {})
                if (not isinstance(peer.get('id'), str) or not ID_RE.fullmatch(peer['id'])
                        or peer.get('fingerprint') != self.fingerprint
                        or (self.peer.get('id') and peer['id'] != self.peer['id'])):
                    raise TransferError('The pairing identity changed. Pair again.')
                self.trust.update(peer['id'], {'name': str(peer.get('name', 'Spectrum PC'))[:100],
                    'fingerprint': self.fingerprint, 'secret': secret,
                    'addresses': self.addresses, 'port': self.port})
                return peer
            if response.get('phase') != 'pending' or time.monotonic() > deadline:
                raise TransferError('Pairing was declined or expired. Try pairing again.')
            if self.cancelled.wait(0.5):
                raise InterruptedError('Pairing cancelled.')

    def status(self):
        last = None
        for attempt in range(4):
            try:
                return self.request('GET', '/v1/transfers/' + self.ticket['id'], token=self.ticket['token'])
            except NetworkError as error:
                last = error
                self.progress({'phase': 'retrying', 'message': 'Connection interrupted. Reconnecting…'})
                if self.cancelled.wait(min(2 ** attempt, 4)):
                    raise InterruptedError('Transfer cancelled.')
        raise last

    def send(self, paths, sender='Spectrum PC'):
        self.authenticate()
        rows, sources = collect_files(paths, self.progress)
        self.progress({'phase': 'waiting', 'message': 'Waiting for the receiving PC to accept…'})
        offer = {'sender': sender, 'files': rows, 'request_id': secrets.token_hex(16)}
        for attempt in range(4):
            try:
                self.ticket = self.request('POST', '/v1/offer', offer, token=self.session)
                if not ID_RE.fullmatch(str(self.ticket.get('id', ''))) or not TOKEN_RE.fullmatch(str(self.ticket.get('token', ''))):
                    raise TransferError('The receiver returned an invalid transfer identity.')
                break
            except NetworkError:
                if attempt == 3:
                    raise
                if self.cancelled.wait(min(2 ** attempt, 4)):
                    raise InterruptedError('Transfer cancelled.')
        deadline = time.monotonic() + 125
        while True:
            status = self.status()
            if status['phase'] != 'pending':
                break
            if time.monotonic() > deadline:
                raise TransferError('The receiver did not accept in time.')
            if self.cancelled.wait(0.5):
                raise InterruptedError('Transfer cancelled.')
        if status['phase'] != 'receiving':
            raise TransferError(status.get('error') or 'The receiver declined the transfer.')
        total = sum(row['size'] for row in rows)
        last_emit = 0
        for index, (source, identity) in enumerate(sources):
            with open_source(Path(source)) as stream:
                if tuple(identity) != file_identity(os.fstat(stream.fileno())):
                    raise TransferError('A selected file changed. Select it again before sending.')
                failures = 0
                while True:
                    state = self.status()
                    if state['phase'] != 'receiving':
                        raise TransferError(state.get('error') or 'The receiver stopped this transfer.')
                    offset = state['offsets'][index]
                    if not isinstance(offset, int) or not 0 <= offset <= rows[index]['size']:
                        raise TransferError('The receiver returned an invalid upload position.')
                    if offset == rows[index]['size']:
                        break
                    stream.seek(offset)
                    chunk = stream.read(min(CHUNK, rows[index]['size'] - offset))
                    if not chunk:
                        raise TransferError('A selected file became shorter while sending.')
                    try:
                        result = self.request('PUT', f'/v1/transfers/{self.ticket["id"]}/files/{index}',
                                              body=chunk, token=self.ticket['token'], offset=offset)
                        if not result.get('ok'):
                            continue
                        failures = 0
                    except NetworkError:
                        failures += 1
                        if failures > 4:
                            raise
                        self.progress({'phase': 'retrying', 'message': 'Connection interrupted. Resuming from the receiver position…'})
                        if self.cancelled.wait(min(2 ** failures, 4)):
                            raise InterruptedError('Transfer cancelled.')
                        continue
                    done = sum(state['offsets']) + len(chunk)
                    now = time.monotonic()
                    if now - last_emit >= 0.2 or done == total:
                        self.progress({'phase': 'sending', 'message': 'Sending ' + rows[index]['name'],
                                       'bytes': done, 'total': total, 'percent': round(done * 100 / total) if total else 100})
                        last_emit = now
                if tuple(identity) != file_identity(os.fstat(stream.fileno())):
                    raise TransferError('A selected file changed while sending. The incomplete transfer was not published.')
        try:
            result = self.request('POST', '/v1/transfers/' + self.ticket['id'] + '/commit', token=self.ticket['token'])
        except NetworkError:
            result = self.status()
            if result['phase'] != 'complete':
                result = self.request('POST', '/v1/transfers/' + self.ticket['id'] + '/commit', token=self.ticket['token'])
        if result.get('phase') != 'complete':
            raise TransferError('The receiver did not confirm the completed transfer.')
        return result

    def abort(self):
        if self.pair_ticket:
            saved = self.cancelled
            self.cancelled = threading.Event()
            try:
                self.close()
                self.timeout = min(self.timeout, 3)
                self.request('POST', '/v1/pair/' + self.pair_ticket + '/cancel', token=self.session)
            except (TransferError, OSError):
                pass
            finally:
                self.cancelled = saved
        if self.ticket:
            saved = self.cancelled
            self.cancelled = threading.Event()
            try:
                self.close()
                self.timeout = min(self.timeout, 3)
                self.addresses = [getattr(self, 'selected_address', self.addresses[0])]
                self.request('POST', '/v1/transfers/' + self.ticket['id'] + '/cancel', token=self.ticket['token'])
            except (TransferError, OSError):
                pass
            finally:
                self.cancelled = saved
        self.close()
