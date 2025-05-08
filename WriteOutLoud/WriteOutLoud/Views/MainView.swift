// File: Views/MainView.swift
// VERSION: Added explicit self reference for isCharacterPracticeComplete

import SwiftUI
import PencilKit
import Speech
import UIKit // Needed for UIColor comparison/creation

// MARK: - Delegate Coordinator Class
// Handles delegate methods and interacts with MainView state via closures
final class DelegateCoordinator: NSObject, ObservableObject, StrokeInputDelegate, SpeechRecognitionDelegate, ConcurrencyAnalyzerDelegate {

    // References (assigned in MainView.initialSetup)
    var strokeInputController: StrokeInputController?
    var speechRecognitionController: SpeechRecognitionController?
    var concurrencyAnalyzer: ConcurrencyAnalyzer?
    var feedbackController: FeedbackController?
    var pkCanvasView: PKCanvasView?

    // Closures to modify MainView's @State (assigned in MainView.initialSetup)
    var updateCurrentStrokeAttemptData: ((MainView.StrokeAttemptData?) -> Void)?
    var getCurrentStrokeAttemptData: (() -> MainView.StrokeAttemptData?)?
    var updateFinalDrawing: ((PKDrawing?) -> Void)?
    var setIsPracticeComplete: ((Bool) -> Void)?
    var setIsCanvasInteractionEnabled: ((Bool) -> Void)?
    var prepareForSpeech: ((Int) -> Void)?
    var processCompletedStrokeAttempt: (() -> Void)?
    var showFinalResultsAction: (() -> Void)?
    var moveToNextStrokeAction: (() -> Void)?

