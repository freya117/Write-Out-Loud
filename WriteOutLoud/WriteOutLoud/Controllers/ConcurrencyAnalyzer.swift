// File: Controllers/ConcurrencyAnalyzer.swift
import Foundation
import Combine
import AVFoundation // For AVAudioSession potentially

// MARK: - Input/Output Structs (unchanged)
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

// MARK: - Delegate Protocol (unchanged)
protocol ConcurrencyAnalyzerDelegate {
    func strokeAnalysisCompleted(timingData: StrokeTimingData, feedback: StrokeFeedback)
    func overallAnalysisCompleted(overallScore: Double, breakdown: ScoreBreakdown, feedback: String)
}

// MARK: - ConcurrencyAnalyzer Class
class ConcurrencyAnalyzer: ObservableObject {
    // Published Properties (unchanged)
    @Published var analysisHistory: [StrokeTimingData] = []
    @Published var currentOverallScore: Double = 0
    @Published var currentScoreBreakdown: ScoreBreakdown = ScoreBreakdown()

    // Delegate (unchanged)
    var delegate: ConcurrencyAnalyzerDelegate?

    // Internal State
    private var character: Character? // CHANGED: Store full Character object to access strokeCount
    private var currentStrokeTimings: [StrokeTimingData] = []

    // Setup (MODIFIED to store character)
    func setup(for character: Character) {
        self.character = character
        self.currentStrokeTimings.removeAll()
        self.analysisHistory.removeAll()
        self.currentOverallScore = 0
        self.currentScoreBreakdown = ScoreBreakdown()
        print("ConcurrencyAnalyzer setup for character \(character.character) with \(character.strokeCount) strokes.")
    }

    // Analysis (unchanged)
    func analyzeStroke(input: StrokeAnalysisInput) {
        guard let character = character, input.strokeIndex < character.strokeCount else {
            print("Error: Stroke index \(input.strokeIndex) out of bounds or character not set.")
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

    // generateStrokeFeedback (unchanged)
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

    // calculateFinalCharacterScore (MODIFIED to handle partial completion)
    func calculateFinalCharacterScore() {
        guard let character = character else {
            print("Error: No character set for final score calculation.")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentOverallScore = 0
                self.currentScoreBreakdown = ScoreBreakdown()
                self.delegate?.overallAnalysisCompleted(overallScore: 0, breakdown: self.currentScoreBreakdown, feedback: "No character data available.")
            }
            return
        }
        
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
        
        // Process whatever strokes we have (even if incomplete)
        let completedCount = currentStrokeTimings.count
        let totalCount = character.strokeCount
        
        if completedCount < totalCount {
            print("Note: Partial character completion (\(completedCount)/\(totalCount) strokes). Still calculating score for completed strokes.")
        }
        
        // Calculate score breakdown based on completed strokes
        var breakdown = ScoreBreakdown()
        
        // 1. Average stroke accuracy
        var totalAccuracy: Double = 0
        for timing in currentStrokeTimings {
            totalAccuracy += timing.strokeAccuracy
        }
        breakdown.strokeAccuracy = totalAccuracy / Double(completedCount)
        
        // 2. Speech correctness (percentage of strokes with correct speech)
        var correctSpeechCount = 0
        for timing in currentStrokeTimings {
            if timing.transcriptionMatched == true {
                correctSpeechCount += 1
            }
        }
        breakdown.speechCorrectness = completedCount > 0 ? (Double(correctSpeechCount) / Double(completedCount)) * 100.0 : 0
        
        // 3. Average concurrency score
        var totalConcurrency: Double = 0
        var concurrencyDataCount = 0
        for timing in currentStrokeTimings {
            if timing.speechStartTime != nil {
                totalConcurrency += timing.concurrencyScore
                concurrencyDataCount += 1
            }
        }
        breakdown.concurrencyScore = concurrencyDataCount > 0 ? totalConcurrency / Double(concurrencyDataCount) : 0
        
        // Calculate weighted overall score (give more weight to stroke accuracy)
        let overallScore = (
            breakdown.strokeAccuracy * 0.5 +
            breakdown.speechCorrectness * 0.3 +
            breakdown.concurrencyScore * 0.2
        )
        
        // Generate overall feedback message
        let completionRatio = Double(completedCount) / Double(totalCount)
        let feedbackMessage = generateOverallFeedback(
            score: overallScore, 
            breakdown: breakdown, 
            completionRatio: completionRatio
        )
        
        // Update published properties and notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentOverallScore = overallScore
            self.currentScoreBreakdown = breakdown
            self.delegate?.overallAnalysisCompleted(
                overallScore: overallScore,
                breakdown: breakdown,
                feedback: feedbackMessage
            )
        }
    }

    // Generate overall feedback message based on score and completion
    private func generateOverallFeedback(score: Double, breakdown: ScoreBreakdown, completionRatio: Double) -> String {
        var feedback = ""
        
        // Add completion status
        if completionRatio < 1.0 {
            feedback += "You completed \(Int(completionRatio * 100))% of the character. "
            
            if completionRatio < 0.5 {
                feedback += "Try to complete the full character next time. "
            }
        }
        
        // Add score-based feedback
        if score >= 90 {
            feedback += "Excellent work! "
        } else if score >= 75 {
            feedback += "Very good job! "
        } else if score >= 60 {
            feedback += "Good effort! "
        } else if score >= 40 {
            feedback += "Keep practicing. "
        } else {
            feedback += "Let's try again. "
        }
        
        // Add specific feedback
        if breakdown.strokeAccuracy < 60 {
            feedback += "Focus on stroke shape accuracy. "
        }
        
        if breakdown.speechCorrectness < 60 {
            feedback += "Remember to say the correct stroke names. "
        }
        
        if breakdown.concurrencyScore < 40 {
            feedback += "Try to speak while writing. "
        }
        
        return feedback
    }
}
