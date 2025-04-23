// File: Views/MainView.swift
import SwiftUI
import PencilKit
import Speech // Required for SFSpeechRecognizerAuthorizationStatus

/**
 The main container view for the application using SwiftUI.
 It orchestrates the interaction between the data manager, input controllers,
 analysis controller, feedback controller, and the subviews.
 It acts as the delegate for input and analysis controllers.
 */
struct MainView: View {
    // MARK: - Environment and State Objects
    // Assuming CharacterDataManager is provided by the App's root view
    @EnvironmentObject var characterDataManager: CharacterDataManager
    @StateObject private var strokeInputController = StrokeInputController()
    @StateObject private var speechRecognitionController = SpeechRecognitionController()
    @StateObject private var concurrencyAnalyzer = ConcurrencyAnalyzer()
    @StateObject private var feedbackController = FeedbackController()

    // State for the PKCanvasView instance
    @State private var pkCanvasView = PKCanvasView()
    // State to track selection in CharacterSelectionView
    @State private var selectedCharacterIndex = 0

    // MARK: - Temporary State for Stroke/Speech Data
    @State private var currentStrokeAttemptData: StrokeAttemptData? = nil

    // Helper struct to hold data during processing
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
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Panel (Reference)
                referencePanel(geometry: geometry)
                Divider()
                // Right Panel (Writing)
                writingPanel(geometry: geometry)
            }
            // Provide FeedbackController down the hierarchy
            .environmentObject(feedbackController)
            // Show feedback view as an overlay
            .overlay(feedbackOverlay())
            // Perform initial setup when the view appears
            .onAppear(perform: initialSetup)
            // React to changes in the selected character ID
            .onChange(of: characterDataManager.currentCharacter?.id) { oldId, newId in
                 // Only trigger reset if the ID actually changed
                 if oldId != newId {
                     handleCharacterChange(character: characterDataManager.currentCharacter)
                 }
            }
            // Ignore keyboard safe area if necessary
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        // Ensure CharacterDataManager is available if not provided higher up
        // .environmentObject(CharacterDataManager()) // Or ensure it's passed from App
    }

    // MARK: - Subviews

    /// Builds the left panel containing character selection and reference view.
    @ViewBuilder
    private func referencePanel(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
             // Character Selection View (Assumes implementation exists)
             CharacterSelectionView(
                 selectedIndex: $selectedCharacterIndex,
                 characters: characterDataManager.characters,
                 onSelect: { index in
                     self.selectedCharacterIndex = index
                     // Use safe subscript from Extensions.swift
                     if let character = self.characterDataManager.characters[safe: index] {
                         self.characterDataManager.selectCharacter(withId: character.id)
                     }
                 }
             )
             .padding(.vertical)
             .background(Color(UIColor.secondarySystemBackground))

            Divider()

            // Reference View (Assumes implementation exists)
            if let character = characterDataManager.currentCharacter {
                ReferenceView(
                    character: character,
                    currentStrokeIndex: $strokeInputController.currentStrokeIndex // Pass index binding
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Placeholder if no character is selected
                Spacer()
                Text("Select a character")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(width: geometry.size.width * 0.45) // Adjust width ratio as needed
        .background(Color(UIColor.systemBackground))
    }

    /// Builds the right panel containing the writing area and controls.
    @ViewBuilder
    private func writingPanel(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Writing Pane View (Assumes implementation exists)
             WritingPaneView(
                 pkCanvasView: $pkCanvasView, // Pass the binding to the PKCanvasView instance
                 character: characterDataManager.currentCharacter,
                 strokeInputController: strokeInputController // Pass controller for index access
             )
             .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Controls Section
            controlsSection()
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
        }
        .frame(width: geometry.size.width * 0.55) // Adjust width ratio
        .background(Color(UIColor.systemBackground).opacity(0.9))
    }

    /// Builds the controls area below the writing pane.
    @ViewBuilder
    private func controlsSection() -> some View {
        // Use local variables for clarity and state access
        let currentIdx = self.strokeInputController.currentStrokeIndex
        let totalStrokes = self.characterDataManager.currentCharacter?.strokeCount ?? 0
        let isComplete = totalStrokes > 0 && currentIdx >= totalStrokes

        VStack(spacing: 15) {
            // Progress Indicator
            if isComplete {
                Text("Character Complete!")
                    .font(.headline).foregroundColor(.green)
            } else if totalStrokes > 0 {
                Text("Stroke \(currentIdx + 1) of \(totalStrokes)")
                    .font(.headline).foregroundColor(.secondary)
            } else {
                Text("-") // Placeholder if no character loaded
                    .font(.headline).foregroundColor(.secondary)
            }

            // Action Buttons
            HStack(spacing: 20) {
                // Reset Button
                Button {
                    self.resetCurrentStrokeAction()
                } label: {
                    Label("Reset Stroke", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle()) // Assumes defined in ButtonStyles.swift
                .disabled(isComplete || totalStrokes == 0) // Disable if complete or no character

                // Next/Results Button
                nextOrResultsButton(isComplete: isComplete, totalStrokes: totalStrokes)
            }
        }
    }

    /// Builds the button that either moves to the next stroke or shows final results.
     @ViewBuilder
     private func nextOrResultsButton(isComplete: Bool, totalStrokes: Int) -> some View {
         // Check if analysis is pending for the current stroke
         let analysisPending = self.currentStrokeAttemptData != nil
         // Check if all strokes have been analyzed for the final result
         // Important: Need to compare against totalStrokes ONLY IF totalStrokes > 0
         let allStrokesAnalyzed = totalStrokes > 0 && self.concurrencyAnalyzer.analysisHistory.count == totalStrokes

         Button {
             if isComplete {
                 self.showFinalResultsAction()
             } else {
                 self.moveToNextStrokeAction()
             }
         } label: {
             Label(isComplete ? "Show Results" : "Next Stroke", systemImage: isComplete ? "checkmark.circle" : "chevron.right")
         }
         .buttonStyle(PrimaryButtonStyle()) // Assumes defined in ButtonStyles.swift
         .disabled(
             self.characterDataManager.currentCharacter == nil || totalStrokes == 0 || // No character or character has no strokes
             (!isComplete && analysisPending) || // Not complete, but analysis is pending for current stroke
             (isComplete && !allStrokesAnalyzed) // Is complete, but not all strokes analyzed yet
         )
     }


    /// Builds the feedback overlay view.
    @ViewBuilder
    private func feedbackOverlay() -> some View {
        // Use the showFeedbackView flag from the FeedbackController
        if feedbackController.showFeedbackView {
            // Dimming background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow dismissing by tapping background only for stroke feedback
                    if feedbackController.feedbackType == .stroke {
                        feedbackController.dismissFeedback()
                        // Decide if dismissing stroke feedback should automatically move next
                        // moveToNextStrokeAction() // Optional: trigger move on tap-dismiss
                    }
                }

            // Actual Feedback View (Assumes implementation exists)
            FeedbackView(
                // Pass actions for the buttons within FeedbackView
                onContinue: {
                    self.feedbackController.dismissFeedback()
                    self.moveToNextStrokeAction()
                },
                onTryAgain: {
                    self.feedbackController.dismissFeedback()
                    self.resetForNewCharacterAttempt()
                },
                onClose: {
                    self.feedbackController.dismissFeedback()
                    // Decide if closing overall feedback should select next char or do nothing
                }
            )
            // FeedbackController already injected via .environmentObject earlier in body
        }
    }

    // MARK: - Setup & Lifecycle
    /// Initial setup when the view appears.
    private func initialSetup() {
        print("MainView appeared. Setting up delegates.")
        // Set delegates
        strokeInputController.delegate = self
        speechRecognitionController.delegate = self
        concurrencyAnalyzer.delegate = self

        // Setup controllers for the initially selected character (if any)
        if let currentChar = characterDataManager.currentCharacter,
           let index = characterDataManager.characters.firstIndex(where: { $0.id == currentChar.id }) {
            selectedCharacterIndex = index
            handleCharacterChange(character: currentChar) // Explicitly call setup for initial load
        } else if !characterDataManager.characters.isEmpty {
            // If no character was pre-selected, select the first one
            selectedCharacterIndex = 0
            let firstChar = characterDataManager.characters[0]
            characterDataManager.selectCharacter(withId: firstChar.id) // This triggers onChange -> handleCharacterChange
        } else {
            // Handle case where there are no characters at all
             handleCharacterChange(character: nil)
        }
    }

    /// Handles setup and reset logic when the selected character changes.
    private func handleCharacterChange(character: Character?) {
        guard let character = character, !character.strokes.isEmpty else { // Also check if character has strokes
            print("No character selected or character has no strokes - clearing state.")
            pkCanvasView.drawing = PKDrawing() // Clear canvas
            // Reset controllers with an empty character or handle nil state appropriately
            strokeInputController.setup(with: pkCanvasView, for: Character.empty) // Use empty character from Extensions.swift
            concurrencyAnalyzer.setup(for: Character.empty)
            speechRecognitionController.configure(with: Character.empty) // Ensure speech controller is also reset/configured appropriately
            feedbackController.reset()
            currentStrokeAttemptData = nil
            // Ensure selectedCharacterIndex reflects no valid selection if applicable
            if character == nil {
                 // Optionally find index of empty char or set to a specific state like -1
                 // selectedCharacterIndex = -1 // Or manage index based on actual characters array
                 // If using index 0 for empty, ensure CharacterSelectionView handles it.
            }
            return
        }
        print("Handling character change to: \(character.character)")
        // Reset state and configure controllers for the new character
        resetForNewCharacterAttempt()
    }

    // MARK: - Actions
    /// Resets the state for a new attempt at the current character.
    private func resetForNewCharacterAttempt() {
        guard let character = characterDataManager.currentCharacter else { return }
        print("Resetting for new attempt at character: \(character.character)")

        // Reset controllers
        strokeInputController.setup(with: pkCanvasView, for: character) // Resets index to 0
        speechRecognitionController.configure(with: character) // Configure (e.g., vocabulary)
        concurrencyAnalyzer.setup(for: character) // Clear previous analysis data
        feedbackController.reset() // Hide feedback, clear scores

        // Reset temporary state
        currentStrokeAttemptData = nil

        // Prepare for the first stroke if the character has strokes
        if !character.strokes.isEmpty {
            prepareForStrokeIndex(strokeInputController.currentStrokeIndex) // Should be 0
        } else {
            print("Character \(character.character) has no strokes to practice.")
            // Potentially update UI to reflect this state
        }
    }

    /// Resets the drawing canvas for the current stroke.
    private func resetCurrentStrokeAction() {
        guard let character = characterDataManager.currentCharacter,
              strokeInputController.currentStrokeIndex < character.strokeCount else {
            print("Cannot reset stroke, character complete or not loaded.")
            return
        }
        print("Resetting current stroke: \(strokeInputController.currentStrokeIndex + 1)")
        // Clear canvas via the controller
        strokeInputController.resetForNextStroke()
        // Reset any pending analysis data for this stroke
        currentStrokeAttemptData = nil
        // Stop speech if it was somehow left running
        speechRecognitionController.stopRecording()
        // Prepare speech recognizer for the same stroke again
        prepareForStrokeIndex(strokeInputController.currentStrokeIndex)
    }

    /// Advances to the next stroke.
    private func moveToNextStrokeAction() {
        guard let character = characterDataManager.currentCharacter else { return }
        // Ensure current analysis is complete before moving on
        guard currentStrokeAttemptData == nil else {
            print("Cannot move to next stroke, analysis pending.")
            // Optionally show a message to the user
            return
        }
        // Check if there is a next stroke
        let currentIdx = strokeInputController.currentStrokeIndex
        if currentIdx < character.strokeCount - 1 {
            print("Moving to next stroke.")
            // Tell input controller to advance and clear canvas
            strokeInputController.moveToNextStroke()
            // Prepare speech recognizer for the new stroke index
            prepareForStrokeIndex(strokeInputController.currentStrokeIndex)
        } else if currentIdx == character.strokeCount - 1 {
             print("Last stroke completed, preparing for results.")
             // Advance the index one last time so 'isComplete' logic triggers correctly
             strokeInputController.moveToNextStroke() // This will make currentStrokeIndex == strokeCount
             // Ensure speech is stopped if it wasn't already (e.g., error case)
             speechRecognitionController.stopRecording()
        } else {
            print("Already completed or cannot move next.")
        }
    }

    /// Triggers the calculation and presentation of the final character score.
    private func showFinalResultsAction() {
        guard let character = characterDataManager.currentCharacter else { return }
        // Ensure current analysis is complete (or all strokes are analyzed)
        guard currentStrokeAttemptData == nil else {
             print("Cannot show final results, analysis pending for last stroke.")
             return
         }
        guard concurrencyAnalyzer.analysisHistory.count == character.strokeCount else {
             print("Cannot show final results, not all strokes analyzed (\(concurrencyAnalyzer.analysisHistory.count)/\(character.strokeCount)).")
             return
         }

        print("Showing final results.")
        concurrencyAnalyzer.calculateFinalCharacterScore() // Analyzer will call delegate to show feedback
    }

    /// Prepares the speech controller for the stroke at the given index.
    private func prepareForStrokeIndex(_ index: Int) {
        // Use safe subscripting from Extensions.swift
        guard let character = characterDataManager.currentCharacter,
              let expectedStroke = character.strokes[safe: index] else { return }
        speechRecognitionController.prepareForStroke(expectedName: expectedStroke.name)
    }

    /// Processes the combined results after both stroke and speech data are available.
    private func processCompletedStrokeAttempt() {
        // Use optional binding for safety
        guard let attemptData = self.currentStrokeAttemptData else {
            print("Error: processCompletedStrokeAttempt called but no attempt data found.")
            return
        }
        print("Processing completed stroke attempt for index: \(attemptData.strokeIndex)")

        // --- 1. Calculate Stroke Accuracy ---
        // *** UPDATED: Using StrokeAnalysis.calculateAccuracy ***
        let strokeAccuracy = StrokeAnalysis.calculateAccuracy(
            drawnPoints: attemptData.drawnPoints,
            expectedStroke: attemptData.expectedStroke
        )
        // --- End Update ---

        // --- 2. Prepare Input for Concurrency Analyzer ---
        let analysisInput = StrokeAnalysisInput(
            strokeIndex: attemptData.strokeIndex,
            expectedStroke: attemptData.expectedStroke,
            strokeStartTime: attemptData.strokeStartTime,
            strokeEndTime: attemptData.strokeEndTime,
            strokeAccuracy: strokeAccuracy, // Use calculated accuracy
            speechStartTime: attemptData.speechStartTime,
            speechEndTime: attemptData.speechEndTime,
            finalTranscription: attemptData.finalTranscription,
            transcriptionMatched: attemptData.transcriptionMatched,
            speechConfidence: attemptData.speechConfidence
        )

        // --- 3. Trigger Analysis ---
        concurrencyAnalyzer.analyzeStroke(input: analysisInput) // Analyzer calls delegate when done

        // --- 4. Clear Temporary Data ---
        // Ensure this happens on main thread if it affects UI state indirectly
        DispatchQueue.main.async {
            self.currentStrokeAttemptData = nil
        }
    }
}

