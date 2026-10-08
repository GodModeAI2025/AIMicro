#!/usr/bin/env python3
"""Local TLS host. No third-party runtime dependencies, no cloud relay."""
import argparse
import fcntl
import hashlib
import http.server
import ipaddress
import json
import os
import pathlib
import socket
import ssl
import subprocess
import sys
import threading
import time
import urllib.parse

from host_core import APIError, AuthStore, ActionRouter, write_private_json


ACTION_TITLES = {
    "focus": "Fenster fokussieren", "inspect": "Sitzung prüfen", "select": "Sitzung wählen",
    "send": "Senden", "stop": "Unterbrechen", "approve": "Freigeben", "decline": "Ablehnen",
    "new_chat": "Neuer Chat", "fork": "Abzweigen", "toggle_fast": "Fast-Modus",
    "toggle_plan": "Plan-Modus", "history_back": "Zurück", "history_forward": "Vorwärts",
    "toggle_sidebar": "Seitenleiste", "composer_previous": "Composer zurück",
    "composer_next": "Composer weiter", "composer_select": "Composer auswählen",
    "composer_cancel": "Composer abbrechen", "reasoning_decrease": "Reasoning reduzieren",
    "reasoning_increase": "Reasoning erhöhen", "reasoning_select": "Reasoning wählen",
    "conversation_previous": "Gespräch hoch", "conversation_next": "Gespräch runter",
    "conversation_latest": "Neueste Nachricht", "open_settings": "Einstellungen",
    "open_browser": "Browser", "open_terminal": "Terminal", "review": "Änderungen prüfen",
    "git_commit": "Git Commit", "git_push": "Git Push", "pr_create": "Pull Request",
    "attach_file": "Datei anhängen", "attach_photo": "Foto anhängen", "plugins": "Plugins",
    "schedules": "Geplante Aufgaben", "skill": "Skill ausführen", "voice_chat": "Sprachdialog",
    "mute": "Mikrofon stumm", "custom_shortcut": "Eigener Shortcut",
}


def host_addresses():
    addresses = []
    for interface in ("en0", "en1", "en2"):
        try:
            result = subprocess.run(["/usr/sbin/ipconfig", "getifaddr", interface], capture_output=True, text=True, timeout=2)
            value = result.stdout.strip()
            if value and not ipaddress.ip_address(value).is_loopback:
                addresses.append(value)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
    return list(dict.fromkeys(addresses)) or ["127.0.0.1"]


