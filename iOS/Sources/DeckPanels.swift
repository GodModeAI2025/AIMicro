import SwiftUI
import AVFoundation

struct LayerSelection: View {
    let profiles:[ControlProfile]; let choose:(Int)->Void
    let connection:()->Void; let sessions:()->Void; let actions:()->Void; let edit:()->Void
    var body: some View {
        ScrollView {
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                ForEach(profiles) { p in DeckButton(title:p.title,icon:"square.stack") { choose(p.id) } }
                DeckButton(title:"Verbindung",icon:"network",action:connection)
                DeckButton(title:"Agenten",icon:"terminal",action:sessions)
                DeckButton(title:"Aktionen",icon:"list.bullet",action:actions)
                DeckButton(title:"Belegung",icon:"slider.horizontal.3",action:edit)
            }
        }
    }
}
struct ConnectionPanel: View {
    let model:RemoteModel
    @State private var payload = ""
    @State private var scanning = false
    @FocusState private var editing:Bool
    var body: some View {
        if scanning {
            ZStack(alignment:.bottom) {
                QRScanner { value in payload = value; scanning = false }
                DeckButton(title:"Scan abbrechen",icon:"xmark") { scanning = false }.padding(8)
            }
        } else {
            ScrollView {
                VStack(alignment:.leading,spacing:8) {
                    Text(model.settings?.url.absoluteString ?? "QR vom Mac scannen oder Payload einsetzen").font(.system(size:15)).lineLimit(1)
                    TextField("aimicro://pair?url=…",text:$payload).focused($editing).submitLabel(.done).onSubmit { editing = false }.textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(size:14)).frame(minHeight:48).padding(.horizontal,12).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                    HStack(spacing:8) {
                        DeckButton(title:"QR scannen",icon:"qrcode.viewfinder") { scanning = true }
                        DeckButton(title:"Koppeln",icon:"lock",enabled:!model.busy && !payload.isEmpty) { let text = payload; payload = ""; Task { await model.pair(text) } }
                        DeckButton(title:"Entkoppeln",icon:"link",enabled:model.settings != nil) { Task { await model.forget() } }
                    }
                    Text(model.message).font(.system(size:13)).foregroundStyle(.secondary)
                    ForEach(model.state?.issues ?? [],id:\.code) { Text($0.message).font(.system(size:13)).foregroundStyle(.orange) }
                }
            }
        }
    }
}
struct ActionRegistry: View {
    let model:RemoteModel; @Binding var search:String; let reviewApproval:()->Void
    var body: some View {
        VStack(spacing:8) {
            TextField("Aktionen suchen",text:$search).padding(.horizontal,12).frame(height:48).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
            ScrollView {
                LazyVStack(spacing:8) {
                    ForEach((model.state?.actions ?? RemoteAction.microRegistry).filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) }) { action in
                        let enabled = model.connected && !model.busy && (!action.requiresSession || model.supports(action.id)) && (!(action.id == "approve" || action.id == "decline") || model.selected?.approval != nil)
                        VStack(alignment:.leading,spacing:2) {
                            DeckButton(title:action.title,icon:"bolt",enabled:enabled) { if action.id == "approve" || action.id == "decline" { reviewApproval() } else { Task { await model.perform(action.id) } } }
                            if !enabled { Text(model.connected ? "Keine passende Capability oder aktuelle Freigabe" : "Host nicht verbunden").font(.system(size:12)).foregroundStyle(.secondary) }
                        }
                    }
                    if model.state == nil { Text("Nach Kopplung werden die tatsächlichen Host-Aktionen geladen.").font(.system(size:15)) }
                }
            }
        }
    }
}
struct ProfileEditor: View {
    @Binding var profile:ControlProfile; let actions:[RemoteAction]; let save:()->Void
    var body: some View {
        ScrollView {
            VStack(spacing:8) {
                TextField("Profilname",text:$profile.title).padding(.horizontal,12).frame(height:48).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                MappingPicker(title:"Oben",value:$profile.up,actions:actions)
                MappingPicker(title:"Unten",value:$profile.down,actions:actions)
                MappingPicker(title:"Links",value:$profile.left,actions:actions)
                MappingPicker(title:"Rechts",value:$profile.right,actions:actions)
                Picker("Reglermodus",selection:$profile.dialMode) { Text("Composer").tag("composer"); Text("Reasoning").tag("reasoning"); Text("Scrollen").tag("scroll"); Text("Custom").tag("custom") }.frame(minHeight:48)
                if profile.dialMode == "custom" {
                    MappingPicker(title:"Regler hoch",value:Binding($profile.dialUp, replacingNilWith:""),actions:actions)
                    MappingPicker(title:"Regler runter",value:Binding($profile.dialDown, replacingNilWith:""),actions:actions)
                    MappingPicker(title:"Regler drücken",value:Binding($profile.dialPress, replacingNilWith:""),actions:actions)
                    MappingPicker(title:"Regler halten",value:Binding($profile.dialHold, replacingNilWith:""),actions:actions)
                }
                DeckButton(title:"Belegung speichern",icon:"checkmark",action:save)
            }
        }
    }
}
struct MappingPicker: View {
    let title:String; @Binding var value:String; let actions:[RemoteAction]
    var body: some View {
        HStack { Text(title); Spacer(); Picker(title,selection:$value) { Text("Nicht belegt").tag(""); if !value.isEmpty && !actions.contains(where:{$0.id == value}) { Text("\(value) · nicht verfügbar").tag(value) }; ForEach(actions) { Text($0.title).tag($0.id) } }.pickerStyle(.menu) }.padding(.horizontal,12).frame(minHeight:48).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:12))
    }
}
struct QRScanner: UIViewControllerRepresentable {
    let found:(String)->Void
    func makeUIViewController(context:Context)->QRController { let controller = QRController(); controller.found = found; return controller }
    func updateUIViewController(_ controller:QRController,context:Context) {}
    static func dismantleUIViewController(_ controller:QRController,coordinator:()) { controller.active = false; controller.runner.stop() }
}
final class QRController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    let runner = CameraRunner()
    var capture: AVCaptureSession { runner.capture }
    var found:((String)->Void)?
    private var layer:AVCaptureVideoPreviewLayer?
    private var delivered = false
    var active = true
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            guard await AVCaptureDevice.requestAccess(for:.video), active, let device = AVCaptureDevice.default(for:.video), let input = try? AVCaptureDeviceInput(device:device), capture.canAddInput(input) else { return }
            capture.addInput(input); let output = AVCaptureMetadataOutput()
            guard capture.canAddOutput(output) else { return }; capture.addOutput(output); output.setMetadataObjectsDelegate(self,queue:.main); output.metadataObjectTypes = [.qr]
            let layer = AVCaptureVideoPreviewLayer(session:capture); layer.videoGravity = .resizeAspectFill; view.layer.addSublayer(layer); self.layer = layer; layer.frame = view.bounds
            // Small local scanning session; no frames are retained or transmitted.
            runner.start()
        }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); layer?.frame = view.bounds }
    func metadataOutput(_ output:AVCaptureMetadataOutput,didOutput metadataObjects:[AVMetadataObject],from connection:AVCaptureConnection) {
        guard !delivered, let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue, (try? PairPayload(value)) != nil else { return }
        delivered = true; runner.stop(); found?(value)
    }
}