// MARK: - Delegate Conformance (StrokeInputDelegate)
extension MainView: StrokeInputDelegate {
    func strokeBegan(at time: Date, strokeType: StrokeType) {
        DispatchQueue.main.async {
            // Only start if we have a valid character and current stroke index
            guard let character = self.characterDataManager.currentCharacter,
                  self.strokeInputController.currentStrokeIndex < character.strokeCount else {
                 print("Stroke began, but no valid character/stroke index.")
                 return
            }

            self.currentStrokeAttemptData = nil // Clear previous attempt data for safety
            self.prepareForStrokeIndex(self.strokeInputController.currentStrokeIndex)
            do {
                try self.speechRecognitionController.startRecording()
            } catch {
                print("Error starting speech recording: \(error)")
                // TODO: Show error alert to user (implement UI state for alerts)
                // Maybe proceed without speech for this stroke? Or force reset?
                // For now, just logs error. Analysis will proceed without speech data later.
            }
        }
    }

    func strokeUpdated(points: [CGPoint]) {
        // Optional: Use for real-time feedback if needed
    }

    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int) {
        print("Delegate: strokeEnded for index \(strokeIndex) at \(time)")
        // Use controller's start time if available, otherwise fallback
        let startTime = self.strokeInputController.strokeStartTime ?? time.addingTimeInterval(-0.5) // Fallback if start time is missing

        // Use DispatchQueue.main.async for state update safety
        DispatchQueue.main.async {
             // Ensure points were captured
            guard !drawnPoints.isEmpty else {
                print("Warning: Stroke ended with no points captured. Resetting.")
                self.resetCurrentStrokeAction() // Reset if no points drawn
                return
            }
            
            print("DEBUG: Processing stroke with \(drawnPoints.count) points") // Add debug log to verify
            
            // Create the temporary data
            self.currentStrokeAttemptData = StrokeAttemptData(
                strokeIndex: strokeIndex,
                expectedStroke: expectedStroke,
                strokeStartTime: startTime,
                strokeEndTime: time,
                drawnPoints: drawnPoints
            )
            // Stop speech recognition, which will trigger finalization/error delegates
            // Only stop if it was actually started (check speech controller state if needed)
            if self.speechRecognitionController.isRecording {
                self.speechRecognitionController.stopRecording()
            } else {
                // If speech wasn't recording (e.g., permission error), process immediately without speech data
                print("Speech was not recording when stroke ended. Processing without speech data.")
                self.currentStrokeAttemptData?.speechStartTime = nil
                self.currentStrokeAttemptData?.speechEndTime = nil
                self.currentStrokeAttemptData?.finalTranscription = nil
                self.currentStrokeAttemptData?.transcriptionMatched = false // Treat as incorrect if no speech attempt
                self.currentStrokeAttemptData?.speechConfidence = 0.0
                self.processCompletedStrokeAttempt()
            }
            // Analysis happens in speechTranscriptionFinalized or speechRecognitionErrorOccurred or immediately above
        }
    }
    

    func allStrokesCompleted() {
        print("Delegate: allStrokesCompleted")
        // UI state (e.g., enabling 'Show Results') handled by checks in controlsSection & nextOrResultsButton
        // This is called when currentStrokeIndex reaches strokeCount
    }
}

