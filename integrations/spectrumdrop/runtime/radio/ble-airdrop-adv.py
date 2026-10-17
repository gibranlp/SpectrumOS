#!/usr/bin/env python3
"""Transmit an Apple Continuity AirDrop (type 0x05) BLE advertisement.

WHY. Measured against a Mac with Finder > AirDrop open for 4 min 35 s: it
published no `_airdrop._tcp` in its MIFs until a sender's BLE AirDrop advert
appeared, then published it 1.13 s later. The BLE advert is the gate on a Mac's
AirDrop publication; without one our sender has nothing to browse. This is the
sender-side half: the wake.

WHAT GOES ON AIR. Manufacturer Specific Data, company 0x004C (Apple), value =
one Continuity TLV `05 12 <18 bytes>`. Two arms, read off the air on 09-07:

  A  (OS 26 shape, current Apple devices)  40 xx xx xx | 00 00 00 00 | 03 | 4 x 2-byte hashes | 00
  B  (published Continuity shape, older OS) 00 x8              | 01 | 4 x 2-byte hashes | 00

The three `xx` bytes vary per device; we send zeros. Hashes are truncated
SHA-256 of the sender's contact identifiers; zeros = "no contact match", which
is what a receiver in Everyone mode accepts. Contacts Only cannot match them.

MECHANICS. BlueZ LEAdvertisement1 over D-Bus (bluetoothd owns the controller;
raw HCI would fight it). ManufacturerData is a dict keyed by company id, the
value starts at the TLV type byte -- the company id is NOT in the value.
The advertising address is whatever the adapter uses: public unless bluetoothd
has `Privacy = device`; reported at start so a run's notes carry the truth.

  ble-airdrop-adv.py --arm A --seconds 120 --interval-ms 100
  ble-airdrop-adv.py --type 0x7e --seconds 20   # plumbing smoke, not an AirDrop advert

Prints `<epoch> <HH:MM:SSZ> START|STOP ...` lines (flush) so ble-adv.log lines
up with af.log. Unregisters the advertisement on exit, SIGINT and SIGTERM.
"""
import argparse
import os
import signal
import time

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

from awdl_identity import IdentityError, resolve_identity

APPLE = 0x004C
AD_IFACE = 'org.bluez.LEAdvertisement1'
ADM_IFACE = 'org.bluez.LEAdvertisingManager1'


def payload(arm, tlv_type, hashes, tag):
    h = bytes.fromhex(hashes)
    if len(h) != 8:
        raise SystemExit('--hashes must be 8 bytes (four 2-byte hashes) as hex')
    t = bytes.fromhex(tag)
    if len(t) != 3:
        raise SystemExit('--tag must be 3 bytes as hex')
    if arm == 'A':        # OS 26 shape: 40 <tag> 00000000 03 hashes 00 (the 3 tag bytes rotate with the address on real Macs)
        body = bytes([0x40]) + t + bytes(4) + bytes([0x03]) + h + bytes(1)
    elif arm == 'V2':     # iPhone, Aug 2025 (NetSPI report): 00x8 02 hashes 00
        body = bytes(8) + bytes([0x02]) + h + bytes(1)
    else:                 # published 2019/2020 shape: 00x8 01 hashes 00
        body = bytes(8) + bytes([0x01]) + h + bytes(1)
    assert len(body) == 18
    return bytes([tlv_type, len(body)]) + body

def redact(value):
    """The advert as hex, with the contact-hash bytes masked.

    Every arm puts the four 2-byte hashes at the same place -- body[9:17],
    which is value[11:19] once the TLV type and length are in front -- so one
    slice covers all of them. Shape, arm, version, tag, length and the trailing
    byte stay visible, because those are the diagnostics a capture is compared
    against; the hashes do not, because a 2-byte prefix narrows a phone number
    and this string goes into a log file that outlives the run.

    Zeros are shown as they are: they identify nobody, and seeing them is how
    the old zero-hash behaviour was caught in the first place.
    """
    h = value.hex()
    slots = h[22:38]
    return h if set(slots) == {'0'} else h[:22] + 'xx' * 8 + h[38:]

