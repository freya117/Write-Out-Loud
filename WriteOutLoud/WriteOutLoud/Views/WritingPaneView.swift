// File: Views/WritingPaneView.swift
import SwiftUI
import PencilKit

/**
 Displays the area where the user draws the character strokes.
 Includes a background guide and the interactive PKCanvasView.
 */
struct WritingPaneView: View {
    /// Binding to the PKCanvasView instance managed by the parent.
    @Binding var pkCanvasView: PKCanvasView
    /// The character currently being practiced (used for the guide).
    let character: Character?
    /// ObservedObject to access the current stroke index from the input controller.
    @ObservedObject var strokeInputController: StrokeInputController // This is passed in but not directly used in body here

    var body: some View {
        ZStack {
            // --- Background Guide ---
            if let character = character {
                // *** Uses GuideView defined in Views/GuideView.swift ***
                GuideView(character: character) // Assumes GuideView exists
                    .foregroundColor(.gray.opacity(0.15)) // Adjust opacity as needed
                    .allowsHitTesting(false) // Ensure guide doesn't block drawing
            }

            // --- Drawing Canvas ---
            // *** Uses CanvasView defined in Views/CanvasView.swift ***
            // Your comment said PKCanvasRepresentable, but your previous file was CanvasView. Assuming CanvasView is correct.
            CanvasView(pkCanvasView: $pkCanvasView) // This correctly passes the binding down
        }
        .background(Color(UIColor.systemBackground)) // Use system background for canvas area
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Optional rounding
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1)) // Optional border
        .padding() // Add padding around the writing pane
    }
}
