// File: Views/MainView.swift
// VERSION: Removed obsolete feedbackOverlay and addressed related errors

import SwiftUI
import PencilKit
import Speech
import UIKit // Needed for UIColor comparison/creation

// MARK: - Delegate Coordinator Class
// (Assuming this is the DelegateCoordinator class structure you are using)
final class DelegateCoordinator: NSObject, ObservableObject, StrokeInputDelegate, SpeechRecognitionDelegate, ConcurrencyAnalyzerDelegate {

    var strokeInputController: StrokeInputController?
    var speechRecognitionController: SpeechRecognitionController?
    var concurrencyAnalyzer: ConcurrencyAnalyzer?
    var feedbackController: FeedbackController?
    var pkCanvasView: PKCanvasView?
    var updateCurrentStrokeAttemptData: ((MainView.StrokeAttemptData?) -> Void)?
    var getCurrentStrokeAttemptData: (() -> MainView.StrokeAttemptData?)?
    var updateFinalDrawing: ((PKDrawing?) -> Void)?
    var setIsPracticeComplete: ((Bool) -> Void)?
    var setIsCanvasInteractionEnabled: ((Bool) -> Void)?
    var prepareForSpeech: ((Int) -> Void)?
    var processCompletedStrokeAttempt: (() -> Void)?
    var showFinalResultsAction: (() -> Void)?
    var moveToNextStrokeAction: (() -> Void)?
    var updateUserProgress: ((Double) -> Void)?