final class CameraRunner: @unchecked Sendable {
    let capture = AVCaptureSession()
    private let queue = DispatchQueue(label:"AIMicro.camera")
    func start() { queue.async { self.capture.startRunning() } }
    func stop() { queue.async { self.capture.stopRunning() } }
}

extension Binding where Value == String {
    init(_ source:Binding<String?>, replacingNilWith defaultValue:String) { self.init(get:{source.wrappedValue ?? defaultValue},set:{source.wrappedValue = $0}) }
}
struct ApprovalPanel: View {
    let state:HostState; let sessionID:String; let model:RemoteModel; let close:()->Void
    @State private var reviewed = false
    var body: some View {
        let session = state.sessions.first { $0.id == sessionID }
        VStack(spacing:8) {
            ScrollView { VStack(alignment:.leading,spacing:6) {
                Text("\(session?.provider ?? "") · \(session?.title ?? "")").font(.system(size:16,weight:.semibold))
                Text(session?.approval?.title ?? "Aktuelle Freigabe").font(.system(size:17,weight:.semibold))
                Text(session?.approval?.detail ?? "Keine überprüfbaren Anfragedetails verfügbar. Freigabe bleibt gesperrt.").font(.system(size:16)).textSelection(.enabled)
                if let scope = session?.approval?.scopeHash { Text("Scope: \(scope)").font(.system(size:12,design:.monospaced)) }
            }.frame(maxWidth:.infinity,alignment:.leading) }
            HStack(spacing:8) {
                DeckButton(title:reviewed ? "Geprüft" : "Details geprüft",icon:"eye",enabled:session?.approval?.detail?.isEmpty == false) { reviewed.toggle() }
                DeckButton(title:"Einmal erlauben",icon:"checkmark",enabled:reviewed && model.supports("approve")) { confirm("approve") }
                DeckButton(title:"Ablehnen",icon:"xmark",enabled:model.supports("decline")) { confirm("decline") }
            }
        }
    }
    func confirm(_ action:String) {
        guard let host = model.settings?.hostId, let request = try? ActionBinding.create(state:state,expectedHostID:host,sessionID:sessionID,action:action,text:nil,parameters:[:]) else { return }
        Task { await model.submit(request); close() }
    }
}

struct SlotBindingEditor: View {
    @Bindable var model:RemoteModel
    var body: some View {
        ScrollView {
            VStack(spacing:8) {
                ForEach(0..<6,id: \.self) { index in
                    VStack(alignment:.leading,spacing:4) {
                        HStack { Text("Taste \(index + 1)"); Spacer(); Picker("Bindung",selection:$model.slots[index].mode) { Text("Zuletzt").tag("recent"); Text("Pinned").tag("pinned"); Text("Priorität").tag("priority"); Text("Custom").tag("custom") }.frame(minHeight:48) }
                        if model.slots[index].mode == "custom" { Picker("Sitzung",selection:Binding($model.slots[index].sessionID,replacingNilWith:"")) { Text("Nicht belegt").tag(""); ForEach(model.state?.sessions ?? []) { Text($0.title).tag($0.id) } }.frame(minHeight:48) }
                        if model.slots[index].mode == "pinned", !(model.state?.sessions.contains(where:{$0.pinned != nil}) ?? false) { Text("Host liefert keine Pinned-Information; Taste bleibt unbelegt.").font(.system(size:12)).foregroundStyle(.secondary) }
                    }.padding(.horizontal,12).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
                }
                Text("Zuletzt verwendet Host-Reihenfolge, wenn Aktivitätszeit fehlt. Priorität nutzt gemeldete Freigaben, Fehler und ungelesene Meldungen.").font(.system(size:12)).foregroundStyle(.secondary)
                DeckButton(title:"Tasten speichern",icon:"checkmark",action:model.saveSlots)
            }
        }
    }
}
