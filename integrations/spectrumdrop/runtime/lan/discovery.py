# SPDX-License-Identifier: MIT
from __future__ import annotations

import ipaddress
import socket
import threading
import time

from .common import ID_RE, SERVICE, TOKEN_RE, VERSION, endpoint


def addresses() -> list[str]:
    import ifaddr
    result = set()
    for adapter in ifaddr.get_adapters():
        if adapter.name.startswith(('awdl', 'docker', 'veth')):
            continue
        for entry in adapter.ips:
            value = entry.ip[0] if isinstance(entry.ip, tuple) else entry.ip
            ip = ipaddress.ip_address(value)
            if not ip.is_loopback and not ip.is_unspecified and not ip.is_multicast and not (ip.version == 6 and ip.is_link_local):
                result.add(str(ip))
    return sorted(result)


class Discovery:
    def __init__(self, identity: dict, interfaces=None, advertised_addresses=None):
        from zeroconf import InterfaceChoice, IPVersion, ServiceBrowser, Zeroconf
        self.identity = identity
        self.advertised_addresses = advertised_addresses
        self.lock = threading.RLock()
        self.peers = {}
        self.error = ''
        self.info = None
        self.zero = Zeroconf(ip_version=IPVersion.All, interfaces=interfaces if interfaces is not None else InterfaceChoice.All)
        self.browser = ServiceBrowser(self.zero, SERVICE, handlers=[self.changed])

    def changed(self, zeroconf, service_type, name, state_change):
        from zeroconf import ServiceStateChange
        if state_change is ServiceStateChange.Removed:
            with self.lock:
                self.peers.pop(name, None)
            return
        info = zeroconf.get_service_info(service_type, name, timeout=1200)
        if info is None:
            return
        try:
            fields = {k.decode(): v.decode() for k, v in info.properties.items() if isinstance(v, bytes)}
            identifier, fingerprint = fields['id'], fields['fingerprint']
            if fields.get('version') != str(VERSION) or not ID_RE.fullmatch(identifier) or not TOKEN_RE.fullmatch(fingerprint) or identifier == self.identity['id']:
                return
            hosts = []
            for value in info.parsed_scoped_addresses():
                try:
                    hosts.append(endpoint(value))
                except (ValueError, RuntimeError):
                    continue
            if not hosts or not 1 <= info.port <= 65535:
                return
            row = {'id': identifier, 'name': fields.get('name', 'Spectrum PC')[:100],
                   'fingerprint': fingerprint, 'addresses': hosts[:8], 'port': info.port,
                   'seen': time.monotonic()}
            with self.lock:
                if len(self.peers) < 128 or name in self.peers:
                    self.peers[name] = row
        except (KeyError, UnicodeError, ValueError):
            return

    def advertise(self, name: str, port: int):
        from zeroconf import ServiceInfo
        self.withdraw()
        hosts = self.advertised_addresses if self.advertised_addresses is not None else addresses()
        if not hosts:
            self.error = 'No local network address. Connect Ethernet or Wi-Fi, then try again.'
            return
        info = ServiceInfo(SERVICE, self.identity['id'] + '.' + SERVICE,
            addresses=[ipaddress.ip_address(value).packed for value in hosts], port=port,
            properties={'version': str(VERSION), 'id': self.identity['id'], 'name': name[:100],
                        'fingerprint': self.identity['fingerprint']},
            server='spectrumdrop-' + self.identity['id'] + '.local.')
        try:
            self.zero.register_service(info, allow_name_change=True)
            self.info = info
            self.error = ''
        except Exception:
            self.error = 'Automatic discovery is unavailable. Connect using the receiver IP address.'

    def withdraw(self):
        if self.info is not None:
            try:
                self.zero.unregister_service(self.info)
            finally:
                self.info = None

    def snapshot(self):
        with self.lock:
            return [{k: v for k, v in item.items() if k != 'seen'} for item in self.peers.values()]

    def close(self):
        self.withdraw()
        self.browser.cancel()
        self.zero.close()
