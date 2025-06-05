// File: App/WriteOutLoudApp.swift
import SwiftUI

@main
struct WriteOutLoudApp: App {
    // Create the manager instances as StateObjects
    // This ensures they persist for the lifetime of the app and can be observed.
    @StateObject private var characterDataManager = CharacterDataManager()
    @StateObject private var userManager = UserManager()

    var body: some Scene {
        WindowGroup {
            // Set AuthenticationContainer as the root view
            AuthenticationContainer()
                // Inject the managers into the environment
                .environmentObject(characterDataManager)
                .environmentObject(userManager)
        }
    }
}
