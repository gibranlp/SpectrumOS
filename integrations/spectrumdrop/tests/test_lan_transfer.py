from pathlib import Path
import hashlib
import io
import json
import os
import secrets
import ssl
import sys
import tempfile
import threading
import time
import unittest
import zlib

RUNTIME = Path(__file__).resolve().parents[1] / 'runtime'
sys.path.insert(0, str(RUNTIME))
sys.path.insert(0, str(RUNTIME / 'radio'))
from lan.common import CHUNK, TransferError, ensure_identity, manifest, proof
from lan.client import Client
from lan.service import Node
from dvzip import DVZipReader


class LanTransferTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.downloads = self.root / 'received'
        self.downloads.mkdir()
        self.identity = ensure_identity(self.root / 'identity')
        self.node = Node({'name': 'Receiver', 'directory': str(self.downloads), 'max_receive_percent': 90},
                         self.identity, host='127.0.0.1', port=0)
        self.node.start(5)
        self.peer = {'addresses': ['127.0.0.1'], 'port': self.node.server.server_port,
                     'fingerprint': self.identity['fingerprint']}
        self.clients = []

    def tearDown(self):
        for client in self.clients:
            client.close()
        self.node.stop()
        self.temp.cleanup()

    def client(self, code=None, peer=None):
        client = Client(peer or self.peer, code or self.node.code, timeout=2)
        self.clients.append(client)
        return client

    def offer(self, data=b'example', name='example.txt'):
        client = self.client()
        client.authenticate()
        row = {'name': name, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        job = client.request('POST', '/v1/offer', {'sender': 'Sender', 'files': [row]}, token=client.session)
        client.ticket = job
        return client, job

    def test_authenticated_consent_gates_upload(self):
        client, ticket = self.offer()
        with self.assertRaisesRegex(TransferError, 'not accepted'):
            client.request('PUT', f'/v1/transfers/{ticket["id"]}/files/0', body=b'example', token=ticket['token'], offset=0)
        self.assertEqual(list(self.downloads.iterdir()), [])
        self.node.decide(ticket['id'], False)
        self.assertEqual(client.status()['phase'], 'declined')

    def test_wrong_code_and_certificate_are_rejected(self):
        with self.assertRaisesRegex(TransferError, 'incorrect'):
            self.client('A' * 16).authenticate()
        peer = {**self.peer, 'fingerprint': '0' * 64}
        with self.assertRaisesRegex(TransferError, 'identity changed'):
            self.client(peer=peer).authenticate()

    def test_proof_is_bound_to_certificate_and_direction(self):
        code, nonce = self.node.code, 'a' * 64
        self.assertNotEqual(proof(code, 'a' * 64, nonce, 'request'), proof(code, 'b' * 64, nonce, 'request'))
        self.assertNotEqual(proof(code, 'a' * 64, nonce, 'request'), proof(code, 'a' * 64, nonce, 'response'))

    def test_resume_offset_and_atomic_commit(self):
        payload = secrets.token_bytes(500000)
        client, ticket = self.offer(payload)
        self.node.decide(ticket['id'], True)
        path = f'/v1/transfers/{ticket["id"]}/files/0'
        client.request('PUT', path, body=payload[:12345], token=ticket['token'], offset=0)
        client.close()
        self.assertEqual(client.status()['offsets'], [12345])
        response = client.request('PUT', path, body=b'wrong-offset', token=ticket['token'], offset=0)
        self.assertEqual(response['offset'], 12345)
        client.close()
        client.request('PUT', path, body=payload[12345:], token=ticket['token'], offset=12345)
        self.assertTrue(all(path.name.endswith('.partial') for path in self.downloads.iterdir()))
        final = client.request('POST', f'/v1/transfers/{ticket["id"]}/commit', token=ticket['token'])
        self.assertEqual((Path(final['folder']) / 'example.txt').read_bytes(), payload)
        again = client.request('POST', f'/v1/transfers/{ticket["id"]}/commit', token=ticket['token'])
        self.assertEqual(again['folder'], final['folder'])
        self.assertEqual(len(list(self.downloads.iterdir())), 1)

    def test_bad_checksum_never_publishes_files(self):
        client, ticket = self.offer(b'correct')
        self.node.decide(ticket['id'], True)
        with self.assertRaisesRegex(TransferError, 'checksum'):
            client.request('PUT', f'/v1/transfers/{ticket["id"]}/files/0', body=b'invalid', token=ticket['token'], offset=0)
        self.assertEqual(list(self.downloads.iterdir()), [])
        self.assertEqual(client.status()['phase'], 'failed')

    def test_stop_cancels_partial_transfer(self):
        client, ticket = self.offer()
        self.node.decide(ticket['id'], True)
        self.node.stop()
        self.assertEqual(self.node.jobs[ticket['id']].phase, 'cancelled')
        self.assertEqual(list(self.downloads.iterdir()), [])
        self.assertFalse(self.node.status()['receiving'])
        self.assertEqual(self.node.status()['code'], '')

    def test_sender_streams_multiple_files_with_internal_name_collisions(self):
        source = self.root / 'source'
        source.mkdir()
        paths = []
        for name, data in [('0', b'first'), ('1', secrets.token_bytes(CHUNK + 1024)), ('empty', b'')]:
            path = source / name
            path.write_bytes(data)
            paths.append(str(path))
        client = self.client()
        result = {}
        def sending():
            try:
                result['value'] = client.send(paths, sender='Sender')
            except BaseException as error:
                result['error'] = error
        thread = threading.Thread(target=sending)
        thread.start()
        deadline = time.monotonic() + 5
        while not self.node.jobs and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue(self.node.jobs)
        self.node.decide(next(iter(self.node.jobs)), True)
        thread.join(10)
        self.assertFalse(thread.is_alive())
        if 'error' in result:
            raise result['error']
        final = Path(result['value']['folder'])
        for path in paths:
            self.assertEqual((final / Path(path).name).read_bytes(), Path(path).read_bytes())

    def test_path_traversal_and_duplicate_names_are_rejected(self):
        for name in ['../outside', '/tmp/file', '..', 'a/b', 'a\\b', 'line\nbreak']:
            with self.subTest(name=name), self.assertRaises(TransferError):
                manifest([{'name': name, 'size': 1, 'sha256': 'a' * 64}])
        row = {'name': 'duplicate', 'size': 1, 'sha256': 'a' * 64}
        with self.assertRaises(TransferError):
            manifest([row, row])

    def test_expiry_clears_visibility_and_pending_consent(self):
        client, ticket = self.offer()
        self.node.deadline = time.monotonic() - 1
        self.node.housekeeping()
        self.assertFalse(self.node.status()['receiving'])
        self.assertEqual(self.node.jobs[ticket['id']].phase, 'cancelled')
        self.assertEqual(list(self.downloads.iterdir()), [])

    def test_repeated_offer_is_idempotent(self):
        client=self.client();client.authenticate()
        value={'sender':'Sender','request_id':'a'*32,'files':[{'name':'empty','size':0,'sha256':hashlib.sha256(b'').hexdigest()}]}
        first=client.request('POST','/v1/offer',value,token=client.session)
        second=client.request('POST','/v1/offer',value,token=client.session)
        self.assertEqual(first['id'],second['id']);self.assertEqual(first['token'],second['token'])
        self.assertEqual(len(self.node.jobs),1)

    def test_real_socket_drop_retains_exact_received_offset(self):
        payload=secrets.token_bytes(300000);client,ticket=self.offer(payload)
        self.node.decide(ticket['id'],True)
        path=f'/v1/transfers/{ticket["id"]}/files/0'
        partial=payload[:25000]
        headers=f'PUT {path} HTTP/1.1\r\nHost: localhost\r\nAuthorization: {ticket["token"]}\r\nContent-Length: {len(payload)}\r\nX-SpectrumDrop-Offset: 0\r\n\r\n'.encode()
        client.connection.sock.sendall(headers+partial);client.close()
        deadline=time.monotonic()+3
        while self.node.jobs[ticket['id']].offsets[0]!=len(partial) and time.monotonic()<deadline:time.sleep(0.01)
        self.assertEqual(client.status()['offsets'],[len(partial)])
        client.request('PUT',path,body=payload[len(partial):],token=ticket['token'],offset=len(partial))
        result=client.request('POST',f'/v1/transfers/{ticket["id"]}/commit',token=ticket['token'])
        self.assertEqual((Path(result['folder'])/'example.txt').read_bytes(),payload)

    def test_stalled_upload_can_be_stopped_without_waiting_for_socket_timeout(self):
        client,ticket=self.offer(b'x'*500000);self.node.decide(ticket['id'],True)
        headers=f'PUT /v1/transfers/{ticket["id"]}/files/0 HTTP/1.1\r\nHost: localhost\r\nAuthorization: {ticket["token"]}\r\nContent-Length: 500000\r\nX-SpectrumDrop-Offset: 0\r\n\r\n'.encode()
        client.connection.sock.sendall(headers+b'x'*1000)
        deadline=time.monotonic()+2
        while self.node.jobs[ticket['id']].active_socket is None and time.monotonic()<deadline:time.sleep(0.01)
        self.assertIsNotNone(self.node.jobs[ticket['id']].active_socket)
        started=time.monotonic();self.node.stop();self.assertLess(time.monotonic()-started,2)
        self.assertEqual(list(self.downloads.iterdir()),[])


    def test_lost_offer_upload_and_commit_acknowledgements_do_not_duplicate_files(self):
        from lan.client import NetworkError
        source=self.root/'payload';source.write_bytes(secrets.token_bytes(200000))
        client=self.client();original=client.request;lost=set();result={}
        def interrupted(method,path,*args,**kwargs):
            value=original(method,path,*args,**kwargs)
            stage='offer' if path=='/v1/offer' else 'put' if method=='PUT' else 'commit' if path.endswith('/commit') else ''
            if stage and stage not in lost:
                lost.add(stage);client.close();raise NetworkError('Simulated lost acknowledgement')
            return value
        client.request=interrupted
        def sending():
            try:result['value']=client.send([str(source)])
            except BaseException as error:result['error']=error
        thread=threading.Thread(target=sending);thread.start();deadline=time.monotonic()+5
        while not self.node.jobs and time.monotonic()<deadline:time.sleep(0.01)
        self.assertTrue(self.node.jobs);self.node.decide(next(iter(self.node.jobs)),True)
        thread.join(15);self.assertFalse(thread.is_alive())
        if 'error' in result:raise result['error']
        self.assertEqual(lost,{'offer','put','commit'});self.assertEqual(len(self.node.jobs),1)
        self.assertEqual(len(list(self.downloads.iterdir())),1)
        self.assertEqual((Path(result['value']['folder'])/'payload').read_bytes(),source.read_bytes())

    def test_truncated_disk_file_cannot_be_published(self):
        client,ticket=self.offer(b'correct');self.node.decide(ticket['id'],True)
        client.request('PUT',f'/v1/transfers/{ticket["id"]}/files/0',body=b'correct',token=ticket['token'],offset=0)
        (self.node.jobs[ticket['id']].stage/'data'/'0').write_bytes(b'x')
        with self.assertRaisesRegex(TransferError,'incomplete on disk'):
            client.request('POST',f'/v1/transfers/{ticket["id"]}/commit',token=ticket['token'])
        self.assertEqual(list(self.downloads.iterdir()),[])



class MacStreamingTests(unittest.TestCase):
    def test_mac_upload_preparation_and_wire_stream_use_bounded_memory(self):
        import ast, logging, shutil, tracemalloc, uuid
        from unittest.mock import patch
        import libarchive
        path=RUNTIME/'radio/airdrop-send.py'
        tree=ast.parse(path.read_text());node=next(item for item in tree.body if isinstance(item,ast.ClassDef) and item.name=='AirDropClient')
        namespace={'Path':Path,'os':os,'tempfile':tempfile,'time':time,'uuid':uuid,'DVZipReader':DVZipReader,'shutil':shutil,'log':logging.getLogger('stream-check'),'t':lambda:'test'}
        exec(compile(ast.Module(body=[node],type_ignores=[]),str(path),'exec'),namespace)
        with tempfile.TemporaryDirectory() as directory,patch.dict(os.environ,XDG_CACHE_HOME=directory):
            source=Path(directory)/'payload.bin';block=secrets.token_bytes(65536)
            with source.open('wb') as stream:
                for _ in range(128):stream.write(block)
            client=namespace['AirDropClient'](None,('127.0.0.1',1));observed={}
            def consume(path,body,headers=None):
                digest=hashlib.sha256();count=0
                while data:=body.read(8192):digest.update(data);count+=len(data)
                observed['bytes']=count
                self.assertEqual(headers['Content-Type'],'application/x-dvzip')
                return True,b''
            client.post=consume
            tracemalloc.start()
            try:
                self.assertTrue(client.send_upload([str(source)]))
                peak=tracemalloc.get_traced_memory()[1]
                self.__class__.last_peak=peak
            finally:tracemalloc.stop()
            self.assertGreater(observed['bytes'],source.stat().st_size)
            self.assertLess(peak,4*1024*1024)
            self.assertEqual(list((Path(directory)/'spectrumdrop/send').iterdir()),[])

    def test_stream_matches_existing_dvzip_wire_format(self):
        for payload in [b'', b'hello' * 20000, secrets.token_bytes(200000)]:
            expected = bytearray()
            for start in range(0, len(payload), 65536):
                raw = payload[start:start + 65536]
                compressed = zlib.compress(raw, 6)
                block = compressed if len(compressed) < len(raw) else raw
                header = len(block) if len(compressed) < len(raw) else len(block) | 0x80000000
                expected.extend(header.to_bytes(4, 'big') + block)
            reader = DVZipReader(io.BytesIO(payload))
            chunks = []
            while chunk := reader.read(8192):
                self.assertLessEqual(len(reader.pending), 65540)
                chunks.append(chunk)
            self.assertEqual(b''.join(chunks), bytes(expected))


if __name__ == '__main__':
    unittest.main()
