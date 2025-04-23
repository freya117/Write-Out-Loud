// File: Controllers/ConcurrencyAnalyzer.swift
import Foundation
import Combine
import AVFoundation // For AVAudioSession potentially

// MARK: - Input/Output Structs (remain the same)
struct StrokeAnalysisInput {
    let strokeIndex: Int
    let expectedStroke: Stroke
    let strokeStartTime: Date
    let strokeEndTime: Date
    let strokeAccuracy: Double
    let speechStartTime: Date?
    let speechEndTime: Date?
    let finalTranscription: String?
    let transcriptionMatched: Bool?
    let speechConfidence: Float?
}
struct StrokeTimingData {
    let strokeIndex: Int
    let strokeType: StrokeType
    let strokeName: String
    let strokeStartTime: Date
    let strokeEndTime: Date
    let strokeAccuracy: Double
    let speechStartTime: Date?
    let speechEndTime: Date?
    let finalTranscription: String?
    let transcriptionMatched: Bool?
    let speechConfidence: Float?
    let concurrencyScore: Double
    var strokeDuration: TimeInterval { strokeEndTime.timeIntervalSince(strokeStartTime) }
    var speechDuration: TimeInterval? {
        guard let start = speechStartTime, let end = speechEndTime else { return nil }
        return max(0, end.timeIntervalSince(start))
    }
}
struct ScoreBreakdown {
    var strokeAccuracy: Double = 0
    var speechCorrectness: Double = 0
    var concurrencyScore: Double = 0
}
struct StrokeFeedback {
    var strokeMessage: String = ""
    var speechMessage: String = ""
    var concurrencyMessage: String = ""
}

// MARK: - Delegate Protocol (remains the same - no :AnyObject)
protocol ConcurrencyAnalyzerDelegate {
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback)
    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String)
}

// MARK: - ConcurrencyAnalyzer Class
class ConcurrencyAnalyzer: ObservableObject {
    // Published Properties (remain the same)
    @Published var analysisHistory: [StrokeTimingData] = []
    @Published var currentOverallScore: Double = 0
    @Published var currentScoreBreakdown: ScoreBreakdown = ScoreBreakdown()

    // Delegate (remains the same - no weak)
    var delegate: ConcurrencyAnalyzerDelegate?

    // Internal State (remain the same)
    private var characterStrokes: [Stroke] = []
    private var currentStrokeTimings: [StrokeTimingData] = []

    // Setup (remains the same)
    func setup(for character: Character) {
        self.characterStrokes = character.strokes
        self.currentStrokeTimings.removeAll()
        self.analysisHistory.removeAll()
        self.currentOverallScore = 0
        self.currentScoreBreakdown = ScoreBreakdown()
        print("ConcurrencyAnalyzer setup for character \(character.character) with \(character.strokeCount) strokes.")
    }

