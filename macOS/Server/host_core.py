"""Authentication and command boundary. No platform/UI imports in this module."""
import collections
import contextlib
import hashlib
import hmac
import json
import os
import pathlib
import secrets
import threading
import time
import uuid


class APIError(Exception):
    def __init__(self, status, code, message=None):
        super().__init__(message or code)
        self.status, self.code = status, code


def write_private_json(path, value):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = path.with_suffix(path.suffix + ".tmp")
    fd = os.open(str(temporary), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False)
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)


class AuthStore:
    def __init__(self, state_dir, clock=time.time):
        self.path = pathlib.Path(state_dir) / "devices.json"
        self.clock = clock
        self.lock = threading.RLock()
        self.attempts = collections.defaultdict(collections.deque)
        self.global_attempts = collections.deque()
        self.devices = {}
        self.host_id = str(uuid.uuid4())
        if self.path.exists():
            data = json.loads(self.path.read_text())
            self.host_id, self.devices = data["hostId"], data.get("devices", {})
        self.rotate_pairing()
        self._save()

    def _save(self):
        write_private_json(self.path, {"hostId": self.host_id, "devices": self.devices})

    def rotate_pairing(self):
        with self.lock:
            self.pairing_code = "%06d" % secrets.randbelow(1000000)
            self.expires_at = self.clock() + 600

    @property
    def device_count(self):
        with self.lock:
            return len(self.devices)

    def pair(self, code, device_name, address):
        with self.lock:
            now = self.clock()
            for old_address in list(self.attempts):
                if not self.attempts[old_address] or self.attempts[old_address][-1] < now - 60:
                    del self.attempts[old_address]
            attempts = self.attempts[address]
            while attempts and attempts[0] < now - 60:
                attempts.popleft()
            while self.global_attempts and self.global_attempts[0] < now - 600:
                self.global_attempts.popleft()
            if len(attempts) >= 5 or len(self.global_attempts) >= 30:
                raise APIError(429, "pairingThrottled", "Zu viele Kopplungsversuche. Später erneut versuchen.")
            attempts.append(now)
            self.global_attempts.append(now)
            if now > self.expires_at or not isinstance(code, str) or not code.isascii() or not hmac.compare_digest(code, self.pairing_code):
                raise APIError(401, "invalidPairingCode", "Kopplungscode falsch oder abgelaufen.")
            if not isinstance(device_name, str) or not 1 <= len(device_name) <= 128:
                raise APIError(400, "invalidDeviceName")
            try:
                device_name.encode("utf-8")
            except UnicodeEncodeError:
                raise APIError(400, "invalidDeviceName")
            if len(self.devices) >= 16:
                raise APIError(409, "deviceLimit", "Zuerst ein vorhandenes Gerät entkoppeln.")
            token = secrets.token_urlsafe(32)
            digest = hashlib.sha256(token.encode()).hexdigest()
            self.devices[digest] = {"name": device_name, "createdAt": now}
            self._save()
            self.rotate_pairing()
            return {"token": token, "hostId": self.host_id, "expiresAt": None}

    def authenticate(self, token):
        if not isinstance(token, str) or not 20 <= len(token) <= 256:
            return False
        digest = hashlib.sha256(token.encode()).hexdigest()
        with self.lock:
            return digest if digest in self.devices else False

    def revoke(self, token):
        digest = hashlib.sha256((token or "").encode()).hexdigest()
        with self.lock:
            self.devices.pop(digest, None)
            self._save()

    @contextlib.contextmanager
    def execution_guard(self, device_id):
        # Revocation linearizes with command execution, including queued requests.
        with self.lock:
            if device_id not in self.devices:
                raise APIError(401, "deviceRevoked")
            yield

    def revoke_all(self):
        with self.lock:
            self.devices.clear()
            self.rotate_pairing()
            self._save()


class ActionRouter:
    def __init__(self, snapshot, execute, execution_guard=None):
        self.snapshot, self.execute = snapshot, execute
        self.execution_guard = execution_guard or (lambda _: contextlib.nullcontext())
        self.lock = threading.RLock()
        self.completed = collections.OrderedDict()

    def dispatch(self, request, device_id):
        if not isinstance(request, dict):
            raise APIError(400, "invalidCommand")
        identifier = request.get("commandId")
        try:
            uuid.UUID(identifier)
        except (ValueError, TypeError, AttributeError):
            raise APIError(400, "invalidCommandId")
        encoded = json.dumps(request, sort_keys=True, separators=(",", ":"))
        digest = hashlib.sha256(encoded.encode()).hexdigest()
        key = (device_id, identifier)
        with self.lock:
            previous = self.completed.get(key)
            if previous:
                if previous[0] != digest:
                    raise APIError(409, "commandIdReused")
                return previous[1]
            state = self.snapshot()
            if request.get("hostId") != state["hostId"]:
                raise APIError(409, "wrongHost")
            revision = request.get("expectedRevision")
            if type(revision) is not int or revision != state["revision"]:
                raise APIError(409, "staleRevision", "Zustand geändert. Bitte erneut prüfen.")
            if not state.get("accessibilityTrusted"):
                raise APIError(403, "accessibilityPermissionRequired")
            sessions = [s for s in state["sessions"] if s["id"] == request.get("sessionId")]
            if len(sessions) != 1:
                raise APIError(409, "sessionChanged")
            session = sessions[0]
            action = request.get("action")
            if not isinstance(action, str) or action not in session.get("capabilities", []):
                raise APIError(422, "unsupportedAction", "Diese Aktion ist für diese Sitzung nicht verfügbar.")
            if action in ("approve", "decline", "reject"):
                approval = session.get("approval")
                if not approval or request.get("requestId") != approval.get("requestId"):
                    raise APIError(409, "approvalChanged")
            text = request.get("text")
            if isinstance(text, str):
                try:
                    text.encode("utf-8")
                except UnicodeEncodeError:
                    raise APIError(400, "invalidText")
            if action == "send" and (not isinstance(text, str) or not text.strip() or len(text.encode()) > 32000):
                raise APIError(400, "invalidText")
            parameters = request.get("parameters", {})
            if not isinstance(parameters, dict) or len(json.dumps(parameters).encode()) > 4096:
                raise APIError(400, "invalidParameters")
            # Target metadata originates from the current adapter snapshot, never the client.
            payload = {"command": "action", "sessionId": session["id"], "title": session.get("title", ""),
                "chatTitle": session.get("chatTitle", session.get("title", "")), "action": action,
                "text": text, "requestId": request.get("requestId"), "parameters": parameters}
            with self.execution_guard(device_id):
                result = self.execute(payload)
            if not isinstance(result, dict):
                result = {"ok": False, "status": "error", "message": "Ungültige Adapterantwort."}
            result = dict(result)
            result.setdefault("status", "applied" if result.get("ok") else "error")
            result.setdefault("message", result.get("error", "Bestätigt." if result.get("ok") else "Aktion fehlgeschlagen."))
            result["revision"] = state["revision"]
            self.completed[key] = (digest, result)
            while len(self.completed) > 1000:
                self.completed.popitem(last=False)
            return result