    // MARK: - StrokeInputDelegate
    func strokeBegan(at time: Date, strokeType: StrokeType) {
        print("Coordinator: strokeBegan")
        updateCurrentStrokeAttemptData?(nil)
        if let controller = strokeInputController {
            prepareForSpeech?(controller.currentStrokeIndex)
            do { try speechRecognitionController?.startRecording() } catch {
                print("Coordinator Error: Failed to start speech - \(error)")
                if let idx = strokeInputController?.currentStrokeIndex,
                   let charStrokes = strokeInputController?.character?.strokes,
                   let exp = charStrokes[safe: idx] {
                    let failed = MainView.StrokeAttemptData(strokeIndex: idx, expectedStroke: exp, strokeStartTime: time, strokeEndTime: time, drawnPoints: [], transcriptionMatched: false)
                    updateCurrentStrokeAttemptData?(failed); processCompletedStrokeAttempt?()
                }
            }
        }
    }
    func strokeUpdated(points: [CGPoint]) { /* Optional: handle live updates */ }
    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int) {
        print("Coordinator: strokeEnded for index \(strokeIndex)")
        guard let startTime = strokeInputController?.strokeStartTime, strokeIndex == strokeInputController?.currentStrokeIndex else { return }
        let attempt = MainView.StrokeAttemptData(strokeIndex: strokeIndex, expectedStroke: expectedStroke, strokeStartTime: startTime, strokeEndTime: time, drawnPoints: drawnPoints)
        updateCurrentStrokeAttemptData?(attempt)
        speechRecognitionController?.processStrokeCompletion(strokeIndex: strokeIndex, startTime: startTime, endTime: time)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let data = self.getCurrentStrokeAttemptData?(), data.strokeIndex == strokeIndex, data.speechStartTime == nil {
                print("Coordinator: No speech detected for stroke \(strokeIndex) after waiting, processing analysis now.")
                var currentData = data; currentData.transcriptionMatched = nil
                self.updateCurrentStrokeAttemptData?(currentData); self.processCompletedStrokeAttempt?()
            } else if let data = self.getCurrentStrokeAttemptData?(), data.strokeIndex == strokeIndex {
                print("Coordinator: Speech data potentially received for stroke \(strokeIndex).")
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
        if var data = getCurrentStrokeAttemptData?(), data.strokeIndex == strokeInputController?.currentStrokeIndex, data.speechStartTime == nil {
            data.speechStartTime = time; updateCurrentStrokeAttemptData?(data)
        }
    }
    func speechRecordingStopped(at time: Date, duration: TimeInterval) { print("Coordinator: speechRecordingStopped. Duration: \(duration)") }
    func speechTranscriptionFinalized(transcription: String, matchesExpected: Bool, confidence: Float, startTime: Date, endTime: Date) {
        print("Coordinator: speechTranscriptionFinalized. Match: \(matchesExpected), Text: \"\(transcription)\"")
        if var data = getCurrentStrokeAttemptData?(), data.strokeIndex == strokeInputController?.currentStrokeIndex, !data.isReadyForAnalysis {
            data.speechEndTime = endTime; data.finalTranscription = transcription; data.transcriptionMatched = matchesExpected; data.speechConfidence = confidence
            updateCurrentStrokeAttemptData?(data); processCompletedStrokeAttempt?()
        } else { print("Coordinator: Transcription for non-current/already processed stroke, or no pending data.") }
    }
    func speechRecognitionErrorOccurred(_ error: Error) {
        print("Coordinator: speechRecognitionErrorOccurred: \(error.localizedDescription)")
        if var data = getCurrentStrokeAttemptData?(), data.strokeIndex == strokeInputController?.currentStrokeIndex, !data.isReadyForAnalysis {
            data.transcriptionMatched = false; data.finalTranscription = "[Error]"; data.speechEndTime = Date()
            updateCurrentStrokeAttemptData?(data); processCompletedStrokeAttempt?()
        } else { print("Coordinator: Error for non-current/already processed stroke, or no pending data.") }
    }
    func speechRecognitionNotAvailable() {
        print("Coordinator: speechRecognitionNotAvailable.")
        if var data = getCurrentStrokeAttemptData?(), data.strokeIndex == strokeInputController?.currentStrokeIndex, !data.isReadyForAnalysis {
            data.transcriptionMatched = nil; data.finalTranscription = "[N/A]"; data.speechEndTime = Date()
            updateCurrentStrokeAttemptData?(data); processCompletedStrokeAttempt?()
        } else { print("Coordinator: Unavailability for non-current/already processed stroke, or no pending data.") }
    }
    func speechAuthorizationDidChange(to status: SFSpeechRecognizerAuthorizationStatus) { print("Coordinator: speechAuthorizationDidChange: \(status)") }

    // MARK: - ConcurrencyAnalyzerDelegate
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback) {
        print("Coordinator: strokeAnalysisCompleted for index \(timingData.strokeIndex).")
        DispatchQueue.main.async {
            // The FeedbackController now only records feedback internally and plays sounds.
            // It does not directly drive a pop-up UI view.
            self.feedbackController?.recordStrokeFeedback(index: timingData.strokeIndex, feedback: feedback)
            
            if let currentData = self.getCurrentStrokeAttemptData?(), currentData.strokeIndex == timingData.strokeIndex {
                self.updateCurrentStrokeAttemptData?(nil)
                print("Coordinator: Cleared currentStrokeAttemptData for index \(timingData.strokeIndex) after analysis.")
            }
            // The WritingPaneView might update its StrokeInfoBar here based on new analysisHistory.
            // Move to next stroke logic
            if self.strokeInputController?.isDrawing == false && self.pkCanvasView?.isUserInteractionEnabled == true {
                print("Coordinator: Drawing ended and canvas enabled, proceeding to next stroke action.")
                self.moveToNextStrokeAction?()
            } else {
                print("Coordinator: Not moving to next stroke. isDrawing: \(String(describing: self.strokeInputController?.isDrawing)), canvasInteraction: \(String(describing: self.pkCanvasView?.isUserInteractionEnabled)).")
            }
        }
    }
    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String) {
        print("Coordinator: overallAnalysisCompleted. Score: \(overallScore)")
        guard let finalDrawing = pkCanvasView?.drawing, let history = concurrencyAnalyzer?.analysisHistory else {
            print("Coordinator Error: Missing canvas drawing or analysis history for final feedback.")
            DispatchQueue.main.async { self.setIsPracticeComplete?(true) }
            return
        }
        var strokesWithFeedback: [PKStroke] = []
        let accuracyThreshold = 60.0; let inaccurateColor = UIColor.red; let accurateColor = UIColor.systemGreen
        for (index, drawnStroke) in finalDrawing.strokes.enumerated() {
            var newStroke = drawnStroke
            if let analysisData = history.first(where: { $0.strokeIndex == index }) {
                newStroke.ink = PKInk(newStroke.ink.inkType, color: analysisData.strokeAccuracy < accuracyThreshold ? inaccurateColor : accurateColor)
            }
            strokesWithFeedback.append(newStroke)
        }
        let finalFeedbackDrawing = PKDrawing(strokes: strokesWithFeedback)
        DispatchQueue.main.async {
            // FeedbackController now calculates, stores, and plays sound.
            // It does not manage a pop-up view.
            self.feedbackController?.calculateAndPresentOverallFeedback(score: overallScore, breakdown: breakdown, message: feedback)
            self.updateFinalDrawing?(finalFeedbackDrawing) // This state is used by WritingPaneView
            self.setIsPracticeComplete?(true)             // This state is used by WritingPaneView
            self.updateCurrentStrokeAttemptData?(nil)     // Final clear
            self.updateUserProgress?(overallScore)
            print("  Coordinator: Final feedback generated and state updated for WritingPaneView. Interaction remains disabled.")
        }
    }
}


