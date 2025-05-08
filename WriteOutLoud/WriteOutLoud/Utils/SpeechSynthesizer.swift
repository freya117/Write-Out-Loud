// File: Utils/SpeechSynthesizer.swift

import Foundation
import AVFoundation // Needed for AVSpeechSynthesizer

/**
 A simple utility struct to handle Text-to-Speech using AVSpeechSynthesizer.
 */
struct SpeechSynthesizer {

    // Shared instance to manage the speech queue
    private static let synthesizer = AVSpeechSynthesizer()

    /**
     Speaks the given text using the specified BCP-47 language code.

     - Parameters:
       - text: The string to be spoken.
       - language: The BCP-47 language code (e.g., "en-US", "zh-CN"). Defaults to "zh-CN".
     */
    static func speak(text: String, language: String = "zh-CN") {
        // Ensure text is not empty
        guard !text.isEmpty else {
            print("SpeechSynthesizer: Cannot speak empty text.")
            return
        }

        // Configure audio session for playback
        configureAudioSessionForPlayback()

        // Stop any currently speaking utterance before starting a new one
        // This prevents overlap if the user taps quickly.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Create the utterance
        let utterance = AVSpeechUtterance(string: text)

        // Set the voice based on the language code
        utterance.voice = AVSpeechSynthesisVoice(language: language)

        // Adjust speech rate and pitch if desired (optional)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate // Use default rate
        // utterance.pitchMultiplier = 1.0 // Default pitch

        // Speak the utterance
        print("SpeechSynthesizer: Speaking '\(text)' in language '\(language)'")
        synthesizer.speak(utterance)
    }

    // Optional: Function to stop speaking immediately
    static func stopSpeaking() {
        if synthesizer.isSpeaking {
            print("SpeechSynthesizer: Stopping current speech.")
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // Configure the audio session for playback
    private static func configureAudioSessionForPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            print("SpeechSynthesizer: Configuring audio session for playback")
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("SpeechSynthesizer: Audio session configured successfully for playback")
        } catch {
            print("SpeechSynthesizer: Failed to configure audio session for playback: \(error)")
        }
    }
}
