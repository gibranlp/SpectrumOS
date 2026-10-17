#!/usr/bin/env python3
"""Parse AWDL action frames (from awdl-af-listen) into AirDrop service records.

Input lines: `<epoch> <freq> <sa> <hexbody>` where hexbody starts at the
action-frame category byte (7f 00 17 f2 | awdl fixed header | TLVs; category 127 = vendor-specific), or
`--body <hex>` for one body.  Output: one JSON object per frame that carries
Service Response (TLV 2) or Arpa (TLV 16) records:

  {"ts", "sa", "type" (0 PSF / 3 MIF), "host", "services": {name: {...}}}

Service Response body layout (from a Mac's MIF, 2026-09-03):
  name_len(u16, counts the type byte) | name | type(u8) | data_len(u16) |
  0000 | rdata.  PTR rdata = name; SRV rdata = prio, weight, port (BE) +
  target name; TXT rdata = length-prefixed strings.
Names use AWDL's fixed dictionary for the tail: c0 07 _airdrop._tcp.local,
c0 0a _tcp.local, c0 0b _udp.local, c0 0c local, c0 00 end.  Unknown codes
are rendered as <c0xx>.

  tools/awdl-af-listen awdl0 | tools/awdl-af-parse.py
  tools/awdl-af-parse.py --body 0409...            # one frame
  tools/awdl-af-parse.py --airdrop < af.log        # only peers offering _airdrop._tcp
"""
import json
import struct
import sys

DICT = {0x00: '', 0x07: '_airdrop._tcp.local', 0x0a: '_tcp.local', 0x0b: '_udp.local', 0x0c: 'local'}


def name(b, off):
    """DNS-style labels with AWDL's c0xx dictionary tail; returns (name, next)."""
    labels = []
    while off < len(b):
        l = b[off]
        if l == 0xc0:
            code = b[off + 1]
            tail = DICT.get(code, f'<c0{code:02x}>')
            if tail:
                labels.append(tail)
            return '.'.join(labels), off + 2
        if l == 0:
            return '.'.join(labels), off + 1
        labels.append(b[off + 1:off + 1 + l].decode('utf-8', 'replace'))
        off += 1 + l
    return '.'.join(labels), off


def tlvs(body):
    i = 0
    while i + 3 <= len(body):
        t = body[i]
        l = struct.unpack('<H', body[i + 1:i + 3])[0]
        yield t, body[i + 3:i + 3 + l]
        i += 3 + l


def service_response(v):
    nlen = struct.unpack('<H', v[:2])[0]
    n, _ = name(v, 2)
    off = 2 + nlen - 1              # name_len counts the type byte
    rtype = v[off]
    dlen = struct.unpack('<H', v[off + 1:off + 3])[0]
    rd = v[off + 5:off + 5 + dlen]  # 2 unknown bytes before rdata
    if rtype == 12:
        val = {'ptr': name(rd, 0)[0]}
    elif rtype == 33:
        prio, weight, port = struct.unpack('>HHH', rd[:6])
        val = {'srv': {'port': port, 'target': name(rd, 6)[0]}}
    elif rtype == 16:
        txt, j = [], 0
        while j < len(rd):
            l = rd[j]; txt.append(rd[j + 1:j + 1 + l].decode('utf-8', 'replace')); j += 1 + l
        val = {'txt': txt}
    else:
        val = {f'type{rtype}': rd.hex()}
    return n, val


def parse_body(body):
    if body[:4] != bytes.fromhex('7f0017f2'):
        return None
    hdr = body[4:4 + 12]              # awdl_hdr_t: magic 08, version 10, subtype, reserved, phy_tx(4), target_tx(4)
    if len(hdr) < 12 or hdr[0] != 0x08:
        return None
    rec = {'type': hdr[2], 'host': None, 'services': {}}
    for t, v in tlvs(body[16:]):
        if t == 16 and len(v) > 1:
            rec['host'] = name(v, 1)[0]
        elif t == 2 and len(v) > 5:
            try:
                n, val = service_response(v)
            except (struct.error, IndexError):
                continue
            rec['services'].setdefault(n, {}).update(val)
    return rec


def airdrop_endpoint(rec):
    """The AirDrop receiver identity in a parsed frame, or None."""
    ptr = rec['services'].get('_airdrop._tcp.local', {}).get('ptr')
    if not ptr:
        return None
    inst = rec['services'].get(ptr) or rec['services'].get(f'{ptr}._airdrop._tcp.local', {})
    srv = inst.get('srv', {})
    return {'id': ptr.split('.')[0], 'port': srv.get('port'), 'target': srv.get('target'),
            'txt': inst.get('txt'), 'host': rec['host']}


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--body' in args:
        rec = parse_body(bytes.fromhex(args[args.index('--body') + 1]))
        print(json.dumps(rec, ensure_ascii=False, indent=1)); sys.exit(0)
    only_airdrop = '--airdrop' in args
    for line in sys.stdin:
        parts = line.split()
        if len(parts) < 4:
            continue
        ts, freq, sa, hexbody = parts[:4]
        try:
            rec = parse_body(bytes.fromhex(hexbody))
        except ValueError:
            continue
        if not rec or (not rec['services'] and not rec['host']):
            continue
        out = {'ts': float(ts), 'freq': int(freq), 'sa': sa, **rec}
        if only_airdrop:
            ep = airdrop_endpoint(rec)
            if not ep:
                continue
            out = {'ts': float(ts), 'sa': sa, **ep}
        print(json.dumps(out, ensure_ascii=False)); sys.stdout.flush()