// MARK: - MainView Struct
struct MainView: View {
    @EnvironmentObject private var characterDataManager: CharacterDataManager
    @EnvironmentObject private var userManager: UserManager

    @StateObject private var strokeInputController = StrokeInputController()
    @StateObject private var speechRecognitionController = SpeechRecognitionController()
    @StateObject private var concurrencyAnalyzer = ConcurrencyAnalyzer()
    @StateObject private var feedbackController = FeedbackController()
    @StateObject private var delegateCoordinator = DelegateCoordinator()

    @State private var isCanvasInteractionEnabled: Bool = true
    @State private var isCharacterPracticeComplete: Bool = false
    @State private var finalDrawingWithFeedback: PKDrawing?
    @State private var showingRealTimeTranscript: Bool = true
    @State private var currentStrokeAttemptData: StrokeAttemptData?
    @State private var lastTranscript: String = ""
    @State private var pkCanvasView: PKCanvasView = PKCanvasView()

    @State private var selectedCharacterIndex = 0

    struct StrokeAttemptData {
        let strokeIndex: Int; let expectedStroke: Stroke; let strokeStartTime: Date; let strokeEndTime: Date
        let drawnPoints: [CGPoint]; var speechStartTime: Date? = nil; var speechEndTime: Date? = nil
        var finalTranscription: String? = nil; var transcriptionMatched: Bool? = nil
        var speechConfidence: Float? = nil
        var isReadyForAnalysis: Bool { return speechStartTime == nil || transcriptionMatched != nil }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    HStack {
                        Text("Show Real-time Transcript")
                            .font(.subheadline)
                        Toggle("", isOn: $showingRealTimeTranscript)
                            .labelsHidden()
                    }
                    .tint(.blue)
                    .padding(.vertical, 4)
                    .padding(.horizontal)
                }
                .background(Color(UIColor.systemGray6).opacity(0.7))
                HStack(spacing: 0) {
                    referencePanel(geometry: geometry)
                    Divider()
                    writingPanel(geometry: geometry, isInteractionEnabled: isCanvasInteractionEnabled, onTapToWriteAgain: resetForNewCharacterAttempt)
                }
                .frame(maxHeight: .infinity)
            }
            .environmentObject(characterDataManager)
            .onAppear(perform: initialSetup)
            .onChange(of: characterDataManager.currentCharacter?.id) { oldId, newId in
                 if oldId != newId {
                     if let newChar = characterDataManager.currentCharacter, let idx = characterDataManager.characters.firstIndex(where: { $0.id == newChar.id }) { selectedCharacterIndex = idx }
                     handleCharacterChange(character: characterDataManager.currentCharacter)
                 }
            }
            .onChange(of: characterDataManager.characters) { oldChars, newChars in
                 if oldChars.isEmpty && !newChars.isEmpty && characterDataManager.currentCharacter == nil { initialSetup() }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    @ViewBuilder private func referencePanel(geometry: GeometryProxy) -> some View {
       VStack(spacing: 0) {
             Text("Characters Selection").font(.headline).padding(.vertical, 8).padding(.horizontal).frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.secondarySystemBackground))
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
            showRealtimeTranscript: showingRealTimeTranscript,
            realtimeTranscript: lastTranscript // Pass String value, not Binding
        )
        .frame(width: geometry.size.width * 0.60)
    }

    private func initialSetup() {
        print("MainView: initialSetup called.")
        delegateCoordinator.strokeInputController = self.strokeInputController
        delegateCoordinator.speechRecognitionController = self.speechRecognitionController
        delegateCoordinator.concurrencyAnalyzer = self.concurrencyAnalyzer
        delegateCoordinator.feedbackController = self.feedbackController
        delegateCoordinator.pkCanvasView = self.pkCanvasView
        delegateCoordinator.updateCurrentStrokeAttemptData = { data in self.currentStrokeAttemptData = data }
        delegateCoordinator.getCurrentStrokeAttemptData = { return self.currentStrokeAttemptData }
        delegateCoordinator.updateFinalDrawing = { drawing in self.finalDrawingWithFeedback = drawing }
        delegateCoordinator.setIsPracticeComplete = { complete in self.isCharacterPracticeComplete = complete }
        delegateCoordinator.setIsCanvasInteractionEnabled = { enabled in self.isCanvasInteractionEnabled = enabled }
        delegateCoordinator.prepareForSpeech = { index in self.prepareForSpeech(strokeIndex: index) }
        delegateCoordinator.processCompletedStrokeAttempt = { self.processCompletedStrokeAttempt() }
        delegateCoordinator.showFinalResultsAction = { self.showFinalResultsAction() }
        delegateCoordinator.moveToNextStrokeAction = { self.moveToNextStrokeAction() }
        delegateCoordinator.updateUserProgress = { accuracy in
            if let characterId = self.characterDataManager.currentCharacter?.id {
                self.userManager.updateUserProgress(characterId: characterId, accuracy: accuracy)
            }
        }
        strokeInputController.delegate = delegateCoordinator
        speechRecognitionController.delegate = delegateCoordinator
        concurrencyAnalyzer.delegate = delegateCoordinator
        print("MainView: Delegates assigned to Coordinator.")
        if !characterDataManager.characters.isEmpty && characterDataManager.currentCharacter == nil {
             selectedCharacterIndex = 0
             characterDataManager.selectCharacter(withId: characterDataManager.characters[0].id)
        } else if let currentChar = characterDataManager.currentCharacter {
             if let idx = characterDataManager.characters.firstIndex(of: currentChar) { selectedCharacterIndex = idx }
             handleCharacterChange(character: currentChar)
        } else { handleCharacterChange(character: nil) }
    }

    private func handleCharacterChange(character: Character?) {
        print("MainView: handleCharacterChange for \(character?.character ?? "nil character")")
        guard let character = character, !character.strokes.isEmpty else {
            print("MainView: No character or character has no strokes. Clearing state.")
            pkCanvasView.drawing = PKDrawing()
            strokeInputController.setup(with: pkCanvasView, for: .empty)
            concurrencyAnalyzer.setup(for: .empty)
            speechRecognitionController.configure(with: .empty)
            feedbackController.reset()
            currentStrokeAttemptData = nil; finalDrawingWithFeedback = nil
            isCharacterPracticeComplete = false; isCanvasInteractionEnabled = false; lastTranscript = ""
            return
        }
        resetForNewCharacterAttempt()
    }

    func resetForNewCharacterAttempt() {
        print("MainView: resetForNewCharacterAttempt called.")
        guard let character = characterDataManager.currentCharacter else { return }
        strokeInputController.setup(with: pkCanvasView, for: character)
        speechRecognitionController.configure(with: character)
        concurrencyAnalyzer.setup(for: character)
        feedbackController.reset()
        pkCanvasView.drawing = PKDrawing(); currentStrokeAttemptData = nil; finalDrawingWithFeedback = nil
        isCharacterPracticeComplete = false; isCanvasInteractionEnabled = true; lastTranscript = ""
        if !character.strokes.isEmpty { prepareForSpeech(strokeIndex: 0) }
    }

    func moveToNextStrokeAction() {
        print("MainView: moveToNextStrokeAction. SIC index before: \(strokeInputController.currentStrokeIndex)")
        let indexJustCompleted = strokeInputController.currentStrokeIndex
        let shouldContinue = strokeInputController.checkCompletionAndAdvance(indexJustCompleted: indexJustCompleted)
        print("MainView: checkCompletionAndAdvance returned \(shouldContinue). SIC index after: \(strokeInputController.currentStrokeIndex)")
        if shouldContinue {
            pkCanvasView.drawing = PKDrawing()
            prepareForSpeech(strokeIndex: strokeInputController.currentStrokeIndex)
        } else { print("MainView: All strokes complete or error.") }
    }

    func showFinalResultsAction() {
        print("MainView: showFinalResultsAction called.")
        isCanvasInteractionEnabled = false
        concurrencyAnalyzer.calculateFinalCharacterScore()
    }

    func prepareForSpeech(strokeIndex: Int) {
        print("MainView: prepareForSpeech for index \(strokeIndex).")
        guard let char = characterDataManager.currentCharacter, let stroke = char.strokes[safe: strokeIndex] else { return }
        speechRecognitionController.prepareForStroke(expectedName: stroke.name)
    }

    func processCompletedStrokeAttempt() {
        print("MainView: processCompletedStrokeAttempt...")
        guard let attemptData = self.currentStrokeAttemptData else { print("MainView Error: nil attemptData."); return }
        guard attemptData.isReadyForAnalysis else { print("MainView: Attempt data (stroke \(attemptData.strokeIndex)) not ready."); return }
        print("MainView: Processing stroke \(attemptData.strokeIndex). Accuracy calc on background.")
        
        // Create a local copy of the data to use in the background task
        let localAttemptData = attemptData
        
        DispatchQueue.global(qos: .userInitiated).async(execute: DispatchWorkItem(block: {
            let accuracy = StrokeAnalysis.calculateAccuracy(
                drawnPoints: localAttemptData.drawnPoints, expectedStroke: localAttemptData.expectedStroke
            )
            
            let input = StrokeAnalysisInput(
                strokeIndex: localAttemptData.strokeIndex, 
                expectedStroke: localAttemptData.expectedStroke,
                strokeStartTime: localAttemptData.strokeStartTime, 
                strokeEndTime: localAttemptData.strokeEndTime,
                strokeAccuracy: accuracy,
                speechStartTime: localAttemptData.speechStartTime, 
                speechEndTime: localAttemptData.speechEndTime,
                finalTranscription: localAttemptData.finalTranscription,
                transcriptionMatched: localAttemptData.transcriptionMatched, 
                speechConfidence: localAttemptData.speechConfidence
            )
            
            // Use a work item for the main queue execution
            let mainQueueWork = DispatchWorkItem {
                print("MainView: Accuracy calc done for \(input.strokeIndex). Sending to Analyzer.")
                self.concurrencyAnalyzer.analyzeStroke(input: input)
            }
            DispatchQueue.main.async(execute: mainQueueWork)
        }))
    }
}
