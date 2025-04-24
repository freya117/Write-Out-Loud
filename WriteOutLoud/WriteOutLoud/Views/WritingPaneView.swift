// File: Views/WritingPaneView.swift
import SwiftUI
import PencilKit

/**
 Displays the area where the user draws the character strokes.
 Includes a background trace image guide and the interactive PKCanvasView.
 */
struct WritingPaneView: View {
    /// Binding to the PKCanvasView instance managed by the parent.
    @Binding var pkCanvasView: PKCanvasView
    /// The character currently being practiced (used for the guide image).
    let character: Character?
    /// ObservedObject to access the current stroke index (maybe needed later, keep it).
    @ObservedObject var strokeInputController: StrokeInputController

    // Access DataManager to load images
    @EnvironmentObject var characterDataManager: CharacterDataManager

    var body: some View {
        // Use GeometryReader to get the container size for scaling the trace image
        GeometryReader { geometry in
            ZStack {
                // --- Background Trace Image Guide ---
                if let character = character {
                    if let traceImage = characterDataManager.getCharacterImage(character, type: .trace) {
                        Image(uiImage: traceImage)
                            .resizable()
                            .scaledToFit()
                            .opacity(0.08) // Keep it faint
                            // *** ADDED FRAME TO MAKE TRACE IMAGE SMALLER ***
                            // Make the trace image occupy a smaller portion (e.g., 70%) of the container
                            .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.7)
                            .allowsHitTesting(false)
                            // The ZStack will center it by default
                    } else {
                         Image(systemName: "photo.fill")
                             .resizable()
                             .scaledToFit()
                             .opacity(0.05) // Keep placeholder faint
                             .foregroundColor(.secondary)
                             // Apply frame to placeholder too
                             .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.7)
                             .allowsHitTesting(false)
                    }
                } else {
                     Text("Select a character to start writing")
                         .font(.title2)
                         .foregroundColor(.secondary)
                }

                // --- Drawing Canvas (Should be on top) ---
                CanvasView(pkCanvasView: $pkCanvasView)
                    // Make sure canvas is not restricted by the trace image frame
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // *** SET BACKGROUND TO WHITE ***
            .background(Color.white) // Set background to white
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Use a slightly darker border for contrast against white
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
            .padding()
        } // End GeometryReader
    }
}
