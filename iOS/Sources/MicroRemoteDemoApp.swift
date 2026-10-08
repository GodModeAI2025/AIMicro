import SwiftUI

@main struct AIMicroApp: App {
    var body: some Scene { WindowGroup { RemoteDeck().preferredColorScheme(.dark).statusBarHidden() } }
}
enum DeckOverlay { case none, layers, connection, sessions, actions, edit, draft, approval, bindings }

struct RemoteDeck: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = RemoteModel()
    @State private var speech = SpeechCapture()
    @State private var layer = 0
    @State private var overlay = DeckOverlay.none
    @State private var search = ""
    @State private var approvalState: HostState?
    @State private var approvalSessionID: String?
    @State private var speechLatched = false
    @State private var holdingSpeech = false
    func dialAvailable(_ mode:String)->Bool { switch mode { case "composer": return ["composer_previous","composer_next"].contains(where:model.supports); case "reasoning": return ["reasoning_select","reasoning_increase","reasoning_decrease"].contains(where:model.supports); case "scroll": return ["conversation_previous","conversation_next"].contains(where:model.supports); default:return model.supports(model.profiles[layer].dialUp ?? "") || model.supports(model.profiles[layer].dialDown ?? "") } }
    func dialAction(_ mode:String,value:String)->String { let up = value == "1" || value == "high"; switch mode { case "composer": return up ? "composer_previous" : "composer_next"; case "reasoning": if model.supports("reasoning_select") { return "reasoning_select" }; return up ? "reasoning_increase" : "reasoning_decrease"; case "scroll": return up ? "conversation_previous" : "conversation_next"; default: return up ? model.profiles[layer].dialUp ?? "" : model.profiles[layer].dialDown ?? "" } }
    func reviewApproval() { approvalState = model.state; approvalSessionID = model.selectedID; overlay = .approval }
    func dialPressAction()->String { switch model.profiles[layer].dialMode { case "composer":"composer_select"; case "reasoning":"reasoning_select"; case "scroll":"conversation_latest"; default:model.profiles[layer].dialPress ?? "" } }
    var body: some View {
        GeometryReader { geo in
            VStack(spacing:12) {
                LiveAgentStrip(sessions:model.displayedSessions,selected:model.selectedID,connected:model.connected,focus:{ session in Task { await model.focus(session) } }) { session in Task { await model.select(session) } }
                Group {
                    switch overlay {
                    case .none:
                        HStack(spacing:16) {
                            LiveDirectionPad(profile:model.profiles[layer],supports:model.supports) { action in Task { await model.perform(action) } }
                            LiveContext(model:model,showDraft:{ overlay = .draft },showDetails:{ overlay = .actions },reviewApproval:reviewApproval)
                            LiveDial(mode:model.profiles[layer].dialMode,enabled:dialAvailable(model.profiles[layer].dialMode),press:{ Task { await model.perform(dialPressAction()) } },hold:{ if model.profiles[layer].dialMode == "custom" { Task { await model.perform(model.profiles[layer].dialHold ?? "") } } else { overlay = .edit } }) { value in Task { await model.perform(dialAction(model.profiles[layer].dialMode, value:value),parameters:["value":value]) } }
                        }
                    case .layers:
                        LayerSelection(profiles:model.profiles,choose:{layer = $0; overlay = .none},connection:{overlay = .connection},sessions:{overlay = .sessions},actions:{overlay = .actions},edit:{overlay = .edit})
                    case .connection: ConnectionPanel(model:model)
                    case .bindings: SlotBindingEditor(model:model)
                    case .sessions:
                        VStack(spacing:8) { DeckButton(title:"Sechs Agententasten belegen",icon:"slider.horizontal.3") { overlay = .bindings }
                        ScrollView { LazyVStack(spacing:8) { ForEach(model.state?.sessions ?? []) { session in DeckButton(title:session.title,icon:"terminal") { Task { await model.select(session); overlay = .none } } } } } }
                    case .actions: ActionRegistry(model:model,search:$search,reviewApproval:reviewApproval)
                    case .edit: ProfileEditor(profile:$model.profiles[layer],actions:model.state?.actions ?? [],save:model.saveProfiles)
                    case .approval:
                        if let state = approvalState, let id = approvalSessionID { ApprovalPanel(state:state,sessionID:id,model:model) { overlay = .none } }
                    case .draft:
                        VStack(spacing:8) {
                            TextField("Nachricht an Agent",text:$model.draft,axis:.vertical).font(.system(size:18)).lineLimit(2...3).padding(12).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                            Text(speech.recording ? "Aufnahme läuft · lokale Spracherkennung" : speech.error ?? "Text prüfen. Senden bleibt ausdrücklich.").font(.system(size:13)).foregroundStyle(.secondary)
                        }
                    }
                }.frame(maxHeight:.infinity)
                HStack(spacing:12) {
                    DeckButton(title:overlay == .none ? model.profiles[layer].title : "Zurück",icon:overlay == .none ? "square.stack" : "arrow.uturn.backward") { overlay = overlay == .none ? .layers : .none }
                    Text(speech.recording ? "Aufnahme stoppen" : "Sprechen").font(.system(size:16,weight:.semibold)).frame(maxWidth:.infinity).frame(height:56)
                        .background(speech.recording ? Color.red.opacity(0.3) : Color.mint.opacity(0.16),in:RoundedRectangle(cornerRadius:14))
                        .contentShape(Rectangle())
                        .onTapGesture(count:2) { speechLatched.toggle(); overlay = .draft; if speechLatched { Task { await speech.start() } } else { speech.stop() } }
                        .onLongPressGesture(minimumDuration:0.25,perform:{},onPressingChanged:{ pressed in
                            guard !speechLatched else { return }; holdingSpeech = pressed
                            if pressed { overlay = .draft; Task { await speech.start(); if !holdingSpeech { speech.stop() } } } else { speech.stop() }
                        })
                        .accessibilityLabel("Halten zum Sprechen, doppeltippen für Daueraufnahme")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { overlay = .draft; if speech.recording { speech.stop() } else { Task { await speech.start() } } }
                    DeckButton(title:"Senden",icon:"arrow.up",enabled:model.supports("send") && !model.draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) { speech.stop(); speechLatched = false; Task { await model.perform("send") } }
                }
            }.padding(.horizontal,16).padding(.vertical,12).frame(width:geo.size.width,height:geo.size.height)
                .background(Color(red:0.045,green:0.055,blue:0.07))
                .onAppear { print("LAYOUT viewport=\(geo.size) safeInsets=\(geo.safeAreaInsets)") }
        }.task { model.activate() }.onChange(of:scenePhase) { _,phase in if phase == .active { model.activate() } else { speech.stop(); model.suspend() } }.onChange(of:model.state?.revision) { _,revision in if overlay == .approval && revision != approvalState?.revision { overlay = .none } }.onChange(of:model.selectedID) { _,_ in if overlay == .approval { overlay = .none } }.onChange(of:speech.transcript) { _,value in model.draft = value }
    }
}

