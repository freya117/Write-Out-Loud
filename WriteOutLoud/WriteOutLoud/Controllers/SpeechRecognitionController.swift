// File: Controllers/SpeechRecognitionController.swift

import Foundation
import Speech // Provides SFSpeechRecognizer, SFSpeechRecognitionTask etc.
import Combine // For ObservableObject
import AVFoundation // For AVAudioSession

/// Delegate protocol for the SpeechRecognitionController.
protocol SpeechRecognitionDelegate {
    /// Called when the speech recording successfully starts.
    func speechRecordingStarted(at time: Date)

    /// Called when the speech recording stops (either manually or automatically).
    func speechRecordingStopped(at time: Date, duration: TimeInterval)

    /// Called when the speech recognizer finalizes a transcription segment.
    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date)

    /// Called if an error occurs during speech recognition setup or processing.
    func speechRecognitionErrorOccurred(_ error: Error)

    /// Called if speech recognition is unavailable (e.g., no permission, restricted, no network for server-based).
    func speechRecognitionNotAvailable()

    /// Called when the authorization status changes (optional, for UI updates).
    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus)
}

/**
 Manages speech input using Apple's Speech framework (SFSpeechRecognizer).
 It handles requesting authorization, starting/stopping audio recording,
 processing the audio to get text transcriptions, and checking if the
 transcription contains an expected stroke name.
 */
class SpeechRecognitionController: NSObject, ObservableObject, SFSpeechRecognizerDelegate {

    // MARK: - Published Properties
    /// Indicates if the audio engine is currently recording. Drives UI state.
    @Published var isRecording: Bool = false
    /// The latest (potentially partial) recognized text fragment. Useful for live UI feedback.
    @Published var recognizedTextFragment: String = ""
    /// The current authorization status for speech recognition.
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Speech Recognition Components
    /// The speech recognizer instance, configured for Mandarin Chinese.
    /// Note: Force unwrap assumes zh-CN locale exists and SFSpeechRecognizer init doesn't fail. Consider handling nil.
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
    /// The request object that handles buffering audio for recognition.
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    /// The active recognition task processing the audio stream.
    private var recognitionTask: SFSpeechRecognitionTask?
    /// The audio engine responsible for capturing microphone input.
    private let audioEngine = AVAudioEngine()
    /// Flag to track if tap is installed on audio input node
    private var isTapInstalled = false

    // MARK: - Internal State
    /// Timestamp recorded when the current recording session started.
    private var speechStartTime: Date?
    /// Timestamp of the last received speech result (used for accurate end time).
    private var lastSpeechTime: Date?
    /// The pinyin name of the stroke currently expected to be spoken (e.g., "héng"). Set externally.
    private var currentExpectedStrokeName: String? = nil
     /// Timer to automatically stop recording after a period of silence or max duration.
     private var stopTimer: Timer?
     private let maxRecordingDuration: TimeInterval = 5.0 // Max seconds per stroke recording
     private let silenceDetectionInterval: TimeInterval = 1.5 // Seconds of silence before stopping

    // MARK: - Delegate
    var delegate: SpeechRecognitionDelegate?

    // MARK: - Initialization
    override init() {
        super.init()
        speechRecognizer.delegate = self // Set delegate to receive availability changes
        // Request authorization when the controller is created
        requestSpeechAuthorization()
    }

    deinit {
        // Make sure we clean up audio resources when the controller is deallocated
        stopAudioEngineAndCleanupSession()
    }

    // MARK: - Configuration
    func configure(with character: Character) {
        print("SpeechRecognitionController configured for character \(character.character)")
        resetStateForNewCharacter()
    }

