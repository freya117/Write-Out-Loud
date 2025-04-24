// File: Views/MainView.swift
// VERSION: Modified to handle final stroke feedback correctly

import SwiftUI
import PencilKit
import Speech // Required for SFSpeechRecognizerAuthorizationStatus

struct MainView: View {
    // MARK: - Environment and State Objects
    @EnvironmentObject var characterDataManager: CharacterDataManager
    @StateObject private var strokeInputController = StrokeInputController()
    @StateObject private var speechRecognitionController = SpeechRecognitionController()
    @StateObject private var concurrencyAnalyzer = ConcurrencyAnalyzer()
    @StateObject private var feedbackController = FeedbackController() // Owned by MainView

    // State for the PKCanvasView instance
    @State private var pkCanvasView = PKCanvasView()
    // State to track selection in CharacterSelectionView
    @State private var selectedCharacterIndex = 0

    // State for stroke attempt data
    @State private var currentStrokeAttemptData: StrokeAttemptData? = nil

    // Temporary storage for stroke attempt data
    struct StrokeAttemptData {
        let strokeIndex: Int
        let expectedStroke: Stroke
        let strokeStartTime: Date
        let strokeEndTime: Date
        let drawnPoints: [CGPoint]
        var speechStartTime: Date? = nil
        var speechEndTime: Date? = nil
        var finalTranscription: String? = nil
        var transcriptionMatched: Bool? = nil
        var speechConfidence: Float? = nil

        var isReadyForAnalysis: Bool {
            // Ready if speech wasn't started OR if speech was started and we have a result (matched != nil)
            return speechStartTime == nil || transcriptionMatched != nil
        }
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                referencePanel(geometry: geometry)
                Divider()
                writingPanel(geometry: geometry)
            }
            .environmentObject(characterDataManager)
            .overlay(feedbackOverlay()) // Apply overlay
            .environmentObject(feedbackController) // Inject FeedbackController for overlay
            .onAppear(perform: initialSetup)
            .onChange(of: characterDataManager.currentCharacter?.id) { oldId, newId in
                 if oldId != newId {
                     // Update selectedCharacterIndex to match data manager's current character
                     if let newChar = characterDataManager.currentCharacter,
                        let newIdx = characterDataManager.characters.firstIndex(where: { $0.id == newChar.id }) {
                         selectedCharacterIndex = newIdx
                     }
                     handleCharacterChange(character: characterDataManager.currentCharacter)
                 }
            }
            .onChange(of: characterDataManager.characters) { oldChars, newChars in
                 print("Character list changed. Count: \(newChars.count)")
                 if oldChars.isEmpty && !newChars.isEmpty && characterDataManager.currentCharacter == nil {
                     print("Characters loaded after initial appear, running setup.")
                     initialSetup() // Re-run setup if characters load later
                 }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    // MARK: - Subviews (Reference Panel, Writing Panel - Unchanged from your provided code)
     @ViewBuilder
     private func referencePanel(geometry: GeometryProxy) -> some View {
         VStack(spacing: 0) {
             // Character Selection Bar at the top
             CharacterSelectionView(
                 selectedIndex: $selectedCharacterIndex,
                 characters: characterDataManager.characters,
                 onSelect: { index in
                     // Update state and data manager when selection changes
                     self.selectedCharacterIndex = index
                     if index >= 0 && index < self.characterDataManager.characters.count {
                         let character = self.characterDataManager.characters[index]
                         // Let data manager handle setting the current character
                         // This triggers the .onChange(of: characterDataManager.currentCharacter) handler
                         self.characterDataManager.selectCharacter(withId: character.id)
                     }
                 }
             )
             .padding(.vertical)
             .background(Color(UIColor.secondarySystemBackground))
             .frame(minHeight: 80)

             Divider()

             // Reference View fills the remaining space
             GeometryReader { referenceGeometry in
                 ReferenceView(character: characterDataManager.currentCharacter)
                     .frame(width: referenceGeometry.size.width, height: referenceGeometry.size.height)
             }
             .frame(maxWidth: .infinity, maxHeight: .infinity)

         }
         .frame(width: geometry.size.width * 0.45) // Adjust panel width as needed
         .background(Color(UIColor.systemBackground)) // Ensure panel has background
     }


    @ViewBuilder
    private func writingPanel(geometry: GeometryProxy) -> some View {
        WritingPaneView(
            pkCanvasView: $pkCanvasView,
            character: characterDataManager.currentCharacter,
            strokeInputController: strokeInputController // Pass the controller if needed by WritingPaneView
        )
        .frame(width: geometry.size.width * 0.55) // Adjust panel width as needed
    }

    // MARK: - Feedback Overlay (MODIFIED)
    @ViewBuilder
    private func feedbackOverlay() -> some View {
        // Show overlay only when feedbackController signals
        if feedbackController.showFeedbackView {
            // Dimmed background, dismisses stroke feedback on tap
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow background tap ONLY to dismiss intermediate stroke feedback
                    if feedbackController.feedbackType == .stroke {
                        // --- MODIFICATION: Only dismiss if NOT the last stroke ---
                        let isLastStroke = (strokeInputController.currentStrokeIndex == (characterDataManager.currentCharacter?.strokeCount ?? 0) - 1)
                        if !isLastStroke {
                            feedbackController.dismissFeedback()
                             // Should we automatically move to next stroke on tap?
                             // self.moveToNextStrokeAction() // Maybe not - require button press
                            print("Feedback Overlay: Background tap dismissed intermediate stroke feedback.")
                        } else {
                             print("Feedback Overlay: Background tap ignored for final stroke feedback.")
                        }
                        // --- END MODIFICATION ---
                    }
                     // Do not dismiss overall feedback on background tap
                }

            // The actual FeedbackView content
            FeedbackView(
                // --- MODIFIED: Pass stroke index and total ---
                strokeIndex: feedbackController.feedbackType == .stroke ? strokeInputController.currentStrokeIndex : nil,
                totalStrokes: characterDataManager.currentCharacter?.strokeCount,
                // --- END MODIFICATION ---

                // Action when "Continue" is pressed after an intermediate stroke
                onContinue: {
                    self.moveToNextStrokeAction()
                },
                // Action when "Show Final Results" is pressed after the *final* stroke
                onShowFinalResults: {
                    self.showFinalResultsAction()
                },
                // Action when "Try Again" is pressed after overall feedback
                onTryAgain: {
                    self.resetForNewCharacterAttempt()
                },
                // Action when the explicit 'X' close button is tapped (on overall feedback)
                onClose: {
                    // Just dismisses, no other action needed here as Try Again handles reset
                    // feedbackController.dismissFeedback() // Already handled by FeedbackView's button
                    print("Feedback Overlay: Close action triggered.")
                }
            )
            // Provide the FeedbackController to the FeedbackView environment
            .environmentObject(feedbackController)
        }
    }


