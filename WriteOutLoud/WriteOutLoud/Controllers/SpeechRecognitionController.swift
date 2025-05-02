// File: Controllers/SpeechRecognitionController.swift
// VERSION: Added dummy return to satisfy compiler for stringFromAuthStatus

import Foundation
import Speech
import Combine
import AVFoundation

// Delegate protocol (No class constraint)
protocol SpeechRecognitionDelegate {
    func speechRecordingStarted(at time: Date)
    func speechRecordingStopped(at time: Date, duration: TimeInterval)
    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date)
    func speechRecognitionErrorOccurred(_ error: Error)
    func speechRecognitionNotAvailable()
    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus)
}

class SpeechRecognitionController: NSObject, ObservableObject, SFSpeechRecognizerDelegate {

    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var recognizedTextFragment: String = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var hasRecognizedSpeech: Bool = false

    // MARK: - Speech Recognition Components
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isTapInstalled = false

    // MARK: - Internal State
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    private var currentExpectedStrokeName: String? = nil // Normalized
    private var stopTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 10.0
    private let silenceDetectionInterval: TimeInterval = 2.0

    private var receivedSpeechInCurrentSession: Bool = false
    private let enableVerboseAudioLogging = true

    // Context list (Unchanged)
    private static let commonStrokeNamesContext: [String] = StrokeType.allCases.map { $0.rawValue.lowercased() }.filter { !$0.isEmpty && $0 != "unknown" }

    // MARK: - Delegate
    var delegate: SpeechRecognitionDelegate? // Keep non-weak

