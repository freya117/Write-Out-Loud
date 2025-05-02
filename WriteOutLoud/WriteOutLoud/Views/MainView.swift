// File: Views/MainView.swift
// VERSION: Fixed weak self capture in Coordinator setup closures

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
        updateCurrentStrokeAttemptData?(nil)
        if let controller = strokeInputController {
            prepareForSpeech?(controller.currentStrokeIndex)
            do { try speechRecognitionController?.startRecording() }
            catch {
                 print("Coordinator Error: Failed to start speech - \(error)")
                 if let idx = strokeInputController?.currentStrokeIndex, let exp = strokeInputController?.character?.strokes[safe: idx] {
                      let failed = MainView.StrokeAttemptData(strokeIndex: idx, expectedStroke: exp, strokeStartTime: time, strokeEndTime: time, drawnPoints: [], transcriptionMatched: false)
                      updateCurrentStrokeAttemptData?(failed); processCompletedStrokeAttempt?()
                 }
            }
        }
    }
    func strokeUpdated(points: [CGPoint]) { }
    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int) {
        print("Coordinator: strokeEnded for index \(strokeIndex)")
        guard let startTime = strokeInputController?.strokeStartTime, strokeIndex == strokeInputController?.currentStrokeIndex else { return }
        let attempt = MainView.StrokeAttemptData(strokeIndex: strokeIndex, expectedStroke: expectedStroke, strokeStartTime: startTime, strokeEndTime: time, drawnPoints: drawnPoints)
        updateCurrentStrokeAttemptData?(attempt)
        speechRecognitionController?.stopRecording()
        if getCurrentStrokeAttemptData?()?.speechStartTime == nil {
             print("Coordinator: No speech detected for stroke \(strokeIndex), processing analysis now.")
             var currentData = getCurrentStrokeAttemptData?(); currentData?.transcriptionMatched = nil
             updateCurrentStrokeAttemptData?(currentData); processCompletedStrokeAttempt?()
        } else { print("Coordinator: Waiting for speech transcription result for stroke \(strokeIndex)...") }
    }
    func allStrokesCompleted() {
        print("Coordinator: allStrokesCompleted")
        DispatchQueue.main.async { self.setIsCanvasInteractionEnabled?(false); self.showFinalResultsAction?() }
    }

    // MARK: - SpeechRecognitionDelegate
    func speechRecordingStarted(at time: Date) {
        print("Coordinator: speechRecordingStarted")
        if var data = getCurrentStrokeAttemptData?(), data.speechStartTime == nil { data.speechStartTime = time; updateCurrentStrokeAttemptData?(data) }
    }
    func speechRecordingStopped(at time: Date, duration: TimeInterval) { print("Coordinator: speechRecordingStopped") }
    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date) {
        print("Coordinator: speechTranscriptionFinalized. Match: \(matchesExpected)")
        if var data = getCurrentStrokeAttemptData?(), data.strokeIndex == strokeInputController?.currentStrokeIndex {
            data.speechEndTime = endTime; data.finalTranscription = transcription; data.transcriptionMatched = matchesExpected; data.speechConfidence = confidence
            updateCurrentStrokeAttemptData?(data); processCompletedStrokeAttempt?()
        } else { print("Coordinator Warning: Stale/missing data on speech finalization.") }
    }
    func speechRecognitionErrorOccurred(_ error: Error) {
        print("Coordinator: speechRecognitionErrorOccurred: \(error.localizedDescription)")
        if var data = getCurrentStrokeAttemptData?(), data.isReadyForAnalysis == false {
            data.transcriptionMatched = false; data.finalTranscription = "[Error]"; data.speechEndTime = Date(); updateCurrentStrokeAttemptData?(data); processCompletedStrokeAttempt?()
        }
    }
    func speechRecognitionNotAvailable() {
        print("Coordinator: speechRecognitionNotAvailable.")
        if var data = getCurrentStrokeAttemptData?(), data.isReadyForAnalysis == false {
            data.transcriptionMatched = nil; data.finalTranscription = "[N/A]"; data.speechEndTime = Date(); updateCurrentStrokeAttemptData?(data); processCompletedStrokeAttempt?()
        }
    }
    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus) { print("Coordinator: speechAuthorizationDidChange: \(status)") }

    // MARK: - ConcurrencyAnalyzerDelegate
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback) {
        print("Coordinator: strokeAnalysisCompleted for index \(timingData.strokeIndex).")
        DispatchQueue.main.async {
            self.feedbackController?.recordStrokeFeedback(index: timingData.strokeIndex, feedback: feedback)
            self.updateCurrentStrokeAttemptData?(nil) // Clear after analysis
            self.moveToNextStrokeAction?() // Move immediately
        }
    }
    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String) {
        print("Coordinator: overallAnalysisCompleted. Score: \(overallScore)")
        guard let finalDrawing = pkCanvasView?.drawing, let history = concurrencyAnalyzer?.analysisHistory else { setIsPracticeComplete?(true); return }
        var strokesWithFeedback: [PKStroke] = []; let threshold = 70.0; let badColor = UIColor.red; let goodColor = UIColor.systemGreen
        for analysisData in history.sorted(by: { $0.strokeIndex < $1.strokeIndex }) {
            if let drawn = finalDrawing.strokes[safe: analysisData.strokeIndex] {
                var new = drawn; let target = analysisData.strokeAccuracy < threshold ? badColor : goodColor
                new.ink = PKInk(new.ink.inkType, color: target); strokesWithFeedback.append(new)
            }
        }
        if finalDrawing.strokes.count > history.count { strokesWithFeedback.append(contentsOf: finalDrawing.strokes[history.count...]) }
        let finalFeedbackDrawing = PKDrawing(strokes: strokesWithFeedback)
        DispatchQueue.main.async {
            self.feedbackController?.calculateAndPresentOverallFeedback(score: overallScore, breakdown: breakdown, message: feedback)
            self.updateFinalDrawing?(finalFeedbackDrawing); self.setIsPracticeComplete?(true); self.updateCurrentStrokeAttemptData?(nil)
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
    @State private var showRealtimeTranscript: Bool = false // State for toggle

    // Temporary storage struct (Definition remains)
    struct StrokeAttemptData { /* ... as before ... */
        let strokeIndex: Int; let expectedStroke: Stroke; let strokeStartTime: Date; let strokeEndTime: Date
        let drawnPoints: [CGPoint]; var speechStartTime: Date? = nil; var speechEndTime: Date? = nil
        var finalTranscription: String? = nil; var transcriptionMatched: Bool? = nil
        var speechConfidence: Float? = nil
        var isReadyForAnalysis: Bool { return speechStartTime == nil || transcriptionMatched != nil }
    }

    // MARK: - Body (Unchanged)
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                transcriptToggle().padding(.horizontal).padding(.top, 8) // Toggle added
                HStack(spacing: 0) {
                    referencePanel(geometry: geometry)
                    Divider()
                    writingPanel(geometry: geometry, isInteractionEnabled: isCanvasInteractionEnabled, onTapToWriteAgain: resetForNewCharacterAttempt)
                }
            }
            .environmentObject(characterDataManager)
            .onAppear(perform: initialSetup)
            .onChange(of: characterDataManager.currentCharacter?.id) { oldId, newId in if oldId != newId { if let newChar = characterDataManager.currentCharacter, let idx = characterDataManager.characters.firstIndex(where: { $0.id == newChar.id }) { selectedCharacterIndex = idx }; handleCharacterChange(character: characterDataManager.currentCharacter) } }
            .onChange(of: characterDataManager.characters) { oldChars, newChars in if oldChars.isEmpty && !newChars.isEmpty && characterDataManager.currentCharacter == nil { initialSetup() } }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    // MARK: - Subviews (Unchanged)
    @ViewBuilder private func transcriptToggle() -> some View { Toggle("Show Real-time Transcript", isOn: $showRealtimeTranscript).padding(.vertical, 4).tint(.blue) }
    @ViewBuilder private func referencePanel(geometry: GeometryProxy) -> some View { /* ... as before ... */
       VStack(spacing: 0) {
             CharacterSelectionView(selectedIndex: $selectedCharacterIndex, characters: characterDataManager.characters, onSelect: { index in self.selectedCharacterIndex = index; if index >= 0 && index < self.characterDataManager.characters.count { self.characterDataManager.selectCharacter(withId: self.characterDataManager.characters[index].id) } }).padding(.vertical).background(Color(UIColor.secondarySystemBackground)).frame(minHeight: 80); Divider()
             GeometryReader { refGeo in ReferenceView(character: characterDataManager.currentCharacter).frame(width: refGeo.size.width, height: refGeo.size.height) }.frame(maxWidth: .infinity, maxHeight: .infinity)
         }.frame(width: geometry.size.width * 0.40).background(Color(UIColor.systemBackground))
    }
    @ViewBuilder private func writingPanel(geometry: GeometryProxy, isInteractionEnabled: Bool, onTapToWriteAgain: @escaping () -> Void) -> some View { /* ... as before ... */
        WritingPaneView(pkCanvasView: $pkCanvasView, character: characterDataManager.currentCharacter, strokeInputController: strokeInputController, currentStrokeIndex: strokeInputController.currentStrokeIndex, isPracticeComplete: isCharacterPracticeComplete, analysisHistory: concurrencyAnalyzer.analysisHistory, finalDrawingWithFeedback: finalDrawingWithFeedback, isInteractionEnabled: isInteractionEnabled, onTapToWriteAgain: onTapToWriteAgain, showRealtimeTranscript: showRealtimeTranscript, realtimeTranscript: speechRecognitionController.recognizedTextFragment)
        .frame(width: geometry.size.width * 0.60)
    }

    // MARK: - Setup & Lifecycle
    private func initialSetup() {
        print("MainView: initialSetup")

        // ***** Setup Coordinator (REMOVED [weak self]) *****
        delegateCoordinator.strokeInputController = self.strokeInputController
        delegateCoordinator.speechRecognitionController = self.speechRecognitionController
        delegateCoordinator.concurrencyAnalyzer = self.concurrencyAnalyzer
        delegateCoordinator.feedbackController = self.feedbackController
        delegateCoordinator.pkCanvasView = self.pkCanvasView

        // Provide closures for state modification (No weak self)
        delegateCoordinator.updateCurrentStrokeAttemptData = { data in self.currentStrokeAttemptData = data }
        delegateCoordinator.getCurrentStrokeAttemptData = { return self.currentStrokeAttemptData } // No weak self needed for read
        delegateCoordinator.updateFinalDrawing = { drawing in self.finalDrawingWithFeedback = drawing }
        delegateCoordinator.setIsPracticeComplete = { complete in self.isCharacterPracticeComplete = complete }
        delegateCoordinator.setIsCanvasInteractionEnabled = { enabled in self.isCanvasInteractionEnabled = enabled }

        // Provide closures for actions (No weak self)
        delegateCoordinator.prepareForSpeech = { index in self.prepareForSpeech(strokeIndex: index) }
        delegateCoordinator.processCompletedStrokeAttempt = { self.processCompletedStrokeAttempt() }
        delegateCoordinator.showFinalResultsAction = { self.showFinalResultsAction() }
        delegateCoordinator.moveToNextStrokeAction = { self.moveToNextStrokeAction() }

        // Assign coordinator as the delegate
        strokeInputController.delegate = delegateCoordinator
        speechRecognitionController.delegate = delegateCoordinator
        concurrencyAnalyzer.delegate = delegateCoordinator
        print("MainView: Delegates assigned to Coordinator.")
        // **************************************************

        // Initial character selection logic
         if !characterDataManager.characters.isEmpty && characterDataManager.currentCharacter == nil {
             selectedCharacterIndex = 0; characterDataManager.currentCharacter = characterDataManager.characters[0]
         } else if let currentChar = characterDataManager.currentCharacter {
             if let idx = characterDataManager.characters.firstIndex(of: currentChar) { selectedCharacterIndex = idx }
             handleCharacterChange(character: currentChar)
         } else { handleCharacterChange(character: nil) }
    }

    // Character change handling (unchanged logic)
    private func handleCharacterChange(character: Character?) {
        guard let character = character, !character.strokes.isEmpty else {
            pkCanvasView.drawing = PKDrawing(); strokeInputController.setup(with: pkCanvasView, for: .empty)
            concurrencyAnalyzer.setup(for: .empty); speechRecognitionController.configure(with: .empty)
            feedbackController.reset(); currentStrokeAttemptData = nil; finalDrawingWithFeedback = nil
            isCharacterPracticeComplete = false; isCanvasInteractionEnabled = false; return
        }
        resetForNewCharacterAttempt()
    }

    // MARK: - Actions (Called via closures from Coordinator now)
    func resetForNewCharacterAttempt() {
        print("MainView: resetForNewCharacterAttempt called.")
        guard let character = characterDataManager.currentCharacter else { return }
        strokeInputController.setup(with: pkCanvasView, for: character); speechRecognitionController.configure(with: character)
        concurrencyAnalyzer.setup(for: character); feedbackController.reset()
        pkCanvasView.drawing = PKDrawing(); currentStrokeAttemptData = nil; finalDrawingWithFeedback = nil
        isCharacterPracticeComplete = false; isCanvasInteractionEnabled = true
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
        guard let attemptData = self.currentStrokeAttemptData, attemptData.isReadyForAnalysis else { return }
        let accuracy = StrokeAnalysis.calculateAccuracy(drawnPoints: attemptData.drawnPoints, expectedStroke: attemptData.expectedStroke)
        let input = StrokeAnalysisInput(
             strokeIndex: attemptData.strokeIndex, expectedStroke: attemptData.expectedStroke,
             strokeStartTime: attemptData.strokeStartTime, strokeEndTime: attemptData.strokeEndTime,
             strokeAccuracy: accuracy, speechStartTime: attemptData.speechStartTime,
             speechEndTime: attemptData.speechEndTime, finalTranscription: attemptData.finalTranscription,
             transcriptionMatched: attemptData.transcriptionMatched, speechConfidence: attemptData.speechConfidence
        )
        concurrencyAnalyzer.analyzeStroke(input: input)
    }
}

// REMOVED: Delegate conformance extensions for MainView
