import AppKit
import ApplicationServices
import CryptoKit

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? { var value: CFTypeRef?; guard AXUIElementCopyAttributeValue(e, name as CFString, &value) == .success else { return nil }; return value }
func str(_ e: AXUIElement, _ name: String) -> String { attr(e,name) as? String ?? "" }
func children(_ e: AXUIElement) -> [AXUIElement] { attr(e,kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func nodes(_ e: AXUIElement, depth: Int = 0, budget: inout Int) -> [AXUIElement] { guard depth < 18 && budget > 0 else { return [] }; budget -= 1; return [e] + children(e).flatMap { nodes($0,depth:depth+1,budget:&budget) } }
func digest(_ s: String) -> String { SHA256.hash(data:Data(s.utf8)).map { String(format:"%02x",$0) }.joined() }
func label(_ e: AXUIElement) -> String { [str(e,kAXTitleAttribute),str(e,kAXDescriptionAttribute),str(e,kAXValueAttribute)].first(where: { !$0.isEmpty }) ?? "" }
struct Target { let app: NSRunningApplication; let window: AXUIElement; let title: String; let id: String; let provider: String }
func targets() -> [Target] {
 NSWorkspace.shared.runningApplications.flatMap { app -> [Target] in
  let bundle = app.bundleIdentifier ?? ""; let name = app.localizedName ?? ""
  guard bundle == "com.openai.codex" || ["com.apple.Terminal","com.googlecode.iterm2","com.mitchellh.ghostty"].contains(bundle) else { return [] }
  let windows = attr(AXUIElementCreateApplication(app.processIdentifier),kAXWindowsAttribute) as? [AXUIElement] ?? []
  return windows.enumerated().map { idx,w in let title = str(w,kAXTitleAttribute); return Target(app:app,window:w,title:title,id:digest("\(app.processIdentifier):\(idx):\(title)"),provider:(bundle == "com.openai.codex") ? "codexDesktop" : "terminal") }
 }
}
// Terminal automation is shipped application code. No agent-driven live desktop testing.
import Darwin
struct TerminalTab {
 let bundle:String; let window:Int; let index:Int; let tty:String; let selected:Bool; let pid:Int32; let group:Int32
 var id:String {digest("claude|\(bundle)|\(window)|\(index)|\(tty)|\(pid)")}
 var title:String {"Claude · \(tty.replacingOccurrences(of:"/dev/",with:""))"}
}
func runTool(_ executable:String,_ args:[String])->(Int32,String) {let p=Process();p.executableURL=URL(fileURLWithPath:executable);p.arguments=args;let out=Pipe();p.standardOutput=out;p.standardError=FileHandle.nullDevice;do{try p.run();let data=out.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit();return(p.terminationStatus,String(decoding:data,as:UTF8.self))}catch{return(-1,"")}}
func script(_ source:String)->(Int32,String) {runTool("/usr/bin/osascript",["-e","with timeout of 3 seconds\n"+source+"\nend timeout"])}
func foregroundClaude(_ tty:String)->(Int32,Int32)? {
 guard tty.hasPrefix("/dev/tty"),tty.dropFirst(8).allSatisfy({$0.isLetter || $0.isNumber}) else{return nil}
 let fd=open(tty,O_RDONLY|O_NOCTTY|O_NONBLOCK);guard fd >= 0 else{return nil};defer{close(fd)}
 let group=tcgetpgrp(fd);guard group > 0 else{return nil}
 let result=runTool("/bin/ps",["-axo","pid=,pgid=,tty=,comm="]);guard result.0 == 0 else{return nil}
 let home=FileManager.default.homeDirectoryForCurrentUser.path
 let matches=result.1.split(separator:"\n").compactMap {line -> Int32? in
  let fields=line.split(maxSplits:3,whereSeparator:{$0 == " " || $0 == "\t"});guard fields.count == 4,Int32(fields[1]) == group,fields[2] == tty.dropFirst(5) else{return nil}
  let path=String(fields[3]);let resolved=URL(fileURLWithPath:path).resolvingSymlinksInPath().path
  let nativePath=resolved.hasPrefix(home+"/.local/share/claude/versions/") || resolved == home+"/.local/bin/claude" || resolved == "/opt/homebrew/bin/claude" || resolved == "/usr/local/bin/claude"
  guard nativePath,let pid=Int32(fields[0]) else{return nil};return pid
 }
 guard matches.count == 1 else{return nil};return(matches[0],group)
}
func terminalTabs()->([TerminalTab],Bool) {
 var tabs:[TerminalTab]=[];var denied=false
 for app in NSWorkspace.shared.runningApplications {
  guard let bundle=app.bundleIdentifier,["com.apple.Terminal","com.googlecode.iterm2"].contains(bundle) else{continue}
  let source:String
  if bundle == "com.apple.Terminal" {
   source="""
   tell application id "com.apple.Terminal"
    set answer to ""
    repeat with w in windows
     set numberOfTab to 0
     repeat with t in tabs of w
      set numberOfTab to numberOfTab + 1
      set selectedFlag to (tty of t is tty of selected tab of w)
      set answer to answer & (tty of t) & tab & (id of w) & tab & numberOfTab & tab & selectedFlag & linefeed
     end repeat
    end repeat
    return answer
   end tell
   """
  } else {
   source="""
   tell application id "com.googlecode.iterm2"
    set answer to ""
    repeat with w in windows
     set numberOfTab to 0
     repeat with t in tabs of w
      set numberOfTab to numberOfTab + 1
      set s to current session of t
      set selectedFlag to (unique ID of s is unique ID of current session of current tab of w)
      set answer to answer & (tty of s) & tab & (id of w) & tab & numberOfTab & tab & selectedFlag & linefeed
     end repeat
    end repeat
    return answer
   end tell
   """
  }
  let result=script(source);if result.0 != 0{denied=true;continue}
  for line in result.1.split(separator:"\n") {let parts=line.split(separator:"\t");guard parts.count == 4,let window=Int(parts[1]),let index=Int(parts[2]),let fg=foregroundClaude(String(parts[0])) else{continue};tabs.append(TerminalTab(bundle:bundle,window:window,index:index,tty:String(parts[0]),selected:parts[3] == "true",pid:fg.0,group:fg.1))}
 }
 return(tabs,denied)
}
func terminalContents(_ t:TerminalTab)->String? {
 let source=t.bundle == "com.apple.Terminal" ? "tell application id \"com.apple.Terminal\" to return contents of tab \(t.index) of window id \(t.window)" : "tell application id \"com.googlecode.iterm2\" to return contents of current session of tab \(t.index) of window id \(t.window)"
 let r=script(source);return r.0 == 0 ? String(r.1.suffix(12000)) : nil
}
func terminalApproval(_ t:TerminalTab,_ contents:String)->[String:Any]? {
 let tail=String(contents.suffix(4000))
 guard let question=tail.range(of:"Do you want to proceed?",options:.backwards) else{return nil}
 let active=String(tail[question.lowerBound...]);let choiceLines=active.split(separator:"\n").map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}
 guard active.count <= 1800,choiceLines.contains("1. Yes") || choiceLines.contains("❯ 1. Yes"),choiceLines.contains("3. No") || choiceLines.contains("❯ 3. No"),choiceLines.contains(where:{$0.hasPrefix("2. Yes, and") || $0.hasPrefix("❯ 2. Yes, and")}),let endChoice=active.range(of:"3. No",options:.backwards) else{return nil}
 let footer=String(active[endChoice.upperBound...]).trimmingCharacters(in:.whitespacesAndNewlines)
 let allowedFooters=["","Esc to cancel","Esc to reject","Enter to select","Enter to select · Esc to cancel","Esc to cancel · Enter to select"]
 guard allowedFooters.contains(footer) else{return nil}
 let scope=digest(t.id+"|"+tail)
 return ["requestId":scope,"scopeHash":scope,"title":"Claude fragt nach Freigabe","detail":tail,"approveChoice":"1","rejectChoice":"3"]
}
func emptyClaudePrompt(_ contents:String)->Bool {
 let lines=contents.split(separator:"\n").suffix(8).map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}
 return lines.last(where:{$0.hasPrefix("❯")}) == "❯"
}
func terminalSnapshot()->([[String:Any]],Bool) {
 let inventory=terminalTabs();let sessions=inventory.0.map {t -> [String:Any] in
  let contents:String?=nil;let approval:[String:Any]?=nil
  var caps=["inspect","focus","select"]
  if AXIsProcessTrusted() && t.selected {caps.append("stop")}
  var record:[String:Any]=["id":t.id,"sessionId":t.id,"provider":"claude","providerProven":true,"title":t.title,"pid":t.pid,"windowId":t.window,"tty":t.tty,"selected":t.selected,"status":approval != nil ? "needsInput" : (contents.map(emptyClaudePrompt) == true ? "idle" : "unknown"),"capabilities":caps,"binding":"foregroundNativeClaudeTTY","appBundleId":t.bundle,"unsupportedFeatures":["send","approve","decline"],"limitation":"existingTerminalHasNoAuthenticatedActiveInputState"]
  if let approval{record["approval"]=approval};return record
 };return(sessions,inventory.1)
}
func terminalIsFront(_ t:TerminalTab)->Bool {
 guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == t.bundle else{return false}
 let result=script("tell application id \""+t.bundle+"\" to return id of front window")
 return result.0 == 0 && Int(result.1.trimmingCharacters(in:.whitespacesAndNewlines)) == t.window
}
func terminalAction(_ input:[String:Any])->[String:Any]? {
 guard let id=input["sessionId"] as? String else{return nil}
 let inventory=terminalTabs().0.filter{$0.id == id};guard inventory.count == 1,let t=inventory.first else{return nil}
 guard input["title"] as? String == t.title else{return ["ok":false,"error":"targetChangedOrAmbiguous"]}
 let action=input["action"] as? String ?? ""
 if ["focus","select"].contains(action) {
  let source=t.bundle == "com.apple.Terminal" ? "tell application id \"com.apple.Terminal\"\nset selected tab of window id \(t.window) to tab \(t.index) of window id \(t.window)\nset index of window id \(t.window) to 1\nactivate\nend tell" : "tell application id \"com.googlecode.iterm2\"\nselect tab \(t.index) of window id \(t.window)\nactivate\nend tell"
  guard script(source).0 == 0,terminalTabs().0.contains(where:{$0.id == id && $0.selected}) else{return ["ok":false,"error":"terminalSelectionReadbackFailed"]};return ["ok":true]
 }
 guard AXIsProcessTrusted() else{return ["ok":false,"error":"accessibilityPermissionRequired"]}
 if ["send","approve","decline"].contains(action){return ["ok":false,"error":"terminalActiveInputStateNotAuthenticated"]}
 guard t.selected,terminalIsFront(t) else{return ["ok":false,"error":"terminalMustBeSelectedAndFocused"]}
 let contents="";var text="";var key:CGKeyCode=36
 if action == "send" {guard let value=input["text"] as? String,!value.isEmpty,value.utf8.count <= 65536,emptyClaudePrompt(contents),terminalApproval(t,contents) == nil else{return ["ok":false,"error":"emptyClaudePromptNotProven"]};text=value}
 else if action == "stop" {key=53}
 else if ["approve","decline"].contains(action) {guard let approval=terminalApproval(t,contents),let requestId=input["requestId"] as? String,approval["requestId"] as? String == requestId else{return ["ok":false,"error":"requestBindingChanged"]};text=action == "approve" ? "1" : "3"}
 else{return ["ok":false,"error":"unsupportedAction"]}
 guard terminalTabs().0.contains(where:{$0.id == id && $0.selected && $0.pid == t.pid && $0.group == t.group}),foregroundClaude(t.tty)?.0 == t.pid,terminalIsFront(t) else{return ["ok":false,"error":"foregroundClaudeChanged"]}
 if !text.isEmpty {let chars=Array(text.utf16);guard let down=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:true),let up=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:false) else{return ["ok":false,"error":"keyboardEventUnavailable"]};chars.withUnsafeBufferPointer{down.keyboardSetUnicodeString(stringLength:chars.count,unicodeString:$0.baseAddress!);up.keyboardSetUnicodeString(stringLength:chars.count,unicodeString:$0.baseAddress!)};down.post(tap:.cghidEventTap);up.post(tap:.cghidEventTap)}
 guard foregroundClaude(t.tty)?.0 == t.pid,terminalIsFront(t) else{return ["ok":false,"error":"targetChangedTextRetained"]}
 CGEvent(keyboardEventSource:nil,virtualKey:key,keyDown:true)?.post(tap:.cghidEventTap);CGEvent(keyboardEventSource:nil,virtualKey:key,keyDown:false)?.post(tap:.cghidEventTap)
 return ["ok":true,"delivery":"keyboardEventsPosted","sessionId":id]
}

