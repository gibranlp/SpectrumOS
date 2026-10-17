#!/usr/bin/env python3
"""Answer mDNS queries for our AirDrop identity on awdl0.

WHY. Measured control: a peer Mac's sharingd saw our advert, created a Bonjour
service and sent DISCOVER seven times over thirty seconds, and every attempt
timed out at "Bonjour service failed discovery" -- it could not resolve our
Arpa hostname (the one in awdl_afs_pload) to an address. Our capture holds its
28 queries for that name; we answered none, because the only thing we put in
mDNS is the hold loop's unsolicited announcements, which start at T0, after
sharingd has given up. When the Mac happens to resolve us over the D2D path
(every earlier transfer) this never matters; when it does not, no transfer, no
tile, and the hold measures nothing.

WHAT. AF_PACKET on awdl0; for every mDNS query (UDP 5353, QR=0) whose question
names our host, the _airdrop._tcp service, or our instance, send the same
announcement frame the announcer sends (PTR + SRV + TXT + AAAA, multicast --
the Mac accepts the mDNS group from us; unicast needs a peer entry). One reply
per query burst (100 ms), so a Mac's repeated queries do not become a flood.
Frames arrive decapsulated (eth:ipv6:udp) thanks to the driver's
brcmf_rx_eth_type_trans; SNAP-wrapped ones are handled too. Root; runs from
the moment awdl_afs_pload is loaded, through the hold.

  awdl-mdns-respond.py --iface awdl0 --port 8771 --flags 136
"""
import argparse
import importlib
import os
import socket
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
adv = importlib.import_module('awdl-airdrop-adv')
ident = importlib.import_module('awdl_identity')

ETH_P_ALL = 0x0003
ETH_P_IPV6 = 0x86dd


def dns_name(pkt, off):
    """Read a possibly compressed DNS name; returns (lowercase name, next offset)."""
    labels = []
    jumped = False
    nxt = None
    hops = 0
    while True:
        if off >= len(pkt):
            raise ValueError('truncated name')
        n = pkt[off]
        if n == 0:
            off += 1
            break
        if n & 0xc0 == 0xc0:
            if nxt is None:
                nxt = off + 2
            off = ((n & 0x3f) << 8) | pkt[off + 1]
            hops += 1
            if hops > 16:
                raise ValueError('compression loop')
            continue
        labels.append(pkt[off + 1:off + 1 + n].decode('ascii', 'replace').lower())
        off += 1 + n
    return '.'.join(labels), (nxt if nxt is not None else off)


def questions(dns):
    """Question names of an mDNS query, or [] if this is not a query."""
    if len(dns) < 12:
        return []
    flags, qd = struct.unpack('!HH', dns[2:6])
    if flags & 0x8000 or qd == 0:
        return []
    out, off = [], 12
    try:
        for _ in range(qd):
            name, off = dns_name(dns, off)
            off += 4  # qtype, qclass
            out.append(name)
    except ValueError:
        return []
    return out


def mdns_payload(frame):
    """(src_mac, dns bytes) for an IPv6/UDP/5353 frame, plain or Apple-SNAP wrapped; else None."""
    if len(frame) < 14:
        return None
    src = frame[6:12]
    etype = struct.unpack('!H', frame[12:14])[0]
    off = 14
    if etype == ETH_P_IPV6:
        pass
    elif etype <= 1500 and frame[14:17] == b'\xaa\xaa\x03':  # 802.2 SNAP: dsap ssap ctl oui(3) pid(2) + awdl hdr
        # aa aa 03 | 00 17 f2 | 08 00 | 03 04 | seq(2) | 00 00 | 86 dd
        if frame[17:22] != adv.APPLE_OUI + adv.AWDL_PROTO or frame[28:30] != b'\x86\xdd':
            return None
        off = 30
    else:
        return None
    ip6 = frame[off:off + 40]
    if len(ip6) < 40 or ip6[6] != 17:
        return None
    udp = frame[off + 40:off + 48]
    if len(udp) < 8 or struct.unpack('!H', udp[2:4])[0] != 5353:
        return None
    return src, frame[off + 48:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--iface', default='awdl0')
    ap.add_argument('--port', type=int, default=8771)
    ap.add_argument('--flags', type=int, default=0x88)
    ap.add_argument('--host', default=f'{ident.awdl_host()}.local')
    ap.add_argument('--service-id', default=None)
    ap.add_argument('--min-gap', type=float, default=0.1, help='seconds between replies')
    ap.add_argument('--burst', type=int, default=5, help='frames per reply (multicast air fate is 25-50%%)')
    a = ap.parse_args()

    mac = bytes.fromhex(open(f'/sys/class/net/{a.iface}/address').read().strip().replace(':', ''))
    sid = a.service_id or mac.hex()
    ll = adv.eui64_ll(mac)
    dst6 = socket.inet_pton(socket.AF_INET6, 'ff02::fb')
    # The observed queries were type 1 (A). We have no A record; RFC 6762 6.1 says answer
    # a query for a name we own but a type we lack with an NSEC naming the types
    # we do have (AAAA=28, NSEC=47), so the querier stops waiting for an A.
    msg = adv.announcement(sid, a.host, a.port, a.flags, ll)
    nsec = adv.rr(a.host, 47, adv.CACHE_FLUSH, 120, adv.dname(a.host) + b'\x00\x06' + bytes([0, 0, 0, 0x08, 0, 0x01]))
    ancount = struct.unpack('!H', msg[6:8])[0] + 1
    msg = msg[:6] + struct.pack('!H', ancount) + msg[8:] + nsec
    payload = adv.udp6(ll, dst6, msg)
    ours = {a.host.lower().rstrip('.'), '_airdrop._tcp.local', f'{sid}._airdrop._tcp.local'.lower()}

    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(ETH_P_ALL))
    s.bind((a.iface, 0))
    print(f'{time.time():.3f} responding on {a.iface} for {sorted(ours)} -> {socket.inet_ntop(socket.AF_INET6, ll)}:{a.port}', flush=True)
    seq = 0x4000
    last = 0.0
    replies = 0
    while True:
        frame = s.recv(4096)
        got = mdns_payload(frame)
        if not got:
            continue
        src, dns = got
        if src == mac:
            continue
        hit = [q for q in questions(dns) if q in ours]
        if not hit:
            continue
        now = time.time()
        if now - last < a.min_gap:
            continue
        # Burst of 5 at 20 ms, as the announcer does: our multicast reaches the
        # air 25-50% of the time (frames outside our active slots are dropped),
        # and single replies changed nothing in the peer's query rate.
        try:
            for i in range(a.burst):
                s.send(adv.wrap(mac, payload, (seq + i) & 0xffff))
                if i + 1 < a.burst:
                    time.sleep(0.02)
        except OSError as e:
            print(f'{now:.3f} send error: {e}', flush=True)
            continue
        seq += a.burst
        last = now
        replies += 1
        print(f'{now:.3f} {time.strftime("%H:%M:%SZ", time.gmtime(now))} query from {src.hex(":")} for {hit[0]} -> answered ({replies})', flush=True)


if __name__ == '__main__':
    main()
