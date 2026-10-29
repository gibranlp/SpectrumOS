# SPDX-License-Identifier: MIT
from __future__ import annotations

import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import socketserver
import ssl
import subprocess
import tempfile
import threading
import time

from .common import BUFFER, CHUNK, ID_RE, MAX_JSON, TOKEN_RE, TransferError, access_code, atomic_json, manifest, proof
from .trust import TrustStore, paired_proof


class LimitedThreads:
    daemon_threads = True
    block_on_close = False

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.slots.release()


class TransferServer(LimitedThreads, socketserver.ThreadingMixIn, HTTPServer):
    allow_reuse_address = True

    def __init__(self, address, node, family=socket.AF_INET):
        self.address_family = family
        self.node = node
        self.slots = threading.BoundedSemaphore(8)
        super().__init__(address, TransferHandler)
        if family == socket.AF_INET6:
            pass

    def server_bind(self):
        if self.address_family == socket.AF_INET6:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()

    def handle_error(self, request, address):
        pass


class Incoming:
    def __init__(self, files, sender, session):
        self.id = secrets.token_hex(16)
        self.token = secrets.token_hex(32)
        self.files = files
        self.sender = str(sender)[:100]
        self.session = session
        self.phase = 'pending'
        self.error = ''
        self.folder = ''
        self.offsets = [0] * len(files)
        self.hashes = [hashlib.sha256() for _ in files]
        self.stage = None
        self.updated = time.monotonic()
        self.lock = threading.RLock()
        self.cancelled = threading.Event()
        self.active_socket = None

    def public(self, summary=False):
        with self.lock:
            return {'id': self.id, 'sender': self.sender, 'files': [{'name': item['name'], 'size': item['size']} for item in self.files[:5]] if summary else self.files,
                    'file_count': len(self.files), 'phase': self.phase,
                    'error': self.error, 'folder': self.folder, 'offsets': [] if summary else list(self.offsets),
                    'bytes': sum(self.offsets), 'total': sum(row['size'] for row in self.files)}


