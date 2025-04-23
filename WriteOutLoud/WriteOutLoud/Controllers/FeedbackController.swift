// FeedbackController.swift
import Foundation
import Combine
import SwiftUI // For @Published, Color etc.
import AVFoundation // For AVAudioPlayer

class FeedbackController: ObservableObject {
    // Published properties to drive the FeedbackView
    @Published var currentStrokeFeedback: StrokeFeedback? = nil // Optional, only set after a stroke
    @Published var overallScoreMessage: String = ""
    @Published var overallScore: Double = 0 // Overall score (0-100)
    @Published var scoreBreakdown: ScoreBreakdown = ScoreBreakdown()
    @Published var showFeedbackView: Bool = false // Controls visibility of the feedback UI
    @Published var feedbackType: FeedbackType = .stroke // Determines content of the feedback UI

    // Keep track of feedback history if needed (e.g., for review)
    private(set) var strokeFeedbacks: [StrokeFeedback] = []

    // Audio player instance
    private var audioPlayer: AVAudioPlayer?

    // Reset state for a new character learning session
    func reset() {
        currentStrokeFeedback = nil
        overallScoreMessage = ""
        overallScore = 0
        scoreBreakdown = ScoreBreakdown()
        showFeedbackView = false
        strokeFeedbacks = []
        audioPlayer = nil // Release player
        print("FeedbackController reset.")
    }

    // Update feedback after a single stroke analysis
    func presentStrokeFeedback(index: Int, feedback: StrokeFeedback) {
        // Store feedback
        if index >= strokeFeedbacks.count {
            strokeFeedbacks.append(feedback)
        } else {
            strokeFeedbacks[index] = feedback // Update if re-attempting?
        }

        // Update published properties for UI
        currentStrokeFeedback = feedback
        feedbackType = .stroke
        showFeedbackView = true // Trigger the view to appear

        print("Presenting stroke \(index) feedback.")
        // Optionally play a brief sound based on stroke performance?
        // playSoundForStroke(feedback)
    }

    // Update feedback after the entire character analysis
    func presentOverallFeedback(score: Double, breakdown: ScoreBreakdown, message: String) {
        overallScore = score
        scoreBreakdown = breakdown
        overallScoreMessage = message
        feedbackType = .overall
        currentStrokeFeedback = nil // Clear stroke feedback when showing overall
        showFeedbackView = true // Trigger the view to appear

        print("Presenting overall feedback. Score: \(String(format: "%.1f", score))")
        // Play sound based on overall performance
        playFeedbackSound(overallScore: score)
    }

    // Dismiss the feedback view (called by the view itself)
    func dismissFeedback() {
        showFeedbackView = false
        print("Feedback view dismissed.")
    }

    // Play appropriate sound feedback based on overall score
    private func playFeedbackSound(overallScore: Double) {
        let soundName: String

        // Select sound based on score thresholds (0-100)
        if overallScore >= 90 { soundName = "excellent_sound" } // Use descriptive filenames
        else if overallScore >= 70 { soundName = "good_sound" }
        else if overallScore >= 50 { soundName = "ok_sound" }
        else { soundName = "try_again_sound" }

        // Assume sound files are MP3 format in the main bundle
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("Error: Sound file '\(soundName).mp3' not found in bundle.")
            return
        }

        do {
            // Stop previous sound if playing
            audioPlayer?.stop()
            
            // Configure audio session for playback (important for proper sound behavior)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default) // Adjust category as needed
            try audioSession.setActive(true)

            // Create and play the sound
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("Playing feedback sound: \(soundName).mp3")
        } catch let error as NSError {
             // More specific error handling
             if error.domain == NSOSStatusErrorDomain && error.code == AVAudioSession.ErrorCode.cannotStartPlaying.rawValue {
                 print("Error playing sound: Cannot start playing. Is another app using audio?")
             } else {
                  print("Error initializing or playing sound file '\(soundName).mp3': \(error.localizedDescription)")
             }
             audioPlayer = nil // Reset player on error
        }
    }

    // Enum to differentiate feedback types for the UI
    enum FeedbackType {
        case stroke
        case overall
    }
}