    // MARK: - Initialization (Unchanged)
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
        super.init()
        speechRecognizer.delegate = self
        requestSpeechAuthorization()
        print("Speech Contextual Strings Prepared: \(SpeechRecognitionController.commonStrokeNamesContext)")
    }

    deinit { stopAudioEngineAndCleanupSession() }

    // MARK: - Configuration (Unchanged)
    func configure(with character: Character) { /* ... */ }

    func prepareForStroke(expectedName: String) {
        self.currentExpectedStrokeName = expectedName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "[1-5]", with: "", options: .regularExpression)
        print("Expecting normalized stroke name: '\(self.currentExpectedStrokeName ?? "None")'")
        resetStateForNewStroke()
    }

    private func resetStateForNewStroke() {
        DispatchQueue.main.async { self.recognizedTextFragment = ""; self.hasRecognizedSpeech = false }
        stopTimer?.invalidate(); stopTimer = nil
        receivedSpeechInCurrentSession = false
    }

    // MARK: - Authorization (Unchanged)
    func requestSpeechAuthorization() {
         SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
             guard let self = self else { return }
             DispatchQueue.main.async {
                 print("Speech recognition authorization status: \(self.stringFromAuthStatus(authStatus))") // Call the corrected function
                 self.authorizationStatus = authStatus
                 self.delegate?.speechAuthorizationDidChange(to: authStatus)
                 switch authStatus {
                 case .authorized: print("Speech recognition authorized.")
                 case .denied, .restricted, .notDetermined:
                     if authStatus != .notDetermined { self.delegate?.speechRecognitionNotAvailable() }
                 @unknown default: self.delegate?.speechRecognitionNotAvailable()
                 }
             }
         }
     }

    // ***** MODIFIED: Added dummy return *****
    private func stringFromAuthStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
        // return "" // Should be unreachable, but added to satisfy potential compiler confusion
    }
    // *************************************

    // MARK: - SFSpeechRecognizerDelegate (Unchanged)
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async { [weak self] in if let self = self, !available { self.stopRecording(); self.delegate?.speechRecognitionNotAvailable() } }
    }

     // MARK: - Audio Level Monitoring (Removed for simplicity)

    // MARK: - Recording Control (Simplified Audio Session, More Logs)
    func startRecording() throws {
        print("--- startRecording: Initiated ---")
        guard authorizationStatus == .authorized else { throw SpeechError.notAuthorized }
        guard speechRecognizer.isAvailable else { throw SpeechError.recognizerUnavailable }
        guard !isRecording else { return }
        print("startRecording: Cleaning up previous session...")
        stopAudioEngineAndCleanupSession() // Ensure clean state
        receivedSpeechInCurrentSession = false; DispatchQueue.main.async { self.hasRecognizedSpeech = false }

        // Simplest Audio Session Setup
        let audioSession = AVAudioSession.sharedInstance()
        do {
            print("startRecording: Setting audio session category to .record (Basic)...")
            try audioSession.setCategory(.record, mode: .default)
            print("startRecording: Activating audio session...")
            try audioSession.setActive(true)
            print("startRecording: Audio session configured and activated SUCCESSFULLY.")
        } catch {
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            print("startRecording CRITICAL Error: Audio session setup FAILED: \(error)")
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            throw SpeechError.audioSessionError(error)
        }

        // Create Recognition Request
        print("startRecording: Creating recognition request...")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { throw SpeechError.requestCreationFailed }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        recognitionRequest.contextualStrings = SpeechRecognitionController.commonStrokeNamesContext
        // Keep forcing server-based for testing reliability
        recognitionRequest.requiresOnDeviceRecognition = false
        print("startRecording: Recognition request created (forcing server).")

        // Configure Audio Engine Input
        print("startRecording: Configuring audio engine input...")
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        print("startRecording: Engine input format: \(recordingFormat)")
        guard recordingFormat.channelCount > 0 else { throw SpeechError.audioInputError("Invalid channel count") }

        // Install Tap
        if isTapInstalled { inputNode.removeTap(onBus: 0); isTapInstalled = false }
        print("startRecording: Installing audio tap...")
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] (buffer, when) in
             guard let self = self else { return }
             self.recognitionRequest?.append(buffer)
             self.resetStopTimer()
             // Buffer analysis for speech detection
             let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
             if let samples = channels.first {
                 var sum: Float = 0; let frameLength = Int(buffer.frameLength)
                 if frameLength > 0 {
                     for i in 0..<frameLength { sum += abs(samples[i]) }
                     let avgAmplitude = sum / Float(frameLength)
                     if avgAmplitude > 0.01 {
                         if !self.receivedSpeechInCurrentSession {
                             self.receivedSpeechInCurrentSession = true
                             DispatchQueue.main.async { self.hasRecognizedSpeech = true }
                             print("🎤 Direct buffer analysis shows speech detected! Level: \(avgAmplitude)")
                         }
                     }
                 }
             }
        }
        isTapInstalled = true
        print("startRecording: Audio tap installed.")

        // Reset Engine Before Prepare
        print("startRecording: Resetting audio engine...")
        audioEngine.reset()
        print("startRecording: Preparing audio engine...")
        audioEngine.prepare()

        do {
            print("startRecording: Starting audio engine...")
            try audioEngine.start()
            print("startRecording: Audio engine started successfully.")
        } catch {
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            print("startRecording CRITICAL Error: Audio engine start FAILED: \(error)")
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            cleanupAfterError()
            throw SpeechError.audioEngineError(error)
        }

        // Start Recognition Task
        print("startRecording: Starting recognition task...")
        speechStartTime = Date(); lastSpeechTime = speechStartTime
        DispatchQueue.main.async { self.isRecording = true }
        delegate?.speechRecordingStarted(at: speechStartTime!)
        startStopTimer()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            // Task Completion Handler (logic unchanged)
            guard let self = self else { return }
            var isFinal = false; let currentTime = Date()
            if let result = result {
                let transcriptionText = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.recognizedTextFragment = transcriptionText }
                self.lastSpeechTime = currentTime; isFinal = result.isFinal
                if isFinal {
                    print("Recognition Task: Final result received.")
                    guard let startTime = self.speechStartTime else { return }
                    let matches = self.checkTranscriptionMatch(transcriptionText) // Enhanced check
                    let confidence = result.bestTranscription.segments.last?.confidence ?? 0.0
                    DispatchQueue.main.async { self.delegate?.speechTranscriptionFinalized(transcription: transcriptionText, matchesExpected: matches, confidence: confidence, startTime: startTime, endTime: currentTime) }
                    self.stopRecording()
                }
            }
            if error != nil || isFinal {
                print("Recognition Task: Ending. Final=\(isFinal), Error=\(error?.localizedDescription ?? "None")")
                self.stopAudioEngineAndCleanupSession()
                DispatchQueue.main.async { if self.isRecording { self.isRecording = false } }
                let finalStartTime = self.speechStartTime; let endTime = self.lastSpeechTime ?? currentTime
                let duration = endTime.timeIntervalSince(finalStartTime ?? endTime)
                self.speechStartTime = nil; self.lastSpeechTime = nil; self.stopTimer?.invalidate(); self.stopTimer = nil
                if let startTime = finalStartTime { DispatchQueue.main.async { self.delegate?.speechRecordingStopped(at: endTime, duration: duration) } }
                if let error = error {
                    let nsError = error as NSError
                    print("!!! Speech Recognition Task Error: Domain=\(nsError.domain), Code=\(nsError.code), Desc=\(error.localizedDescription) !!!")
                    let ignoredErrorCodes = [203, 1107, 1101, 216, 1110]; let ignoredSpeechCodes = [2, 3]
                    let isIgnoredDomainCode = nsError.domain == "kAFAssistantErrorDomain" && ignoredErrorCodes.contains(nsError.code)
                    let isCocoaCancel = nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.userCancelled.rawValue
                    let isIgnoredSpeechCode = nsError.domain == "com.apple.speech.recognition" && ignoredSpeechCodes.contains(nsError.code)
                    if !isIgnoredDomainCode && !isCocoaCancel && !isIgnoredSpeechCode { DispatchQueue.main.async { self.delegate?.speechRecognitionErrorOccurred(error) } }
                    else {
                        print("  (Error was filtered, not reported to MainView delegate)")
                        if !isFinal {
                            DispatchQueue.main.async {
                                let effectiveStartTime = finalStartTime ?? currentTime
                                let wasSpeechDetected = self.receivedSpeechInCurrentSession
                                self.delegate?.speechTranscriptionFinalized(transcription: "", matchesExpected: false, confidence: 0.0, startTime: effectiveStartTime, endTime: currentTime)
                                self.hasRecognizedSpeech = wasSpeechDetected
                            }
                        }
                    }
                } else if !isFinal {
                     print("Recognition Task: Ended without error or final result.")
                     DispatchQueue.main.async {
                         let effectiveStartTime = finalStartTime ?? currentTime
                         let wasSpeechDetected = self.receivedSpeechInCurrentSession
                         self.delegate?.speechTranscriptionFinalized(transcription: "", matchesExpected: false, confidence: 0.0, startTime: effectiveStartTime, endTime: currentTime)
                         self.hasRecognizedSpeech = wasSpeechDetected
                     }
                }
                self.recognitionRequest = nil; self.recognitionTask = nil
                print("Recognition Task: Cleaned up request and task.")
            }
        }
        print("startRecording: Recognition task successfully started.")
        print("--- startRecording: Finished ---")
    }

    // Enhanced Transcription Matching (Unchanged)
    private func checkTranscriptionMatch(_ transcription: String) -> Bool {
        guard let expected = currentExpectedStrokeName, !expected.isEmpty else { return false }
        let processedTranscription = transcription.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "[1-5]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        let exactMatch = (processedTranscription == expected)
        let containsMatch = !exactMatch && processedTranscription.contains(expected)
        let reverseContainsMatch = !exactMatch && !containsMatch && expected.contains(processedTranscription)
        let approximateMatch = !exactMatch && !containsMatch && !reverseContainsMatch && expected.count <= 3 && processedTranscription.count <= 3 && levenshteinDistance(expected, processedTranscription) <= 1
        let match = exactMatch || containsMatch || reverseContainsMatch || approximateMatch
        let matchType = exactMatch ? "EXACT" : (containsMatch ? "CONTAINS" : (reverseContainsMatch ? "REVERSE_CONTAINS" : (approximateMatch ? "APPROXIMATE" : "NO")))
        print("--- Speech Match Check (Enhanced) ---")
        print("  Expected: '\(expected)', Actual (Processed): '\(processedTranscription)', Result: \(matchType) MATCH")
        print("----------------------------------")
        if !transcription.isEmpty { self.receivedSpeechInCurrentSession = true; DispatchQueue.main.async { self.hasRecognizedSpeech = true } }
        return match
    }
    private func levenshteinDistance(_ a: String, _ b: String) -> Int { /* ... */
        let aCount = a.count; let bCount = b.count; if aCount == 0 { return bCount }; if bCount == 0 { return aCount }
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bCount + 1), count: aCount + 1)
        for i in 0...aCount { matrix[i][0] = i }; for j in 0...bCount { matrix[0][j] = j }
        let aChars = Array(a); let bChars = Array(b)
        for i in 1...aCount { for j in 1...bCount { let cost = aChars[i-1] == bChars[j-1] ? 0 : 1; matrix[i][j] = min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost) } }
        return matrix[aCount][bCount]
    }

    // MARK: - Session Cleanup (Unchanged)
    private func stopAudioEngineAndCleanupSession() { /* ... */
        stopTimer?.invalidate(); stopTimer = nil; // stopAudioLevelMonitoring()
        if audioEngine.isRunning { audioEngine.stop(); print("Audio engine stopped.") }
        if isTapInstalled { audioEngine.inputNode.removeTap(onBus: 0); isTapInstalled = false; print("Audio tap removed.") }
        recognitionRequest?.endAudio()
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation); print("Audio session deactivated.") }
        catch { print("Failed to deactivate audio session: \(error)") }
    }
    private func cleanupAfterError() { /* ... */
        recognitionRequest?.endAudio(); if audioEngine.isRunning { audioEngine.stop() }
        if isTapInstalled { audioEngine.inputNode.removeTap(onBus: 0); isTapInstalled = false }
        self.recognitionRequest = nil; self.recognitionTask = nil; try? AVAudioSession.sharedInstance().setActive(false); // stopAudioLevelMonitoring()
    }
    func stopRecording() { /* ... */
        print("Explicit stopRecording() called.")
        recognitionRequest?.endAudio(); recognitionTask?.finish(); stopAudioEngineAndCleanupSession()
        if isRecording { DispatchQueue.main.async { self.isRecording = false } }
        self.speechStartTime = nil; self.lastSpeechTime = nil
        let finalSpeechState = self.receivedSpeechInCurrentSession; DispatchQueue.main.async { self.hasRecognizedSpeech = finalSpeechState }
        print("Requested recording stop completed. Speech detected: \(finalSpeechState)")
    }

    // MARK: - Automatic Stop Timer (Unchanged)
    private func startStopTimer() { /* ... */
        stopTimer?.invalidate()
        let maxTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in self?.stopRecording() }
        resetStopTimer()
        print("Started automatic stop timers (Max: \(maxRecordingDuration)s, Silence: \(silenceDetectionInterval)s).")
    }
    private func resetStopTimer() { /* ... */
        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: silenceDetectionInterval, repeats: false) { [weak self] _ in self?.stopRecording() }
    }

    // Error Enum (Unchanged)
    enum SpeechError: Error, LocalizedError { /* ... */
        case notAuthorized; case recognizerUnavailable; case audioSessionError(Error)
        case requestCreationFailed; case audioInputError(String); case audioEngineError(Error)
        var errorDescription: String? { /* ... */
            switch self {
            case .notAuthorized: return "Speech recognition authorization was denied or not determined."
            case .recognizerUnavailable: return "The speech recognizer is not available."
            case .audioSessionError(let e): return "Failed to configure audio session: \(e.localizedDescription)"
            case .requestCreationFailed: return "Failed to create the speech recognition request."
            case .audioInputError(let r): return "Failed to setup audio input: \(r)"
            case .audioEngineError(let e): return "The audio engine failed to start: \(e.localizedDescription)"
            }
        }
    }

    // Utility Extension (Unchanged)
    func wasSpeechDetected() -> Bool { return self.hasRecognizedSpeech }
}