    // Analysis (remains the same)
    func analyzeStroke(input: StrokeAnalysisInput) {
        guard input.strokeIndex < characterStrokes.count else {
            print("Error: Stroke index \(input.strokeIndex) out of bounds.")
            return
        }
        guard input.expectedStroke.order == input.strokeIndex + 1 else {
            print("Error: Mismatch between input index (\(input.strokeIndex)) and expected order (\(input.expectedStroke.order)).")
            return
        }

        var concurrencyScore: Double = 0.0
        if let speechStart = input.speechStartTime, let speechEnd = input.speechEndTime {
            let overlapRatio = TimestampSynchronizer.calculateOverlapRatio(
                startTime1: input.strokeStartTime, endTime1: input.strokeEndTime,
                startTime2: speechStart, endTime2: speechEnd
            )
            concurrencyScore = overlapRatio * 100.0
        } else {
            concurrencyScore = 0.0
        }

        let timingData = StrokeTimingData(
            strokeIndex: input.strokeIndex,
            strokeType: input.expectedStroke.type,
            strokeName: input.expectedStroke.name,
            strokeStartTime: input.strokeStartTime,
            strokeEndTime: input.strokeEndTime,
            strokeAccuracy: input.strokeAccuracy,
            speechStartTime: input.speechStartTime,
            speechEndTime: input.speechEndTime,
            finalTranscription: input.finalTranscription,
            transcriptionMatched: input.transcriptionMatched,
            speechConfidence: input.speechConfidence,
            concurrencyScore: concurrencyScore
        )

        currentStrokeTimings.append(timingData)
        DispatchQueue.main.async { [weak self] in
            self?.analysisHistory.append(timingData)
        }

        let feedback = generateStrokeFeedback(for: timingData)

        print("Stroke \(input.strokeIndex) Analysis Complete: Acc=\(String(format: "%.1f", timingData.strokeAccuracy)), Speech=\(timingData.transcriptionMatched ?? false), Conc=\(String(format: "%.1f", timingData.concurrencyScore))")

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.strokeAnalysisCompleted(timingData: timingData, feedback: feedback)
        }
    }

    // generateStrokeFeedback (Add @unknown default if needed, remains same otherwise)
    private func generateStrokeFeedback(for timing: StrokeTimingData) -> StrokeFeedback {
        var feedback = StrokeFeedback()

        // 1. Stroke accuracy feedback
        if timing.strokeAccuracy >= 90 { feedback.strokeMessage = "Excellent stroke!" }
        else if timing.strokeAccuracy >= 70 { feedback.strokeMessage = "Good stroke shape." }
        else if timing.strokeAccuracy >= 50 { feedback.strokeMessage = "Okay stroke, check the reference shape." }
        else { feedback.strokeMessage = "Try drawing the stroke shape more carefully." }

        // 2. Speech correctness feedback
        switch timing.transcriptionMatched {
        case true:
            feedback.speechMessage = "Correct name: '\(timing.strokeName)'!"
        case false:
            if let transcription = timing.finalTranscription, !transcription.isEmpty {
                feedback.speechMessage = "Hmm, heard '\(transcription)'. Expected: '\(timing.strokeName)'."
            } else {
                feedback.speechMessage = "Incorrect stroke name spoken. Expected: '\(timing.strokeName)'."
            }
        case nil:
            feedback.speechMessage = "Remember to say the stroke name ('\(timing.strokeName)') aloud!"
        // Add @unknown default for future proofing, though Bool? only has 3 states
        @unknown default:
             print("Warning: Unexpected case in transcriptionMatched switch: \(String(describing: timing.transcriptionMatched))")
             feedback.speechMessage = "Error processing speech result."
        }

        // 3. Concurrency feedback
        if timing.speechStartTime != nil {
             if timing.concurrencyScore >= 85 { feedback.concurrencyMessage = "Great timing - speech and writing synced!" }
             else if timing.concurrencyScore >= 60 { feedback.concurrencyMessage = "Good timing synchronization." }
             else if timing.concurrencyScore >= 30 { feedback.concurrencyMessage = "Try to speak *while* drawing the stroke." }
             else { feedback.concurrencyMessage = "Work on synchronizing your speech and writing." }
        } else {
             feedback.concurrencyMessage = ""
        }

        return feedback
    }

    // calculateFinalCharacterScore (Pass speechAttemptCount)
    func calculateFinalCharacterScore() {
        guard !currentStrokeTimings.isEmpty else {
            print("No stroke data to calculate final score.")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentOverallScore = 0
                self.currentScoreBreakdown = ScoreBreakdown()
                self.delegate?.overallAnalysisCompleted(overallScore: 0, breakdown: self.currentScoreBreakdown, feedback: "No strokes were analyzed.")
            }
            return
        }

        let numStrokes = Double(currentStrokeTimings.count)
        var totalStrokeAccuracy: Double = 0
        var totalSpeechCorrectnessScore: Double = 0
        var totalConcurrencyScore: Double = 0
        // *** Declare speechAttemptCount here ***
        var speechAttemptCount: Int = 0

        for timing in currentStrokeTimings {
            totalStrokeAccuracy += timing.strokeAccuracy
            totalSpeechCorrectnessScore += (timing.transcriptionMatched == true) ? 100.0 : 0.0
            if timing.speechStartTime != nil {
                totalConcurrencyScore += timing.concurrencyScore
                speechAttemptCount += 1 // Increment here
            }
        }

        let avgStrokeAccuracy = totalStrokeAccuracy / numStrokes
        let avgSpeechCorrectness = totalSpeechCorrectnessScore / numStrokes
        let avgConcurrencyScore = speechAttemptCount > 0 ? (totalConcurrencyScore / Double(speechAttemptCount)) : 0.0

        let breakdown = ScoreBreakdown(
            strokeAccuracy: avgStrokeAccuracy,
            speechCorrectness: avgSpeechCorrectness,
            concurrencyScore: avgConcurrencyScore
        )

        let overallScore = (avgStrokeAccuracy * 0.5) + (avgSpeechCorrectness * 0.3) + (avgConcurrencyScore * 0.2)
        let finalOverallScore = max(0.0, min(100.0, overallScore))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentScoreBreakdown = breakdown
            self.currentOverallScore = finalOverallScore
        }

        print("Final Character Score Calculation:")
        print("  Avg Accuracy: \(String(format: "%.1f", breakdown.strokeAccuracy))")
        print("  Avg Speech Correctness: \(String(format: "%.1f", breakdown.speechCorrectness))")
        print("  Avg Concurrency (on \(speechAttemptCount) attempts): \(String(format: "%.1f", breakdown.concurrencyScore))")
        print("  Overall Score: \(String(format: "%.1f", finalOverallScore))")

        // *** Pass speechAttemptCount to feedback generation ***
        let overallFeedback = generateOverallFeedbackMessage(score: finalOverallScore, breakdown: breakdown, speechAttempts: speechAttemptCount) // Pass it here

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.overallAnalysisCompleted(
                overallScore: finalOverallScore,
                breakdown: breakdown,
                feedback: overallFeedback
            )
        }
    }

    // generateOverallFeedbackMessage (Accept and use speechAttempts)
    /// Generates an overall feedback message based on the final scores.
    // *** MODIFIED: Added speechAttempts parameter to the signature ***
    private func generateOverallFeedbackMessage(score: Double, breakdown: ScoreBreakdown, speechAttempts: Int) -> String {
        var messages: [String] = []

        // Stroke accuracy feedback
        if breakdown.strokeAccuracy >= 90 { messages.append("Excellent stroke accuracy!") }
        else if breakdown.strokeAccuracy >= 70 { messages.append("Good overall stroke shapes.") }
        else { messages.append("Focus on improving stroke shapes.") }

        // Speech feedback
        if breakdown.speechCorrectness >= 90 { messages.append("Perfect stroke naming!") }
        else if breakdown.speechCorrectness >= 60 { messages.append("You named most strokes correctly.") }
        else { messages.append("Review the stroke names carefully.") }

        // Concurrency feedback (Use speechAttempts parameter)
        // *** FIXED: Use the passed-in speechAttempts parameter ***
        if speechAttempts > 0 && breakdown.speechCorrectness > 30 {
             if breakdown.concurrencyScore >= 80 { messages.append("Great job syncing speech and writing!") }
             else if breakdown.concurrencyScore >= 50 { messages.append("Work on your timing synchronization.") }
             else { messages.append("Try saying the name *while* drawing.") }
        } else if speechAttempts > 0 { // User attempted speech but got names mostly wrong
             messages.append("Focus on saying the correct names first, then work on timing.")
        }
        // If speechAttempts is 0, no concurrency feedback is given.

        // Overall performance message
        if score >= 90 { messages.append("Outstanding work!") }
        else if score >= 75 { messages.append("Very good! Keep practicing.") }
        else if score >= 60 { messages.append("Good effort! Practice makes perfect.") }
        else { messages.append("Keep practicing to improve.") }

        return messages.joined(separator: " ")
    }
}
