// File: Views/MainView.swift
// VERSION: Fixed CharacterSelectionView call syntax

import SwiftUI
import PencilKit
import Speech
import UIKit

struct MainView: View {
    // MARK: - Environment and State Objects
    @EnvironmentObject var characterDataManager: CharacterDataManager
    @StateObject private var strokeInputController = StrokeInputController()
    @StateObject private var speechRecognitionController = SpeechRecognitionController()
    @StateObject private var concurrencyAnalyzer = ConcurrencyAnalyzer()
    @StateObject private var feedbackController = FeedbackController()

    @State private var pkCanvasView = PKCanvasView()
    @State private var selectedCharacterIndex = 0
    @State private var currentStrokeAttemptData: StrokeAttemptData? = nil
    @State private var finalDrawingWithFeedback: PKDrawing? = nil
    @State private var isCharacterPracticeComplete: Bool = false
    @State private var isCanvasInteractionEnabled: Bool = true

    // Temporary storage during stroke processing
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
            return speechStartTime == nil || transcriptionMatched != nil
        }
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                referencePanel(geometry: geometry)
                Divider()
                writingPanel(
                    geometry: geometry,
                    isInteractionEnabled: isCanvasInteractionEnabled,
                    onTapToWriteAgain: resetForNewCharacterAttempt
                )
            }
            .environmentObject(characterDataManager)
            .onAppear(perform: initialSetup)
            .onChange(of: characterDataManager.currentCharacter?.id) { oldId, newId in
                 if oldId != newId {
                      if let newChar = characterDataManager.currentCharacter,
                         let newIdx = characterDataManager.characters.firstIndex(where: { $0.id == newChar.id }) {
                          selectedCharacterIndex = newIdx
                      }
                      handleCharacterChange(character: characterDataManager.currentCharacter)
                 }
            }
            .onChange(of: characterDataManager.characters) { oldChars, newChars in
                 if oldChars.isEmpty && !newChars.isEmpty && characterDataManager.currentCharacter == nil {
                      initialSetup()
                 }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    // MARK: - Subviews

    // ***** CORRECTED CharacterSelectionView call *****
    @ViewBuilder
    private func referencePanel(geometry: GeometryProxy) -> some View {
       VStack(spacing: 0) {
             // Corrected call: arguments are inside the parentheses
             CharacterSelectionView(
                 selectedIndex: $selectedCharacterIndex,
                 characters: characterDataManager.characters,
                 onSelect: { index in
                     self.selectedCharacterIndex = index
                     if index >= 0 && index < self.characterDataManager.characters.count {
                          let character = self.characterDataManager.characters[index]
                          self.characterDataManager.selectCharacter(withId: character.id)
                     }
                 }
             )
             .padding(.vertical)
             .background(Color(UIColor.secondarySystemBackground))
             .frame(minHeight: 80)

             Divider()

             GeometryReader { referenceGeometry in
                 ReferenceView(character: characterDataManager.currentCharacter)
                      .frame(width: referenceGeometry.size.width, height: referenceGeometry.size.height)
             }
             .frame(maxWidth: .infinity, maxHeight: .infinity)
         }
         .frame(width: geometry.size.width * 0.45)
         .background(Color(UIColor.systemBackground))
    }
    // ************************************************

    @ViewBuilder
    private func writingPanel(geometry: GeometryProxy, isInteractionEnabled: Bool, onTapToWriteAgain: @escaping () -> Void) -> some View {
        WritingPaneView(
            pkCanvasView: $pkCanvasView,
            character: characterDataManager.currentCharacter,
            strokeInputController: strokeInputController,
            currentStrokeIndex: strokeInputController.currentStrokeIndex,
            isPracticeComplete: isCharacterPracticeComplete,
            analysisHistory: concurrencyAnalyzer.analysisHistory,
            finalDrawingWithFeedback: finalDrawingWithFeedback,
            isInteractionEnabled: isInteractionEnabled,
            onTapToWriteAgain: onTapToWriteAgain
        )
        .frame(width: geometry.size.width * 0.55)
    }

    // MARK: - Setup & Lifecycle
    private func initialSetup() {
        print("MainView appeared. Setting up delegates.")
        strokeInputController.delegate = self
        speechRecognitionController.delegate = self
        concurrencyAnalyzer.delegate = self

         if !characterDataManager.characters.isEmpty && characterDataManager.currentCharacter == nil {
             selectedCharacterIndex = 0
             characterDataManager.currentCharacter = characterDataManager.characters[0]
         } else if let currentChar = characterDataManager.currentCharacter {
             if let currentIndex = characterDataManager.characters.firstIndex(of: currentChar) {
                 selectedCharacterIndex = currentIndex
             }
             handleCharacterChange(character: currentChar)
         } else {
             handleCharacterChange(character: nil)
         }
    }

    private func handleCharacterChange(character: Character?) {
        guard let character = character, !character.strokes.isEmpty else {
            print("Handle character change: No character - clearing state.")
            pkCanvasView.drawing = PKDrawing()
            strokeInputController.setup(with: pkCanvasView, for: Character.empty)
            concurrencyAnalyzer.setup(for: Character.empty)
            speechRecognitionController.configure(with: Character.empty)
            feedbackController.reset()
            currentStrokeAttemptData = nil
            finalDrawingWithFeedback = nil
            isCharacterPracticeComplete = false
            isCanvasInteractionEnabled = false
            return
        }
        print("Handling character change to: \(character.character)")
        resetForNewCharacterAttempt()
    }

    // MARK: - Actions
    private func resetForNewCharacterAttempt() {
        guard let character = characterDataManager.currentCharacter else { return }
        print("Resetting for new attempt at character: \(character.character)")
        strokeInputController.setup(with: pkCanvasView, for: character)
        speechRecognitionController.configure(with: character)
        concurrencyAnalyzer.setup(for: character)
        feedbackController.reset()
        pkCanvasView.drawing = PKDrawing()
        currentStrokeAttemptData = nil
        finalDrawingWithFeedback = nil
        isCharacterPracticeComplete = false
        isCanvasInteractionEnabled = true

        if !character.strokes.isEmpty {
            prepareForSpeech(strokeIndex: 0)
        }
    }

    private func moveToNextStrokeAction() {
        let controllerIndexBefore = strokeInputController.currentStrokeIndex
        print(">>> MainView.moveToNextStrokeAction: Called. Index BEFORE: \(controllerIndexBefore)")
        let shouldPrepareNext = strokeInputController.checkCompletionAndAdvance(indexJustCompleted: controllerIndexBefore)
        if shouldPrepareNext {
            let nextIndex = strokeInputController.currentStrokeIndex
            print("<<< Preparing next stroke at index \(nextIndex).")
            prepareForSpeech(strokeIndex: nextIndex)
        } else { print("<<< Completion signaled.") }
    }

    private func showFinalResultsAction() {
        print(">>> MainView.showFinalResultsAction called (all strokes completed).")
        isCanvasInteractionEnabled = false
        print("  - Canvas interaction DISABLED.")
        concurrencyAnalyzer.calculateFinalCharacterScore()
    }

    private func prepareForSpeech(strokeIndex: Int) {
        guard let character = characterDataManager.currentCharacter,
              let stroke = character.strokes[safe: strokeIndex] else { return }
        print("MainView.prepareForSpeech: Index \(strokeIndex), Name: '\(stroke.name)'")
        speechRecognitionController.prepareForStroke(expectedName: stroke.name)
    }

    private func processCompletedStrokeAttempt() {
        guard let attemptData = self.currentStrokeAttemptData else { return }
        guard attemptData.isReadyForAnalysis else { return }
        print("Processing completed stroke attempt for index: \(attemptData.strokeIndex)")
        let strokeAccuracy = StrokeAnalysis.calculateAccuracy(
            drawnPoints: attemptData.drawnPoints, expectedStroke: attemptData.expectedStroke
        )
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
        concurrencyAnalyzer.analyzeStroke(input: analysisInput)
    }
}

