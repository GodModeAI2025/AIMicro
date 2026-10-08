import SwiftUI
import AppKit
import Observation
import CoreImage.CIFilterBuiltins

@MainActor @Observable final class HostModel {
 var trusted = AXIsProcessTrusted()
 var running = false
 var pairing = ""
 var status = "Host gestoppt"
 var deviceCount = 0
 var accessibilityTrusted = false
 var automationRequired = false
 var expiresAt = ""
 var launchedAt:Date?
 var process: Process?
 let root = URL(fileURLWithPath:CommandLine.arguments.first ?? "").deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
 var configuration: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/AIMicroHost/pairing.json") }
 func refresh() {
  trusted = AXIsProcessTrusted()
  guard running,let owned=process,owned.isRunning,let launch=launchedAt else {pairing="";deviceCount=0;accessibilityTrusted=false;return}
  guard let attrs=try? FileManager.default.attributesOfItem(atPath:configuration.path),let modified=attrs[.modificationDate] as? Date,modified >= launch else {pairing="";return}
  if let data=try? Data(contentsOf:configuration), let object=try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
   guard let pid=object["processId"] as? Int,pid == Int(owned.processIdentifier),let expiry=object["expiresAt"] as? Double,currentPairing(running:running,ownedPID:Int(owned.processIdentifier),configPID:pid,modified:modified,launched:launch,expires:Date(timeIntervalSince1970:expiry),now:Date()) else {pairing="";status="Host läuft; Kopplung abgelaufen oder Hostnachweis fehlt";return}
   status="HTTPS-Host bereit zur Kopplung"
   deviceCount = object["deviceCount"] as? Int ?? 0
   accessibilityTrusted = object["accessibilityTrusted"] as? Bool ?? false
   automationRequired = object["automationRequired"] as? Bool ?? false
   expiresAt = String(describing:object["expiresAt"] ?? "")
   pairing = object["pairingURL"] as? String ?? object["pairing_url"] as? String ?? ""
  }
 }
 func start() {
  guard !running else {return}
  let bundled=root.appendingPathComponent("Server/server.py")
  let fallback=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("outputs/AIMicro/macOS/Server/server.py")
  let script=FileManager.default.fileExists(atPath:bundled.path) ? bundled : fallback
  guard FileManager.default.fileExists(atPath:script.path) else { status="server.py fehlt im App-Bundle"; return }
  let p=Process(); p.executableURL=URL(fileURLWithPath:"/usr/bin/python3"); p.arguments=[script.path]
  p.environment=ProcessInfo.processInfo.environment.merging(["MICRO_REMOTE_CONFIG":configuration.path,"MICRO_REMOTE_STATE_DIR":configuration.deletingLastPathComponent().path,"MICRO_REMOTE_AX_HELPER":root.appendingPathComponent("Helper/MicroRemoteAX").path]) {_,new in new}
  p.standardOutput=FileHandle.nullDevice; p.standardError=FileHandle.nullDevice
  p.terminationHandler={ [weak self] completed in Task { @MainActor in guard let self,self.process === completed else{return};self.running=false;self.pairing="";self.deviceCount=0;self.status="Host beendet (\(completed.terminationStatus))" } }
  do {launchedAt=Date();pairing="";try p.run(); process=p; running=true; status="Lokaler Host läuft. Kopplungsdaten werden geladen."} catch {status="Host konnte nicht starten: \(error.localizedDescription)"}
 }
 func stop() {process?.terminate(); process=nil;launchedAt=nil; running=false; status="Host gestoppt"; pairing=""}
 func revoke() {
  let file=configuration.deletingLastPathComponent().appendingPathComponent("revoke.json")
  do {try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true);try Data("{\"revokeAll\":true}".utf8).write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);status="Widerruf aller Geräte angefordert"} catch {status="Widerruf fehlgeschlagen"}
 }
 func automationSettings() {NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)}
 func settings() { let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options); NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)}
}
import ApplicationServices
struct QRView: View {
 let value:String
 var body:some View {
  if let image=makeImage() {Image(nsImage:image).interpolation(.none).resizable().scaledToFit().frame(width:180,height:180).padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius:12))}
 }
 func makeImage()->NSImage? {guard !value.isEmpty else{return nil}; let filter=CIFilter.qrCodeGenerator();filter.message=Data(value.utf8); guard let ci=filter.outputImage?.transformed(by:CGAffineTransform(scaleX:8,y:8)),let cg=CIContext().createCGImage(ci,from:ci.extent) else{return nil};return NSImage(cgImage:cg,size:NSSize(width:cg.width,height:cg.height))}
}
struct PermissionView:View {
 let trusted:Bool; let settings:()->Void
 var body:some View {VStack(alignment:.leading,spacing:8){Label(trusted ? "Bedienungshilfen aktiv" : "Bedienungshilfen erforderlich",systemImage:trusted ? "checkmark.shield" : "lock.shield").foregroundStyle(trusted ? .green : .orange);Text("Für vorhandene Codex-Chats muss macOS die Bedienung erlauben. Aktiviere AIMicro Host und gegebenenfalls MicroRemoteAX unter Datenschutz & Sicherheit → Bedienungshilfen.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true);Button("macOS-Einstellungen öffnen",action:settings)}}
}
struct HostView:View {
 let model:HostModel
 var body:some View {VStack(alignment:.leading,spacing:22){HStack{Image(systemName:"iphone.and.arrow.forward").font(.largeTitle);VStack(alignment:.leading){Text("AIMicro Host").font(.title.bold());Text("Vorhandene Sitzungen auf diesem Mac").foregroundStyle(.secondary)}};PermissionView(trusted:model.trusted,settings:model.settings);Button("Automation für Terminal/iTerm prüfen"){model.automationSettings()};Divider();HStack(alignment:.top,spacing:24){QRView(value:model.pairing);VStack(alignment:.leading,spacing:12){Text(model.status).font(.headline);Text("Gekoppelte Geräte: \(model.deviceCount)").font(.callout);Text(model.accessibilityTrusted ? "Sitzungsadapter autorisiert" : "Sitzungsadapter: Bedienungshilfen fehlen").font(.caption).foregroundStyle(.secondary);Text("Claude-Terminals: Automation-Freigabe für Terminal/iTerm und ein nachgewiesener nativer Claude-Prozess erforderlich.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true);if model.pairing.isEmpty{Text("Starte den Host. Der QR-Code erscheint, sobald die HTTPS-Brücke ihre Kopplungsdaten bereitstellt.").foregroundStyle(.secondary)}else{Text("Mit der iPhone-App scannen. Der Code enthält den Kopplungsschlüssel; teile ihn nur mit deinem eigenen iPhone.").foregroundStyle(.secondary);Button("Kopplungslink kopieren"){NSPasteboard.general.clearContents();NSPasteboard.general.setString(model.pairing,forType:.string)}};HStack{Button(model.running ? "Host stoppen" : "Host starten"){if model.running{model.stop()}else{model.start()}}.buttonStyle(.borderedProminent);Button("Aktualisieren"){model.refresh()};Button("Alle Geräte trennen"){model.revoke()}.disabled(!model.running)}}};Spacer();Text("Aktionen werden nur für eindeutig gebundene Sitzungen ausgeführt. Fehlende Rechte oder unklare Ziele sperren die Steuerung.").font(.caption).foregroundStyle(.secondary)}.padding(28).frame(minWidth:580,minHeight:430).task{while !Task.isCancelled{model.refresh();try? await Task.sleep(for:.seconds(2))}}}
}
@main struct MicroRemoteHostApp:App {
 @State private var model=HostModel()
 var body:some Scene {
  WindowGroup {HostView(model:model).onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) {_ in model.stop()}}
  MenuBarExtra("AIMicro",systemImage:"iphone.and.arrow.forward") {
   Button("Host öffnen") {NSApp.activate();NSApp.windows.first?.makeKeyAndOrderFront(nil)}
   Button("Host stoppen") {model.stop()}.disabled(!model.running)
   Divider()
   Button("Beenden") {model.stop();NSApp.terminate(nil)}
  }
 }
}
