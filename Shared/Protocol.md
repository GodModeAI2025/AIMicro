# AIMicro protocol v1

Current direction supersedes this HTTPS/desktop baseline: direct SSH to herdr, not yet implemented. Work stopped at the user request; see [WORK-STATUS.md](../docs/WORK-STATUS.md).
HTTPS only. The iPhone compares SHA-256 of the server leaf certificate with the fingerprint supplied out-of-band by the macOS host's QR code. No universal trust bypass.

QR: `aimicro://pair?url=https%3A%2F%2F192.0.2.1%3A9443&fingerprint=<64hex>&code=<six-digits>`.

- `GET /v1/health`: public `{version:1, pairingRequired:true}`; no personal data.
- `POST /v1/pair`: `{code,deviceName}` → `{token,hostId,hostName,expiresAt:null}`. Code expires after ten minutes; failure rate limited. Device token is opaque and revocable, stored only in iOS Keychain.
- All following requests require `Authorization: Bearer <token>`.
- `GET /v1/state`: full `HostState`.
- `GET /v1/events`: SSE, event `state`, data `HostState`. Reconnect starts with a full snapshot.
- `POST /v1/actions`: `ActionRequest` → `{ok,status,message,revision}`. Invalid revision/request binding returns 409; unavailable actions 422; missing permissions 403. Send text is at most 32000 UTF-8 bytes. No arbitrary shell execution endpoint.
- `POST /v1/unpair`: revokes this device token.

HostState:
```json
{
  "version": 1,
  "hostId": "opaque-stable-id",
  "hostName": "Mac",
  "revision": 1,
  "connected": true,
  "accessibilityTrusted": false,
  "sessions": [{
    "id": "opaque-stable-session-id",
    "provider": "codex",
    "title": "API",
    "selected": false,
    "status": "unknown",
    "unread": false,
    "capabilities": ["focus", "select", "send", "stop"],
    "approval": null
  }],
  "actions": [{"id":"focus","title":"Fokussieren","requiresSession":true}],
  "issues": [{"code":"accessibilityPermissionRequired","message":"Bedienungshilfen auf dem Mac freigeben."}]
}
```

ActionRequest:
```json
{
  "commandId":"unique-UUID",
  "hostId":"opaque-stable-id",
  "sessionId":"opaque-stable-session-id",
  "expectedRevision":1,
  "action":"send",
  "text":"Run the tests",
  "requestId":null,
  "parameters":{}
}
```

States: `idle`, `running`, `needsInput`, `error`, `unassigned`, `unknown`; completion/unread remain independent. Unknown never becomes idle by inference. Sensitive approvals require the actual provider request ID and a matching current request. Commands are deduplicated and failures are never represented as success. A session-capability array is authoritative; the UI disables missing actions with an explanation. TLS/bootstrap/device pairing is independent of provider login.

The macOS helper receives one JSON request on stdin and returns one JSON result on stdout. Snapshot `{command:"snapshot"}` → `{trusted,sessions,apps,error?}`. Action `{command:"action",sessionId,action,text?,requestId?,parameters?}` → `{ok,status,message}`. Helper paths are host controlled, never request parameters. The server performs authentication, target and revision validation before invoking the helper.
