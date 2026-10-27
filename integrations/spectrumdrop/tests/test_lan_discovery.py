from pathlib import Path
import secrets
import sys
import time
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'runtime'))
from lan.discovery import Discovery


class LanDiscoveryTests(unittest.TestCase):
    def test_two_loopback_nodes_discover_and_remove_each_other(self):
        first={'id':secrets.token_hex(16),'fingerprint':'a'*64}
        second={'id':secrets.token_hex(16),'fingerprint':'b'*64}
        one=Discovery(first,interfaces=['127.0.0.1'],advertised_addresses=['127.0.0.1'])
        two=Discovery(second,interfaces=['127.0.0.1'],advertised_addresses=['127.0.0.1'])
        try:
            one.advertise('First Spectrum',8857);two.advertise('Second Spectrum',8858)
            deadline=time.monotonic()+8
            while (not one.snapshot() or not two.snapshot()) and time.monotonic()<deadline:time.sleep(0.1)
            self.assertEqual(one.snapshot()[0]['id'],second['id'])
            self.assertEqual(two.snapshot()[0]['id'],first['id'])
            self.assertEqual(one.snapshot()[0]['fingerprint'],second['fingerprint'])
            self.assertEqual(one.snapshot()[0]['port'],8858)
            self.assertEqual(one.snapshot()[0]['addresses'],['127.0.0.1'])
            two.withdraw();deadline=time.monotonic()+5
            while one.snapshot() and time.monotonic()<deadline:time.sleep(0.1)
            self.assertEqual(one.snapshot(),[])
        finally:
            one.close();two.close()


if __name__=='__main__':unittest.main()