def certificate(state_dir):
    cert, key = state_dir / "host.pem", state_dir / "host.key"
    if not cert.exists() or not key.exists():
        temporary_key = state_dir / "host-new.key"
        temporary_cert = state_dir / "host-new.pem"
        subprocess.run(["/usr/bin/openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes",
            "-days", "3650", "-subj", "/CN=AIMicro Local Host", "-keyout", str(temporary_key),
            "-out", str(temporary_cert)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        os.chmod(temporary_key, 0o600)
        os.chmod(temporary_cert, 0o600)
        temporary_key.replace(key)
        temporary_cert.replace(cert)
    pem = cert.read_text()
    digest = hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()
    return cert, key, digest


class Host:
    def __init__(self, state_dir, helper, config_file, port):
        self.state_dir, self.helper, self.config_file, self.port = state_dir, helper, config_file, port
        self.auth = AuthStore(state_dir)
        self.host_name = socket.gethostname().split(".")[0]
        self.lock = threading.RLock()
        self.revision = 1
        self.last_signature = None
        self.cached = None
        self.cached_at = 0
        self.cert, self.key, self.fingerprint = certificate(state_dir)
        self.router = ActionRouter(self.snapshot, self.helper_call, self.auth.execution_guard)
        self.closed = threading.Event()

    def helper_call(self, payload):
        if not self.helper or not pathlib.Path(self.helper).is_file():
            return {"trusted": False, "sessions": [], "error": "adapterUnavailable", "ok": False}
        try:
            result = subprocess.run([self.helper], input=json.dumps(payload) + "\n", capture_output=True,
                text=True, timeout=10, check=False)
            lines = result.stdout.strip().splitlines()
            if result.returncode != 0 or not lines:
                return {"trusted": False, "sessions": [], "error": "adapterFailed", "ok": False}
            return json.loads(lines[-1])
        except (OSError, ValueError, subprocess.TimeoutExpired):
            return {"trusted": False, "sessions": [], "error": "adapterFailed", "ok": False}

    def snapshot(self, refresh=False):
        with self.lock:
            if self.cached is not None and not refresh and time.monotonic() - self.cached_at < 0.75:
                return self.cached
            raw = self.helper_call({"command": "snapshot"})
            trusted = bool(raw.get("trusted", False))
            sessions = []
            for source in raw.get("sessions", [])[:100]:
                if not isinstance(source, dict) or not source.get("id"):
                    continue
                # Generic terminal windows are never inferred to be Claude Code.
                if source.get("provider") in ("claude", "codex") and not source.get("providerProven", False):
                    continue
                item = {key: source.get(key) for key in ("id", "provider", "title", "selected", "chatTitle")}
                item["title"] = str(item.get("title") or "Unbenannte Sitzung")[:256]
                item["status"] = source.get("status", "unknown")
                if item["status"] not in ("idle", "running", "needsInput", "error", "unassigned", "unknown"):
                    item["status"] = "unknown"
                item["unread"] = bool(source.get("unread", False))
                item["capabilities"] = source.get("capabilities", []) if trusted else []
                item["approval"] = source.get("approval")
                item["commands"] = source.get("commands", [])
                sessions.append(item)
            issues = []
            if not trusted:
                issues.append({"code": raw.get("error", "accessibilityPermissionRequired"),
                    "message": "Bedienungshilfen für AIMicro Host auf dem Mac freigeben."})
            if trusted and not sessions:
                issues.append({"code": "noProvenSessions", "message": "Keine nachgewiesene Codex-/Claude-Sitzung verfügbar."})
            if raw.get("automationRequired"):
                issues.append({"code": "automationPermissionRequired", "message": "Automation für Terminal/iTerm auf dem Mac freigeben."})
            registry = [{"id": key, "title": title, "requiresSession": True} for key, title in ACTION_TITLES.items()]
            known = {item["id"] for item in registry}
            for session in sessions:
                for command in session.get("commands", []):
                    identifier = "menu:" + str(command.get("id", ""))
                    if identifier != "menu:" and identifier not in known:
                        registry.append({"id": identifier, "title": str(command.get("label", identifier)), "requiresSession": True})
                        known.add(identifier)
            state = {"version": 1, "hostId": self.auth.host_id, "hostName": self.host_name,
                "connected": True, "accessibilityTrusted": trusted, "sessions": sessions,
                "actions": registry,
                "issues": issues}
            signature = hashlib.sha256(json.dumps(state, sort_keys=True).encode()).hexdigest()
            if self.last_signature is not None and self.last_signature != signature:
                self.revision += 1
            self.last_signature = signature
            state["revision"] = self.revision
            self.cached, self.cached_at = state, time.monotonic()
            self.write_config(trusted)
            return state

    def write_config(self, trusted=None):
        base_url = "https://%s:%d" % (host_addresses()[0], self.port)
        qr = "aimicro://pair?" + urllib.parse.urlencode({"url": base_url,
            "fingerprint": self.fingerprint, "code": self.auth.pairing_code})
        write_private_json(self.config_file, {"pairingURL": qr, "baseURL": base_url,
            "fingerprint": self.fingerprint, "pairingCode": self.auth.pairing_code,
            "expiresAt": self.auth.expires_at, "hostId": self.auth.host_id, "port": self.port,
            "processId": os.getpid(),
            "accessibilityTrusted": bool(trusted), "deviceCount": self.auth.device_count})

    def housekeeping(self):
        while not self.closed.wait(2):
            revoke_file = self.state_dir / "revoke.json"
            if revoke_file.exists():
                try:
                    command = json.loads(revoke_file.read_text())
                    if command.get("revokeAll") is True:
                        self.auth.revoke_all()
                except (ValueError, OSError):
                    pass
                try:
                    revoke_file.unlink()
                except OSError:
                    pass
            if time.time() > self.auth.expires_at:
                self.auth.rotate_pairing()
            self.snapshot(refresh=True)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        # HTTP logging could expose tokens/QR/user text. No request log.
        pass

    def setup(self):
        super().setup()
        self.connection.settimeout(20)

    @property
    def host(self):
        return self.server.host

    def send_json(self, status, data):
        payload = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def identity(self):
        value = self.headers.get("Authorization", "")
        token = value[7:] if value.startswith("Bearer ") else None
        identity = self.host.auth.authenticate(token)
        if not identity:
            raise APIError(401, "unauthorized", "Gerät ist nicht gekoppelt oder wurde widerrufen.")
        return token, identity

    def body(self):
        if self.headers.get("Transfer-Encoding"):
            raise APIError(400, "unsupportedTransferEncoding")
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            raise APIError(400, "invalidContentLength")
        if size <= 0 or size > 40000:
            raise APIError(413, "bodyTooLarge")
        try:
            data = json.loads(self.rfile.read(size))
        except (ValueError, UnicodeError):
            raise APIError(400, "invalidJSON")
        if not isinstance(data, dict):
            raise APIError(400, "invalidJSON")
        return data

    def do_GET(self):
        try:
            if self.path == "/v1/health":
                self.send_json(200, {"version": 1, "pairingRequired": True})
                return
            token, identity = self.identity()
            if self.path == "/v1/state":
                self.send_json(200, self.host.snapshot())
            elif self.path == "/v1/events":
                self.events(token)
            else:
                raise APIError(404, "notFound")
        except APIError as error:
            self.send_json(error.status, {"ok": False, "code": error.code, "message": str(error)})
        except (BrokenPipeError, ConnectionResetError, TimeoutError, OSError):
            self.close_connection = True

    def events(self, token):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        last = None
        while not self.host.closed.is_set() and self.host.auth.authenticate(token):
            state = self.host.snapshot()
            if state["revision"] != last:
                data = "event: state\ndata: " + json.dumps(state) + "\n\n"
                last = state["revision"]
            else:
                data = ": heartbeat\n\n"
            self.wfile.write(data.encode())
            self.wfile.flush()
            self.host.closed.wait(1)

    def do_POST(self):
        try:
            if self.path == "/v1/pair":
                data = self.body()
                result = self.host.auth.pair(data.get("code"), data.get("deviceName"), self.client_address[0])
                result["hostName"] = self.host.host_name
                self.host.write_config(self.host.snapshot().get("accessibilityTrusted"))
                self.send_json(200, result)
                return
            token, identity = self.identity()
            if self.path == "/v1/actions":
                result = self.host.router.dispatch(self.body(), identity)
                self.host.cached_at = 0
                self.send_json(200, result)
            elif self.path == "/v1/unpair":
                self.host.auth.revoke(token)
                self.host.write_config(self.host.snapshot().get("accessibilityTrusted"))
                self.send_json(200, {"ok": True})
            else:
                raise APIError(404, "notFound")
        except APIError as error:
            self.close_connection = True
            self.send_json(error.status, {"ok": False, "code": error.code, "message": str(error)})
        except (BrokenPipeError, ConnectionResetError, TimeoutError, OSError):
            self.close_connection = True


class TLSServer(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 16

    def __init__(self, *args, **kwargs):
        self.slots = threading.BoundedSemaphore(32)
        super().__init__(*args, **kwargs)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            request.close()
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        secured = None
        try:
            request.settimeout(5)
            secured = self.tls_context.wrap_socket(request, server_side=True, do_handshake_on_connect=False)
            secured.do_handshake()
            secured.settimeout(20)
            self.finish_request(secured, client_address)
        except (ssl.SSLError, OSError, TimeoutError):
            pass
        finally:
            self.shutdown_request(secured if secured is not None else request)
            self.slots.release()


def main():
    default_state = pathlib.Path.home() / "Library" / "Application Support" / "AIMicro"
    parser = argparse.ArgumentParser()
    parser.add_argument("--state-dir", default=os.environ.get("MICRO_REMOTE_STATE_DIR", str(default_state)))
    parser.add_argument("--port", type=int, default=int(os.environ.get("MICRO_REMOTE_PORT", "9443")))
    parser.add_argument("--bind", default=os.environ.get("MICRO_REMOTE_HOST", "0.0.0.0"))
    parser.add_argument("--helper", default=os.environ.get("MICRO_REMOTE_AX_HELPER"))
    args = parser.parse_args()
    state_dir = pathlib.Path(args.state_dir)
    state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(state_dir, 0o700)
    # One owner per credential store prevents pairing/certificate races.
    lock_fd = os.open(str(state_dir / "host.lock"), os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(lock_fd)
        raise SystemExit("AIMicro Host already owns this state directory.")
    config_file = pathlib.Path(os.environ.get("MICRO_REMOTE_CONFIG", str(state_dir / "pairing.json")))
    host = Host(state_dir, args.helper, config_file, args.port)
    server = TLSServer((args.bind, args.port), Handler)
    host.port = server.server_address[1]
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(str(host.cert), str(host.key))
    # Handshakes run in bounded workers; a silent TCP peer cannot block accept().
    server.tls_context = context
    server.host = host
    host.snapshot(refresh=True)
    threading.Thread(target=host.housekeeping, daemon=True).start()
    print("AIMicro Host ready on port %d; private pairing details in local configuration." % host.port, flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        host.closed.set()
        server.server_close()


if __name__ == "__main__":
    main()