    func prepareForStroke(expectedName: String) {
        self.currentExpectedStrokeName = expectedName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) // Store normalized
        print("Expecting stroke name: '\(self.currentExpectedStrokeName ?? "None")'")
        resetStateForNewStroke()
    }

    private func resetStateForNewCharacter() {
        // No character-specific state currently, but good practice
    }

    private func resetStateForNewStroke() {
        // Ensure UI updates on main thread if changing published properties
        DispatchQueue.main.async {
            self.recognizedTextFragment = ""
        }
        // Invalidate timer if active from previous stroke
         stopTimer?.invalidate()
         stopTimer = nil
    }

    // MARK: - Authorization
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }
            DispatchQueue.main.async {
                print("Speech recognition authorization status: \(self.stringFromAuthStatus(authStatus))")
                self.authorizationStatus = authStatus
                self.delegate?.speechAuthorizationDidChange(to: authStatus)

                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized.")
                case .denied, .restricted, .notDetermined:
                    if authStatus != .notDetermined {
                        print("Speech recognition not available (Status: \(self.stringFromAuthStatus(authStatus))).")
                        self.delegate?.speechRecognitionNotAvailable()
                    }
                @unknown default:
                    print("Unknown speech recognition authorization status.")
                    self.delegate?.speechRecognitionNotAvailable()
                }
            }
        }
    }

    // Helper to get descriptive string for auth status
    private func stringFromAuthStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }


    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !available {
                print("Speech recognizer became unavailable.")
                self.stopRecording() // Stop if it becomes unavailable while recording
                self.delegate?.speechRecognitionNotAvailable()
            } else {
                print("Speech recognizer became available.")
            }
        }
    }

    // MARK: - Recording Control
    func startRecording() throws {
        // --- Pre-checks ---
        guard authorizationStatus == .authorized else {
            print("Cannot start recording: Speech recognition not authorized.")
            requestSpeechAuthorization() // Re-prompt if not determined, otherwise user needs settings
            throw SpeechError.notAuthorized
        }
        guard speechRecognizer.isAvailable else {
            print("Cannot start recording: Speech recognizer is not available.")
            delegate?.speechRecognitionNotAvailable()
            throw SpeechError.recognizerUnavailable
        }
        guard !isRecording else {
            print("Already recording.")
            return
        }
        
        // Always ensure we clean up any existing session before starting a new one
        stopAudioEngineAndCleanupSession()

        // --- Configure Audio Session ---
        let audioSession = AVAudioSession.sharedInstance()
        do {
             // Use measurement preset, duck others
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session configured and activated.")
        } catch {
            print("Audio session setup failed: \(error)")
            throw SpeechError.audioSessionError(error)
        }

        // --- Create Recognition Request ---
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        recognitionRequest.shouldReportPartialResults = true // Get intermediate results
         // Contextual strings can improve accuracy for expected words
         if let expectedName = self.currentExpectedStrokeName, !expectedName.isEmpty {
             recognitionRequest.contextualStrings = [expectedName]
             print("Added contextual string: '\(expectedName)'")
         }

        // Use on-device recognition if possible
        if #available(iOS 13, *), speechRecognizer.supportsOnDeviceRecognition {
            print("Attempting to use on-device recognition.")
            recognitionRequest.requiresOnDeviceRecognition = true
        } else {
            print("Using server-based recognition (on-device not supported or iOS < 13).")
             recognitionRequest.requiresOnDeviceRecognition = false // Explicitly false
        }

        // --- Configure Audio Engine Input ---
        let inputNode = audioEngine.inputNode
        
        // This is the key fix - Get the format directly from input node and use that exact format for the tap
        let recordingFormat = inputNode.inputFormat(forBus: 0) // Use inputFormat instead of outputFormat
        
        print("Audio recording format: \(recordingFormat)")

        // Make sure we don't have an existing tap
        if isTapInstalled {
            print("Removing existing tap before installing a new one")
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        // Install tap with the input format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self?.recognitionRequest?.append(buffer)
             // Reset silence timer on receiving audio data
             self?.resetStopTimer()
        }
        isTapInstalled = true

        // --- Start Audio Engine ---
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start failed: \(error)")
            cleanupAfterError()
            throw SpeechError.audioEngineError(error)
        }

        // --- Start Recognition Task ---
        speechStartTime = Date()
        lastSpeechTime = speechStartTime
         DispatchQueue.main.async {
             self.isRecording = true
         }
        print("Speech recording started at \(speechStartTime!)")
        delegate?.speechRecordingStarted(at: speechStartTime!)
         startStopTimer() // Start the automatic stop timer

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return } // Ensure self is available

            var isFinal = false
            let currentTime = Date()

            if let result = result {
                let transcriptionText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedTextFragment = transcriptionText // Update UI
                }
                self.lastSpeechTime = currentTime // Update last known speech time

                // Check for expected name match in partial results if needed (optional)
                // let partialMatch = self.checkTranscriptionMatch(transcriptionText)
                // print("Partial: '\(transcriptionText)', Match: \(partialMatch)")

                isFinal = result.isFinal
                if isFinal {
                    print("Final transcription received: '\(transcriptionText)'")
                    guard let startTime = self.speechStartTime else {
                        print("Warning: Final transcription received, but start time is missing.")
                        // Handle missing start time? Maybe ignore this result?
                        return
                    }
                    // Perform final match check
                    let matches = self.checkTranscriptionMatch(transcriptionText)
                    let confidence = result.bestTranscription.segments.last?.confidence ?? 0.0

                    print("Comparing final processed '\(transcriptionText.lowercased().replacingOccurrences(of: " ", with: ""))' with '\(self.currentExpectedStrokeName ?? "")'. Match: \(matches)")

                    DispatchQueue.main.async {
                        self.delegate?.speechTranscriptionFinalized(
                            transcription: transcriptionText, // Report the original final text
                            matchesExpected: matches,
                            confidence: confidence,
                            startTime: startTime,
                            endTime: currentTime // Use the time this final result was processed
                        )
                    }
                    // Final result received, we can stop recording immediately
                     self.stopRecording() // Explicitly stop now
                }
            }

            // --- Handle Errors or End of Task ---
            if error != nil || isFinal {
                print("Stopping recording task. Final: \(isFinal), Error: \(error?.localizedDescription ?? "None")")
                 self.stopAudioEngineAndCleanupSession() // Stop engine/session

                DispatchQueue.main.async {
                     if self.isRecording { // Only update if it was recording
                         self.isRecording = false
                     }
                }

                let finalStartTime = self.speechStartTime
                let endTime = self.lastSpeechTime ?? currentTime
                let duration = endTime.timeIntervalSince(finalStartTime ?? endTime)

                 // Reset timing and state for next recording
                 self.speechStartTime = nil
                 self.lastSpeechTime = nil
                 self.stopTimer?.invalidate() // Ensure timer is stopped
                 self.stopTimer = nil
                 // Keep currentExpectedStrokeName until prepareForStroke is called

                // Notify delegate that recording stopped
                if let startTime = finalStartTime {
                     print("Speech recording stopped at \(endTime). Duration: \(String(format: "%.2f", duration))s.")
                     DispatchQueue.main.async {
                         self.delegate?.speechRecordingStopped(at: endTime, duration: duration)
                     }
                }

                // Report errors to delegate (filtering out expected cancellations/timeouts)
                if let error = error {
                    let nsError = error as NSError
                    // Common codes: 203 (No speech), 1107/1101 (Network/Session), 216 (Timeout), Cocoa Cancelled
                     let ignoredErrorCodes = [203, 1107, 1101, 216]
                     let isIgnoredDomainCode = nsError.domain == "kAFAssistantErrorDomain" && ignoredErrorCodes.contains(nsError.code)
                     let isCocoaCancel = nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.userCancelled.rawValue
                     // SFSpeechRecognizerError codes (e.g., 1=busy, 2=cancelled, 3=no-match, 4=audio-error) - maybe ignore 2/3?
                     let isSpeechCancelOrNomatch = nsError.domain == "com.apple.speech.recognition" && [2, 3].contains(nsError.code)

                    if !isIgnoredDomainCode && !isCocoaCancel && !isSpeechCancelOrNomatch {
                        print("Speech recognition error reported: \(error)")
                        DispatchQueue.main.async {
                            self.delegate?.speechRecognitionErrorOccurred(error)
                        }
                    } else {
                        print("Speech recognition task ended (likely due to stop, cancellation, timeout, or no speech). Error code: \(nsError.code), Domain: \(nsError.domain)")
                         // If no final transcription was generated (e.g., timeout, no speech),
                         // we need to tell the delegate, perhaps with matchesExpected=false
                         if !isFinal { // Check if we reached here without isFinal=true
                             DispatchQueue.main.async {
                                 // Use captured start time if available, else use currentTime
                                 let effectiveStartTime = finalStartTime ?? currentTime
                                 self.delegate?.speechTranscriptionFinalized(
                                     transcription: "", // No transcription
                                     matchesExpected: false, // Cannot match
                                     confidence: 0.0,
                                     startTime: effectiveStartTime,
                                     endTime: currentTime // Use current time as end
                                 )
                             }
                         }
                    }
                }

                // Clean up task and request objects
                self.recognitionRequest = nil
                self.recognitionTask = nil // Crucial to nil the task here
                print("Cleaned up recognition task and request.")
            }
        }
    }

     /// Check if the transcription contains the expected stroke name (case-insensitive, ignoring spaces).
     private func checkTranscriptionMatch(_ transcription: String) -> Bool {
         guard let expected = currentExpectedStrokeName, !expected.isEmpty else {
             print("Warning: Trying to match transcription, but no expected stroke name is set.")
             return false // Cannot match if nothing is expected
         }
         // Normalize transcription: lowercase, remove spaces
         let processedTranscription = transcription.lowercased().replacingOccurrences(of: " ", with: "")
         // Use contains for flexibility (e.g., user says "heng zhe gou" but only "hengzhe" is expected)
         return processedTranscription.contains(expected)
     }

    /// Stops the audio engine, removes the tap, and deactivates the audio session.
    private func stopAudioEngineAndCleanupSession() {
         stopTimer?.invalidate() // Stop timer first
         stopTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            print("Audio engine stopped.")
        }
        
        // Always check and remove tap if installed
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
            print("Audio tap removed.")
        }

        // End any ongoing recognition request
        recognitionRequest?.endAudio()

        // Deactivate audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated.")
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

     /// Cleans up audio engine and session after an error during startup.
     private func cleanupAfterError() {
         recognitionRequest?.endAudio() // Ensure request knows audio ended
         
         if audioEngine.isRunning {
             audioEngine.stop()
         }
         
         if isTapInstalled {
             audioEngine.inputNode.removeTap(onBus: 0)
             isTapInstalled = false
         }
         
         self.recognitionRequest = nil
         self.recognitionTask = nil
         try? AVAudioSession.sharedInstance().setActive(false) // Try to deactivate session
     }

    /// Explicitly stops the recording process and cleans up resources.
    func stopRecording() {
        print("Explicit stopRecording() called.")

        // Signal end of input for the request if it exists
        recognitionRequest?.endAudio()
        
        // Ask for final result and finish the task if it exists
        recognitionTask?.finish()
         
        // Make sure we clean up all audio resources
        stopAudioEngineAndCleanupSession()

        // Update recording state if needed
        if isRecording {
            DispatchQueue.main.async {
                self.isRecording = false
            }
        }
        
        // Handle case where task might not notify completion
        let finalStartTime = self.speechStartTime
        if let startTime = finalStartTime, self.lastSpeechTime != nil {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Reset state
            self.speechStartTime = nil
            self.lastSpeechTime = nil
            
            // Notify delegate
            print("Speech recording stopped. Duration: \(String(format: "%.2f", duration))s.")
            DispatchQueue.main.async {
                self.delegate?.speechRecordingStopped(at: endTime, duration: duration)
            }
        }
        
        print("Requested recording stop completed.")
    }

    // MARK: - Automatic Stop Timer
     private func startStopTimer() {
         stopTimer?.invalidate() // Invalidate previous timer if any
         // Schedule timer for max duration
         stopTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
             print("Max recording duration (\(self?.maxRecordingDuration ?? 0)s) reached. Stopping recording.")
             self?.stopRecording()
         }
         // Initialize silence detection (reset the timer whenever audio comes in)
         resetStopTimer() // Start the silence detection period initially
         print("Started automatic stop timer (max duration: \(maxRecordingDuration)s, silence: \(silenceDetectionInterval)s).")
     }

     private func resetStopTimer() {
         stopTimer?.invalidate() // Invalidate current timer
         // Reschedule timer for silence interval
         stopTimer = Timer.scheduledTimer(withTimeInterval: silenceDetectionInterval, repeats: false) { [weak self] _ in
             print("Silence detected for \(self?.silenceDetectionInterval ?? 0)s. Stopping recording.")
             self?.stopRecording()
         }
     }

    // MARK: - Error Enum
    enum SpeechError: Error, LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case audioSessionError(Error)
        case requestCreationFailed
        case audioInputError(String)
        case audioEngineError(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Speech recognition authorization was denied or not determined."
            case .recognizerUnavailable: return "The speech recognizer is not available on this device or locale."
            case .audioSessionError(let underlyingError): return "Failed to configure audio session: \(underlyingError.localizedDescription)"
            case .requestCreationFailed: return "Failed to create the speech recognition request."
            case .audioInputError(let reason): return "Failed to setup audio input: \(reason)"
            case .audioEngineError(let underlyingError): return "The audio engine failed to start: \(underlyingError.localizedDescription)"
            }
        }
    }
}