def default_record():
    """The disk record used only by the explicit research override."""
    import pwd
    uid = os.getuid()
    if uid == 0:
        for var in ('PKEXEC_UID', 'SUDO_UID'):
            value = os.environ.get(var)
            if value and value.isdigit():
                uid = int(value)
                break
    home = pwd.getpwuid(uid).pw_dir
    return os.path.join(home, '.spectrumdrop', 'keys', 'validation_record.cms')


DEFAULT_RECORD = default_record()


def hashes_from_record(record):
    """The four 2-byte contact hashes, derived from our own Apple ID record.

    Zeros mean "no contact match", which only an Everyone-mode receiver
    accepts -- so a wake advert with zeros cannot wake a Contacts Only device,
    and that is the whole reason this exists. The record's
    ValidatedEmailHashes/ValidatedPhoneHashes are full SHA-256 of the
    identifiers Apple verified for this account, and the advert carries the
    first two bytes of each.

    The signature is not checked here: identity publication validates it.
    Accept bytes so a cached record never needs a plaintext disk copy.

    Returns hex, and nothing here ever prints a hash or an identifier: a full
    hash is reversible to a phone number by brute force, and a prefix narrows
    one.
    """
    import plistlib
    import subprocess
    proc = subprocess.run(
        ['openssl', 'cms', '-verify', '-noverify', '-inform', 'DER'],
        input=record, capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(f'cannot read validation record: {proc.stderr.decode(errors="replace").strip()}')
    plist = plistlib.loads(proc.stdout)
    emails = [h.lower()[:4] for h in (plist.get('ValidatedEmailHashes') or []) if isinstance(h, str)]
    phones = [h.lower()[:4] for h in (plist.get('ValidatedPhoneHashes') or []) if isinstance(h, str)]
    if not emails and not phones:
        raise SystemExit('validation record validates no identifiers; nothing to advertise')
    # Slot order follows the genuine advert measured off the air on 2026-09-19
    # (results/ble-cap-.../SHAPE.md): slot 0 email, slot 1 phone, slot 2 the
    # account's Apple ID/DSID hash, slot 3 email. The DSID hash is NOT in the
    # validation record and cannot be derived from it, so slot 2 carries
    # another email instead. That device advertised a rotating 4-of-N subset of
    # its identifiers rather than a fixed tuple, and the wake proven on
    # 2026-09-19 06:30Z needed only a match, not a particular slot -- so the
    # positions here mirror a real advert without claiming the receiver is
    # position-sensitive.
    slots = [emails[0:1], phones[0:1], emails[1:2], emails[2:3]]
    # Spare identifiers of either kind fill any slot left empty, rather than
    # advertising a zero the receiver cannot match.
    spare = [h for h in emails[3:] + phones[1:]]
    out = []
    for slot in slots:
        if slot:
            out.append(slot[0])
        elif spare:
            out.append(spare.pop(0))
        else:
            out.append('0000')
    return ''.join(out), len(emails) + len(phones)



class Advertisement(dbus.service.Object):
    PATH = '/org/omarchy/airdrop/adv0'

    def __init__(self, bus, value, interval_ms, connectable):
        super().__init__(bus, self.PATH)
        self.props = {
            'Type': 'peripheral' if connectable else 'broadcast',
            'ManufacturerData': dbus.Dictionary(
                {dbus.UInt16(APPLE): dbus.Array(value, signature='y')}, signature='qv'),
            'Includes': dbus.Array([], signature='s'),
            'MinInterval': dbus.UInt32(interval_ms),
            'MaxInterval': dbus.UInt32(interval_ms),
        }

    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='ss', out_signature='v')
    def Get(self, iface, name):
        return self.props[name]

    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='s', out_signature='a{sv}')
    def GetAll(self, iface):
        if iface != AD_IFACE:
            raise dbus.exceptions.DBusException('org.freedesktop.DBus.Error.InvalidArgs')
        return self.props

    @dbus.service.method(AD_IFACE, in_signature='', out_signature='')
    def Release(self):
        stamp('RELEASED by bluetoothd')


