from pathlib import Path
import hashlib
import secrets
import sys
import tempfile
import threading
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'runtime'))
from lan.client import Client
from lan.common import TransferError, ensure_identity
from lan.service import Node
from lan.trust import TrustStore, paired_proof


class LanPairingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.nodes = []
        self.clients = []
        self.a = self.node('A')
        self.b = self.node('B')

    def node(self, name):
        folder = self.root / name
        folder.mkdir(exist_ok=True)
        node = Node({'name': name, 'directory': str(folder), 'max_receive_percent': 90},
                    ensure_identity(folder / 'identity'), host='127.0.0.1', port=0)
        node.start(5)
        self.nodes.append(node)
        return node

    def client(self, source, target, code=''):
        peer = {'id': target.identity['id'], 'addresses': ['127.0.0.1'],
                'port': target.server.server_port, 'fingerprint': target.identity['fingerprint']}
        client = Client(peer, code, identity=source.identity, timeout=2)
        self.clients.append(client)
        return client

    def tearDown(self):
        for client in self.clients:
            client.close()
        for node in self.nodes:
            node.stop()
        self.temp.cleanup()

    def pair(self, accept=True):
        client = self.client(self.a, self.b, self.b.code)
        result = {}
        def worker():
            try:
                result['peer'] = client.pair('A')
            except BaseException as error:
                result['error'] = error
        thread = threading.Thread(target=worker)
        thread.start()
        deadline = time.monotonic() + 5
        while not self.b.status()['pair_requests'] and time.monotonic() < deadline and thread.is_alive():
            time.sleep(0.01)
        requests = self.b.status()['pair_requests']
        self.assertEqual(len(requests), 1, result)
        self.assertEqual(self.a.trust.public(), [])
        self.assertEqual(self.b.trust.public(), [])
        self.b.decide_pair(requests[0]['id'], accept)
        thread.join(5)
        self.assertFalse(thread.is_alive())
        return result

    def test_pairing_requires_consent_and_saves_both_directions(self):
        self.assertNotIn('error', self.pair())
        for source, target in ((self.a, self.b), (self.b, self.a)):
            client = self.client(source, target)
            client.authenticate()
            self.assertTrue(target.session_valid(client.session))
            row = source.trust.read()[target.identity['id']]
            self.assertEqual(row['fingerprint'], target.identity['fingerprint'])
            self.assertNotIn('secret', source.trust.public()[0])
            self.assertEqual(source.trust.path.stat().st_mode & 0o777, 0o600)

    def test_decline_saves_neither_pc(self):
        result = self.pair(accept=False)
        self.assertIsInstance(result.get('error'), TransferError)
        self.assertEqual(self.a.trust.public(), [])
        self.assertEqual(self.b.trust.public(), [])

    def test_saved_pair_survives_service_restart_and_new_receive_code(self):
        self.assertNotIn('error', self.pair())
        old_code = self.b.code
        self.b.stop()
        self.b = self.node('B')
        self.assertNotEqual(self.b.code, old_code)
        client = self.client(self.a, self.b)
        client.authenticate()
        self.assertTrue(self.b.session_valid(client.session))

    def test_paired_transfer_still_needs_acceptance_and_verifies_file(self):
        self.assertNotIn('error', self.pair())
        for source, target in ((self.a, self.b), (self.b, self.a)):
            client = self.client(source, target)
            client.authenticate()
            data = b'paired transfer payload'
            row = {'name': 'hello.txt', 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
            ticket = client.request('POST', '/v1/offer', {'sender': 'Spoofed name', 'files': [row]}, token=client.session)
            self.assertEqual(ticket['phase'], 'pending')
            self.assertEqual(ticket['sender'], source.config['name'])
            path = f'/v1/transfers/{ticket["id"]}/files/0'
            with self.assertRaisesRegex(TransferError, 'not accepted'):
                client.request('PUT', path, body=data, token=ticket['token'], offset=0)
            target.decide(ticket['id'], True)
            client.request('PUT', path, body=data, token=ticket['token'], offset=0)
            result = client.request('POST', f'/v1/transfers/{ticket["id"]}/commit', token=ticket['token'])
            self.assertEqual((Path(result['folder']) / 'hello.txt').read_bytes(), data)

    def test_forget_revokes_existing_sessions_and_new_connections(self):
        self.assertNotIn('error', self.pair())
        client = self.client(self.a, self.b)
        client.authenticate()
        self.b.forget(self.a.identity['id'])
        self.assertFalse(self.b.session_valid(client.session))
        with self.assertRaisesRegex(TransferError, 'not paired'):
            self.client(self.a, self.b).authenticate()
        self.a.forget(self.b.identity['id'])
        with self.assertRaisesRegex(TransferError, 'Pair this PC'):
            self.client(self.a, self.b)

    def test_discovery_cannot_replace_saved_certificate(self):
        self.assertNotIn('error', self.pair())
        attacker = self.node('Attacker')
        peer = {'id': self.b.identity['id'], 'addresses': ['127.0.0.1'],
                'port': attacker.server.server_port, 'fingerprint': attacker.identity['fingerprint']}
        client = Client(peer, identity=self.a.identity)
        self.clients.append(client)
        with self.assertRaisesRegex(TransferError, 'identity changed'):
            client.authenticate()
        rows = self.a.trust.peers([peer])
        self.assertTrue(rows[0]['identity_changed'])
        self.assertEqual(self.a.trust.read()[self.b.identity['id']]['fingerprint'], self.b.identity['fingerprint'])

    def test_challenge_is_single_use_and_bound_to_direction_and_identities(self):
        self.assertNotIn('error', self.pair())
        nonce = self.b.challenge({'id': self.a.identity['id']})['nonce']
        row = self.b.trust.read()[self.a.identity['id']]
        signature = paired_proof(row['secret'], self.b.identity['fingerprint'], self.a.identity['fingerprint'], nonce, 'request')
        value = {'nonce': nonce, 'proof': signature}
        self.b.authenticate_paired(value)
        with self.assertRaisesRegex(TransferError, 'expired'):
            self.b.authenticate_paired(value)
        fresh = self.b.challenge({'id': self.a.identity['id']})['nonce']
        bad = paired_proof(row['secret'], self.b.identity['fingerprint'], self.a.identity['fingerprint'], fresh, 'response')
        with self.assertRaisesRegex(TransferError, 'failed'):
            self.b.authenticate_paired({'nonce': fresh, 'proof': bad})

    def test_stopped_and_expired_receiving_cannot_authenticate_paired_pc(self):
        self.assertNotIn('error', self.pair())
        self.b.deadline = time.monotonic() - 1
        with self.assertRaisesRegex(TransferError, 'receiving is off'):
            self.client(self.a, self.b).authenticate()

    def test_pairing_expiry_cannot_be_accepted(self):
        client = self.client(self.a, self.b, self.b.code)
        client.authenticate()
        value = {'id': self.a.identity['id'], 'name': 'A', 'fingerprint': self.a.identity['fingerprint'], 'secret': secrets.token_hex(32)}
        request = self.b.request_pair(value, client.session, '127.0.0.1')
        self.b.pair_requests[request['id']]['deadline'] = time.monotonic() - 1
        with self.assertRaisesRegex(TransferError, 'expired'):
            self.b.decide_pair(request['id'], True)
        self.assertEqual(self.b.trust.public(), [])
        self.assertEqual(self.b.status()['pair_requests'], [])

    def test_malformed_pair_authentication_and_unpaired_code_free_client_fail(self):
        with self.assertRaises(TransferError):
            self.client(self.a, self.b)
        with self.assertRaises(TransferError):
            self.b.challenge({'id': []})
        with self.assertRaises(TransferError):
            self.b.authenticate_paired({'nonce': []})

    def test_paired_pc_list_remains_available_without_discovery(self):
        self.assertNotIn('error', self.pair())
        rows = self.a.trust.peers([])
        self.assertTrue(rows[0]['offline'])
        self.assertEqual(rows[0]['id'], self.b.identity['id'])
        self.assertNotIn('secret', rows[0])

    def test_incorrect_saved_secret_cannot_authenticate(self):
        self.assertNotIn('error', self.pair())
        identifier = self.b.identity['id']
        row = self.a.trust.read()[identifier]
        self.a.trust.update(identifier, {**row, 'secret': secrets.token_hex(32)})
        with self.assertRaisesRegex(TransferError, 'authentication failed'):
            self.client(self.a, self.b).authenticate()

    def test_cancelled_pairing_cannot_be_accepted(self):
        client = self.client(self.a, self.b, self.b.code)
        client.authenticate()
        request = client.request('POST', '/v1/pair', {'id': self.a.identity['id'], 'name': 'A',
            'fingerprint': self.a.identity['fingerprint'], 'secret': secrets.token_hex(32)}, token=client.session)
        client.pair_ticket = request['id']
        client.abort()
        with self.assertRaisesRegex(TransferError, 'expired'):
            self.b.decide_pair(request['id'], True)
        self.assertEqual(self.b.trust.public(), [])

    def test_forget_cancels_pending_authenticated_uploads(self):
        self.assertNotIn('error', self.pair())
        client = self.client(self.a, self.b)
        client.authenticate()
        row = {'name': 'hello.txt', 'size': 1, 'sha256': hashlib.sha256(b'a').hexdigest()}
        ticket = client.request('POST', '/v1/offer', {'files': [row]}, token=client.session)
        self.b.decide(ticket['id'], True)
        self.b.forget(self.a.identity['id'])
        self.assertEqual(self.b.jobs[ticket['id']].phase, 'cancelled')
        self.assertIsNone(self.b.jobs[ticket['id']].stage)
