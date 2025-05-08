// File: Controllers/SpeechRecognitionController.swift
// VERSION: Added speech segmentation based on stroke timing

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
    
    // New properties for segmentation
    private var continuousTranscription: String = ""
    private var strokeSegments: [StrokeSegment] = []
    private var isSegmentingEnabled: Bool = true
    private var currentCharacter: Character? = nil
    private var totalStrokeCount: Int = 0
    private var strokeTimingMap: [Int: (startTime: Date, endTime: Date)] = [:]
    private var pendingTranscripts: [String] = []

    // Common Chinese stroke names for better matching
    private static let chineseStrokeNames: [String] = [
        "横", "竖", "撇", "捺", "点", "提", "折", "横折", "竖折", "横撇", "横钩", "竖钩", "竖提"
    ]

    // Map of similar-sounding Chinese words that should be considered matches
    private static let similarSoundingWords: [String: String] = [
        "树": "竖",   // Both pronounced "shù"
        "术": "竖",   // Similar pronunciation
        "数": "竖",   // Similar pronunciation
        "说": "竖",   // Similar pronunciation
        "我": "横",   // Sometimes misrecognized
        "和": "横",   // Similar pronunciation
        "河": "横",   // Similar pronunciation
        "合": "横折", // Sometimes misrecognized
        "盒": "横折"  // Sometimes misrecognized
    ]

    // Context list - expanded with common Chinese stroke names
    private static let commonStrokeNamesContext: [String] = {
        var names = StrokeType.allCases.map { $0.rawValue.lowercased() }.filter { !$0.isEmpty && $0 != "unknown" }
        names.append(contentsOf: chineseStrokeNames)
        return names
    }()

    // MARK: - Delegate
    var delegate: SpeechRecognitionDelegate? // Keep non-weak

    // MARK: - Stroke Segment Struct
    struct StrokeSegment {
        let index: Int
        let startTime: Date
        let endTime: Date
        let expectedName: String
        var transcription: String = ""
        var matchesExpected: Bool = false
        var confidence: Float = 0.0
    }

    // MARK: - Initialization
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
        super.init()
        speechRecognizer.delegate = self
        requestSpeechAuthorization()
        print("Speech Contextual Strings Prepared: \(SpeechRecognitionController.commonStrokeNamesContext)")
    }

    deinit { stopAudioEngineAndCleanupSession() }

    // MARK: - Configuration
    func configure(with character: Character) {
        // Reset speech segments when configuring for a new character
        strokeSegments = []
        continuousTranscription = ""
        isSegmentingEnabled = true
        currentCharacter = character
        totalStrokeCount = character.strokeCount
        print("Configured for character with \(totalStrokeCount) strokes")
    }

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

    // MARK: - Authorization
    func requestSpeechAuthorization() {
         SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
             guard let self = self else { return }
             DispatchQueue.main.async {
                 print("Speech recognition authorization status: \(self.stringFromAuthStatus(authStatus))")
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
    }

    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async { [weak self] in if let self = self, !available { self.stopRecording(); self.delegate?.speechRecognitionNotAvailable() } }
    }

    // MARK: - Recording Control
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
            // Task Completion Handler
            guard let self = self else { return }
            var isFinal = false; let currentTime = Date()
            if let result = result {
                let transcriptionText = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.recognizedTextFragment = transcriptionText }
                self.continuousTranscription = transcriptionText // Store for segmentation
                self.lastSpeechTime = currentTime; isFinal = result.isFinal
                
                if isFinal {
                    print("Recognition Task: Final result received: \(transcriptionText)")
                    guard let startTime = self.speechStartTime else { return }
                    let matches = self.checkTranscriptionMatch(transcriptionText)
                    let confidence = result.bestTranscription.segments.last?.confidence ?? 0.0
                    DispatchQueue.main.async {
                        self.delegate?.speechTranscriptionFinalized(
                            transcription: transcriptionText,
                            matchesExpected: matches,
                            confidence: confidence,
                            startTime: startTime,
                            endTime: currentTime
                        )
                    }
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

    // MARK: - Stroke Segmentation
    // Add a new stroke segment when a stroke is completed
    func segmentSpeechForStroke(strokeIndex: Int, startTime: Date, endTime: Date) {
        guard isSegmentingEnabled, let expectedName = currentExpectedStrokeName, !expectedName.isEmpty else {
            print("Segmentation skipped: No expected name or segmentation disabled")
            return
        }
        
        // Store stroke timing for future reference
        strokeTimingMap[strokeIndex] = (startTime: startTime, endTime: endTime)
        
        // Check if we already processed this stroke to avoid duplicates
        if let existingSegment = strokeSegments.first(where: { $0.index == strokeIndex }) {
            print("Segment for stroke \(strokeIndex) already exists, not creating duplicate")
            // Still notify delegate about the existing result to ensure UI is updated
            DispatchQueue.main.async {
                self.delegate?.speechTranscriptionFinalized(
                    transcription: existingSegment.transcription,
                    matchesExpected: existingSegment.matchesExpected,
                    confidence: existingSegment.confidence,
                    startTime: existingSegment.startTime,
                    endTime: existingSegment.endTime
                )
            }
            return
        }
        
        print("Segmenting speech for stroke \(strokeIndex): \(expectedName)")
        
        // If this is the first stroke and we have any speech, make sure to assign it
        if strokeIndex == 0 && !continuousTranscription.isEmpty {
            // For the first stroke, use whatever speech we have
            processFirstStrokeTranscript(strokeIndex, startTime, endTime, expectedName)
        } else if strokeIndex > 0 && !continuousTranscription.isEmpty {
            // For subsequent strokes, try to segment the speech
            processTranscriptForMultipleStrokes()
        } else {
            // If we have no transcript yet, check if we detected speech activity
            if receivedSpeechInCurrentSession {
                // We detected speech but don't have a transcript yet
                // Create a segment with an empty string but mark it as "detected"
                createAndNotifySegment(
                    strokeIndex: strokeIndex,
                    startTime: startTime,
                    endTime: endTime,
                    expectedName: expectedName,
                    transcription: "...", // Placeholder to indicate speech was detected
                    wasDetected: true
                )
            } else {
                // No speech detected at all
                processTranscriptForSingleStroke(strokeIndex, startTime, endTime, expectedName)
            }
        }
    }

    // Special handling for the first stroke to ensure speech is assigned
    private func processFirstStrokeTranscript(_ strokeIndex: Int, _ startTime: Date, _ endTime: Date, _ expectedName: String) {
        print("Processing first stroke transcript: \"\(continuousTranscription)\"")
        
        // For the first stroke, check if the transcript contains any similar-sounding words
        for (similarWord, strokeName) in Self.similarSoundingWords {
            if continuousTranscription.contains(similarWord) && strokeName == expectedName {
                print("First stroke contains similar-sounding word '\(similarWord)' for '\(expectedName)'")
                createAndNotifySegment(
                    strokeIndex: strokeIndex,
                    startTime: startTime,
                    endTime: endTime,
                    expectedName: expectedName,
                    transcription: similarWord
                )
                return
            }
        }
        
        // If no similar-sounding words, use the whole transcript
        createAndNotifySegment(
            strokeIndex: strokeIndex,
            startTime: startTime,
            endTime: endTime,
            expectedName: expectedName,
            transcription: continuousTranscription
        )
    }

    // Process transcript when we need to segment across multiple strokes
    private func processTranscriptForMultipleStrokes() {
        guard !continuousTranscription.isEmpty else { return }
        
        // Store current transcript for later segmentation
        pendingTranscripts.append(continuousTranscription)
        
        print("Full transcript to segment: \"\(continuousTranscription)\"")
        
        // Try to split the transcript into parts based on known stroke names
        let segmentedParts = splitTranscriptByStrokeNames(continuousTranscription)
        print("Segmented into \(segmentedParts.count) parts: \(segmentedParts)")
        
        // If we have enough segments to match our strokes
        if segmentedParts.count >= strokeTimingMap.count {
            // Match segments to strokes based on timing
            for (index, (strokeIndex, timing)) in strokeTimingMap.sorted(by: { $0.key < $1.key }).enumerated() {
                if index < segmentedParts.count {
                    let segment = segmentedParts[index]
                    let expectedName = getExpectedNameForStroke(strokeIndex)
                    
                    // Create new segment
                    createAndNotifySegment(
                        strokeIndex: strokeIndex,
                        startTime: timing.startTime,
                        endTime: timing.endTime,
                        expectedName: expectedName,
                        transcription: segment
                    )
                }
            }
        } else {
            // Fallback: best-effort assignment of transcript parts to strokes
            print("Not enough segments, using best-effort matching")
            handleInsufficientSegments(segmentedParts)
        }
    }

    // Handle cases where we couldn't split transcript into enough parts
    private func handleInsufficientSegments(_ parts: [String]) {
        let strokeCount = strokeTimingMap.count
        
        // If we have exactly the same number of parts as strokes, match them directly
        if parts.count == strokeCount {
            for (i, (strokeIndex, timing)) in strokeTimingMap.sorted(by: { $0.key < $1.key }).enumerated() {
                let expectedName = getExpectedNameForStroke(strokeIndex)
                createAndNotifySegment(
                    strokeIndex: strokeIndex,
                    startTime: timing.startTime,
                    endTime: timing.endTime,
                    expectedName: expectedName,
                    transcription: parts[i]
                )
            }
            return
        }
        
        // Special case: If we have one transcript with multiple stroke names combined
        if parts.count == 1 && strokeCount > 1 {
            let transcript = parts[0]
            
            // Check if the single transcript contains multiple expected stroke names
            var matched = false
            for (strokeIndex, timing) in strokeTimingMap.sorted(by: { $0.key < $1.key }) {
                let expectedName = getExpectedNameForStroke(strokeIndex)
                
                // Simple check: Does the transcript contain this expected name?
                if containsStrokeName(transcript, strokeName: expectedName) {
                    print("Matched transcript to stroke \(strokeIndex) based on content match")
                    
                    // If it's a direct match for the expected name, use just that name
                    if transcript == expectedName {
                        createAndNotifySegment(
                            strokeIndex: strokeIndex,
                            startTime: timing.startTime,
                            endTime: timing.endTime,
                            expectedName: expectedName,
                            transcription: expectedName
                        )
                    } else {
                        // Otherwise, use the full transcript but prioritize matching this stroke
                        createAndNotifySegment(
                            strokeIndex: strokeIndex,
                            startTime: timing.startTime,
                            endTime: timing.endTime,
                            expectedName: expectedName,
                            transcription: transcript
                        )
                    }
                    matched = true
                }
            }
            
            // If we couldn't match any strokes, just assign to first stroke
            if !matched && !strokeTimingMap.isEmpty {
                let firstStroke = strokeTimingMap.sorted(by: { $0.key < $1.key }).first!
                let expectedName = getExpectedNameForStroke(firstStroke.key)
                
                createAndNotifySegment(
                    strokeIndex: firstStroke.key,
                    startTime: firstStroke.value.startTime,
                    endTime: firstStroke.value.endTime,
                    expectedName: expectedName,
                    transcription: transcript
                )
            }
            return
        }
        
        // Try to assign available parts to strokes in order, handling any mismatch in counts
        let partsCount = parts.count
        let strokeIndices = strokeTimingMap.sorted(by: { $0.key < $1.key }).map { $0.key }
        
        // Distribute parts evenly among strokes
        for i in 0..<strokeIndices.count {
            let strokeIndex = strokeIndices[i]
            let timing = strokeTimingMap[strokeIndex]!
            let expectedName = getExpectedNameForStroke(strokeIndex)
            
            // Calculate which part index to use for this stroke
            let partIndex: Int
            if partsCount <= strokeIndices.count {
                // Fewer parts than strokes - some strokes will share parts
                partIndex = min(i, partsCount - 1)
            } else {
                // More parts than strokes - distribute parts among strokes
                let partsPerStroke = partsCount / strokeIndices.count
                let startIndex = i * partsPerStroke
                let endIndex = (i == strokeIndices.count - 1) ? partsCount - 1 : startIndex + partsPerStroke - 1
                
                // Find the part that best matches this stroke
                var bestMatchIndex = startIndex
                var bestMatchScore = 0.0
                
                for j in startIndex...endIndex {
                    let part = parts[j]
                    if containsStrokeName(part, strokeName: expectedName) {
                        // Exact match gets highest priority
                        bestMatchIndex = j
                        break
                    }
                    
                    // Otherwise score based on substring matching
                    let score = findBestSubstringMatch(haystack: part, needle: expectedName)
                    if score > bestMatchScore {
                        bestMatchScore = score
                        bestMatchIndex = j
                    }
                }
                
                partIndex = bestMatchIndex
            }
            
            // Create segment with the selected part
            if partIndex >= 0 && partIndex < parts.count {
                createAndNotifySegment(
                    strokeIndex: strokeIndex,
                    startTime: timing.startTime,
                    endTime: timing.endTime,
                    expectedName: expectedName,
                    transcription: parts[partIndex]
                )
            }
        }
    }

    // Helper to get expected name for a stroke
    private func getExpectedNameForStroke(_ strokeIndex: Int) -> String {
        guard let existingSegment = strokeSegments.first(where: { $0.index == strokeIndex }) else {
            // This is a new stroke, so return current expected name
            return currentExpectedStrokeName ?? ""
        }
        return existingSegment.expectedName
    }

    // Split continuous transcript by known stroke names
    private func splitTranscriptByStrokeNames(_ transcript: String) -> [String] {
        // Get all the stroke names in order of appearance
        var segments: [String] = []
        var remainingText = transcript
        
        // If the transcript contains multiple stroke names, try to split it
        // First, look for stroke names in the order they should appear
        var strokeNamesToFind: [String] = []
        
        // Build ordered list of expected stroke names from the timing map
        for (strokeIndex, _) in strokeTimingMap.sorted(by: { $0.key < $1.key }) {
            let expectedName = getExpectedNameForStroke(strokeIndex)
            if !expectedName.isEmpty {
                strokeNamesToFind.append(expectedName)
            }
        }
        
        print("Looking for these stroke names in order: \(strokeNamesToFind)")
        
        // If we have clear stroke names to find, try to extract them in sequence
        if !strokeNamesToFind.isEmpty && strokeNamesToFind.count >= 2 {
            var extractedSegments: [String] = []
            var lastIndex = 0
            
            // Try to find each expected stroke name in sequence
            for strokeName in strokeNamesToFind {
                if let range = remainingText.range(of: strokeName, options: [], range: remainingText.index(remainingText.startIndex, offsetBy: lastIndex)..<remainingText.endIndex, locale: nil) {
                    let startPos = remainingText.distance(from: remainingText.startIndex, to: range.lowerBound)
                    let endPos = remainingText.distance(from: remainingText.startIndex, to: range.upperBound)
                    
                    // If this is not the first segment, get everything before this stroke name
                    // and assign it to the previous stroke
                    if lastIndex > 0 && startPos > lastIndex {
                        let previousText = String(remainingText[remainingText.index(remainingText.startIndex, offsetBy: lastIndex)..<range.lowerBound])
                        if !previousText.isEmpty {
                            extractedSegments.append(previousText.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                    
                    // Add this stroke name segment
                    extractedSegments.append(strokeName)
                    lastIndex = endPos
                }
            }
            
            // Handle any remaining text after the last found stroke name
            if lastIndex < remainingText.count {
                let remainingSegment = String(remainingText[remainingText.index(remainingText.startIndex, offsetBy: lastIndex)..<remainingText.endIndex])
                if !remainingSegment.isEmpty {
                    extractedSegments.append(remainingSegment.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            
            // If we successfully extracted segments, use them
            if !extractedSegments.isEmpty {
                segments = extractedSegments
                print("Successfully segmented transcript by expected stroke names: \(segments)")
                return segments.filter { !$0.isEmpty }
            }
        }
        
        // Fallback: Use the general approach with any stroke names
        segments = []
        
        // If there are numbers in the transcript (like "数"), first clean them
        let cleanedTranscript = cleanTranscription(remainingText, forExpected: "")
        remainingText = cleanedTranscript
        
        // Try to identify any stroke names in the transcript
        for strokeName in Self.chineseStrokeNames.sorted(by: { $0.count > $1.count }) {
            if remainingText.contains(strokeName) {
                // Use regular expressions to find all occurrences
                let pattern = strokeName.replacingOccurrences(of: "(", with: "\\(")
                                       .replacingOccurrences(of: ")", with: "\\)")
                
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsString = remainingText as NSString
                    let matches = regex.matches(in: remainingText, options: [], range: NSRange(location: 0, length: nsString.length))
                    
                    if matches.count > 0 {
                        // If we found multiple occurrences, split based on those
                        var lastEnd = 0
                        
                        for match in matches {
                            let range = match.range
                            
                            // Get text before this match
                            if range.location > lastEnd {
                                let beforeText = nsString.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
                                if !beforeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    segments.append(beforeText.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                            }
                            
                            // Add the stroke name itself
                            segments.append(strokeName)
                            
                            lastEnd = range.location + range.length
                        }
                        
                        // Get text after the last match
                        if lastEnd < nsString.length {
                            let afterText = nsString.substring(with: NSRange(location: lastEnd, length: nsString.length - lastEnd))
                            if !afterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                segments.append(afterText.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                        }
                        
                        remainingText = ""
                        break
                    }
                } catch {
                    print("Regex error: \(error)")
                }
            }
        }
        
        // If no segments were found with the regex approach, try component splitting
        if segments.isEmpty && !remainingText.isEmpty {
            for strokeName in Self.chineseStrokeNames.sorted(by: { $0.count > $1.count }) {
                if remainingText.contains(strokeName) {
                    let components = remainingText.components(separatedBy: strokeName)
                    if components.count > 1 {
                        // Keep the stroke name with the segments
                        for (index, component) in components.enumerated() {
                            if !component.isEmpty {
                                segments.append(component.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                            // Add the stroke name between components (except after the last one)
                            if index < components.count - 1 {
                                segments.append(strokeName)
                            }
                        }
                        remainingText = ""
                        break
                    }
                }
            }
        }
        
        // If still no segments, just return the whole cleaned transcript
        if segments.isEmpty {
            segments = [remainingText.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        
        return segments.filter { !$0.isEmpty }
    }

    // Check if a transcript contains a specific stroke name
    private func containsStrokeName(_ transcript: String, strokeName: String) -> Bool {
        return transcript.contains(strokeName)
    }

    // Process transcript for a single stroke (simpler case)
    private func processTranscriptForSingleStroke(_ strokeIndex: Int, _ startTime: Date, _ endTime: Date, _ expectedName: String) {
        let transcription = continuousTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        createAndNotifySegment(
            strokeIndex: strokeIndex,
            startTime: startTime,
            endTime: endTime,
            expectedName: expectedName,
            transcription: transcription
        )
    }

    // Create a segment and notify delegate
    private func createAndNotifySegment(
        strokeIndex: Int, 
        startTime: Date, 
        endTime: Date, 
        expectedName: String, 
        transcription: String,
        wasDetected: Bool = false
    ) {
        // Don't clean empty transcriptions
        let cleanedTranscription = transcription.isEmpty ? transcription : cleanTranscription(transcription, forExpected: expectedName)
        
        // If we have a placeholder "..." for detected speech, check for similar-sounding words
        let finalTranscription = cleanedTranscription == "..." ? expectedName : cleanedTranscription
        
        // Determine match status - handle special case for detected speech with no transcript
        let matchResult: Bool
        if wasDetected && cleanedTranscription == "..." {
            // If speech was detected but no transcript yet, assume it matches
            matchResult = true
            print("Speech detected but no transcript yet, assuming match for stroke \(strokeIndex)")
        } else {
            // Otherwise check if the transcript matches the expected name
            matchResult = checkTranscriptionMatch(finalTranscription, against: expectedName)
        }
        
        let segment = StrokeSegment(
            index: strokeIndex,
            startTime: startTime,
            endTime: endTime,
            expectedName: expectedName,
            transcription: finalTranscription,
            matchesExpected: matchResult,
            confidence: 0.8
        )
        
        // Update or add to our segments list
        if let existingIndex = strokeSegments.firstIndex(where: { $0.index == strokeIndex }) {
            strokeSegments[existingIndex] = segment
        } else {
            strokeSegments.append(segment)
        }
        
        print("Added speech segment for stroke \(strokeIndex): \(expectedName)")
        print("Segment transcription: \"\(finalTranscription)\", matches: \(matchResult)")
        
        // Notify delegate about this segment's transcription result
        DispatchQueue.main.async {
            print("### Notifying delegate with DEFINITIVE match status: \(matchResult) for '\(finalTranscription)'")
            self.delegate?.speechTranscriptionFinalized(
                transcription: finalTranscription, 
                matchesExpected: matchResult,
                confidence: segment.confidence,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }
    }

    // Clean up transcription to focus on stroke names
    private func cleanTranscription(_ transcription: String, forExpected expected: String) -> String {
        var cleaned = transcription
        
        // Remove known non-stroke terms
        let nonStrokeTerms = ["数", "是", "一", "二", "三", "四", "五"]
        for term in nonStrokeTerms {
            cleaned = cleaned.replacingOccurrences(of: term, with: "")
        }
        
        // Check for similar-sounding words and replace them with the expected stroke name
        for (similarWord, strokeName) in Self.similarSoundingWords {
            if cleaned.contains(similarWord) && strokeName == expected {
                print("Found similar-sounding word '\(similarWord)' for expected '\(expected)' - treating as match")
                return expected
            }
        }
        
        // If after cleaning we find an exact match for the expected name, return just that
        if cleaned.contains(expected) {
            return expected
        }
        
        // Try to extract just the stroke names from the transcript
        for strokeName in Self.chineseStrokeNames.sorted(by: { $0.count > $1.count }) {
            if cleaned.contains(strokeName) && strokeName != expected {
                // If transcript contains another stroke name that's not the expected one,
                // AND it also contains the expected one, prioritize the expected one
                if cleaned.contains(expected) {
                    return expected
                }
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Enhanced Transcription Matching with specific target
    private func checkTranscriptionMatch(_ transcription: String, against expectedName: String) -> Bool {
        // Don't attempt matching on empty transcription
        guard !transcription.isEmpty else { 
            return false 
        }
        
        // Check for similar-sounding words first
        for (similarWord, strokeName) in Self.similarSoundingWords {
            if transcription.contains(similarWord) && strokeName == expectedName {
                print("Similar-sounding word match: '\(similarWord)' matches expected '\(expectedName)'")
                return true
            }
        }
        
        let processedTranscription = transcription.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[1-5]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let processedExpected = expectedName.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if transcript contains the expected stroke name
        let exactMatch = (processedTranscription == processedExpected)
        let containsMatch = !exactMatch && processedTranscription.contains(processedExpected)
        let reverseContainsMatch = !exactMatch && !containsMatch && processedExpected.contains(processedTranscription)
        
        // More flexible matching for short stroke names (<=3 chars)
        let approximateMatch = !exactMatch && !containsMatch && !reverseContainsMatch &&
                              processedExpected.count <= 3 && 
                              (levenshteinDistance(processedExpected, processedTranscription) <= 1 ||
                               findBestSubstringMatch(haystack: processedTranscription, needle: processedExpected) >= 0.7)
        
        // Direct matching against known Chinese stroke names
        let strokeNameMatch = Self.chineseStrokeNames.contains(processedTranscription) && 
                              processedTranscription == processedExpected
        
        let match = exactMatch || containsMatch || reverseContainsMatch || approximateMatch || strokeNameMatch
        let matchType = exactMatch ? "EXACT" : (containsMatch ? "CONTAINS" :
                        (reverseContainsMatch ? "REVERSE_CONTAINS" : (approximateMatch ? "APPROXIMATE" : 
                         (strokeNameMatch ? "STROKE_NAME" : "NO"))))
        
        print("--- Speech Match Check (Targeted) ---")
        print("  Expected: '\(processedExpected)', Actual: '\(processedTranscription)', Result: \(matchType) MATCH")
        print("----------------------------------")
        
        if !transcription.isEmpty {
            self.receivedSpeechInCurrentSession = true
            DispatchQueue.main.async { self.hasRecognizedSpeech = true }
        }
        
        return match
    }

    // Helper function to find best substring match
    private func findBestSubstringMatch(haystack: String, needle: String) -> Double {
        guard !haystack.isEmpty && !needle.isEmpty else { return 0.0 }
        guard haystack.count >= needle.count else { return Double(needle.count) / Double(haystack.count) }
        
        var bestMatchRatio = 0.0
        
        // Slide the needle through the haystack
        for i in 0...(haystack.count - needle.count) {
            let startIndex = haystack.index(haystack.startIndex, offsetBy: i)
            let endIndex = haystack.index(startIndex, offsetBy: needle.count)
            let substring = String(haystack[startIndex..<endIndex])
            
            let distance = levenshteinDistance(substring, needle)
            let matchRatio = 1.0 - (Double(distance) / Double(needle.count))
            
            if matchRatio > bestMatchRatio {
                bestMatchRatio = matchRatio
            }
        }
        
        return bestMatchRatio
    }

    // Generic transcription matching (for backward compatibility)
    private func checkTranscriptionMatch(_ transcription: String) -> Bool {
        guard let expected = currentExpectedStrokeName, !expected.isEmpty else { return false }
        return checkTranscriptionMatch(transcription, against: expected)
    }
    
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aCount = a.count; let bCount = b.count
        if aCount == 0 { return bCount }
        if bCount == 0 { return aCount }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bCount + 1), count: aCount + 1)
        for i in 0...aCount { matrix[i][0] = i }
        for j in 0...bCount { matrix[0][j] = j }
        
        let aChars = Array(a); let bChars = Array(b)
        for i in 1...aCount {
            for j in 1...bCount {
                let cost = aChars[i-1] == bChars[j-1] ? 0 : 1
                matrix[i][j] = min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
            }
        }
        return matrix[aCount][bCount]
    }

    // MARK: - Session Cleanup
    private func stopAudioEngineAndCleanupSession() {
        stopTimer?.invalidate(); stopTimer = nil
        if audioEngine.isRunning { audioEngine.stop(); print("Audio engine stopped.") }
        if isTapInstalled { audioEngine.inputNode.removeTap(onBus: 0); isTapInstalled = false; print("Audio tap removed.") }
        recognitionRequest?.endAudio()
        
        // Properly release audio session
        do { 
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated.")
            
            // Reset audio session category to ambient (default) to allow other sessions to work
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            print("Audio session reset to ambient category.")
        }
        catch { 
            print("Failed to deactivate audio session: \(error)") 
        }
        
        // Nil out recognition objects
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func cleanupAfterError() {
        recognitionRequest?.endAudio()
        if audioEngine.isRunning { audioEngine.stop() }
        if isTapInstalled { audioEngine.inputNode.removeTap(onBus: 0); isTapInstalled = false }
        
        // Properly release audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            print("Audio session reset after error.")
        } catch {
            print("Failed to reset audio session after error: \(error)")
        }
        
        self.recognitionRequest = nil
        self.recognitionTask = nil
    }
    
    func stopRecording() {
        print("Explicit stopRecording() called.")
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        stopAudioEngineAndCleanupSession()
        
        if isRecording { DispatchQueue.main.async { self.isRecording = false } }
        self.speechStartTime = nil
        self.lastSpeechTime = nil
        let finalSpeechState = self.receivedSpeechInCurrentSession
        DispatchQueue.main.async { self.hasRecognizedSpeech = finalSpeechState }
        
        print("Requested recording stop completed. Speech detected: \(finalSpeechState)")
    }

    // MARK: - Automatic Stop Timer
    private func startStopTimer() {
        stopTimer?.invalidate()
        let maxTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in self?.stopRecording() }
        resetStopTimer()
        print("Started automatic stop timers (Max: \(maxRecordingDuration)s, Silence: \(silenceDetectionInterval)s).")
    }
    
    private func resetStopTimer() {
        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: silenceDetectionInterval, repeats: false) { [weak self] _ in self?.stopRecording() }
    }

    // Error Enum
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
            case .recognizerUnavailable: return "The speech recognizer is not available."
            case .audioSessionError(let e): return "Failed to configure audio session: \(e.localizedDescription)"
            case .requestCreationFailed: return "Failed to create the speech recognition request."
            case .audioInputError(let r): return "Failed to setup audio input: \(r)"
            case .audioEngineError(let e): return "The audio engine failed to start: \(e.localizedDescription)"
            }
        }
    }

    // Utility Extension
    func wasSpeechDetected() -> Bool { return self.hasRecognizedSpeech }

    // MARK: - Actions (Called from MainView)
    func processStrokeCompletion(strokeIndex: Int, startTime: Date, endTime: Date) {
        print("Processing stroke completion for stroke \(strokeIndex) - maintaining continuous recording")
        
        // We don't stop recording between strokes - instead we segment what was recorded
        // This allows us to capture speech across stroke boundaries
        
        // Process the segment immediately without delays
        segmentSpeechForStroke(
            strokeIndex: strokeIndex,
            startTime: startTime,
            endTime: endTime
        )
        
        // Only stop recording if this is the last stroke of the character
        if let totalStrokes = currentCharacter?.strokeCount, strokeIndex >= totalStrokes - 1 {
            print("Last stroke completed, stopping recording")
            stopRecording()
        }
    }
}
