import json
import pathlib
import tempfile
import unittest
import uuid
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "macOS" / "Server"))
from host_core import AuthStore, ActionRouter, APIError


class AuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.now = 1000.0
        self.auth = AuthStore(pathlib.Path(self.tmp.name), clock=lambda: self.now)

    def tearDown(self):
        self.tmp.cleanup()

    def test_fr01_wrong_code_never_creates_device(self):
        with self.assertRaises(APIError) as result:
            self.auth.pair("invalid", "phone", "127.0.0.1")
        self.assertEqual(result.exception.status, 401)
        self.assertEqual(self.auth.device_count, 0)

    def test_fr01_expired_pairing_code_rejected(self):
        code = self.auth.pairing_code
        self.now += 601
        with self.assertRaises(APIError):
            self.auth.pair(code, "phone", "127.0.0.1")

    def test_fr01_failed_attempts_are_rate_limited(self):
        for _ in range(5):
            with self.assertRaises(APIError):
                self.auth.pair("invalid", "phone", "127.0.0.1")
        with self.assertRaises(APIError) as result:
            self.auth.pair(self.auth.pairing_code, "phone", "127.0.0.1")
        self.assertEqual(result.exception.status, 429)

    def test_fr01_token_is_persistent_revocable_and_never_saved_plaintext(self):
        token = self.auth.pair(self.auth.pairing_code, "phone", "127.0.0.1")["token"]
        self.assertTrue(self.auth.authenticate(token))
        persisted = (pathlib.Path(self.tmp.name) / "devices.json").read_text()
        self.assertNotIn(token, persisted)
        reopened = AuthStore(pathlib.Path(self.tmp.name), clock=lambda: self.now)
        self.assertTrue(reopened.authenticate(token))
        reopened.revoke(token)
        self.assertFalse(reopened.authenticate(token))

    def test_fr08_missing_token_rejected(self):
        self.assertFalse(self.auth.authenticate(None))
        self.assertFalse(self.auth.authenticate("not-a-token"))

    def test_non_ascii_pairing_code_is_rejected_cleanly(self):
        with self.assertRaises(APIError) as result:
            self.auth.pair("１２３４５６", "phone", "127.0.0.1")
        self.assertEqual(result.exception.status, 401)

    def test_revoked_device_cannot_execute_previously_authenticated_action(self):
        token = self.auth.pair(self.auth.pairing_code, "phone", "127.0.0.1")["token"]
        identity = self.auth.authenticate(token)
        self.auth.revoke(token)
        calls = []
        state = {"hostId": "h", "revision": 1, "accessibilityTrusted": True,
                 "sessions": [{"id": "s", "capabilities": ["focus"]}]}
        router = ActionRouter(lambda: state, lambda data: calls.append(data), self.auth.execution_guard)
        with self.assertRaises(APIError) as result:
            router.dispatch({"commandId": str(uuid.uuid4()), "hostId": "h", "expectedRevision": 1,
                             "sessionId": "s", "action": "focus"}, identity)
        self.assertEqual(result.exception.status, 401)
        self.assertEqual(calls, [])


class TargetBindingTests(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.state = {
            "hostId": "mac-1", "revision": 7, "accessibilityTrusted": True,
            "sessions": [{"id": "chat-1", "capabilities": ["send", "approve", "focus"],
                "approval": {"requestId": "request-1"}}]
        }
        self.router = ActionRouter(lambda: self.state, self.execute)

    def execute(self, data):
        self.calls.append(data)
        return {"ok": True, "status": "applied", "message": "confirmed"}

    def request(self, **changes):
        result = {"commandId": str(uuid.uuid4()), "hostId": "mac-1", "sessionId": "chat-1",
                  "expectedRevision": 7, "action": "send", "text": "hello"}
        result.update(changes)
        return result

    def test_fr03_wrong_host_never_reaches_helper(self):
        with self.assertRaises(APIError):
            self.router.dispatch(self.request(hostId="other"), "device-1")
        self.assertEqual(self.calls, [])

    def test_fr03_stale_revision_never_reaches_helper(self):
        with self.assertRaises(APIError) as result:
            self.router.dispatch(self.request(expectedRevision=6), "device-1")
        self.assertEqual(result.exception.status, 409)
        self.assertEqual(self.calls, [])

    def test_fr02_unknown_session_never_reaches_helper(self):
        with self.assertRaises(APIError):
            self.router.dispatch(self.request(sessionId="other"), "device-1")
        self.assertEqual(self.calls, [])

    def test_fr03_approval_binds_the_current_request(self):
        with self.assertRaises(APIError):
            self.router.dispatch(self.request(action="approve", requestId="old"), "device-1")
        self.assertEqual(self.calls, [])
        self.router.dispatch(self.request(action="approve", requestId="request-1"), "device-1")
        self.assertEqual(len(self.calls), 1)

    def test_fr08_unsupported_shell_action_never_reaches_helper(self):
        with self.assertRaises(APIError):
            self.router.dispatch(self.request(action="shell", text="rm anything"), "device-1")
        self.assertEqual(self.calls, [])

    def test_fr03_duplicate_action_executes_once(self):
        request = self.request()
        first = self.router.dispatch(request, "device-1")
        second = self.router.dispatch(request, "device-1")
        self.assertEqual(first, second)
        self.assertEqual(len(self.calls), 1)

    def test_fr03_reused_id_with_different_payload_rejected(self):
        request = self.request()
        self.router.dispatch(request, "device-1")
        request["text"] = "different"
        with self.assertRaises(APIError):
            self.router.dispatch(request, "device-1")
        self.assertEqual(len(self.calls), 1)

    def test_fr08_no_permission_never_reaches_helper(self):
        self.state["accessibilityTrusted"] = False
        with self.assertRaises(APIError) as result:
            self.router.dispatch(self.request(), "device-1")
        self.assertEqual(result.exception.status, 403)
        self.assertEqual(self.calls, [])

    def test_fr08_text_is_bounded(self):
        with self.assertRaises(APIError):
            self.router.dispatch(self.request(text="x" * 32001), "device-1")
        self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