    // MARK: - Setup & Lifecycle (Unchanged)
    private func initialSetup() {
        print("MainView appeared. Setting up delegates.")
        strokeInputController.delegate = self
        speechRecognitionController.delegate = self
        concurrencyAnalyzer.delegate = self

        // Ensure initial character is selected and setup if data is available
        if !characterDataManager.characters.isEmpty && characterDataManager.currentCharacter == nil {
            print("Initial setup: Selecting first character.")
            selectedCharacterIndex = 0 // Make sure index matches
            let firstChar = characterDataManager.characters[0]
            // Set character in data manager, which will trigger onChange handler
            characterDataManager.selectCharacter(withId: firstChar.id)
            // handleCharacterChange(character: firstChar) // Let onChange handle it
        } else if let currentChar = characterDataManager.currentCharacter {
            print("Initial setup: Character already selected, ensuring setup.")
            // Ensure selectedCharacterIndex reflects the current character
            if let currentIndex = characterDataManager.characters.firstIndex(of: currentChar) {
                selectedCharacterIndex = currentIndex
            }
            // Ensure controllers are configured for the existing character
            handleCharacterChange(character: currentChar)
        } else {
            print("Initial setup: No characters loaded yet.")
            // Clear state if no character is available
            handleCharacterChange(character: nil)
        }
    }

    // Handles changes when a new character is selected (Unchanged)
    private func handleCharacterChange(character: Character?) {
        guard let character = character, !character.strokes.isEmpty else {
            print("Handle character change: No character selected or character has no strokes - clearing state.")
            pkCanvasView.drawing = PKDrawing() // Clear canvas
            // Setup controllers with empty character to reset them
            strokeInputController.setup(with: pkCanvasView, for: Character.empty)
            concurrencyAnalyzer.setup(for: Character.empty)
            speechRecognitionController.configure(with: Character.empty)
            feedbackController.reset()
            currentStrokeAttemptData = nil
            return
        }
        print("Handling character change to: \(character.character)")
        // Reset state for the new character attempt
        resetForNewCharacterAttempt()
    }

    // MARK: - Actions