struct MenuCommand {let id:String;let label:String;let element:AXUIElement}
func focusedWindow(_ t:Target)->Bool {
 guard NSWorkspace.shared.frontmostApplication?.processIdentifier == t.app.processIdentifier,let focused=attr(AXUIElementCreateApplication(t.app.processIdentifier),kAXFocusedWindowAttribute) else{return false}
 return CFEqual(focused,t.window)
}
func safeMenuLabel(_ title:String)->Bool {
 let lower=title.lowercased();let blocked=["approve","approval","allow","reject","decline","deny","send","accept","permission","freigabe","genehmig","erlaub","senden","ablehn","akzeptier","zulass"]
 let navigation=["new chat","new task","new window","settings","preferences","search","search chats","next chat","previous chat","toggle sidebar","toggle terminal","show terminal","show diff","show changes","show project","back","forward","increase text size","decrease text size","actual size","zoom in","zoom out","enter full screen","exit full screen","open project","open folder","neuer chat","neue aufgabe","neues fenster","einstellungen","suchen","nächster chat","vorheriger chat","seitenleiste einblenden","seitenleiste ausblenden","terminal anzeigen","änderungen anzeigen","zurück","vorwärts","vergrößern","verkleinern"]
 let normalized=lower.replacingOccurrences(of:"…",with:"").trimmingCharacters(in:CharacterSet(charactersIn:". "))
 return navigation.contains(normalized) && !blocked.contains(where:lower.contains) && !["yes","no","ja","nein"].contains(lower)
}
func menuCommands(_ app:NSRunningApplication,_ sessionId:String)->[MenuCommand] {
 guard let menu=attr(AXUIElementCreateApplication(app.processIdentifier),kAXMenuBarAttribute) else{return []}
 let root=menu as! AXUIElement;var remaining=600;var entries:[MenuCommand]=[]
 func visit(_ node:AXUIElement,_ path:[String],_ depth:Int) {
  guard depth < 12 && remaining > 0 else{return};remaining -= 1
  let title=str(node,kAXTitleAttribute);let route=path + (title.isEmpty ? [] : [title]);let nested=children(node)
  if str(node,kAXRoleAttribute) == kAXMenuItemRole,!title.isEmpty,nested.isEmpty,(attr(node,kAXEnabledAttribute) as? Bool) == true {
   if safeMenuLabel(title) {
    var actions:CFArray?;AXUIElementCopyActionNames(node,&actions)
    if (actions as? [String] ?? []).contains(kAXPressAction){let key=route.joined(separator:"/")+"|"+str(node,kAXIdentifierAttribute);entries.append(MenuCommand(id:digest(sessionId+"|menu|"+key),label:route.joined(separator:" → "),element:node))}
   }
  }
  for child in nested {visit(child,route,depth+1)}
 }
 visit(root,[],0);return entries.filter {entry in entries.filter {$0.id == entry.id}.count == 1}
}
func codexContext(_ tree:[AXUIElement])->Bool {
 tree.contains {node in
  guard [kAXTextAreaRole,kAXTextFieldRole].contains(str(node,kAXRoleAttribute)) else{return false}
  return [str(node,kAXDescriptionAttribute),str(node,kAXTitleAttribute),str(node,kAXPlaceholderValueAttribute)].contains {value in value.range(of:"codex",options:.caseInsensitive) != nil}
 }
}
struct BoundApproval {let id:String;let title:String;let detail:String;let approve:AXUIElement;let reject:AXUIElement}
func uniqueRequestScope(_ ids:[String])->Bool {Set(ids).count == 1}
func boundApproval(_ tree:[AXUIElement],_ sessionId:String)->BoundApproval? {
 var found:[(Int,BoundApproval)]=[]
 for node in tree where str(node,kAXRoleAttribute) == kAXGroupRole {
  var budget=100;let card=nodes(node,budget:&budget);let texts=card.filter{[kAXStaticTextRole,kAXTextAreaRole].contains(str($0,kAXRoleAttribute))}.map(label).filter{!$0.isEmpty}
  let detail=texts.joined(separator:"\n");guard detail.count >= 20,detail.count <= 5000,["Approval required","Permission required","Run command?","Allow Codex to"].contains(where:detail.contains) else{continue}
  let approve=card.filter{str($0,kAXRoleAttribute) == kAXButtonRole && ["Allow once","Approve once","Allow this time"].contains(label($0)) && (attr($0,kAXEnabledAttribute) as? Bool) == true}
  let reject=card.filter{str($0,kAXRoleAttribute) == kAXButtonRole && ["Reject","Deny","Decline"].contains(label($0)) && (attr($0,kAXEnabledAttribute) as? Bool) == true}
  guard approve.count == 1,reject.count == 1 else{continue}
  found.append((card.count,BoundApproval(id:digest(sessionId+"|request|"+str(node,kAXIdentifierAttribute)+"|"+detail),title:"Codex benötigt Freigabe",detail:detail,approve:approve[0],reject:reject[0])))
 }
 // Minimal card removes duplicate ancestor groups. Distinct requests remain ambiguous and blocked.
 let ids=Set(found.map{$0.1.id});guard uniqueRequestScope(Array(ids)),!found.isEmpty else{return nil}
 let sorted=found.sorted{$0.0 < $1.0};guard let first=sorted.first else{return nil}

 return first.1
}

