#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
from __future__ import annotations

import fcntl
import html
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lan.common import MAX_JSON, TransferError, configuration, data_dir, ensure_identity, runtime_dir
from lan.control import ControlServer, rpc
from lan.service import Node

UNIT = 'spectrumdrop-lan.service'


def ensure_service():
    result = subprocess.run(['systemctl', '--user', 'start', UNIT], capture_output=True, text=True, timeout=15)
    if result.returncode:
        raise TransferError('Could not start SpectrumDrop network sharing. Update SpectrumOS and retry.')
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            return rpc('status')
        except (OSError, TransferError):
            time.sleep(0.1)
    raise TransferError('SpectrumDrop network sharing did not become ready.')


def notify(title, body):
    try:
        def deliver():
            try:
                subprocess.run(['notify-send', '--app-name=SpectrumDrop', title, html.escape(body)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        threading.Thread(target=deliver, daemon=True).start()
    except OSError:
        pass


def daemon():
    directory = runtime_dir()
    with (directory / 'daemon.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        identity = ensure_identity(data_dir())
        discovery = None
        try:
            from lan.discovery import Discovery
            discovery = Discovery(identity)
        except (OSError, RuntimeError, ImportError):
            pass
        node = Node(configuration(), identity, discovery, notifier=notify)
        path = directory / 'control.sock'
        path.unlink(missing_ok=True)
        control = ControlServer(node, path)
        thread = threading.Thread(target=control.serve_forever, daemon=True)
        thread.start()
        done = threading.Event()
        signal.signal(signal.SIGTERM, lambda *_: done.set())
        signal.signal(signal.SIGINT, lambda *_: done.set())
        try:
            while not done.wait(0.5):
                node.housekeeping()
        finally:
            node.stop()
            control.shutdown()
            control.server_close()
            path.unlink(missing_ok=True)
            if discovery:
                discovery.close()


def send():
    from lan.client import Client
    raw = sys.stdin.buffer.read(MAX_JSON + 1)
    if len(raw) > MAX_JSON:
        raise TransferError('Too many selected paths.')
    job = json.loads(raw)
    cancel = threading.Event()
    client = None
    def stopping(*_):
        cancel.set()
        if client and client.connection and client.connection.sock:
            try:
                client.connection.sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
    signal.signal(signal.SIGTERM, stopping)
    signal.signal(signal.SIGINT, stopping)
    def progress(value):
        if cancel.is_set():
            raise InterruptedError('Transfer cancelled.')
        print(json.dumps({'ok': True, **value}), flush=True)
    client = Client(job['peer'], job['code'], progress=progress, cancel=cancel)
    try:
        client.send(job['paths'], sender=socket.gethostname())
        progress({'phase': 'complete', 'message': 'Files sent and verified successfully.', 'percent': 100})
    except BaseException:
        client.abort()
        raise
    finally:
        client.close()


def main():
    args = sys.argv[1:]
    if args == ['daemon']:
        daemon()
        return
    if args == ['send']:
        send()
        return
    if args == ['status']:
        try:
            value = rpc('status')
        except (FileNotFoundError, ConnectionRefusedError):
            value = {'ok': True, 'available': True, 'receiving': False, 'name': socket.gethostname(),
                     'remaining': 0, 'dir': configuration()['directory'], 'code': '', 'incoming': [], 'addresses': []}
    elif len(args) == 2 and args[0] == 'receive':
        minutes = int(args[1])
        if minutes not in (5, 10, 30):
            raise TransferError('Choose a 5, 10 or 30 minute receive window.')
        ensure_service()
        value = rpc('receive', minutes=minutes)
    elif args == ['scan']:
        ensure_service()
        value = rpc('scan')
    elif args == ['stop']:
        try:
            value = rpc('stop')
        except (FileNotFoundError, ConnectionRefusedError):
            value = {'ok': True, 'receiving': False}
    elif len(args) == 2 and args[0] in ('accept', 'decline'):
        value = rpc(args[0], id=args[1])
    else:
        raise TransferError('Usage: lan.py status|receive MINUTES|scan|stop|accept ID|decline ID|send|daemon')
    print(json.dumps(value), flush=True)


if __name__ == '__main__':
    try:
        main()
    except InterruptedError:
        print(json.dumps({'ok': False, 'phase': 'cancelled', 'message': 'Transfer cancelled.'}), flush=True)
        raise SystemExit(130)
    except (TransferError, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        print(json.dumps({'ok': False, 'error': str(error)[:300]}), flush=True)
        raise SystemExit(1)