    // Unchanged
    private func resetForNewCharacterAttempt() {
        guard let character = characterDataManager.currentCharacter else { return }
        print("Resetting for new attempt at character: \(character.character)")
        // Reset controllers and UI for the selected character
        strokeInputController.setup(with: pkCanvasView, for: character) // This sets controller index to 0
        strokeInputController.resetCanvas() // Clear drawing
        speechRecognitionController.configure(with: character)
        concurrencyAnalyzer.setup(for: character)
        feedbackController.reset() // Hide any existing feedback
        currentStrokeAttemptData = nil // Clear any pending attempt data

        // Prepare speech for the first stroke (index 0)
        if !character.strokes.isEmpty {
            prepareForSpeech(strokeIndex: 0) // strokeInputController index is 0 now
        } else {
            print("Character \(character.character) has no strokes to practice.")
        }
    }

    // Action to advance to the next stroke (Unchanged from your provided code)
    private func moveToNextStrokeAction() {
        // Get the index of the stroke that was just completed
        let indexJustCompleted = strokeInputController.currentStrokeIndex
        print("=========================================")
        print(">>> MainView.moveToNextStrokeAction: Called.")
        print("    Index Just Completed: \(indexJustCompleted)")
        print("=========================================")

        // Ask the controller to check completion based on the index just completed
        // and advance its internal state *only* if necessary.
        // We don't rely on its return value to trigger completion anymore.
        _ = strokeInputController.checkCompletionAndAdvance(indexJustCompleted: indexJustCompleted)

        // Get the potentially updated index for the *next* stroke
        let nextIndex = strokeInputController.currentStrokeIndex

        // Ensure we don't try to prepare speech beyond the last stroke
        if let totalStrokes = characterDataManager.currentCharacter?.strokeCount, nextIndex < totalStrokes {
            print("<<< MainView.moveToNextStrokeAction: Preparing for next stroke at index \(nextIndex).")
            // Reset the canvas visually
            strokeInputController.resetCanvas()
            // Prepare speech for the NEW index
            prepareForSpeech(strokeIndex: nextIndex)
        } else {
             print("<<< MainView.moveToNextStrokeAction: Reached end or invalid state. Next index: \(nextIndex)")
             // If checkCompletionAndAdvance detected completion, the onShowFinalResults action
             // should be triggered by the button press now, not here.
        }
    }

    // Unchanged
    private func showFinalResultsAction() {
        print(">>> MainView.showFinalResultsAction called.")
        // Ensure any lingering drawing is cleared before showing results
        strokeInputController.resetCanvas()
        // Trigger the final score calculation and display
        concurrencyAnalyzer.calculateFinalCharacterScore()
    }

    // Renamed for clarity (Unchanged from your provided code)
    private func prepareForSpeech(strokeIndex: Int) {
        guard let character = characterDataManager.currentCharacter,
              let stroke = character.strokes[safe: strokeIndex] else {
            print("MainView.prepareForSpeech: Cannot prepare, invalid character or index \(strokeIndex)")
            return
        }
        print("MainView.prepareForSpeech: Preparing speech for index \(strokeIndex), Name: '\(stroke.name)'")
        speechRecognitionController.prepareForStroke(expectedName: stroke.name)
    }

    // Unchanged
    private func processCompletedStrokeAttempt() {
        guard let attemptData = self.currentStrokeAttemptData else {
            print("Error: processCompletedStrokeAttempt called with nil attemptData.")
            return
        }
        guard attemptData.isReadyForAnalysis else {
             print("Attempt data not ready for analysis yet (waiting for speech?).")
             return
         }

        print("Processing completed stroke attempt for index: \(attemptData.strokeIndex)")

        // Calculate stroke accuracy
        let strokeAccuracy = StrokeAnalysis.calculateAccuracy(
            drawnPoints: attemptData.drawnPoints, expectedStroke: attemptData.expectedStroke
        )
        print("  - Stroke Accuracy Calculated: \(strokeAccuracy)")

        // Prepare input for concurrency analysis
        let analysisInput = StrokeAnalysisInput(
            strokeIndex: attemptData.strokeIndex,
            expectedStroke: attemptData.expectedStroke,
            strokeStartTime: attemptData.strokeStartTime,
            strokeEndTime: attemptData.strokeEndTime,
            strokeAccuracy: strokeAccuracy,
            speechStartTime: attemptData.speechStartTime,
            speechEndTime: attemptData.speechEndTime,
            finalTranscription: attemptData.finalTranscription,
            transcriptionMatched: attemptData.transcriptionMatched,
            speechConfidence: attemptData.speechConfidence
        )

        // Perform the analysis
        concurrencyAnalyzer.analyzeStroke(input: analysisInput)

        // Clear the temporary data on the main thread
        DispatchQueue.main.async {
            self.currentStrokeAttemptData = nil
            print("  - Cleared currentStrokeAttemptData")
        }
    }

} // End of struct MainView


