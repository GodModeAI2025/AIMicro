import Foundation
import CryptoKit
import Security

struct Approval: Codable { let requestId: String; let title: String?; var detail: String? = nil; var scopeHash: String? = nil }
struct RemoteSession: Codable, Identifiable {
    let id: String; let provider: String; let title: String; let selected: Bool
    let status: String; let unread: Bool; let capabilities: [String]; let approval: Approval?
    var pinned: Bool? = nil; var lastActivity: Double? = nil
}
struct RemoteAction: Codable, Identifiable { let id: String; let title: String; let requiresSession: Bool }
struct HostIssue: Codable { let code: String; let message: String }
struct HostState: Codable {
    let version: Int; let hostId: String; let hostName: String; let revision: Int
    let connected: Bool; let accessibilityTrusted: Bool; let sessions: [RemoteSession]
    let actions: [RemoteAction]; let issues: [HostIssue]
}
struct ActionRequest: Codable {
    let commandId: String; let hostId: String; let sessionId: String?
    let expectedRevision: Int; let action: String; let text: String?
    let requestId: String?; let parameters: [String:String]
}
struct ActionAck: Codable { let ok: Bool; let status: String; let message: String; let revision: Int? }
struct PairResponse: Codable { let token: String; let hostId: String; let hostName: String }
struct PairPayload: Equatable {
    let url: URL; let fingerprint: String; let code: String
    init(_ raw: String) throws {
        guard let parts = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)), parts.scheme == "aimicro", parts.host == "pair" else { throw RemoteError.invalidPairing }
        func query(_ name: String) -> String? { let values = parts.queryItems?.filter { $0.name == name }; return values?.count == 1 ? values?.first?.value : nil }
        guard let u = query("url"), let url = URL(string:u), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil, url.path.isEmpty || url.path == "/",
              let fingerprint = query("fingerprint")?.lowercased(), fingerprint.count == 64, fingerprint.allSatisfy({ $0.isHexDigit && $0.isASCII }),
              let code = query("code"), code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw RemoteError.invalidPairing }
        self.url = url; self.fingerprint = fingerprint; self.code = code
    }
}
enum RemoteError: LocalizedError {
    case invalidPairing, unavailable(String), invalidResponse
    var errorDescription: String? { switch self { case .invalidPairing: "Ungültiger QR-Payload: HTTPS, Fingerprint und sechsstelliger Code nötig."; case .unavailable(let text): text; case .invalidResponse: "Ungültige Host-Antwort." } }
}
final class PinnedSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    let fingerprint: String
    let host: String
    init(fingerprint: String, host: String) { self.fingerprint = fingerprint.lowercased(); self.host = host }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
    static func matches(_ certificateData: Data, fingerprint: String) -> Bool {
        SHA256.hash(data: certificateData).map { String(format:"%02x",$0) }.joined() == fingerprint.lowercased()
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == host,
              let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let leaf = chain.first,
              Self.matches(SecCertificateCopyData(leaf) as Data, fingerprint: fingerprint) else {
            completionHandler(.cancelAuthenticationChallenge,nil); return
        }
        // Explicitly trusted only through the exact out-of-band pinned leaf, not arbitrary HTTPS hosts.
        completionHandler(.useCredential, URLCredential(trust:trust))
    }
}
struct ConnectionSettings: Codable { let url: URL; let fingerprint: String; let hostId: String }
struct ControlProfile: Codable, Identifiable {
    var id: Int; var title: String; var up: String; var down: String; var left: String; var right: String; var dialMode: String; var dialPress: String? = nil; var dialHold: String? = nil; var dialUp: String? = nil; var dialDown: String? = nil
    static var defaults: [Self] { ["Steuern","Navigation","Review","Eingabe","Sitzung","Belegung"].enumerated().map { Self(id:$0.offset,title:$0.element,up:$0.offset == 0 ? "toggle_plan" : "conversation_previous",down:$0.offset == 0 ? "toggle_sidebar" : "conversation_next",left:"history_back",right:"history_forward",dialMode:$0.offset == 0 ? "composer" : "scroll") } }
}
struct CredentialStore {
    static let service = "com.aimicro.device"
    static func save(_ token: String) throws {
        remove()
        let status = SecItemAdd([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"token",kSecValueData:Data(token.utf8),kSecAttrAccessible:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary,nil)
        guard status == errSecSuccess else { throw RemoteError.unavailable("Keychain konnte Token nicht speichern (OSStatus \(status)).") }
    }
    static func read() -> String? { var value: CFTypeRef?; let status = SecItemCopyMatching([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"token",kSecReturnData:true,kSecMatchLimit:kSecMatchLimitOne] as CFDictionary,&value); return status == errSecSuccess ? (value as? Data).flatMap { String(data:$0,encoding:.utf8) } : nil }
    static func remove() { SecItemDelete([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"token"] as CFDictionary) }
}

struct ActionBinding {
    static func create(state:HostState,expectedHostID:String,sessionID:String?,action:String,text:String?,parameters:[String:String]) throws -> ActionRequest {
        guard state.connected, state.hostId == expectedHostID else { throw RemoteError.unavailable("Falscher oder getrennter Host") }
        guard let definition = state.actions.first(where:{$0.id == action}) else { throw RemoteError.unavailable("Aktion unbekannt") }
        let matches = state.sessions.filter { $0.id == sessionID }
        let session = matches.count == 1 ? matches.first : nil
        if definition.requiresSession {
            guard let session, session.capabilities.contains(action) else { throw RemoteError.unavailable("Agent oder Capability nicht mehr verfügbar") }
        }
        let approvalAction = action == "approve" || action == "decline"
        guard !approvalAction || session?.approval?.requestId.isEmpty == false else { throw RemoteError.unavailable("Keine aktuelle gebundene Freigabe") }
        guard action != "approve" || session?.approval?.detail?.isEmpty == false else { throw RemoteError.unavailable("Überprüfbare Freigabedetails fehlen") }
        guard action != "send" || (text != nil && !(text?.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ?? true) && (text?.utf8.count ?? 0) <= 32000) else { throw RemoteError.unavailable("Nachricht muss 1 bis 32000 Bytes enthalten") }
        return ActionRequest(commandId:UUID().uuidString,hostId:state.hostId,sessionId:definition.requiresSession ? session?.id : nil,expectedRevision:state.revision,action:action,text:action == "send" ? text : nil,requestId:approvalAction ? session?.approval?.requestId : nil,parameters:parameters)
    }
}

extension RemoteAction {
    static let microRegistry: [RemoteAction] = [
        RemoteAction(id:"focus",title:"Fenster fokussieren",requiresSession:true),
        RemoteAction(id:"inspect",title:"Sitzung prüfen",requiresSession:true),
        RemoteAction(id:"select",title:"Sitzung wählen",requiresSession:true),
        RemoteAction(id:"send",title:"Senden",requiresSession:true),
        RemoteAction(id:"stop",title:"Unterbrechen",requiresSession:true),
        RemoteAction(id:"approve",title:"Freigeben",requiresSession:true),
        RemoteAction(id:"decline",title:"Ablehnen",requiresSession:true),
        RemoteAction(id:"new_chat",title:"Neuer Chat",requiresSession:true),
        RemoteAction(id:"fork",title:"Abzweigen",requiresSession:true),
        RemoteAction(id:"toggle_fast",title:"Fast-Modus",requiresSession:true),
        RemoteAction(id:"toggle_plan",title:"Plan-Modus",requiresSession:true),
        RemoteAction(id:"history_back",title:"Zurück",requiresSession:true),
        RemoteAction(id:"history_forward",title:"Vorwärts",requiresSession:true),
        RemoteAction(id:"toggle_sidebar",title:"Seitenleiste",requiresSession:true),
        RemoteAction(id:"composer_previous",title:"Composer zurück",requiresSession:true),
        RemoteAction(id:"composer_next",title:"Composer weiter",requiresSession:true),
        RemoteAction(id:"composer_select",title:"Composer auswählen",requiresSession:true),
        RemoteAction(id:"composer_cancel",title:"Composer abbrechen",requiresSession:true),
        RemoteAction(id:"reasoning_decrease",title:"Reasoning reduzieren",requiresSession:true),
        RemoteAction(id:"reasoning_increase",title:"Reasoning erhöhen",requiresSession:true),
        RemoteAction(id:"reasoning_select",title:"Reasoning wählen",requiresSession:true),
        RemoteAction(id:"conversation_previous",title:"Gespräch hoch",requiresSession:true),
        RemoteAction(id:"conversation_next",title:"Gespräch runter",requiresSession:true),
        RemoteAction(id:"conversation_latest",title:"Neueste Nachricht",requiresSession:true),
        RemoteAction(id:"open_settings",title:"Einstellungen",requiresSession:true),
        RemoteAction(id:"open_browser",title:"Browser",requiresSession:true),
        RemoteAction(id:"open_terminal",title:"Terminal",requiresSession:true),
        RemoteAction(id:"review",title:"Änderungen prüfen",requiresSession:true),
        RemoteAction(id:"git_commit",title:"Git Commit",requiresSession:true),
        RemoteAction(id:"git_push",title:"Git Push",requiresSession:true),
        RemoteAction(id:"pr_create",title:"Pull Request",requiresSession:true),
        RemoteAction(id:"attach_file",title:"Datei anhängen",requiresSession:true),
        RemoteAction(id:"attach_photo",title:"Foto anhängen",requiresSession:true),
        RemoteAction(id:"plugins",title:"Plugins",requiresSession:true),
        RemoteAction(id:"schedules",title:"Geplante Aufgaben",requiresSession:true),
        RemoteAction(id:"skill",title:"Skill ausführen",requiresSession:true),
        RemoteAction(id:"voice_chat",title:"Sprachdialog",requiresSession:true),
        RemoteAction(id:"mute",title:"Mikrofon stumm",requiresSession:true),
        RemoteAction(id:"custom_shortcut",title:"Eigener Shortcut",requiresSession:true)
    ]
}

struct SlotBinding: Codable, Identifiable {
    var id:Int; var mode:String; var sessionID:String?
    static var defaults:[Self] { (0..<6).map { Self(id:$0,mode:"recent",sessionID:nil) } }
}
