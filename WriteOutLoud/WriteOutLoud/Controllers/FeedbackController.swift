// File: Controllers/FeedbackController.swift
// VERSION: Simplified - No longer drives direct UI feedback view

import Foundation
import Combine
import AVFoundation // For AVAudioPlayer

class FeedbackController: ObservableObject {

    // Published properties for potential final summary (not driving pop-up anymore)
    @Published var overallScoreMessage: String = ""
    @Published var overallScore: Double = 0 // Overall score (0-100)
    @Published var scoreBreakdown: ScoreBreakdown = ScoreBreakdown()
    @Published var isOverallFeedbackReady: Bool = false // Flag indicating final calculation is done

    // Keep track of feedback history if needed internally
    private(set) var strokeFeedbacks: [StrokeFeedback] = [] // Store text feedback if needed internally

    // Audio player instance
    private var audioPlayer: AVAudioPlayer?

    // Reset state for a new character learning session
    func reset() {
        overallScoreMessage = ""
        overallScore = 0
        scoreBreakdown = ScoreBreakdown()
        isOverallFeedbackReady = false
        strokeFeedbacks = []
        audioPlayer?.stop() // Stop any playing sound
        audioPlayer = nil // Release player
        print("FeedbackController reset.")
    }

    // Stores text feedback internally (not for UI display)
    func recordStrokeFeedback(index: Int, feedback: StrokeFeedback) {
        if index >= strokeFeedbacks.count {
            strokeFeedbacks.append(feedback)
        } else {
            strokeFeedbacks[index] = feedback
        }
        print("FeedbackController: Recorded internal feedback for stroke \(index)")
    }


    // Calculate and store final feedback state, play sound
    func calculateAndPresentOverallFeedback(score: Double, breakdown: ScoreBreakdown, message: String) {
        DispatchQueue.main.async {
            self.overallScore = score
            self.scoreBreakdown = breakdown
            self.overallScoreMessage = message
            self.isOverallFeedbackReady = true // Mark final calculation as complete

            print("FeedbackController: Calculated overall feedback. Score: \(String(format: "%.1f", score))")
            // Play sound based on overall performance
            self.playFeedbackSound(overallScore: score)
        }
    }

    // Play appropriate sound feedback based on overall score (Unchanged)
    private func playFeedbackSound(overallScore: Double) {
        let soundName: String

        if overallScore >= 90 { soundName = "excellent_sound" }
        else if overallScore >= 70 { soundName = "good_sound" }
        else if overallScore >= 50 { soundName = "ok_sound" }
        else { soundName = "try_again_sound" }

        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("Error: Sound file '\(soundName).mp3' not found in bundle.")
            return
        }

        do {
            audioPlayer?.stop()
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("Playing feedback sound: \(soundName).mp3")
        } catch let error as NSError {
             if error.domain == NSOSStatusErrorDomain && error.code == AVAudioSession.ErrorCode.cannotStartPlaying.rawValue {
                 print("Error playing sound: Cannot start playing. Is another app using audio?")
             } else {
                  print("Error initializing or playing sound file '\(soundName).mp3': \(error.localizedDescription)")
             }
             audioPlayer = nil
        }
    }
}