func snapshot() -> [String:Any] {
 let trusted = AXIsProcessTrusted(); let terminal = terminalSnapshot(); guard trusted else { return ["trusted":false,"automationRequired":terminal.1,"sessions":terminal.0,"error":"accessibilityPermissionRequired"] }
 let sessions = targets().flatMap { t -> [[String:Any]] in
  var budget = 1200; let tree = nodes(t.window,budget:&budget)
  let buttons = tree.filter { str($0,kAXRoleAttribute) == kAXButtonRole }.map(label).filter { !$0.isEmpty }
  // A selectable row must expose AXSelected. Text and transcript nodes cannot become a chat identity.
  let rows = t.provider == "codexDesktop" ? tree.filter { [kAXRowRole,kAXCellRole].contains(str($0,kAXRoleAttribute)) && attr($0,kAXSelectedAttribute) is Bool && !label($0).isEmpty } : []
  let codexMode=codexContext(tree)
  let uniqueRows = rows.filter { row in rows.filter {label($0) == label(row)}.count == 1 }
  func record(title: String, id: String, selected: Bool, chat: Bool) -> [String:Any] {
   var caps=["focus","inspect"]
   let commands=chat && selected && codexMode && focusedWindow(t) ? menuCommands(t.app,id) : []
   caps += commands.map {"menu:"+$0.id}
   let approval=chat && selected && codexMode ? boundApproval(tree,id) : nil
   if approval != nil {caps += ["approve","decline"]}
   if chat && codexMode { caps.append("select") }
   if chat && selected && codexMode {
    if buttons.filter({["Stop","Stop generating","Stop response","Stopp"].contains($0)}).count == 1 {caps.append("stop")}
    let editors=tree.filter { [kAXTextAreaRole,kAXTextFieldRole].contains(str($0,kAXRoleAttribute)) && ["Message Codex","Ask Codex"].contains(str($0,kAXDescriptionAttribute)) }
    if editors.count == 1 && str(editors[0],kAXValueAttribute).isEmpty && buttons.filter({["Send","Send message"].contains($0)}).count == 1 {caps.append("send")}
   }
   var result:[String:Any] = ["id":id,"sessionId":id,"provider":t.provider == "codexDesktop" ? "codex" : "claude","title":title,"windowTitle":t.title,"chatTitle":chat ? title : "","appBundleId":t.app.bundleIdentifier ?? "","pid":t.app.processIdentifier,"windowId":t.id,"selected":selected,"status":t.provider == "codexDesktop" ? "unknown" : "unassigned","capabilities":caps,"binding":chat ? "selectedAXRow" : "window","providerProven":t.provider == "codexDesktop" && codexMode,"commands":commands.map{["id":$0.id,"label":$0.label,"kind":"menu"]}]
   if let approval {result["approval"]=["requestId":approval.id,"scopeHash":approval.id,"title":approval.title,"detail":approval.detail];result["status"]="needsInput"}
   return result
  }
  if !uniqueRows.isEmpty {return uniqueRows.map {row in record(title:label(row),id:digest(t.id+"|chat|"+label(row)),selected:(attr(row,kAXSelectedAttribute) as? Bool) == true,chat:true)}}
  return [record(title:t.title,id:t.id,selected:false,chat:false)]
 }

 return ["trusted":true,"automationRequired":terminal.1,"sessions":sessions.filter {($0["provider"] as? String) != "claude"} + terminal.0]
}
func action(_ input: [String:Any]) -> [String:Any] {
 if let result=terminalAction(input){return result}
 guard AXIsProcessTrusted() else { return ["ok":false,"error":"accessibilityPermissionRequired"] }
 guard let id=input["sessionId"] as? String, let expected=input["title"] as? String else { return ["ok":false,"error":"targetTitleRequired"] }
 let matching=targets().filter {t in
  if t.id == id && t.title == expected {return true}
  var budget=1200; let tree=nodes(t.window,budget:&budget)
  let rows=tree.filter {[kAXRowRole,kAXCellRole].contains(str($0,kAXRoleAttribute)) && attr($0,kAXSelectedAttribute) is Bool && label($0) == expected}
  return t.provider == "codexDesktop" && rows.count == 1 && digest(t.id+"|chat|"+expected) == id
 }; guard matching.count == 1, let t=matching.first else { return ["ok":false,"error":"targetChangedOrAmbiguous"] }
 let action=input["action"] as? String ?? ""
 if action == "focus" { t.app.activate(); let result=AXUIElementPerformAction(t.window,kAXRaiseAction as CFString); return ["ok":result == .success,"sessionId":id] }
 var budget=1200; let tree=nodes(t.window,budget:&budget)
 guard t.provider == "codexDesktop" else { return ["ok":false,"error":"terminalNeedsExplicitRegisteredTTYAdapter"] }
 let chatTitle=(input["chatTitle"] as? String) ?? (t.id != id ? expected : "")
 guard !chatTitle.isEmpty else { return ["ok":false,"error":"selectedChatProofRequired"] }
 let selected=tree.filter { (attr($0,kAXSelectedAttribute) as? Bool) == true && label($0) == chatTitle }
 if action == "select" && selected.isEmpty {
  guard codexContext(tree) else{return ["ok":false,"error":"codexContextNotProven"]}
  let candidates=tree.filter {label($0) == chatTitle && [kAXRowRole,kAXButtonRole,kAXCellRole].contains(str($0,kAXRoleAttribute))}
  guard candidates.count == 1 else {return ["ok":false,"error":"chatSelectionAmbiguous"]}
  guard AXUIElementPerformAction(candidates[0],kAXPressAction as CFString) == .success else {return ["ok":false,"error":"chatNotSelectable"]}
  var selectionBudget=1200; let refreshed=nodes(t.window,budget:&selectionBudget)
  guard codexContext(refreshed),refreshed.filter({(attr($0,kAXSelectedAttribute) as? Bool) == true && label($0) == chatTitle}).count == 1 else {return ["ok":false,"error":"selectionReadbackFailed"]}
  return ["ok":true,"sessionId":id,"selectedChatTitle":chatTitle]
 }
 guard selected.count == 1 else { return ["ok":false,"error":"selectedChatProofFailed"] }
 guard codexContext(tree) else{return ["ok":false,"error":"codexContextNotProven"]}
 if action == "select" { return ["ok":true,"sessionId":id,"selectedChatTitle":chatTitle] }
 // Approval operations deliberately require a request identifier generated by an inspected request card.
 // Generic approval buttons are never safe proof of which request the user authorized.
 if ["approve","decline"].contains(action) {
  guard let requested=input["requestId"] as? String,let card=boundApproval(tree,id),card.id == requested else{return ["ok":false,"error":"requestBindingUnavailable"]}
  var freshBudget=1200;let fresh=nodes(t.window,budget:&freshBudget)
  guard fresh.filter({(attr($0,kAXSelectedAttribute) as? Bool) == true && label($0) == chatTitle}).count == 1,let current=boundApproval(fresh,id),current.id == requested else{return ["ok":false,"error":"requestBindingChanged"]}
  return ["ok":AXUIElementPerformAction(action == "approve" ? current.approve : current.reject,kAXPressAction as CFString) == .success]
 }
 if action.hasPrefix("menu:") {
  guard focusedWindow(t) else{return ["ok":false,"error":"targetWindowMustBeFocused"]}
  let menuId=String(action.dropFirst(5));let commands=menuCommands(t.app,id).filter{$0.id == menuId}
  guard commands.count == 1 else{return ["ok":false,"error":"menuCommandChanged"]}
  var freshBudget=1200;let fresh=nodes(t.window,budget:&freshBudget)
  guard fresh.filter({(attr($0,kAXSelectedAttribute) as? Bool) == true && label($0) == chatTitle}).count == 1 else{return ["ok":false,"error":"selectedChatProofFailed"]}
  let current=menuCommands(t.app,id).filter{$0.id == menuId};guard current.count == 1,focusedWindow(t) else{return ["ok":false,"error":"menuCommandChanged"]}
  return ["ok":AXUIElementPerformAction(current[0].element,kAXPressAction as CFString) == .success]
 }
 if action == "stop" {
  let stop=tree.filter {str($0,kAXRoleAttribute) == kAXButtonRole && ["Stop","Stop generating","Stop response","Stopp"].contains(label($0))}
  guard stop.count == 1 else {return ["ok":false,"error":"stopControlAmbiguous"]}; return ["ok":AXUIElementPerformAction(stop[0],kAXPressAction as CFString) == .success]
 }
 if action == "send" {
  guard let text=input["text"] as? String, !text.isEmpty, text.utf8.count <= 65536 else {return ["ok":false,"error":"invalidText"]}
  let editors=tree.filter { [kAXTextAreaRole,kAXTextFieldRole].contains(str($0,kAXRoleAttribute)) && ["Message Codex","Ask Codex"].contains(str($0,kAXDescriptionAttribute)) }
  guard editors.count == 1 else {return ["ok":false,"error":"composerNotProven"]}
  // Never replace an existing draft.
  guard str(editors[0],kAXValueAttribute).isEmpty else {return ["ok":false,"error":"existingDraft"]}
  let send=tree.filter {str($0,kAXRoleAttribute) == kAXButtonRole && ["Send","Send message"].contains(label($0))}; guard send.count == 1 else {return ["ok":false,"error":"sendControlAmbiguous"]}
  guard AXUIElementSetAttributeValue(editors[0],kAXValueAttribute as CFString,text as CFString) == .success else {return ["ok":false,"error":"composerNotWritable"]}
  // Re-read selected identity immediately before irreversible send.
  var secondBudget=1200; let fresh=nodes(t.window,budget:&secondBudget)
  guard fresh.filter({(attr($0,kAXSelectedAttribute) as? Bool) == true && label($0) == chatTitle}).count == 1 else {return ["ok":false,"error":"targetChangedDraftRetained"]}
  return ["ok":AXUIElementPerformAction(send[0],kAXPressAction as CFString) == .success]
 }
 return ["ok":false,"error":"unsupportedAction"]
}
if CommandLine.arguments.contains("--self-test") {
 for unsafe in ["Reject","Decline","Run","Continue","Confirm","Always allow","Allow once","Send","Delete","Publish","Ablehnen","Akzeptieren","Zulassen"] {precondition(!safeMenuLabel(unsafe),"Unsafe menu must require dedicated binding")}
 precondition(safeMenuLabel("Settings…"))
 precondition(!uniqueRequestScope(["small-card","large-card"]),"Distinct request scopes must block regardless of card size")
 precondition(uniqueRequestScope(["same-card","same-card"]))
 let tab=TerminalTab(bundle:"com.apple.Terminal",window:10,index:1,tty:"/dev/ttys999",selected:true,pid:100,group:100)
 let other=TerminalTab(bundle:"com.apple.Terminal",window:10,index:1,tty:"/dev/ttys999",selected:true,pid:101,group:101)
 precondition(tab.id != other.id,"Process replacement must invalidate session binding")
 precondition(emptyClaudePrompt("old text\n❯\n? for shortcuts"))
 precondition(!emptyClaudePrompt("❯\nold blank prompt\n❯ unfinished draft"),"Draft must suppress send")
 let prompt="Read file /test\nDo you want to proceed?\n❯ 1. Yes\n2. Yes, and don't ask again\n3. No"
 let approval=terminalApproval(tab,prompt)!
 precondition(approval["requestId"] as? String != terminalApproval(tab,prompt+" changed scope")?["requestId"] as? String,"Changed approval text must invalidate request")
 precondition(terminalApproval(tab,"Should I run this? Yes / No") == nil,"Generic yes/no cannot establish approval")
 precondition(terminalApproval(other,prompt)?["requestId"] as? String != approval["requestId"] as? String,"Process change must invalidate approval")
 print("PASS: process replacement, draft preservation, changed request scope, generic approval rejection")
 exit(0)
}
while let line=readLine() { do { let input=try JSONSerialization.jsonObject(with:Data(line.utf8)) as? [String:Any] ?? [:]; let result=(input["command"] as? String == "action") ? action(input) : snapshot(); let data=try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]); print(String(decoding:data,as:UTF8.self)) } catch { print("{\"ok\":false,\"error\":\"invalidJSON\"}") } }
