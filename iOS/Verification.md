# Native iOS verification — 8 October 2026

The current AIMicro app is a real HTTPS client, not the earlier local UI demo. Xcode MCP built and installed the application, performed native UI interactions, and ran the final six boundary tests: **6 passed, 0 failed, 0 skipped**. The SwiftUI and device-interaction Apple skills were applied. Standard ad-hoc simulator signing is enabled because unsigned simulator applications cannot use Keychain; physical-device signing remains a separate setup step.

## Real connection evidence

A dedicated iPhone SE 3 simulator connected to the actual local HTTPS host on loopback. A deliberately wrong leaf-certificate fingerprint was rejected before pairing. The correct fingerprint paired successfully, stored its device credential in Keychain, polled the real host snapshot, and displayed the actual missing macOS Accessibility permission. Entkoppeln revoked the test pairing and removed its local credential/settings; the UI reported `Verbindung entfernt`.

The first unsigned simulator attempt reached the real pairing response but failed at Keychain storage. After enabling simulator ad-hoc signing, the full flow succeeded. The backend should discard the orphan fixture device credential from the unsuccessful unsigned run. No test pairing secret, token, fingerprint or private host name is included in delivered screenshots. Connected host screenshots remain private test evidence outside delivery.

## Measured small-phone controls

The current native UI was captured at **667 × 375 points**, with zero safe-area insets on the SE 3. Direction buttons are 48 × 48 points; context buttons 101 × 56; the editable-draft launcher 319 × 48; footer controls approximately 203.5 × 56. The draft launcher was corrected after the hierarchy revealed a smaller intrinsic text hit region. The six unassigned slots are intentionally placeholders while the actual host has no readable sessions. No fabricated agents or successful desktop operations are displayed.

`native-disconnected-small.png` is the public generic control screen. `native-unpaired-small.png` shows the successful cleanup state. `native-layout-small.txt` contains redacted current control bounds. Earlier demo screenshots and the large-phone measurements are historical layout evidence; they do not establish the current live app's larger-device, permission or agent behaviour.

## Implemented client behaviour

- Strict `aimicro://pair` QR parser, camera scanning and manual paste; HTTPS only, SHA-256 pin of the exact leaf certificate, expected host matching, redirects refused, ephemeral HTTP session, credential stored only in Keychain.
- Authoritative host/session IDs, capabilities, revision and approval request bindings; polling fallback at approximately one second; disconnected status remains unknown. Actions show acknowledgement/failure instead of optimistic success.
- Same root interface: six persistent profiles, configurable directions, Composer/Reasoning/Scroll/Custom dial modes, custom rotation/press/hold bindings, hold-to-edit for ordinary dial modes, full searchable action catalogue including dynamic host menu identifiers.
- Six persistent agent-slot bindings support recent, pinned, priority and custom selection. Absent pinned/activity metadata is explained; unavailable sessions remain unassigned. Single tap waits 350 ms before selection; double tap requests focus of the exact ID.
- Approval details and scope are preserved. A scrollable review panel captures the exact host snapshot/session/request/revision; allowing once requires visible details and an explicit review gate. Revision or target changes dismiss the review. Missing details, stale bindings and absent capabilities do not become permission grants.
- Real AVAudioEngine/Speech input requires on-device recognition, produces an editable draft and never sends automatically. Hold and double-tap capture gestures are implemented. Camera, microphone, speech and local-network purpose strings are present.

## Meaningful tests and remaining gates

The six native tests cover malformed/insecure/duplicate pairing inputs, wrong certificate bytes/fingerprints, exact target/revision/request encoding, missing target/capability and oversized text rejection, profile persistence, and approval detail/scope preservation plus absent-request rejection.

The actual Mac helper lacked Accessibility consent during the network test. Existing Codex/Claude session enumeration, real focus/send/stop, authentic provider approvals and complete Codex Micro functional parity were therefore **not verified**. Capability-dependent actions remained disabled. The microphone/camera need physical-iPhone permission and behaviour testing; simulator build is not speech or camera evidence. Large-phone current-client layout, Dynamic Type, VoiceOver traversal, reconnect-after-server-restart and background transitions remain additional checks. No SDK-created replacement sessions, provider credential transfer, release, upload or publication was performed.