// MARK: - Delegate Conformance
// ==============================================================================
// StrokeInputDelegate Implementation (MODIFIED allStrokesCompleted)
extension MainView: StrokeInputDelegate {
    func strokeBegan(at time: Date, strokeType: StrokeType) {
        print("MainView: strokeBegan delegate called.")
        self.currentStrokeAttemptData = nil // Clear previous attempt data
        // Prepare speech for the stroke we are *about* to draw
        // The controller's current index should be correct here
        prepareForSpeech(strokeIndex: strokeInputController.currentStrokeIndex)
        // Start recording
        do {
            try speechRecognitionController.startRecording()
            print("  - Speech recording started successfully.")
        } catch {
            print("  - Error starting speech recording: \(error.localizedDescription)")
            // Optionally handle error (e.g., show alert)
        }
    }

    func strokeUpdated(points: [CGPoint]) {
        // Can be used for live drawing feedback if needed
    }

    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int) {
        let controllerIndex = strokeInputController.currentStrokeIndex
        print("-----------------------------------------")
        print(">>> MainView.strokeEnded: Delegate called.")
        print("    Delegate Index (Just Ended): \(strokeIndex)")
        print("    Controller Index (Current State): \(controllerIndex)")
        print("-----------------------------------------")

        // Ensure delegate index matches controller's current state before proceeding
        guard strokeIndex == controllerIndex else {
             print("  - Error: strokeEnded index (\(strokeIndex)) mismatch with controller index (\(controllerIndex)). Possible race condition or stale event. Ignoring.")
             return
        }

        guard let strokeStartTime = strokeInputController.strokeStartTime else {
             print("  - Error: Stroke ended but start time is missing.")
             // Maybe try to recover or just ignore?
             return
        }

        // Create the attempt data structure
        self.currentStrokeAttemptData = StrokeAttemptData(
            strokeIndex: strokeIndex,
            expectedStroke: expectedStroke,
            strokeStartTime: strokeStartTime,
            strokeEndTime: time,
            drawnPoints: drawnPoints
        )
        print("  - Created StrokeAttemptData with stroke info.")

        // Stop speech recording; the result will come via delegate
        speechRecognitionController.stopRecording()
        print("  - Called stopRecording on speech controller.")

        // If speech recording never successfully started (e.g., no mic permission, immediate stop),
        // process the attempt now. Otherwise, wait for speech result delegate.
        // Check if speechStartTime was ever set in the attempt data.
        if self.currentStrokeAttemptData?.speechStartTime == nil {
             print("  - No speech start time recorded for this stroke, processing analysis now.")
             processCompletedStrokeAttempt()
        } else {
             print("  - Waiting for speech transcription result...")
        }
    }

    // --- MODIFIED: Simplify this delegate method ---
    // This is called by StrokeInputController's checkCompletionAndAdvance when the last stroke is identified.
    // We no longer trigger the final results from here directly.
    func allStrokesCompleted() {
        print(">>> MainView: allStrokesCompleted delegate called (Informational).")
        // The final results display is now triggered by the user pressing the
        // 'Show Final Results' button in the FeedbackView after the last stroke's feedback.
        // No action needed here anymore.
    }
    // --- END MODIFICATION ---
}
// ==============================================================================

// SpeechRecognitionDelegate Implementation (Unchanged)
extension MainView: SpeechRecognitionDelegate {
    func speechRecordingStarted(at time: Date) {
        print("MainView: speechRecordingStarted delegate called.")
        // Update attempt data only if it exists (strokeBegan should have created it)
        guard self.currentStrokeAttemptData != nil else {
             print("  - Warning: Speech started but currentStrokeAttemptData is nil.")
             // This might happen if speech starts *before* strokeBegan finishes, though unlikely.
             return
        }
        // Ensure this isn't overwriting an existing start time unless nil
        if self.currentStrokeAttemptData?.speechStartTime == nil {
            self.currentStrokeAttemptData?.speechStartTime = time
            print("  - Updated attempt data with speech start time.")
        } else {
            print("  - Warning: Speech start time already exists, ignoring subsequent start event.")
        }
    }