struct LiveAgentStrip: View {
    let sessions: [RemoteSession?]; let selected: String?; let connected: Bool; let focus:(RemoteSession)->Void; let choose:(RemoteSession)->Void
    @State private var lastID:String?
    @State private var lastTap = Date.distantPast
    @State private var pending:Task<Void,Never>?
    func tapped(_ session:RemoteSession) {
        let now = Date()
        if lastID == session.id && now.timeIntervalSince(lastTap) <= 0.35 { pending?.cancel(); lastID = nil; focus(session) }
        else { pending?.cancel(); lastID = session.id; lastTap = now; pending = Task { try? await Task.sleep(for:.milliseconds(350)); if !Task.isCancelled { choose(session) } } }
    }
    var body: some View {
        HStack(spacing:8) {
            ForEach(0..<6,id:\.self) { index in
                if index < sessions.count, let item = sessions[index] {
                    Button { tapped(item) } label: {
                        HStack(spacing:5) { Circle().fill(statusColor(connected ? item.status : "unknown")).frame(width:6,height:6); Text(item.title).lineLimit(1).font(.system(size:15,weight:.semibold)) }
                            .frame(maxWidth:.infinity).frame(height:48)
                            .background(selected == item.id ? .white.opacity(0.16) : .white.opacity(0.055),in:RoundedRectangle(cornerRadius:12))
                            .overlay(RoundedRectangle(cornerRadius:12).stroke(selected == item.id ? Color.mint : .clear,lineWidth:1))
                    }.buttonStyle(.plain).accessibilityValue(connected ? item.status : "Verbindung unbekannt")
                } else { Text("—").foregroundStyle(.secondary).frame(maxWidth:.infinity).frame(height:48).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12)) }
            }
        }
    }
    func statusColor(_ status:String)->Color { switch status { case "running":.blue; case "needsInput":.orange; case "error":.red; case "idle":.mint; default:.gray } }
}
struct DeckButton: View {
    let title:String; let icon:String; var enabled = true; let action:()->Void
    var body: some View { Button(action:action) { Label(title,systemImage:icon).font(.system(size:16,weight:.semibold)).lineLimit(1).frame(maxWidth:.infinity).frame(height:56).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.4) }
}
struct LiveContext: View {
    let model:RemoteModel; let showDraft:()->Void; let showDetails:()->Void; let reviewApproval:()->Void
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Text(model.connected ? "\(model.selected?.provider ?? "AIMicro") · \(model.selected?.title ?? model.state?.hostName ?? "Mac")" : "AIMicro · Nicht verbunden").font(.system(size:16,weight:.semibold)).foregroundStyle(.mint).lineLimit(1)
            Text(model.selected?.approval?.title ?? (model.connected ? model.state?.issues.first?.message ?? model.message : model.state == nil ? "Mac koppeln über Layer → Verbindung" : "Status unbekannt · Verbindung prüfen")).font(.system(size:17)).lineLimit(2).frame(maxWidth:.infinity,minHeight:44,alignment:.topLeading)
            HStack(spacing:8) {
                DeckButton(title:"",icon:"checkmark",enabled:model.supports("approve") && model.selected?.approval != nil) { reviewApproval() }.accessibilityLabel("Freigabe vor Bestätigung prüfen")
                DeckButton(title:"",icon:"xmark",enabled:model.supports("decline") && model.selected?.approval != nil) { reviewApproval() }.accessibilityLabel("Aktuelle Anfrage prüfen und ablehnen")
                DeckButton(title:"",icon:"text.alignleft",action:showDetails).accessibilityLabel("Alle Aktionen")
            }
            Button(action:showDraft) { Text("Nachricht bearbeiten").font(.system(size:14)).frame(maxWidth:.infinity).frame(height:48).contentShape(Rectangle()) }.buttonStyle(.plain)
        }.frame(maxWidth:.infinity)
    }
}
struct LiveDirectionPad: View {
    let profile:ControlProfile; let supports:(String)->Bool; let action:(String)->Void
    var body: some View {
        VStack(spacing:4) {
            PadKey(symbol:"chevron.up",enabled:supports(profile.up)) { action(profile.up) }
            HStack(spacing:4) { PadKey(symbol:"chevron.left",enabled:supports(profile.left)) { action(profile.left) }; PadKey(symbol:"scope",enabled:supports("focus")) { action("focus") }; PadKey(symbol:"chevron.right",enabled:supports(profile.right)) { action(profile.right) } }
            PadKey(symbol:"chevron.down",enabled:supports(profile.down)) { action(profile.down) }
        }.frame(width:152,height:152)
    }
}
struct PadKey: View {
    let symbol:String; let enabled:Bool; let action:()->Void
    var body: some View { Button(action:action) { Image(systemName:symbol).font(.system(size:20)).frame(width:48,height:48).background(.white.opacity(0.065),in:RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.35).accessibilityHint(enabled ? "Aktion am ausgewählten Agenten" : "Host bietet diese Belegung nicht an") }
}
struct LiveDial: View {
    let mode:String; let enabled:Bool; let press:()->Void; let hold:()->Void; let change:(String)->Void
    @State private var value = 50.0
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08),lineWidth:14)
            Circle().trim(from:0.05,to:value / 100 * 0.75 + 0.1).stroke(enabled ? Color.mint : .gray,style:StrokeStyle(lineWidth:4,lineCap:.round)).rotationEffect(.degrees(90))
            VStack(spacing:4) { Image(systemName:"arrow.up.arrow.down").font(.system(size:24)); Text(mode.capitalized).font(.system(size:13)); Text(enabled ? mode == "reasoning" ? (value < 33 ? "low" : value < 66 ? "medium" : "high") : "Ziehen" : "Nicht verfügbar").font(.system(size:11)).foregroundStyle(.secondary) }
        }.frame(width:124,height:124).padding(4).contentShape(Circle()).opacity(enabled ? 1 : 0.5)
            .gesture(DragGesture().onChanged { value = min(100,max(0,50 - $0.translation.height)) }.onEnded { gesture in if enabled { change(mode == "reasoning" ? (value < 33 ? "low" : value < 66 ? "medium" : "high") : (gesture.translation.height < 0 ? "1" : "-1")) } })
            .onTapGesture(perform:press).onLongPressGesture(minimumDuration:0.5,perform:hold)
            .accessibilityElement(children:.ignore).accessibilityLabel("Regler \(mode)").accessibilityValue(enabled ? String(Int(value)) : "Nicht verfügbar")
            .accessibilityAdjustableAction { direction in if enabled { value = min(100,max(0,value + (direction == .increment ? 10 : -10))); change(mode == "reasoning" ? (value < 33 ? "low" : value < 66 ? "medium" : "high") : (direction == .increment ? "1" : "-1")) } }
    }
}

#Preview("AIMicro Small Landscape", traits: .fixedLayout(width:667,height:375)) { RemoteDeck().preferredColorScheme(.dark) }
