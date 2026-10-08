import SwiftUI
import Observation

@MainActor @Observable final class RemoteModel {
    var state: HostState?
    var selectedID: String?
    var connected = false
    var busy = false
    var message = "Mac verbinden"
    var draft = ""
    var profiles = ControlProfile.defaults
    var slots = SlotBinding.defaults
    var displayedSessions:[RemoteSession?] {
        let sessions = state?.sessions ?? []; var used = Set<String>()
        return slots.map { slot in
            let eligible:[RemoteSession]
            switch slot.mode {
            case "custom": eligible = sessions.filter { $0.id == slot.sessionID }
            case "pinned": eligible = sessions.filter { $0.pinned == true }
            case "priority": eligible = sessions.sorted { rank($0) > rank($1) }
            default: eligible = sessions.sorted { ($0.lastActivity ?? 0) > ($1.lastActivity ?? 0) }
            }
            let chosen = eligible.first { !used.contains($0.id) }; if let chosen { used.insert(chosen.id) }; return chosen
        }
    }
    func rank(_ session:RemoteSession)->Int { (session.status == "needsInput" ? 5 : session.status == "error" ? 4 : session.unread ? 3 : session.status == "running" ? 2 : 0) }
    var settings: ConnectionSettings?
    private var token: String?
    private var client: URLSession?
    private var poll: Task<Void,Never>?
    private var generation = 0
    var selected: RemoteSession? { state?.sessions.first { $0.id == selectedID } }
    init() {
        if let data = UserDefaults.standard.data(forKey:"connection"), let s = try? JSONDecoder().decode(ConnectionSettings.self,from:data) { settings = s; token = CredentialStore.read() }
        if let data = UserDefaults.standard.data(forKey:"slots"), let values = try? JSONDecoder().decode([SlotBinding].self,from:data), values.count == 6, values.enumerated().allSatisfy({ $0.element.id == $0.offset }) { slots = values }
        if let data = UserDefaults.standard.data(forKey:"profiles"), let p = try? JSONDecoder().decode([ControlProfile].self,from:data), p.count == 6, p.enumerated().allSatisfy({ $0.element.id == $0.offset }) { profiles = p }
    }
    func saveSlots() { if let data = try? JSONEncoder().encode(slots) { UserDefaults.standard.set(data,forKey:"slots") } }
    func activate() { if let settings { if client == nil { configure(settings) }; if poll == nil { startPolling() } } }
    func suspend() { generation += 1; poll?.cancel(); poll = nil; connected = false }
    func configure(_ s: ConnectionSettings) {
        client?.invalidateAndCancel()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 10
        config.httpShouldSetCookies = false
        client = URLSession(configuration:config,delegate:PinnedSessionDelegate(fingerprint:s.fingerprint,host:s.url.host ?? ""),delegateQueue:nil)
    }
    func pair(_ raw: String) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let p = try PairPayload(raw)
            generation += 1; poll?.cancel(); connected = false
            let provisional = ConnectionSettings(url:p.url,fingerprint:p.fingerprint,hostId:"")
            configure(provisional)
            let result: PairResponse = try await request(path:"/v1/pair",method:"POST",body:try JSONSerialization.data(withJSONObject:["code":p.code,"deviceName":"AIMicro iPhone"]),authorize:false,settings:provisional)
            try CredentialStore.save(result.token)
            token = result.token; settings = ConnectionSettings(url:p.url,fingerprint:p.fingerprint,hostId:result.hostId)
            UserDefaults.standard.set(try JSONEncoder().encode(settings),forKey:"connection")
            message = "Verbunden mit \(result.hostName)"; startPolling()
        } catch { connected = false; message = error.localizedDescription }
    }
    func startPolling() {
        poll?.cancel(); generation += 1; let current = generation
        poll = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }; await self.refresh(generation:current)
                try? await Task.sleep(for:.seconds(1))
            }
        }
    }
    func refresh(generation expected: Int? = nil) async {
        guard settings != nil, token != nil else { connected = false; return }
        do {
            let next: HostState = try await request(path:"/v1/state")
            guard expected == nil || expected == generation else { return }
            guard next.version == 1, next.hostId == settings?.hostId else { throw RemoteError.unavailable("Host-Identität stimmt nicht.") }
            state = next; connected = next.connected
            if !next.sessions.contains(where:{$0.id == selectedID}) { selectedID = next.sessions.first(where:{$0.selected})?.id ?? next.sessions.first?.id }
        } catch { guard expected == nil || expected == generation else { return }; connected = false; message = "Verbindung unterbrochen: \(error.localizedDescription)" }
    }
    func supports(_ action: String) -> Bool { connected && !busy && (selected?.capabilities.contains(action) ?? false) }
    func focus(_ session:RemoteSession) async { selectedID = session.id; await perform("focus") }
    func select(_ session: RemoteSession) async {
        // Binding is explicit and stable; update local selection before submitting the exact ID.
        selectedID = session.id
        if session.capabilities.contains("select") { await perform("select") }
        else if session.capabilities.contains("focus") { await perform("focus") }
    }
    func perform(_ action: String, parameters: [String:String] = [:]) async {
        guard action != "approve" else { message = "Freigabedetails zuerst prüfen"; return }
        guard connected, !busy, let state, let settings, state.hostId == settings.hostId else { message = "Nicht verbunden"; return }
        let request: ActionRequest
        do { request = try ActionBinding.create(state:state,expectedHostID:settings.hostId,sessionID:selectedID,action:action,text:draft,parameters:parameters) }
        catch { message = error.localizedDescription; return }
        await submit(request)
    }
    func submit(_ request:ActionRequest) async {
        guard connected, !busy, request.hostId == settings?.hostId else { message = "Host nicht verbunden"; return }
        busy = true; defer { busy = false }
        do {
            let ack: ActionAck = try await self.request(path:"/v1/actions",method:"POST",body:try JSONEncoder().encode(request))
            message = ack.message
            if ack.ok && request.action == "send" { draft = "" }
            await refresh()
        } catch { message = error.localizedDescription; await refresh() }
    }
    func saveProfiles() { if let data = try? JSONEncoder().encode(profiles) { UserDefaults.standard.set(data,forKey:"profiles") } }
    func forget() async {
        if connected { let _: ActionAck? = try? await request(path:"/v1/unpair",method:"POST",body:Data("{}".utf8)) }
        generation += 1; poll?.cancel(); client?.invalidateAndCancel(); settings = nil; state = nil; token = nil; connected = false; selectedID = nil
        CredentialStore.remove(); UserDefaults.standard.removeObject(forKey:"connection"); message = "Verbindung entfernt"
    }
    private func request<T:Decodable>(path: String,method: String = "GET",body: Data? = nil,authorize: Bool = true,settings override: ConnectionSettings? = nil) async throws -> T {
        guard let s = override ?? settings, let client else { throw RemoteError.unavailable("Mac zuerst koppeln") }
        let url = s.url.appendingPathComponent(path)
        var request = URLRequest(url:url); request.httpMethod = method; request.httpBody = body
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if authorize { guard let token else { throw RemoteError.unavailable("Gerät nicht gekoppelt") }; request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization") }
        let (data,response) = try await client.data(for:request)
        guard let http = response as? HTTPURLResponse else { throw RemoteError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let value = (try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
            throw RemoteError.unavailable((value?["message"] as? String) ?? (value?["error"] as? String) ?? "Host HTTP \(http.statusCode)")
        }
        return try JSONDecoder().decode(T.self,from:data)
    }
}