    func speechRecordingStopped(at time: Date, duration: TimeInterval) {
        print("MainView: speechRecordingStopped delegate called. Duration: \(String(format: "%.2f", duration))s")
        // Usually no action needed here, we wait for finalized transcription.
    }

    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date) {
        print("MainView: speechTranscriptionFinalized delegate called.")
        print("  - Transcription: '\(transcription)', Match: \(matchesExpected), Confidence: \(confidence)")

        // Ensure we have attempt data to update
        guard self.currentStrokeAttemptData != nil else {
            print("  - Warning: Received speech result but currentStrokeAttemptData is nil. Ignoring.")
            return
        }

        // Add check to ensure this result corresponds to the current stroke index being processed
        // If currentStrokeAttemptData exists, its index should match the controller's index *at the time strokeEnded was called*.
        guard self.currentStrokeAttemptData?.strokeIndex == strokeInputController.currentStrokeIndex else {
            print("  - Warning: Received speech result for index \(self.currentStrokeAttemptData?.strokeIndex ?? -1) but controller is now at index \(strokeInputController.currentStrokeIndex). Ignoring potentially stale result.")
            // Clear potentially stale data to prevent mis-processing
            // self.currentStrokeAttemptData = nil // Or just return
            return
        }

        // Update the attempt data with speech results
        self.currentStrokeAttemptData?.speechStartTime = startTime // Use actual start time from speech result if available
        self.currentStrokeAttemptData?.speechEndTime = endTime
        self.currentStrokeAttemptData?.finalTranscription = transcription
        self.currentStrokeAttemptData?.transcriptionMatched = matchesExpected
        self.currentStrokeAttemptData?.speechConfidence = confidence
        print("  - Updated attempt data with speech results.")

        // Now that speech result is in, process the completed stroke attempt
        processCompletedStrokeAttempt()
    }

    func speechRecognitionErrorOccurred(_ error: Error) {
        print("MainView: speechRecognitionErrorOccurred delegate called. Error: \(error.localizedDescription)")
        // If we were waiting for a speech result for the current stroke, handle the error
        if self.currentStrokeAttemptData != nil && self.currentStrokeAttemptData?.isReadyForAnalysis == false {
             print("  - Marking speech as failed (transcriptionMatched=false) due to error.")
             // Update attempt data to reflect the error
             self.currentStrokeAttemptData?.transcriptionMatched = false // Indicate failure
             self.currentStrokeAttemptData?.finalTranscription = "[Error]" // Or specific error message
             self.currentStrokeAttemptData?.speechEndTime = Date() // Mark end time as now
             self.currentStrokeAttemptData?.speechConfidence = 0.0

             // Process the attempt with the error information
             processCompletedStrokeAttempt()
        } else {
             print("  - Speech error occurred, but no pending stroke attempt or attempt already processed.")
        }
    }

    func speechRecognitionNotAvailable() {
        print("MainView: speechRecognitionNotAvailable delegate called.")
        // Similar to error handling, update attempt data if waiting for speech
         if self.currentStrokeAttemptData != nil && self.currentStrokeAttemptData?.isReadyForAnalysis == false {
             print("  - Marking speech as unavailable (transcriptionMatched=nil).")
             self.currentStrokeAttemptData?.transcriptionMatched = nil // Use nil for unavailable? Or false? Let's use nil.
             self.currentStrokeAttemptData?.finalTranscription = "[Not Available]"
             self.currentStrokeAttemptData?.speechEndTime = Date()
             self.currentStrokeAttemptData?.speechConfidence = 0.0
             processCompletedStrokeAttempt()
         }
    }

    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus) {
        print("MainView: speechAuthorizationDidChange delegate called. Status: \(status)")
        // Optionally update UI or show alerts based on status change
    }
}
// ==============================================================================

// ConcurrencyAnalyzerDelegate Implementation (Unchanged)
extension MainView: ConcurrencyAnalyzerDelegate {
    // This is called AFTER ConcurrencyAnalyzer finishes processing a single stroke
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback) {
        print("MainView: strokeAnalysisCompleted delegate called for index \(timingData.strokeIndex).")
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async {
            // Present the feedback for this specific stroke
            self.feedbackController.presentStrokeFeedback(index: timingData.strokeIndex, feedback: feedback)
            print("  - Called presentStrokeFeedback on feedback controller.")
            // *** IMPORTANT: The check for last stroke and triggering final results
            // *** is now handled by the FeedbackView's button actions based on index/total.
        }
    }

    // This is called AFTER ConcurrencyAnalyzer finishes calculating the overall score
    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String) {
        print("MainView: overallAnalysisCompleted delegate called. Score: \(overallScore)")
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async {
            // Present the final overall feedback
            self.feedbackController.presentOverallFeedback(score: overallScore, breakdown: breakdown, message: feedback)
            print("  - Called presentOverallFeedback on feedback controller.")
        }
    }
}
// ==============================================================================
