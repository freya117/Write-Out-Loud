// GuideView.swift
import SwiftUI

/**
 Displays the complete character strokes as a faint background guide, using StrokeView.
 */
struct GuideView: View {
    let character: Character

    var body: some View {
        ZStack {
            // Draw all strokes statically using StrokeView
            ForEach(character.strokes) { stroke in
                StrokeView(stroke: stroke, animationProgress: 1.0, isAnimating: false)
            }
        }
        // Apply scaling/padding within the ZStack if needed, or rely on parent padding.
        // The scaling is handled within StrokeView itself via GeometryReader.
    }
}
