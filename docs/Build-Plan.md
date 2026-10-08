# Build plan — existing desktop sessions

User explicitly selected existing Codex desktop chats and existing Claude Code terminals, then supplied this repository as delivery location. SDK-created replacement sessions alone do not satisfy that request.

## Requirements and acceptance

| ID | Observable result | Evidence |
|---|---|---|
| FR01 | HTTPS pairing rejects wrong, expired and throttled codes; tokens revocable | backend boundary tests |
| FR02 | Existing sessions have stable, exact target identity | helper readback + tests |
| FR03 | A stale or wrong-target command never reaches another session | backend/AX binding tests |
| FR04 | One landscape control surface, every primary hit target ≥48pt | native MCP hierarchy + touch QA |
| FR05 | State snapshots/event stream preserve permission/unknown/errors | real host integration and SSE tests |
| FR06 | Six layers and configurable controls remain on the same root view | iOS persistence + interaction QA |
| FR07 | Real iPhone microphone dictation makes editable draft; send explicit | native permissions/capture build + real-device gate |
| FR08 | No unauthenticated desktop actions, shell endpoint or TLS trust bypass | tests and independent security review |
| FR09 | Native macOS app starts local host, shows pairing and TCC requirements | build, host process/status readback |
| FR10 | Real iOS↔host pairing and control integration works | simulator/host integration; actual target action when OS consent exists |

## Decisions

Native SwiftUI iOS interface; native macOS companion, a bounded AX helper, Python standard-library HTTPS/SSE host. This avoids introducing a cloud relay or copying provider credentials to the phone. Public CLI/app-server APIs are preferred where they can attach an existing live session. The installed Codex daemon control socket is absent; the existing desktop socket is not assumed to be the public app-server protocol. Generic terminal typing is rejected until the target is proven to be a Claude session, because otherwise text could execute at a shell prompt.

TLS self-signed per-install certificate pinned by the phone through host QR/fingerprint. Runtime private keys, pairing secrets, device tokens, personal session snapshots and Xcode user settings are excluded from public Git. Unsupported capabilities must be visible, never simulated as real actions.

## Waves

1. Protocol and backend authentication/target-binding tests first. Tests run red before implementation.
2. Parent builds host backend; macOS agent builds app/AX helper; iOS agent builds network/pinning/control integration. Files disjoint, contract Shared/Protocol.md fixed.
3. Integrate bundled server/helper and native app, run backend suite, Mac/iOS builds and MCP interaction/network QA.
4. Independent review/security audit, remediate findings and rerun affected tests.
5. Sanitized documentation, current capability matrix, Git delivery and runnable packages. Apple device installation/distribution is reported separately.

The initial projectless directory has no Pulse board or configured remote. The user-provided initially empty repository is used directly; no unrelated repository or team issue is claimed. Tests-first and independent review are retained. This is a new application, not a migration of the user's existing Claude/Codex projects.

## Verify

`python3 -m unittest discover -s Tests -v` from repository root; native host build script; iOS Xcode MCP build/install/run and hierarchy/touch checks; HTTPS pairing/state/actions integration against the actual local host. Live agent mutation is tested only against an explicitly chosen safe target and an actually authorized pending action. TCC and physical microphone/install checks remain separate gates when OS/device consent is needed.