// MARK: - Delegate Conformance (SpeechRecognitionDelegate)
extension MainView: SpeechRecognitionDelegate {
    func speechRecordingStarted(at time: Date) {
        print("Delegate: speechRecordingStarted at \(time)")
        // Update the attempt data only if it exists (i.e., stroke has started)
        DispatchQueue.main.async {
            if self.currentStrokeAttemptData != nil {
                 self.currentStrokeAttemptData?.speechStartTime = time
            } else {
                 print("Warning: Speech started before stroke data was initialized.")
            }
        }
    }

    func speechRecordingStopped(at time: Date, duration: TimeInterval) {
        print("Delegate: speechRecordingStopped at \(time), duration \(String(format: "%.2f", duration))s")
        // Rely on finalized/error delegate calls.
        // Consider adding a failsafe timer here: If neither finalized nor error is called
        // within ~1-2 seconds after stop, maybe force processCompletedStrokeAttempt with missing speech data.
        // For example:
        /*
         DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
             // Check if analysis is still pending for this stroke
             if let currentStrokeIdx = self?.strokeInputController.currentStrokeIndex,
                self?.currentStrokeAttemptData?.strokeIndex == currentStrokeIdx {
                 print("Failsafe: Speech stop detected, but no finalization/error received. Processing without speech data.")
                 self?.currentStrokeAttemptData?.speechEndTime = time // Use stop time as end time
                 self?.currentStrokeAttemptData?.finalTranscription = nil
                 self?.currentStrokeAttemptData?.transcriptionMatched = false
                 self?.currentStrokeAttemptData?.speechConfidence = 0.0
                 self?.processCompletedStrokeAttempt()
             }
         }
         */
    }

    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date) {
        print("Delegate: speechTranscriptionFinalized - Match: \(matchesExpected), Text: '\(transcription)'")
        DispatchQueue.main.async {
            // Ensure corresponding stroke data is waiting and matches the current index
            guard let attemptData = self.currentStrokeAttemptData,
                  attemptData.strokeIndex == self.strokeInputController.currentStrokeIndex else {
                print("Warning: Speech finalized, but no stroke attempt data is waiting or index mismatch. Ignoring.")
                return
            }
            // Add speech results
            self.currentStrokeAttemptData?.speechEndTime = endTime
            self.currentStrokeAttemptData?.finalTranscription = transcription
            self.currentStrokeAttemptData?.transcriptionMatched = matchesExpected
            self.currentStrokeAttemptData?.speechConfidence = confidence
            // Ensure start time is captured if it wasn't already
            if self.currentStrokeAttemptData?.speechStartTime == nil {
                print("Warning: Speech start time was missing, using finalized start time.")
                self.currentStrokeAttemptData?.speechStartTime = startTime
            }
            // Process the combined results
            self.processCompletedStrokeAttempt()
        }
    }

    func speechRecognitionErrorOccurred(_ error: Error) {
        print("Delegate: speechRecognitionErrorOccurred - \(error.localizedDescription)")
        DispatchQueue.main.async {
            // If an error occurs, process the stroke attempt without valid speech data
             // Ensure corresponding stroke data is waiting and matches the current index
             guard let attemptData = self.currentStrokeAttemptData,
                   attemptData.strokeIndex == self.strokeInputController.currentStrokeIndex else {
                print("Speech error occurred, but no stroke data was pending or index mismatch.")
                // TODO: Show user feedback about the speech error (e.g., using an alert state variable)
                return
             }

            print("Processing stroke attempt despite speech error.")
            self.currentStrokeAttemptData?.speechEndTime = nil // Indicate error / no valid end time
            self.currentStrokeAttemptData?.finalTranscription = nil
            self.currentStrokeAttemptData?.transcriptionMatched = false // Treat as incorrect
            self.currentStrokeAttemptData?.speechConfidence = 0.0
            // Ensure start time is nil as well if recording didn't even start properly
            // Or keep start time if it was recorded before error? Depends on desired logic.
             // self.currentStrokeAttemptData?.speechStartTime = nil // Optional reset start time

            self.processCompletedStrokeAttempt() // Process with missing/invalid speech data

            // TODO: Show user feedback about the speech error
        }
    }

    func speechRecognitionNotAvailable() {
        print("Delegate: speechRecognitionNotAvailable")
        DispatchQueue.main.async {
            // TODO: Handle unavailability: Show alert, disable speech features?
            // Maybe add a @State var to disable the speech part of the interaction
            // and adjust scoring weights accordingly if speech is permanently unavailable.
        }
    }

    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus) {
        print("Delegate: speechAuthorizationDidChange to \(status.rawValue)") // Use rawValue for logging if needed
        DispatchQueue.main.async {
            // TODO: Update UI or disable features if status is not .authorized
            if status != .authorized {
                // Show alert explaining the need for permission and how to grant it in Settings.
            }
        }
    }
}

// MARK: - Delegate Conformance (ConcurrencyAnalyzerDelegate)
extension MainView: ConcurrencyAnalyzerDelegate {
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback) {
        print("Delegate: strokeAnalysisCompleted for index \(timingData.strokeIndex)")
        DispatchQueue.main.async {
            // Use FeedbackController to present the feedback
            self.feedbackController.presentStrokeFeedback(index: timingData.strokeIndex, feedback: feedback)
        }
    }

    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String) {
        print("Delegate: overallAnalysisCompleted - Score: \(overallScore)")
        DispatchQueue.main.async {
            // Use FeedbackController to present the final feedback
            self.feedbackController.presentOverallFeedback(score: overallScore, breakdown: breakdown, message: feedback)
        }
    }
}
