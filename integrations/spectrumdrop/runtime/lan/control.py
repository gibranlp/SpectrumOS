# SPDX-License-Identifier: MIT
from __future__ import annotations

import json
import os
from pathlib import Path
import socket
import socketserver

from .common import MAX_JSON, TransferError, configuration, runtime_dir
from .service import LimitedThreads


def rpc(action, **values):
    path = runtime_dir() / 'control.sock'
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(12)
        connection.connect(str(path))
        connection.sendall(json.dumps({'action': action, **values}).encode() + b'\n')
        with connection.makefile('rb') as stream:
            data = stream.readline(MAX_JSON + 1)
        if len(data) > MAX_JSON or not data.endswith(b'\n'):
            raise TransferError('SpectrumDrop returned an invalid local response.')
        value = json.loads(data)
        if not isinstance(value, dict):
            raise TransferError('SpectrumDrop returned an invalid local response.')
        if not value.get('ok'):
            raise TransferError(str(value.get('error', 'SpectrumDrop could not complete the request.'))[:300])
        return value


class ControlServer(LimitedThreads, socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    def __init__(self, node, path):
        import threading
        self.node = node
        self.slots = threading.BoundedSemaphore(4)
        super().__init__(str(path), ControlHandler)
        os.chmod(path, 0o600)

    def handle_error(self, request, address):
        pass


class ControlHandler(socketserver.StreamRequestHandler):
    def handle(self):
        self.request.settimeout(10)
        try:
            raw = self.rfile.readline(MAX_JSON + 1)
            if len(raw) > MAX_JSON or not raw.endswith(b'\n'):
                raise TransferError('Local request is too large.')
            value = json.loads(raw)
            if not isinstance(value, dict):
                raise TransferError('Invalid local request.')
            node = self.server.node
            action = value.get('action')
            if action == 'status':
                result = node.status()
            elif action == 'receive':
                with node.lock:
                    node.config = configuration()
                result = node.start(value.get('minutes'))
            elif action == 'stop':
                result = node.stop()
            elif action in ('accept-pair', 'decline-pair'):
                result = node.decide_pair(value.get('id'), action == 'accept-pair')
            elif action == 'forget':
                result = node.forget(value.get('id'))
            elif action in ('accept', 'decline', 'cancel'):
                if action == 'cancel':
                    with node.lock:
                        job = node.jobs.get(value.get('id'))
                    if job is None:
                        raise TransferError('The incoming transfer is no longer available.')
                    node.fail(job, 'The receiver cancelled the transfer.', 'cancelled')
                    result = node.status()
                else:
                    result = node.decide(value.get('id'), action == 'accept')
            elif action == 'scan':
                import time
                time.sleep(2)
                result = {'peers': node.trust.peers(node.discovery.snapshot() if node.discovery else []),
                          'error': node.discovery.error if node.discovery else 'Automatic discovery is unavailable. Use the receiver IP address.'}
            else:
                raise TransferError('Unknown local SpectrumDrop action.')
            response = {'ok': True, **result}
        except (TransferError, OSError, ValueError, TypeError) as error:
            response = {'ok': False, 'error': str(error)[:300]}
        self.wfile.write(json.dumps(response).encode() + b'\n')