    // MARK: - StrokeInputDelegate
    func strokeBegan(at time: Date, strokeType: StrokeType) {
        print("Coordinator: strokeBegan")
        // Clear any previous attempt data to start fresh
        updateCurrentStrokeAttemptData?(nil)
        
        if let controller = strokeInputController {
            // Prepare the speech recognition with the expected stroke name
            prepareForSpeech?(controller.currentStrokeIndex)
            
            // Start recording for this stroke
            do { 
                try speechRecognitionController?.startRecording() 
            } catch {
                print("Coordinator Error: Failed to start speech - \(error)")
                if let idx = strokeInputController?.currentStrokeIndex, 
                   let exp = strokeInputController?.character?.strokes[safe: idx] {
                    let failed = MainView.StrokeAttemptData(
                        strokeIndex: idx, 
                        expectedStroke: exp, 
                        strokeStartTime: time, 
                        strokeEndTime: time, 
                        drawnPoints: [], 
                        transcriptionMatched: false
                    )
                    updateCurrentStrokeAttemptData?(failed)
                    processCompletedStrokeAttempt?()
                }
            }
        }
    }
    func strokeUpdated(points: [CGPoint]) { }
    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int) {
        print("Coordinator: strokeEnded for index \(strokeIndex)")
        guard let startTime = strokeInputController?.strokeStartTime, strokeIndex == strokeInputController?.currentStrokeIndex else { return }
        
        // Create stroke attempt data
        let attempt = MainView.StrokeAttemptData(
            strokeIndex: strokeIndex, 
            expectedStroke: expectedStroke, 
            strokeStartTime: startTime, 
            strokeEndTime: time, 
            drawnPoints: drawnPoints
        )
        updateCurrentStrokeAttemptData?(attempt)
        
        // Notify speech controller to segment based on this stroke timing
        // This will also stop the recording internally
        speechRecognitionController?.processStrokeCompletion(
            strokeIndex: strokeIndex,
            startTime: startTime,
            endTime: time
        )
        
        // Don't call stopRecording again since processStrokeCompletion handles it
        
        // Reduced delay to make the UI more responsive for fast writing
        // Changed from 0.6s to 0.3s to balance between speech processing and UI responsiveness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            // Check if we have speech data yet
            if let data = self.getCurrentStrokeAttemptData?(), data.speechStartTime == nil {
                print("Coordinator: No speech detected for stroke \(strokeIndex) after waiting, processing analysis now.")
                var currentData = data
                currentData.transcriptionMatched = nil
                self.updateCurrentStrokeAttemptData?(currentData)
                self.processCompletedStrokeAttempt?()
            } else { 
                print("Coordinator: Speech data received for stroke \(strokeIndex), analysis will proceed when transcription finalizes.") 
            }
        }
    }
    func allStrokesCompleted() {
        print("Coordinator: allStrokesCompleted")
        DispatchQueue.main.async { self.setIsCanvasInteractionEnabled?(false); self.showFinalResultsAction?() }
    }

    // MARK: - SpeechRecognitionDelegate
    func speechRecordingStarted(at time: Date) {
        print("Coordinator: speechRecordingStarted")
        if var data = getCurrentStrokeAttemptData?(), data.speechStartTime == nil { 
            data.speechStartTime = time
            updateCurrentStrokeAttemptData?(data) 
        }
    }
    func speechRecordingStopped(at time: Date, duration: TimeInterval) { 
        print("Coordinator: speechRecordingStopped") 
    }
    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date) {
        print("Coordinator: speechTranscriptionFinalized. Match: \(matchesExpected), Text: \"\(transcription)\"")
        
        // Force match status to be a concrete boolean instead of optional
        let definitiveMatchStatus = matchesExpected
        
        // When receiving a finalized transcription from segmentation, we need to check
        // if it matches the current stroke index or one we're still processing
        if var data = getCurrentStrokeAttemptData?() {
            // Check if this transcription is for the current stroke or we're still processing it
            let isRelevantForCurrentData = data.strokeIndex == strokeInputController?.currentStrokeIndex || 
                                           data.isReadyForAnalysis == false
            
            if isRelevantForCurrentData {
                // Set concrete values for analysis
                data.speechEndTime = endTime
                data.finalTranscription = transcription
                data.transcriptionMatched = definitiveMatchStatus // Use the definitive boolean
                data.speechConfidence = confidence
                
                print("Coordinator: Setting DEFINITIVE match status: \(definitiveMatchStatus) for stroke \(data.strokeIndex)")
                updateCurrentStrokeAttemptData?(data)
                
                // Only process if we haven't already processed this stroke
                if data.isReadyForAnalysis == false {
                    print("Coordinator: Processing stroke attempt after receiving transcription")
                    processCompletedStrokeAttempt?()
                } else {
                    print("Coordinator: Stroke already processed, updating UI only")
                    
                    // Even if already processed, make sure the UI is updated with the latest match status
                    if let analysisHistory = concurrencyAnalyzer?.analysisHistory {
                        print("Coordinator: Ensuring UI reflects match status = \(definitiveMatchStatus) for transcript: \"\(transcription)\"")
                    }
                }
            } else {
                print("Coordinator: Transcription received for non-current stroke, possibly from segmentation.")
                
                // Check if this is for a previous stroke that wasn't properly processed
                if let strokeController = strokeInputController, 
                   data.strokeIndex < strokeController.currentStrokeIndex {
                    print("Coordinator: Late transcription for previous stroke \(data.strokeIndex), updating history only")
                }
            }
        } else { 
            print("Coordinator: No current stroke attempt data when finalizing transcription.")
        }
    }
    func speechRecognitionErrorOccurred(_ error: Error) {
        print("Coordinator: speechRecognitionErrorOccurred: \(error.localizedDescription)")
        
        // Only handle error for current stroke data that's still waiting for analysis
        if var data = getCurrentStrokeAttemptData?(), data.isReadyForAnalysis == false {
            // Check if this is for the current stroke
            if data.strokeIndex == strokeInputController?.currentStrokeIndex {
                data.transcriptionMatched = false
                data.finalTranscription = "[Error]"
                data.speechEndTime = Date()
                updateCurrentStrokeAttemptData?(data)
                processCompletedStrokeAttempt?()
                print("Coordinator: Processed error for current stroke attempt.")
            } else {
                print("Coordinator: Error occurred for non-current stroke, ignoring.")
            }
        } else {
            print("Coordinator: No pending stroke data when error occurred.")
        }
    }
    func speechRecognitionNotAvailable() {
        print("Coordinator: speechRecognitionNotAvailable.")
        
        // Only mark as N/A for current stroke data that's still waiting for analysis
        if var data = getCurrentStrokeAttemptData?(), data.isReadyForAnalysis == false {
            if data.strokeIndex == strokeInputController?.currentStrokeIndex {
                data.transcriptionMatched = nil
                data.finalTranscription = "[N/A]"
                data.speechEndTime = Date()
                updateCurrentStrokeAttemptData?(data)
                processCompletedStrokeAttempt?()
                print("Coordinator: Processed unavailability for current stroke attempt.")
            } else {
                print("Coordinator: Unavailability notification for non-current stroke, ignoring.")
            }
        } else {
            print("Coordinator: No pending stroke data when unavailability notification received.")
        }
    }
    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus) { print("Coordinator: speechAuthorizationDidChange: \(status)") }

    // MARK: - ConcurrencyAnalyzerDelegate
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback) {
        print("Coordinator: strokeAnalysisCompleted for index \(timingData.strokeIndex).")
        DispatchQueue.main.async {
            self.feedbackController?.recordStrokeFeedback(index: timingData.strokeIndex, feedback: feedback)
            self.updateCurrentStrokeAttemptData?(nil) // Clear after analysis
            // Check interaction status before moving (important!)
             if self.strokeInputController?.isDrawing == false { // Ensure drawing actually finished
                 self.moveToNextStrokeAction?() // Move immediately
             } else {
                 print("Coordinator: Interaction likely disabled or still drawing, not moving to next stroke.")
             }
        }
    }

    // Iterate original drawing strokes for coloring
    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String) {
        print("Coordinator: overallAnalysisCompleted. Score: \(overallScore)")
        print("Coordinator: Processing final drawing feedback...")

        guard let finalDrawing = pkCanvasView?.drawing, let history = concurrencyAnalyzer?.analysisHistory else {
             print("Coordinator Error: Missing canvas drawing or analysis history for final feedback.")
             DispatchQueue.main.async { self.setIsPracticeComplete?(true) } // Still mark as complete
             return
        }

        var strokesWithFeedback: [PKStroke] = []
        let accuracyThreshold = 60.0  // Accuracy threshold for stroke color
        let inaccurateColor = UIColor.red
        let accurateColor = UIColor.systemGreen

        // Iterate through the actual strokes drawn by the user
        for (index, drawnStroke) in finalDrawing.strokes.enumerated() {
            var newStroke = drawnStroke // Copy the stroke
            // Find analysis data for this stroke index, if it exists
            if let analysisData = history.first(where: { $0.strokeIndex == index }) {
                // Color based ONLY on stroke accuracy, independent of speech/pronunciation results
                let strokeAccuracy = analysisData.strokeAccuracy
                let targetColor = strokeAccuracy < accuracyThreshold ? inaccurateColor : accurateColor
                newStroke.ink = PKInk(newStroke.ink.inkType, color: targetColor)
                print("  Coordinator: Coloring stroke \(index) \(strokeAccuracy < accuracyThreshold ? "RED" : "GREEN") (accuracy: \(String(format: "%.1f", strokeAccuracy)))")
            } else {
                // Keep original color if no analysis data (e.g., extra strokes)
                print("  Coordinator: Keeping original color for stroke \(index) (no analysis data).")
            }
            strokesWithFeedback.append(newStroke) // Append original or colored stroke
        }

        let finalFeedbackDrawing = PKDrawing(strokes: strokesWithFeedback)

        DispatchQueue.main.async {
            self.feedbackController?.calculateAndPresentOverallFeedback(score: overallScore, breakdown: breakdown, message: feedback)
            self.updateFinalDrawing?(finalFeedbackDrawing) // Update state via closure
            self.setIsPracticeComplete?(true)             // Update state via closure
            self.updateCurrentStrokeAttemptData?(nil)      // Ensure cleared
            print("  Coordinator: Final feedback generated. Interaction remains disabled.")
        }
    }
}


