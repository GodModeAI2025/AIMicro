import Foundation
import Speech
import AVFoundation
import Observation

@MainActor @Observable final class SpeechCapture {
    var recording = false
    var transcript = ""
    var error: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var starting = false
    func start() async {
        guard !recording && !starting else { return }; starting = true; defer { starting = false }
        let authorized = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning:$0 == .authorized) } }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard authorized && microphone else { error = "Mikrofon und Spracherkennung in Einstellungen freigeben."; return }
        guard let recognizer = SFSpeechRecognizer(locale:Locale(identifier:"de-DE")), recognizer.isAvailable else { error = "Spracherkennung nicht verfügbar."; return }
        // Fail closed if Apple cannot provide on-device recognition: no silent audio upload.
        guard recognizer.supportsOnDeviceRecognition else { error = "Lokale Spracherkennung ist auf diesem Gerät nicht verfügbar."; return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.record,mode:.measurement,options:.duckOthers)
            try AVAudioSession.sharedInstance().setActive(true,options:.notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest(); request.shouldReportPartialResults = true; request.requiresOnDeviceRecognition = true
            self.request = request; transcript = ""; error = nil
            let input = engine.inputNode; let format = input.outputFormat(forBus:0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw RemoteError.unavailable("Kein Mikrofon verfügbar") }
            input.installTap(onBus:0,bufferSize:1024,format:format) { buffer,_ in request.append(buffer) }
            task = recognizer.recognitionTask(with:request) { [weak self] result,error in
                let text = result?.bestTranscription.formattedString; let final = result?.isFinal ?? false; let errorText = error?.localizedDescription
                Task { @MainActor in
                    if let text { self?.transcript = text }
                    if let errorText { self?.error = errorText }
                    if final || errorText != nil { self?.stop() }
                }
            }
            engine.prepare(); try engine.start(); recording = true
        } catch { self.error = error.localizedDescription; stop() }
    }
    func stop() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus:0) }
        request?.endAudio(); task?.cancel(); task = nil; request = nil; recording = false
        try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
    }
}