// MARK: - Delegate Conformance
extension MainView: StrokeInputDelegate {
     func strokeBegan(at time: Date, strokeType: StrokeType) {
         print("MainView: strokeBegan delegate called.")
         self.currentStrokeAttemptData = nil
         prepareForSpeech(strokeIndex: strokeInputController.currentStrokeIndex)
         do { try speechRecognitionController.startRecording() }
         catch {
             print("  - Error starting speech: \(error.localizedDescription)")
             self.currentStrokeAttemptData?.transcriptionMatched = nil
         }
     }
     func strokeUpdated(points: [CGPoint]) { }
     func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int) {
         let controllerIndex = strokeInputController.currentStrokeIndex
         print(">>> MainView.strokeEnded: Delegate called. Index: \(strokeIndex)")
         guard let strokeStartTime = strokeInputController.strokeStartTime else { return }
         guard strokeIndex == controllerIndex else { return }
         self.currentStrokeAttemptData = StrokeAttemptData(
             strokeIndex: strokeIndex,
             expectedStroke: expectedStroke,
             strokeStartTime: strokeStartTime,
             strokeEndTime: time,
             drawnPoints: drawnPoints
         )
         speechRecognitionController.stopRecording()
         if self.currentStrokeAttemptData?.speechStartTime == nil {
             self.currentStrokeAttemptData?.transcriptionMatched = nil
             processCompletedStrokeAttempt()
         } else { print("  - Waiting for speech transcription result...") }
     }
     func allStrokesCompleted() {
         print(">>> MainView: allStrokesCompleted delegate called.")
         DispatchQueue.main.async {
             self.isCanvasInteractionEnabled = false // Disable immediately
             print("  - Canvas interaction DISABLED by allStrokesCompleted.")
             self.showFinalResultsAction() // Then start final processing
         }
     }
}

