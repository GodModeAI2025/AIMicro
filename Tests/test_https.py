import hashlib
import http.client
import json
import pathlib
import ssl
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "macOS" / "Server"))
from server import Host, Handler, TLSServer


class HTTPSBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = pathlib.Path(cls.tmp.name)
        cls.host = Host(root, None, root / "pairing.json", 0)
        cls.server = TLSServer(("127.0.0.1", 0), Handler)
        cls.host.port = cls.server.server_address[1]
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(str(cls.host.cert), str(cls.host.key))
        cls.server.tls_context = context
        cls.server.host = cls.host
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.host.closed.set()
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)
        cls.tmp.cleanup()

    def connection(self):
        # Trust ONLY this test server's generated certificate; never CERT_NONE.
        context = ssl.create_default_context(cafile=str(self.host.cert))
        context.check_hostname = False  # per-install pinned IP-address transport
        connection = http.client.HTTPSConnection("127.0.0.1", self.host.port, context=context, timeout=5)
        connection.connect()
        self.assertEqual(hashlib.sha256(connection.sock.getpeercert(binary_form=True)).hexdigest(), self.host.fingerprint)
        return connection

    def request(self, path, method="GET", body=None, token=None):
        conn = self.connection()
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        conn.request(method, path, json.dumps(body) if body is not None else None, headers)
        response = conn.getresponse()
        result = response.status, json.loads(response.read())
        conn.close()
        return result

    def pair(self):
        status, result = self.request("/v1/pair", "POST", {"code": self.host.auth.pairing_code, "deviceName": "test phone"})
        self.assertEqual(status, 200)
        return result["token"]

    def test_fr08_https_state_and_actions_require_authentication(self):
        self.assertEqual(self.request("/v1/state")[0], 401)
        self.assertEqual(self.request("/v1/actions", "POST", {})[0], 401)

    def test_fr05_real_https_state_reports_unavailable_adapter(self):
        token = self.pair()
        status, state = self.request("/v1/state", token=token)
        self.assertEqual(status, 200)
        self.assertFalse(state["accessibilityTrusted"])
        self.assertEqual(state["sessions"], [])
        self.assertIn("issues", state)
        self.assertTrue(any(action["id"] == "toggle_fast" for action in state["actions"]))

    def test_fr01_https_revocation_invalidates_token(self):
        token = self.pair()
        self.assertEqual(self.request("/v1/unpair", "POST", token=token)[0], 200)
        self.assertEqual(self.request("/v1/state", token=token)[0], 401)

    def test_fr05_event_stream_begins_with_authoritative_snapshot(self):
        token = self.pair()
        conn = self.connection()
        conn.request("GET", "/v1/events", headers={"Authorization": "Bearer " + token})
        response = conn.getresponse()
        self.assertEqual(response.status, 200)
        self.assertEqual(response.readline().decode().strip(), "event: state")
        line = response.readline().decode()
        self.assertTrue(line.startswith("data: "))
        self.assertEqual(json.loads(line[6:])["hostId"], self.host.auth.host_id)
        conn.close()


if __name__ == "__main__":
    unittest.main()
