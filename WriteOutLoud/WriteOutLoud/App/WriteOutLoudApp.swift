// File: App/WriteOutLoudApp.swift
import SwiftUI

@main
struct WriteOutLoudApp: App {
    // Create the CharacterDataManager instance here as a StateObject
    // This ensures it persists for the lifetime of the app and can be observed.
    @StateObject private var characterDataManager = CharacterDataManager()

    var body: some Scene {
        WindowGroup {
            // Set MainView as the root view
            MainView()
                // Inject the CharacterDataManager into the environment
                .environmentObject(characterDataManager)
        }
    }
}