extension MainView: SpeechRecognitionDelegate {
    func speechRecordingStarted(at time: Date) {
        print("MainView: speechRecordingStarted delegate called.")
        guard self.currentStrokeAttemptData != nil else { return }
        if self.currentStrokeAttemptData?.speechStartTime == nil {
             self.currentStrokeAttemptData?.speechStartTime = time
        }
    }
    func speechRecordingStopped(at time: Date, duration: TimeInterval) { print("MainView: speechRecordingStopped delegate called.") }
    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date) {
        print("MainView: speechTranscriptionFinalized called. Match: \(matchesExpected)")
        guard self.currentStrokeAttemptData != nil else { return }
        guard self.currentStrokeAttemptData?.strokeIndex == strokeInputController.currentStrokeIndex else { return }
        self.currentStrokeAttemptData?.speechEndTime = endTime
        self.currentStrokeAttemptData?.finalTranscription = transcription
        self.currentStrokeAttemptData?.transcriptionMatched = matchesExpected
        self.currentStrokeAttemptData?.speechConfidence = confidence
        processCompletedStrokeAttempt()
    }
    func speechRecognitionErrorOccurred(_ error: Error) {
        print("MainView: speechRecognitionErrorOccurred: \(error.localizedDescription)")
        let nsError = error as NSError; print("  - Error Domain: \(nsError.domain), Code: \(nsError.code)")
        if self.currentStrokeAttemptData != nil && self.currentStrokeAttemptData?.isReadyForAnalysis == false {
             self.currentStrokeAttemptData?.transcriptionMatched = false
             self.currentStrokeAttemptData?.finalTranscription = "[Error]"
             self.currentStrokeAttemptData?.speechEndTime = Date()
             processCompletedStrokeAttempt()
        }
    }
    func speechRecognitionNotAvailable() {
        print("MainView: speechRecognitionNotAvailable.")
         if self.currentStrokeAttemptData != nil && self.currentStrokeAttemptData?.isReadyForAnalysis == false {
              self.currentStrokeAttemptData?.transcriptionMatched = nil
              self.currentStrokeAttemptData?.finalTranscription = "[N/A]"
              self.currentStrokeAttemptData?.speechEndTime = Date()
              processCompletedStrokeAttempt()
         }
    }
    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus) { print("MainView: speechAuthorizationDidChange: \(status)") }
}

extension MainView: ConcurrencyAnalyzerDelegate {
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback) {
        print("MainView: strokeAnalysisCompleted delegate called for index \(timingData.strokeIndex). Accuracy: \(timingData.strokeAccuracy)")
        DispatchQueue.main.async {
            self.feedbackController.recordStrokeFeedback(index: timingData.strokeIndex, feedback: feedback)
            self.currentStrokeAttemptData = nil
            print("  - Recorded internal feedback. Cleared attempt data.")
            if self.isCanvasInteractionEnabled {
                 self.moveToNextStrokeAction()
            } else {
                 print("  - Interaction disabled, not moving to next stroke.")
            }
        }
    }

    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String) {
        print("MainView: overallAnalysisCompleted delegate called. Score: \(overallScore)")
        print("Processing final drawing feedback...")

        let finalDrawing = pkCanvasView.drawing
        var strokesWithFeedback: [PKStroke] = []
        let accuracyThreshold = 70.0
        let inaccurateColor = UIColor.red
        let accurateColor = (pkCanvasView.tool as? PKInkingTool)?.color ?? UIColor.label

        for analysisData in concurrencyAnalyzer.analysisHistory.sorted(by: { $0.strokeIndex < $1.strokeIndex }) {
            let index = analysisData.strokeIndex
            if let drawnStroke = finalDrawing.strokes[safe: index] {
                var newStroke = drawnStroke
                let targetColor = analysisData.strokeAccuracy < accuracyThreshold ? inaccurateColor : accurateColor
                if newStroke.ink.color != targetColor {
                     newStroke.ink = PKInk(newStroke.ink.inkType, color: targetColor)
                     print("  - Coloring stroke \(index) \(analysisData.strokeAccuracy < accuracyThreshold ? "RED" : "ACCURATE") (Accuracy: \(analysisData.strokeAccuracy))")
                } else {
                     print("  - Stroke \(index) already has target color. (Accuracy: \(analysisData.strokeAccuracy))")
                }
                strokesWithFeedback.append(newStroke)
            } else {
                print("  - Warning: No drawn stroke found at index \(index).")
            }
        }
        if finalDrawing.strokes.count > concurrencyAnalyzer.analysisHistory.count {
            print("  - Appending \(finalDrawing.strokes.count - concurrencyAnalyzer.analysisHistory.count) extra stroke(s) with original color.")
            strokesWithFeedback.append(contentsOf: finalDrawing.strokes[concurrencyAnalyzer.analysisHistory.count...])
        }

        let finalFeedbackDrawing = PKDrawing(strokes: strokesWithFeedback)

        DispatchQueue.main.async {
            self.feedbackController.calculateAndPresentOverallFeedback(score: overallScore, breakdown: breakdown, message: feedback)
            self.finalDrawingWithFeedback = finalFeedbackDrawing
            self.isCharacterPracticeComplete = true
            // Interaction remains DISABLED until user taps to reset
            self.currentStrokeAttemptData = nil
            print("  - Final feedback generated. Interaction remains disabled until reset.")
        }
    }
}