// MARK: - MainView Struct
struct MainView: View {
    // MARK: - Environment and State Objects
    @EnvironmentObject var characterDataManager: CharacterDataManager
    @StateObject private var strokeInputController = StrokeInputController()
    @StateObject private var speechRecognitionController = SpeechRecognitionController()
    @StateObject private var concurrencyAnalyzer = ConcurrencyAnalyzer()
    @StateObject private var feedbackController = FeedbackController()
    @StateObject private var delegateCoordinator = DelegateCoordinator() // Coordinator

    @State private var pkCanvasView = PKCanvasView()
    @State private var selectedCharacterIndex = 0
    @State private var currentStrokeAttemptData: StrokeAttemptData? = nil
    @State private var finalDrawingWithFeedback: PKDrawing? = nil
    @State private var isCharacterPracticeComplete: Bool = false
    @State private var isCanvasInteractionEnabled: Bool = true
    @State private var showRealtimeTranscript: Bool = true // Default to showing transcript

    // Temporary storage struct (Definition remains)
    struct StrokeAttemptData { /* ... as before ... */
        let strokeIndex: Int; let expectedStroke: Stroke; let strokeStartTime: Date; let strokeEndTime: Date
        let drawnPoints: [CGPoint]; var speechStartTime: Date? = nil; var speechEndTime: Date? = nil
        var finalTranscription: String? = nil; var transcriptionMatched: Bool? = nil
        var speechConfidence: Float? = nil
        var isReadyForAnalysis: Bool { return speechStartTime == nil || transcriptionMatched != nil }
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    HStack {
                        Text("Show Real-time Transcript")
                            .font(.subheadline)
                        
                        Toggle("", isOn: $showRealtimeTranscript)
                            .labelsHidden()
                    }
                    .tint(.blue)
                    .padding(.vertical, 4)
                    .padding(.horizontal)
                }
                HStack(spacing: 0) {
                    referencePanel(geometry: geometry)
                    Divider()
                    writingPanel(geometry: geometry, isInteractionEnabled: isCanvasInteractionEnabled, onTapToWriteAgain: resetForNewCharacterAttempt)
                }
                .frame(maxHeight: .infinity)
            }
            .environmentObject(characterDataManager)
            .onAppear(perform: initialSetup)
            .onChange(of: characterDataManager.currentCharacter?.id) { oldId, newId in if oldId != newId { if let newChar = characterDataManager.currentCharacter, let idx = characterDataManager.characters.firstIndex(where: { $0.id == newChar.id }) { selectedCharacterIndex = idx }; handleCharacterChange(character: characterDataManager.currentCharacter) } }
            .onChange(of: characterDataManager.characters) { oldChars, newChars in if oldChars.isEmpty && !newChars.isEmpty && characterDataManager.currentCharacter == nil { initialSetup() } }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    // MARK: - Subviews (Unchanged)
    @ViewBuilder private func referencePanel(geometry: GeometryProxy) -> some View {
       VStack(spacing: 0) {
             Text("Characters Selection")
                .font(.headline)
                .padding(.vertical, 8)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
             CharacterSelectionView(selectedIndex: $selectedCharacterIndex, characters: characterDataManager.characters, onSelect: { index in self.selectedCharacterIndex = index; if index >= 0 && index < self.characterDataManager.characters.count { self.characterDataManager.selectCharacter(withId: self.characterDataManager.characters[index].id) } }).padding(.vertical).background(Color(UIColor.secondarySystemBackground)).frame(minHeight: 80); Divider()
             GeometryReader { refGeo in ReferenceView(character: characterDataManager.currentCharacter).frame(width: refGeo.size.width, height: refGeo.size.height) }.frame(maxWidth: .infinity, maxHeight: .infinity)
         }.frame(width: geometry.size.width * 0.40).background(Color(UIColor.systemBackground))
    }
    @ViewBuilder private func writingPanel(geometry: GeometryProxy, isInteractionEnabled: Bool, onTapToWriteAgain: @escaping () -> Void) -> some View {
        WritingPaneView(
            pkCanvasView: $pkCanvasView, 
            character: characterDataManager.currentCharacter, 
            strokeInputController: strokeInputController, 
            currentStrokeIndex: strokeInputController.currentStrokeIndex, 
            isPracticeComplete: isCharacterPracticeComplete, 
            analysisHistory: concurrencyAnalyzer.analysisHistory, 
            finalDrawingWithFeedback: finalDrawingWithFeedback, 
            isInteractionEnabled: isInteractionEnabled,
            onTapToWriteAgain: onTapToWriteAgain,
            showRealtimeTranscript: showRealtimeTranscript,
            realtimeTranscript: speechRecognitionController.recognizedTextFragment
        )
        .frame(width: geometry.size.width * 0.60)
    }


    // MARK: - Setup & Lifecycle (Unchanged)
    private func initialSetup() {
        print("MainView: initialSetup")
        // Setup Coordinator
        delegateCoordinator.strokeInputController = self.strokeInputController; delegateCoordinator.speechRecognitionController = self.speechRecognitionController
        delegateCoordinator.concurrencyAnalyzer = self.concurrencyAnalyzer; delegateCoordinator.feedbackController = self.feedbackController
        delegateCoordinator.pkCanvasView = self.pkCanvasView
        // Provide closures for state modification (No weak self)
        delegateCoordinator.updateCurrentStrokeAttemptData = { data in self.currentStrokeAttemptData = data }
        delegateCoordinator.getCurrentStrokeAttemptData = { return self.currentStrokeAttemptData }
        delegateCoordinator.updateFinalDrawing = { drawing in self.finalDrawingWithFeedback = drawing }
        delegateCoordinator.setIsPracticeComplete = { complete in self.isCharacterPracticeComplete = complete }
        delegateCoordinator.setIsCanvasInteractionEnabled = { enabled in self.isCanvasInteractionEnabled = enabled }
        // Provide closures for actions (No weak self)
        delegateCoordinator.prepareForSpeech = { index in self.prepareForSpeech(strokeIndex: index) }
        delegateCoordinator.processCompletedStrokeAttempt = { self.processCompletedStrokeAttempt() }
        delegateCoordinator.showFinalResultsAction = { self.showFinalResultsAction() }
        delegateCoordinator.moveToNextStrokeAction = { self.moveToNextStrokeAction() }
        // Assign coordinator as the delegate
        strokeInputController.delegate = delegateCoordinator; speechRecognitionController.delegate = delegateCoordinator; concurrencyAnalyzer.delegate = delegateCoordinator
        print("MainView: Delegates assigned to Coordinator.")
        // Initial character selection logic
         if !characterDataManager.characters.isEmpty && characterDataManager.currentCharacter == nil { selectedCharacterIndex = 0; characterDataManager.currentCharacter = characterDataManager.characters[0] }
         else if let currentChar = characterDataManager.currentCharacter { if let idx = characterDataManager.characters.firstIndex(of: currentChar) { selectedCharacterIndex = idx }; handleCharacterChange(character: currentChar) }
         else { handleCharacterChange(character: nil) }
    }

    // Character change handling (unchanged logic)
    private func handleCharacterChange(character: Character?) {
        guard let character = character, !character.strokes.isEmpty else {
            pkCanvasView.drawing = PKDrawing(); strokeInputController.setup(with: pkCanvasView, for: .empty); concurrencyAnalyzer.setup(for: .empty); speechRecognitionController.configure(with: .empty)
            feedbackController.reset(); currentStrokeAttemptData = nil; finalDrawingWithFeedback = nil; isCharacterPracticeComplete = false; isCanvasInteractionEnabled = false; return
        }
        resetForNewCharacterAttempt()
    }

    // MARK: - Actions (Called via closures from Coordinator now)
    func resetForNewCharacterAttempt() {
        print("MainView: resetForNewCharacterAttempt called.")
        guard let character = characterDataManager.currentCharacter else { return }
        strokeInputController.setup(with: pkCanvasView, for: character); speechRecognitionController.configure(with: character); concurrencyAnalyzer.setup(for: character); feedbackController.reset()
        pkCanvasView.drawing = PKDrawing(); currentStrokeAttemptData = nil; finalDrawingWithFeedback = nil; isCharacterPracticeComplete = false; isCanvasInteractionEnabled = true
        if !character.strokes.isEmpty { prepareForSpeech(strokeIndex: 0) }
    }
    func moveToNextStrokeAction() {
        print("MainView: moveToNextStrokeAction called.")
        let idxBefore = strokeInputController.currentStrokeIndex
        let shouldPrepare = strokeInputController.checkCompletionAndAdvance(indexJustCompleted: idxBefore)
        if shouldPrepare { prepareForSpeech(strokeIndex: strokeInputController.currentStrokeIndex) }
    }
    func showFinalResultsAction() {
        print("MainView: showFinalResultsAction called.")
        concurrencyAnalyzer.calculateFinalCharacterScore()
    }
    func prepareForSpeech(strokeIndex: Int) {
        print("MainView: prepareForSpeech called for index \(strokeIndex).")
        guard let char = characterDataManager.currentCharacter, let stroke = char.strokes[safe: strokeIndex] else { return }
        speechRecognitionController.prepareForStroke(expectedName: stroke.name)
    }
    func processCompletedStrokeAttempt() {
        print("MainView: processCompletedStrokeAttempt called.")
        
        guard let attemptData = self.currentStrokeAttemptData, attemptData.isReadyForAnalysis else {
            print("MainView: Attempt data not ready for analysis yet")
            return
        }
        
        print("MainView: Processing completed stroke attempt for index \(attemptData.strokeIndex)")
        
        // Move the heavy stroke analysis calculation to a background queue
        // This prevents UI blockage during fast writing
        DispatchQueue.global(qos: .userInitiated).async {
            // Calculate stroke accuracy (computationally intensive)
            let accuracy = StrokeAnalysis.calculateAccuracy(
                drawnPoints: attemptData.drawnPoints, 
                expectedStroke: attemptData.expectedStroke
            )
            
            // Create analysis input with all data
            let input = StrokeAnalysisInput(
                strokeIndex: attemptData.strokeIndex, 
                expectedStroke: attemptData.expectedStroke, 
                strokeStartTime: attemptData.strokeStartTime, 
                strokeEndTime: attemptData.strokeEndTime,
                strokeAccuracy: accuracy, 
                speechStartTime: attemptData.speechStartTime, 
                speechEndTime: attemptData.speechEndTime, 
                finalTranscription: attemptData.finalTranscription,
                transcriptionMatched: attemptData.transcriptionMatched, 
                speechConfidence: attemptData.speechConfidence
            )
            
            // Back to main thread to update UI and send to analyzer
            DispatchQueue.main.async {
                // Send to analyzer for processing
                self.concurrencyAnalyzer.analyzeStroke(input: input)
                print("MainView: Sent stroke \(attemptData.strokeIndex) for analysis")
            }
        }
    }
}

// REMOVED: Delegate conformance extensions for MainView
