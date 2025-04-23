// File: Views/ReferenceView.swift
import SwiftUI

/**
 Displays the reference information for the current character, including its
 visual representation, pinyin, meaning, and an animated stroke-order guide.
 */
struct ReferenceView: View {
    // MARK: - Properties
    let character: Character?
    @Binding var currentStrokeIndex: Int // Provided by the coordinator/parent

    @State private var isAnimating: Bool = false
    @State private var animationStep: Int = 0
    @State private var animationTimer: Timer?

    private let animationInterval: TimeInterval = 0.8
    private let delayBetweenStrokes: TimeInterval = 0.2

    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            if let character = character {
                characterInfoHeader(character: character)
                strokeAnimationArea(character: character)
                    .frame(minHeight: 300, maxHeight: 400)
                Spacer()
            } else {
                Spacer()
                Text("Select a character").font(.title).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .onDisappear(perform: stopAnimation)
        // *** MODIFIED: Updated onChange syntax for character ID ***
        .onChange(of: character?.id) { oldId, newId in
             // Only reset if the ID actually changed
             if oldId != newId {
                 resetAnimationState()
             }
        }
        // *** MODIFIED: Updated onChange syntax for currentStrokeIndex ***
        .onChange(of: currentStrokeIndex) { oldIndex, newIndex in
            // If external index changes (e.g., user moves next), reset animation step
            if !isAnimating {
                animationStep = newIndex
            }
        }
    }

    // MARK: - Subviews (remain the same)
    @ViewBuilder
    private func characterInfoHeader(character: Character) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(character.character).font(.system(size: 80))
            Text("\(character.pinyin) - \(character.meaning)").font(.title3).foregroundColor(.secondary)
        }
        .padding(.bottom)
    }

    @ViewBuilder
    private func strokeAnimationArea(character: Character) -> some View {
        VStack(spacing: 10) {
            ZStack {
                // Background guide
                ForEach(character.strokes) { stroke in
                    StrokeView(stroke: stroke, animationProgress: 1.0)
                        .foregroundColor(.gray.opacity(0.15))
                }
                // Completed strokes
                ForEach(0..<animationStep, id: \.self) { index in
                    if let stroke = character.strokes[safe: index] {
                        StrokeView(stroke: stroke, animationProgress: 1.0)
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                // Animating stroke
                if let currentAnimatingStroke = character.strokes[safe: animationStep], isAnimating {
                    StrokeView(stroke: currentAnimatingStroke, animationProgress: 1.0, isAnimating: true, duration: animationInterval)
                        .foregroundColor(.blue)
                }
                // Static highlight stroke
                else if let currentPracticeStroke = character.strokes[safe: currentStrokeIndex] {
                    StrokeView(stroke: currentPracticeStroke, animationProgress: 1.0)
                        .foregroundColor(.blue.opacity(0.8))
                }
            }
            .padding(20)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            strokeInfoAndControls(character: character)
        }
    }

    @ViewBuilder
    private func strokeInfoAndControls(character: Character) -> some View {
        let displayIndex = currentStrokeIndex
        HStack {
            if let stroke = character.strokes[safe: displayIndex] {
                 VStack(alignment: .leading) {
                     Text("Stroke \(displayIndex + 1): \(stroke.name)").font(.headline)
                     Text("Say \"\(stroke.name)\"").font(.subheadline).foregroundColor(.secondary)
                 }
                 Spacer()
            } else if displayIndex >= character.strokeCount && character.strokeCount > 0 {
                 Text("Character Complete").font(.headline).foregroundColor(.green)
                 Spacer()
            } else {
                 Text(" ").font(.headline)
                 Spacer()
            }

            Button {
                toggleAnimation()
            } label: {
                Label(isAnimating ? "Stop" : "Animate", systemImage: isAnimating ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.bordered)
            .disabled(character.strokes.isEmpty)
        }
        .padding(.horizontal)
    }

    // MARK: - Animation Logic (remain the same)
    private func toggleAnimation() { /* ... */ }
    private func startAnimation() { /* ... */ }
    private func animateStep() { /* ... */ }
    private func stopAnimation() { /* ... */ }
    private func resetAnimationState() { /* ... */ }
}