def stamp(msg):
    now = time.time()
    print(f'{now:.3f} {time.strftime("%H:%M:%SZ", time.gmtime(now))} {msg}', flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--arm', choices=['A', 'V2', 'B'], default='A')
    ap.add_argument('--tag', default=None,
                    help='3 bytes hex for arm A bytes 1-3 (the candidate SenderIdentityAuthTag); default random')
    ap.add_argument('--type', default='0x05', help='Continuity TLV type; 0x05 = AirDrop. Anything else is a plumbing test')
    ap.add_argument('--hashes', default=None,
                    help='four 2-byte contact hashes, hex; overrides the selected identity')
    ap.add_argument('--hashes-from-record', nargs='?', const=DEFAULT_RECORD, default=None,
                    metavar='RECORD',
                    help=f'research override: derive hashes from a disk record (default {DEFAULT_RECORD}). '
                         'Without an override, use the selected identity.')
    ap.add_argument('--seconds', type=int, default=120)
    ap.add_argument('--interval-ms', type=int, default=100)
    ap.add_argument('--broadcast', action='store_true', help='non-connectable (default: connectable, like Apple)')
    ap.add_argument('--adapter', default='hci0')
    a = ap.parse_args()
    if a.hashes and a.hashes_from_record:
        raise SystemExit('--hashes and --hashes-from-record are mutually exclusive')
    identifiers = None
    if a.hashes_from_record:
        if os.path.exists(a.hashes_from_record):
            with open(a.hashes_from_record, 'rb') as record:
                a.hashes, identifiers = hashes_from_record(record.read())
        else:
            # A self-signed machine has no record and cannot do Contacts Only
            # anyway; it can still wake a receiver set to Everyone, so this
            # degrades rather than refusing to advertise.
            stamp(f'no validation record at {a.hashes_from_record}; advertising zero hashes')
    elif a.hashes is None:
        try:
            identity = resolve_identity(create=False)
        except IdentityError as e:
            raise SystemExit(f'identity error: {e}') from None
        if identity.record_data is not None:
            a.hashes, identifiers = hashes_from_record(identity.record_data)
    a.hashes = a.hashes or '00' * 8
    if a.tag is None:
        a.tag = os.urandom(3).hex()

    value = payload(a.arm, int(a.type, 0), a.hashes, a.tag)
    stamp(f'contact hashes: {"record" if identifiers else "zeros"}'
          + (f', {identifiers} identifiers validated, 4 slots filled' if identifiers else
             ' -- a Contacts Only receiver cannot match these'))
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    path = f'/org/bluez/{a.adapter}'
    adapter = bus.get_object('org.bluez', path)
    props = dbus.Interface(adapter, 'org.freedesktop.DBus.Properties')
    if not bool(props.Get('org.bluez.Adapter1', 'Powered')):
        props.Set('org.bluez.Adapter1', 'Powered', dbus.Boolean(True))
    addr = str(props.Get('org.bluez.Adapter1', 'Address'))
    addr_type = str(props.Get('org.bluez.Adapter1', 'AddressType'))
    manager = dbus.Interface(adapter, ADM_IFACE)

    adv = Advertisement(bus, value, a.interval_ms, not a.broadcast)
    loop = GLib.MainLoop()
    state = {'registered': False}

    def stop(*_):
        if state['registered']:
            try:
                manager.UnregisterAdvertisement(adv.PATH)
            except dbus.exceptions.DBusException as e:
                stamp(f'unregister failed: {e}')
            state['registered'] = False
            stamp('STOP advertisement unregistered')
        loop.quit()

    def registered():
        state['registered'] = True
        stamp(f'START arm={a.arm} tag={a.tag} type={a.type} interval_ms={a.interval_ms} '
              f'{"connectable" if not a.broadcast else "non-connectable"} '
              f'adapter_addr={addr} ({addr_type}) mfr=4c00 value={redact(value)}')
        GLib.timeout_add_seconds(a.seconds, lambda: (stop(), False)[1])

    def failed(e):
        stamp(f'REGISTER FAILED {e}')
        loop.quit()

    for sig in (signal.SIGINT, signal.SIGTERM):
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, sig, lambda *_: (stop(), False)[1])
    manager.RegisterAdvertisement(adv.PATH, {}, reply_handler=registered, error_handler=failed)
    loop.run()
    return 0 if not state['registered'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