class Node:
    def __init__(self, config, identity, discovery=None, host=None, port=8857, notifier=None):
        self.config = config
        self.identity = identity
        self.discovery = discovery
        self.host = host
        self.requested_port = port
        self.notify = notifier or (lambda title, body: None)
        self.lock = threading.RLock()
        self.deadline = 0
        self.code = ''
        self.window = ''
        self.sessions = {}
        self.session_peers = {}
        self.pair_requests = {}
        self.challenges = {}
        self.trust = TrustStore(Path(identity['certificate']).parent)
        self.jobs = {}
        self.attempts = {}
        self.server = None
        self.thread = None
        self.closed = False
        self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self.context.minimum_version = ssl.TLSVersion.TLSv1_2
        self.context.load_cert_chain(identity['certificate'], identity['key'])

    def start(self, minutes):
        if minutes not in (5, 10, 30):
            raise TransferError('Choose a 5, 10 or 30 minute receive window.')
        with self.lock:
            if any(job.phase in ('pending', 'receiving') for job in self.jobs.values()):
                raise TransferError('Finish or decline incoming transfers before starting a new receive window.')
            if self.server is None:
                if self.host is None:
                    try:
                        self.server = TransferServer(('::', self.requested_port), self, socket.AF_INET6)
                    except OSError:
                        self.server = TransferServer(('0.0.0.0', self.requested_port), self)
                else:
                    self.server = TransferServer((self.host, self.requested_port), self)
                self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
                self.thread.start()
            self.deadline = time.monotonic() + minutes * 60
            self.code = access_code()
            self.window = secrets.token_hex(16)
            self.sessions.clear()
            self.session_peers.clear()
            self.pair_requests.clear()
            self.challenges.clear()
            self.attempts.clear()
            port = self.server.server_port
        if self.discovery:
            self.discovery.advertise(self.config['name'], port)
        return self.status()

    def status(self):
        with self.lock:
            receiving = self.deadline > time.monotonic()
            return {'available': True, 'receiving': receiving, 'name': self.config['name'],
                    'remaining': max(0, int(self.deadline - time.monotonic())),
                    'dir': self.config['directory'], 'code': self.code if receiving else '',
                    'port': self.server.server_port if self.server else self.requested_port,
                    'addresses': self.local_addresses(),
                    'paired': self.trust.public(),
                    'pair_requests': [{'id': key, 'name': row['name'], 'fingerprint': row['fingerprint']}
                                      for key, row in self.pair_requests.items()
                                      if row['phase'] == 'pending' and row['deadline'] > time.monotonic() and receiving],
                    'error': self.discovery.error if self.discovery else '',
                    'incoming': [job.public(summary=True) for job in self.jobs.values()][-12:]}

    def local_addresses(self):
        if self.host:
            return [self.host]
        try:
            from .discovery import addresses
            return addresses()
        except (ImportError, OSError):
            return []

    def authenticate(self, value, remote):
        nonce, signature = value.get('nonce'), value.get('proof')
        if not isinstance(nonce, str) or not TOKEN_RE.fullmatch(nonce) or not isinstance(signature, str):
            raise TransferError('Invalid authentication request.')
        with self.lock:
            now = time.monotonic()
            if self.deadline <= now:
                raise TransferError('Receiving is off or the receive window expired.')
            stamp, count = self.attempts.get(remote, (now, 0))
            if now - stamp > 60:
                stamp, count = now, 0
            if count >= 8:
                raise TransferError('Too many code attempts. Wait one minute and retry.')
            expected = proof(self.code, self.identity['fingerprint'], nonce, 'request')
            if not hmac.compare_digest(expected, signature):
                if remote not in self.attempts and len(self.attempts) >= 128:
                    self.attempts = {host: item for host, item in self.attempts.items() if now - item[0] < 60}
                    if len(self.attempts) >= 128:
                        raise TransferError('Too many code attempts. Wait one minute and retry.')
                self.attempts[remote] = (stamp, count + 1)
                raise TransferError('The receiver code is incorrect or has expired.')
            if len(self.sessions) >= 64:
                raise TransferError('Too many active transfer sessions. Restart receiving.')
            token = secrets.token_hex(32)
            self.sessions[token] = self.window
            return {'session': token, 'proof': proof(self.code, self.identity['fingerprint'], nonce, 'response')}

    def session_valid(self, token):
        with self.lock:
            peer = self.session_peers.get(token)
            trusted = self.trust.read().get(peer['id']) if peer else None
            return (self.deadline > time.monotonic() and self.sessions.get(token) == self.window
                    and (peer is None or trusted == peer['record']))

    def challenge(self, value):
        with self.lock:
            now = time.monotonic()
            self.challenges = {key: row for key, row in self.challenges.items() if row[1] > now}
            identifier = value.get('id')
            if not isinstance(identifier, str) or not ID_RE.fullmatch(identifier):
                raise TransferError('Invalid paired PC identity.')
            if self.deadline <= now or identifier not in self.trust.read():
                raise TransferError('This PC is not paired or receiving is off. Pair again using the receiver code.')
            if len(self.challenges) >= 64:
                raise TransferError('Too many authentication requests. Try again shortly.')
            nonce = secrets.token_hex(32)
            self.challenges[nonce] = (identifier, now + 30)
            return {'nonce': nonce}

    def authenticate_paired(self, value):
        with self.lock:
            nonce = value.get('nonce', '')
            if not isinstance(nonce, str) or not TOKEN_RE.fullmatch(nonce):
                raise TransferError('Invalid pairing challenge.')
            challenge = self.challenges.pop(nonce, None)
            if challenge is None or challenge[1] <= time.monotonic() or self.deadline <= time.monotonic():
                raise TransferError('Pair authentication expired. Try sending again.')
            identifier = challenge[0]
            row = self.trust.read().get(identifier)
            if not row or not hmac.compare_digest(str(value.get('proof', '')), paired_proof(
                    row['secret'], self.identity['fingerprint'], row['fingerprint'], nonce, 'request')):
                raise TransferError('Paired PC authentication failed. Pair again using the receiver code.')
            if len(self.sessions) >= 64:
                raise TransferError('Too many active transfer sessions. Restart receiving.')
            token = secrets.token_hex(32)
            self.sessions[token] = self.window
            self.session_peers[token] = {'id': identifier, 'record': row}
            return {'session': token, 'proof': paired_proof(row['secret'], self.identity['fingerprint'],
                                                           row['fingerprint'], nonce, 'response')}

    def request_pair(self, value, session, remote):
        with self.lock:
            if not self.session_valid(session) or session in self.session_peers:
                raise TransferError('Enter the receiver code to pair this PC.')
            identifier, fingerprint, secret = (value.get(key) for key in ('id', 'fingerprint', 'secret'))
            if (not isinstance(identifier, str) or not ID_RE.fullmatch(identifier) or identifier == self.identity['id']
                    or any(not isinstance(item, str) or not TOKEN_RE.fullmatch(item) for item in (fingerprint, secret))):
                raise TransferError('Invalid pairing identity.')
            if len(self.pair_requests) >= 8:
                raise TransferError('Too many pairing requests. Restart receiving.')
            name = str(value.get('name', 'Spectrum PC'))[:100]
            key = secrets.token_hex(16)
            self.pair_requests[key] = {'peer_id': identifier, 'fingerprint': fingerprint, 'secret': secret,
                                       'name': name, 'addresses': [remote], 'port': 8857,
                                       'session': session, 'phase': 'pending', 'deadline': time.monotonic() + 120}
        self.notify('Pair Spectrum PC', f'{name} wants to pair. Open SpectrumDrop to accept or decline.')
        return {'id': key}

    def pair_status(self, identifier, session):
        with self.lock:
            row = self.pair_requests.get(identifier)
            if not row or row['session'] != session or not self.session_valid(session):
                raise TransferError('The pairing request expired. Try pairing again.')
            if row['deadline'] <= time.monotonic() and row['phase'] == 'pending':
                row['phase'] = 'expired'
            return {'phase': row['phase'], 'peer': {'id': self.identity['id'], 'name': self.config['name'],
                    'fingerprint': self.identity['fingerprint'], 'addresses': self.local_addresses(),
                    'port': self.server.server_port}}

    def decide_pair(self, identifier, accept):
        with self.lock:
            row = self.pair_requests.get(identifier)
            if (not row or row['phase'] != 'pending' or row['deadline'] <= time.monotonic()
                    or not self.session_valid(row['session'])):
                raise TransferError('The pairing request expired. Try pairing again.')
            if accept:
                self.trust.update(row['peer_id'], {key: row[key] for key in ('name', 'fingerprint', 'secret', 'addresses', 'port')})
            row['phase'] = 'accepted' if accept else 'declined'
        return self.status()

    def forget(self, identifier):
        with self.lock:
            self.trust.update(identifier)
            for row in self.pair_requests.values():
                if row['peer_id'] == identifier:
                    row['phase'] = 'declined'
            jobs = [job for job in self.jobs.values() if self.session_peers.get(job.session, {}).get('id') == identifier]
        for job in jobs:
            if job.phase in ('pending', 'receiving'):
                self.fail(job, 'The paired PC was forgotten.', 'cancelled')
        return self.status()

    def cancel_pair(self, identifier, session):
        with self.lock:
            row = self.pair_requests.get(identifier)
            if not row or row['session'] != session or not self.session_valid(session):
                raise TransferError('The pairing request expired.')
            if row['phase'] == 'pending':
                row['phase'] = 'cancelled'
            return {'phase': row['phase']}

    def offer(self, value, session):
        files = manifest(value.get('files'))
        request_id = value.get('request_id', '')
        if not isinstance(request_id, str) or (request_id and not ID_RE.fullmatch(request_id)):
            raise TransferError('Invalid transfer request identity.')
        with self.lock:
            if not self.session_valid(session):
                raise TransferError('The receive window expired. Ask the receiver to enable it again.')
            previous = next((job for job in self.jobs.values() if request_id and job.session == session and getattr(job, 'request_id', '') == request_id), None)
            if previous:
                if previous.files != files:
                    raise TransferError('The transfer request contents changed.')
                return {'token': previous.token, **previous.public()}
            if sum(job.phase in ('pending', 'receiving') for job in self.jobs.values()) >= 4:
                raise TransferError('The receiver already has pending transfers.')
            free = shutil.disk_usage(self.config['directory']).free
            reserved = sum(sum(row['size'] for row in job.files) for job in self.jobs.values() if job.phase in ('pending', 'receiving'))
            if sum(row['size'] for row in files) + reserved > max(0, free - 64 * 1024 * 1024) * self.config['max_receive_percent'] / 100:
                raise TransferError('There is not enough allowed free space on the receiver.')
            paired = self.session_peers.get(session)
            job = Incoming(files, paired['record']['name'] if paired else value.get('sender', 'Spectrum PC'), session)
            job.request_id = request_id
            self.jobs[job.id] = job
            while len(self.jobs) > 12:
                old = next((key for key, item in self.jobs.items() if item.phase not in ('pending', 'receiving')), None)
                if old is None:
                    break
                self.jobs.pop(old)
        self.notify('Incoming SpectrumDrop files', f'{job.sender} wants to send {len(files)} files. Open SpectrumDrop to accept or decline.')
        return {'id': job.id, 'token': job.token, **job.public()}

    def find_job(self, identifier, token):
        with self.lock:
            job = self.jobs.get(identifier)
        if job is None or not isinstance(token, str) or not hmac.compare_digest(job.token, token):
            raise TransferError('The transfer is no longer available.')
        return job

    def decide(self, identifier, accept):
        with self.lock:
            job = self.jobs.get(identifier)
        if job is None:
            raise TransferError('The incoming request is no longer available.')
        with job.lock:
            if job.phase != 'pending':
                raise TransferError('This request was already handled.')
            if accept:
                if self.deadline <= time.monotonic():
                    raise TransferError('The receive window expired. Decline this request and restart receiving.')
                job.stage = Path(tempfile.mkdtemp(prefix='.spectrumdrop-', suffix='.partial', dir=self.config['directory']))
                (job.stage / 'data').mkdir()
                (job.stage / 'ready').mkdir()
                job.phase = 'receiving'
                for index, row in enumerate(job.files):
                    descriptor = os.open(job.stage / 'data' / str(index), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
                    os.close(descriptor)
                    if row['size'] == 0 and row['sha256'] != hashlib.sha256(b'').hexdigest():
                        self.fail(job, 'Checksum mismatch for an empty file.')
                        break
            else:
                self.fail(job, 'The receiver declined the transfer.', 'declined')
            job.updated = time.monotonic()
        return self.status()

    def fail(self, job, message, phase='failed'):
        if phase == 'cancelled':
            job.cancelled.set()
            if job.active_socket:
                try:
                    job.active_socket.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
        with job.lock:
            if job.phase in ('complete', 'declined', 'failed', 'cancelled'):
                return
            job.phase = phase
            job.error = message
            job.updated = time.monotonic()
            if job.stage:
                shutil.rmtree(job.stage, ignore_errors=True)
                job.stage = None

    def commit(self, job):
        with job.lock:
            if job.phase == 'complete':
                return job.public()
            if job.phase != 'receiving' or any(job.offsets[i] != row['size'] or job.hashes[i].hexdigest() != row['sha256'] for i, row in enumerate(job.files)):
                raise TransferError('The transfer is incomplete or a file checksum does not match.')
            destination = Path(self.config['directory']) / ('SpectrumDrop ' + time.strftime('%Y-%m-%d %H-%M-%S') + ' ' + job.id[:8])
            if destination.exists():
                raise TransferError('The destination already exists. Retry the transfer.')
            try:
                if any((job.stage / 'data' / str(index)).stat().st_size != row['size'] for index, row in enumerate(job.files)):
                    self.fail(job, 'A received file is incomplete on disk.')
                    raise TransferError(job.error)
                for row in job.files:
                    descriptor = os.open(job.stage / 'ready' / row['name'], os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
                    os.close(descriptor)
                for index, row in enumerate(job.files):
                    os.replace(job.stage / 'data' / str(index), job.stage / 'ready' / row['name'])
                os.rename(job.stage / 'ready', destination)
                shutil.rmtree(job.stage)
                job.stage = None
            except OSError:
                self.fail(job, 'The receiver could not save the files. Check the save folder and available disk space.')
                raise TransferError(job.error) from None
            job.phase = 'complete'
            job.folder = str(destination)
            job.updated = time.monotonic()
        self.notify('SpectrumDrop received files', f'{len(job.files)} files saved in {destination.name}.')
        return job.public()

    def stop(self):
        with self.lock:
            self.deadline = 0
            self.code = ''
            self.sessions.clear()
            self.session_peers.clear()
            self.challenges.clear()
            self.pair_requests.clear()
            jobs = list(self.jobs.values())
        for job in jobs:
            if job.phase in ('pending', 'receiving'):
                self.fail(job, 'Receiving was stopped.', 'cancelled')
        if self.discovery:
            self.discovery.withdraw()
        self.close_listener()
        return self.status()

    def close_listener(self):
        with self.lock:
            server, self.server = self.server, None
        if server:
            server.shutdown()
            server.server_close()

    def housekeeping(self):
        with self.lock:
            now = time.monotonic()
            expired = bool(self.deadline and self.deadline <= now)
            if expired:
                self.deadline = 0
                self.code = ''
            jobs = list(self.jobs.values())
        if expired and self.discovery:
            self.discovery.withdraw()
        for job in jobs:
            if (job.phase == 'pending' and not self.deadline) or (job.phase in ('pending', 'receiving') and now - job.updated > (120 if job.phase == 'pending' else 180)):
                self.fail(job, 'The transfer timed out.', 'cancelled')
        if not self.deadline and not any(job.phase == 'receiving' for job in jobs):
            self.close_listener()


class TransferHandler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    server_version = 'SpectrumDrop/1'
    sys_version = ''

    def setup(self):
        self.request.settimeout(8)
        try:
            self.request = self.server.node.context.wrap_socket(self.request, server_side=True)
            self.request.settimeout(30)
            super().setup()
        except BaseException:
            self.request.close()
            raise

    def finish(self):
        try:
            super().finish()
        finally:
            self.request.close()

    def log_message(self, format, *args):
        pass

    def reply(self, code, value):
        body = json.dumps(value).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        if self.headers.get('Transfer-Encoding') or self.headers.get('Content-Length') is None:
            raise TransferError('A bounded Content-Length is required.')
        try:
            count = int(self.headers['Content-Length'])
        except ValueError:
            raise TransferError('Invalid request size.') from None
        if not 0 <= count <= MAX_JSON:
            raise TransferError('Request metadata is too large.')
        raw = self.rfile.read(count)
        if len(raw) != count:
            raise TransferError('The request was interrupted.')
        value = json.loads(raw)
        if not isinstance(value, dict):
            raise TransferError('Invalid request metadata.')
        return value

    def do_POST(self):
        try:
            node = self.server.node
            value = self.body()
            if self.path == '/v1/auth':
                result = node.authenticate(value, self.client_address[0])
            elif self.path == '/v1/pair-challenge':
                result = node.challenge(value)
            elif self.path == '/v1/auth-paired':
                result = node.authenticate_paired(value)
            elif self.path == '/v1/pair':
                result = node.request_pair(value, self.headers.get('Authorization', ''), self.client_address[0])
            elif re.fullmatch(r'/v1/pair/[0-9a-f]{32}/cancel', self.path):
                result = node.cancel_pair(self.path.split('/')[3], self.headers.get('Authorization', ''))
            elif self.path == '/v1/offer':
                result = node.offer(value, self.headers.get('Authorization', ''))
            else:
                match = re.fullmatch(r'/v1/transfers/([0-9a-f]{32})/(commit|cancel)', self.path)
                if not match:
                    raise TransferError('Unknown request.')
                job = node.find_job(match[1], self.headers.get('Authorization', ''))
                if match[2] == 'cancel':
                    node.fail(job, 'The sender cancelled the transfer.', 'cancelled')
                    result = job.public()
                else:
                    result = node.commit(job)
            self.reply(200, {'ok': True, **result})
        except (TransferError, ValueError, OSError) as error:
            self.close_connection = True
            self.reply(400, {'ok': False, 'error': str(error)[:300]})

    def do_GET(self):
        try:
            pairing = re.fullmatch(r'/v1/pair/([0-9a-f]{32})', self.path)
            if pairing:
                result = self.server.node.pair_status(pairing[1], self.headers.get('Authorization', ''))
                self.reply(200, {'ok': True, **result})
                return
            match = re.fullmatch(r'/v1/transfers/([0-9a-f]{32})', self.path)
            if not match:
                raise TransferError('Unknown request.')
            job = self.server.node.find_job(match[1], self.headers.get('Authorization', ''))
            if job.phase in ('pending', 'receiving'):
                job.updated = time.monotonic()
            self.reply(200, {'ok': True, **job.public()})
        except (TransferError, OSError) as error:
            self.reply(400, {'ok': False, 'error': str(error)[:300]})

    def do_PUT(self):
        job = None
        unread = 0
        try:
            match = re.fullmatch(r'/v1/transfers/([0-9a-f]{32})/files/(\d{1,3})', self.path)
            if not match or self.headers.get('Transfer-Encoding'):
                raise TransferError('Invalid upload request.')
            job = self.server.node.find_job(match[1], self.headers.get('Authorization', ''))
            index = int(match[2])
            count = int(self.headers.get('Content-Length', '-1'))
            offset = int(self.headers.get('X-SpectrumDrop-Offset', '-1'))
            if not 0 <= index < len(job.files) or not 0 < count <= CHUNK:
                raise TransferError('Invalid upload range.')
            unread = count
            with job.lock:
                if job.phase != 'receiving' or job.stage is None:
                    raise TransferError('The receiver has not accepted this transfer.')
                if offset != job.offsets[index]:
                    self.rfile.read(unread)
                    unread = 0
                    self.close_connection = True
                    self.reply(409, {'ok': False, 'error': 'Upload position changed.', 'offset': job.offsets[index]})
                    return
                if offset + count > job.files[index]['size']:
                    raise TransferError('Upload exceeds the declared file size.')
                if count > shutil.disk_usage(job.stage).free - 16 * 1024 * 1024:
                    raise TransferError('The receiver ran out of disk space.')
                job.active_socket = self.connection
                descriptor = os.open(job.stage / 'data' / str(index), os.O_RDWR | os.O_NOFOLLOW)
                with os.fdopen(descriptor, 'r+b') as stream:
                    stream.seek(offset)
                    remaining = count
                    while remaining:
                        chunk = self.rfile.read(min(BUFFER, remaining))
                        if job.cancelled.is_set():
                            raise ConnectionError('The transfer was cancelled.')
                        if not chunk:
                            raise ConnectionError('Upload interrupted; retry from the current position.')
                        stream.write(chunk)
                        job.hashes[index].update(chunk)
                        job.offsets[index] += len(chunk)
                        job.updated = time.monotonic()
                        remaining -= len(chunk)
                        unread -= len(chunk)
                    stream.flush()
                    if job.offsets[index] == job.files[index]['size']:
                        os.fsync(stream.fileno())
                        if job.hashes[index].hexdigest() != job.files[index]['sha256']:
                            self.server.node.fail(job, 'The received file checksum does not match.')
                            raise TransferError(job.error)
                self.reply(200, {'ok': True, 'offset': job.offsets[index]})
        except (ConnectionError, TimeoutError, socket.timeout):
            self.close_connection = True
        except (TransferError, ValueError, OSError) as error:
            if isinstance(error, OSError) and job and job.phase == 'receiving':
                self.server.node.fail(job, 'The receiver could not write the file. Check available disk space.')
            if unread:
                try:
                    self.rfile.read(unread)
                except OSError:
                    pass
            self.close_connection = True
            self.reply(400, {'ok': False, 'error': str(error)[:300]})

        finally:
            if job and job.active_socket is self.connection:
                job.active_socket = None
