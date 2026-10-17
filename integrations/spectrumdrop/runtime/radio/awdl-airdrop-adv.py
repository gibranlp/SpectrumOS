#!/usr/bin/env python3
"""Advertise _airdrop._tcp.local out awdl0 in Apple's AWDL SNAP encapsulation.

WHY THIS EXISTS. Three runs fired SNAP-encapsulated _airdrop._tcp.local
QUERIES and none of them tested anything, because a query needs the right
device to feel like answering. In an AirDrop transfer the RECEIVER advertises
and the SENDER browses, so a Mac that is sending has no reason to reply to us
whatever our encapsulation is. We were asking a question of a device that had
no reason to speak.

So invert it. We advertise; their AirDrop sheet is the oracle. Either this
machine appears on it or it does not. That needs no pcap, does not care which
device is sender or receiver, and is a STRONGER test of the encapsulation than
a query -- their stack has to parse our records well enough to render an entry.

RECORD SHAPE, taken from opendrop's own source rather than from memory
(opendrop/server.py:_init_service, opendrop/config.py:AirDropReceiverFlags):

    PTR   _airdrop._tcp.local        -> <service_id>._airdrop._tcp.local
    SRV   <service_id>._airdrop...   -> 0 0 <port> <host>.local
    TXT   <service_id>._airdrop...   -> flags=<n>
    AAAA  <host>.local               -> our IPv6 link-local

flags defaults to 0x3fb (1019), which is macOS's own default per
sharingd`[SDRapportBrowser defaultSFNodeFlags]. sharingd's
[SDBonjourBrowser removeInvalidNodes:] drops any node that has neither
SUPPORTS_PIPELINING (0x04) nor SUPPORTS_MIXED_TYPES (0x08), so those bits are
not optional if we want to stay in their list.

SECONDARY ORACLE, and the reason to capture anyway. Appearing on the sheet may
additionally require serving the /Discover HTTPS endpoint, which we do not yet
do -- so a no-show is ambiguous. But ANY unicast frame arriving from a peer
after we advertise (a TCP SYN to our port, or an mDNS query for our AAAA)
proves their stack parsed our records, sheet or no sheet. Watch the capture for
traffic addressed to us specifically, not to 33:33:*.

Sent as unsolicited authoritative responses, which is what an mDNS announcement
is. Names are uncompressed; Apple's parser handles that fine and compression
here would buy nothing but bugs.
"""
import argparse, os, socket, struct, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import awdl_identity as ident

APPLE_OUI = b'\x00\x17\xf2'
AWDL_PROTO = b'\x08\x00'
AWDL_MAGIC = b'\x03\x04'
CACHE_FLUSH = 0x8001          # class IN with the cache-flush bit


def eui64_ll(mac):
    b = bytearray(mac)
    b[0] ^= 0x02
    return b'\xfe\x80' + b'\0' * 6 + bytes(b[:3]) + b'\xff\xfe' + bytes(b[3:])


def dname(name):
    out = b''
    for label in name.split('.'):
        if label:
            out += bytes([len(label)]) + label.encode()
    return out + b'\0'


def rr(name, rtype, rclass, ttl, rdata):
    return dname(name) + struct.pack('!HHIH', rtype, rclass, ttl, len(rdata)) + rdata


def csum16(data):
    if len(data) % 2:
        data += b'\0'
    s = sum(struct.unpack(f'!{len(data)//2}H', data))
    while s >> 16:
        s = (s & 0xffff) + (s >> 16)
    return (~s) & 0xffff


def announcement(sid, host, port, flags, ll):
    svc = '_airdrop._tcp.local'
    inst = f'{sid}.{svc}'
    txt = f'flags={flags}'.encode()
    ans = (
        rr(svc,  12, 0x0001,      4500, dname(inst)) +                       # PTR
        rr(inst, 33, CACHE_FLUSH,  120, struct.pack('!HHH', 0, 0, port) + dname(host)) +
        rr(inst, 16, CACHE_FLUSH, 4500, bytes([len(txt)]) + txt) +           # TXT
        rr(host, 28, CACHE_FLUSH,  120, ll)                                  # AAAA
    )
    # QR=1, AA=1. qdcount 0, ancount 4.
    return struct.pack('!HHHHHH', 0, 0x8400, 0, 4, 0, 0) + ans


def udp6(src, dst, payload):
    udp_len = 8 + len(payload)
    pseudo = src + dst + struct.pack('!IHBB', udp_len, 0, 0, 17)
    ck = csum16(pseudo + struct.pack('!HHH', 5353, 5353, udp_len) + b'\0\0' + payload)
    udp = struct.pack('!HHHH', 5353, 5353, udp_len, ck or 0xffff)
    ip6 = struct.pack('!IHBB', 0x60000000, udp_len, 17, 255) + src + dst
    return ip6 + udp + payload


def wrap(mac, payload, seq, snap=True):
    dst = b'\x33\x33\x00\x00\x00\xfb'
    if not snap:
        return dst + mac + b'\x86\xdd' + payload
    body = (b'\xaa\xaa\x03' + APPLE_OUI + AWDL_PROTO + AWDL_MAGIC +
            struct.pack('<H', seq) + b'\x00\x00' + b'\x86\xdd' + payload)
    return dst + mac + struct.pack('!H', len(body)) + body


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--iface', default='awdl0')
    ap.add_argument('--count', type=int, default=20)
    ap.add_argument('--interval', type=float, default=2.0)
    ap.add_argument('--seq', type=int, default=0)
    ap.add_argument('--port', type=int, default=8771)
    ap.add_argument('--flags', type=int, default=0x3fb)
    ap.add_argument('--host', default=f'{ident.awdl_host()}.local')
    ap.add_argument('--service-id', default=None,
                    help='12 hex chars; defaults to the awdl0 MAC')
    ap.add_argument('--plain', action='store_true',
                    help='Ethernet II instead of SNAP -- the negative control')
    ap.add_argument('--dump', action='store_true')
    a = ap.parse_args()

    mac = bytes.fromhex(open(f'/sys/class/net/{a.iface}/address').read().strip().replace(':', ''))
    sid = a.service_id or mac.hex()
    ll = eui64_ll(mac)
    dst6 = socket.inet_pton(socket.AF_INET6, 'ff02::fb')
    payload = udp6(ll, dst6, announcement(sid, a.host, a.port, a.flags, ll))
    kind = 'EthernetII' if a.plain else 'AppleSNAP'

    if a.dump:
        f = wrap(mac, payload, a.seq, snap=not a.plain)
        print(f'{kind} {len(f)}B  {sid}._airdrop._tcp.local -> {a.host}:{a.port} '
              f'flags={a.flags} (0x{a.flags:x})')
        for i in range(0, len(f), 16):
            print(f'  {i:04x}  ' + ' '.join(f'{b:02x}' for b in f[i:i + 16]))
        raise SystemExit(0)

    print(f'{a.iface}: {kind}  advertising {sid}._airdrop._tcp.local '
          f'-> {a.host}:{a.port} flags=0x{a.flags:x} from '
          f'{socket.inet_ntop(socket.AF_INET6, ll)}')

    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW)
    s.bind((a.iface, 0))
    sent = fail = 0
    seq = a.seq
    for i in range(a.count):
        try:
            s.send(wrap(mac, payload, seq & 0xffff, snap=not a.plain))
            sent += 1
        except OSError as e:
            fail += 1
            if fail == 1:
                print(f'  send error: {e}')
        seq += 1
        if i + 1 < a.count:
            time.sleep(a.interval)
    print(f'  sent={sent} failed={fail} next_seq={seq & 0xffff}')


if __name__ == '__main__':
    main()
