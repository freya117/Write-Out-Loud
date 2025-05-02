// File: Views/WritingPaneView.swift
// VERSION: Added Real-time Transcript Display

import SwiftUI
import PencilKit
import AVFoundation

struct WritingPaneView: View {
    // MARK: - Bindings and State
    @Binding var pkCanvasView: PKCanvasView
    let character: Character?
    @ObservedObject var strokeInputController: StrokeInputController

    // Data passed down from MainView
    let currentStrokeIndex: Int
    let isPracticeComplete: Bool
    let analysisHistory: [StrokeTimingData]
    let finalDrawingWithFeedback: PKDrawing?

    // Interaction state and reset action
    let isInteractionEnabled: Bool
    let onTapToWriteAgain: () -> Void

    // ***** NEW: Properties for Real-time Transcript *****
    let showRealtimeTranscript: Bool
    let realtimeTranscript: String
    // ***************************************************

    @EnvironmentObject var characterDataManager: CharacterDataManager

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Stroke Info Bar (Unchanged)
            StrokeInfoBar(
                character: character,
                currentStrokeIndex: currentStrokeIndex,
                isPracticeComplete: isPracticeComplete,
                analysisHistory: analysisHistory
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6).opacity(0.7))

            Divider()

            // --- Main Writing Area ---
            GeometryReader { geometry in
                ZStack(alignment: .bottom) { // Align ZStack content to bottom for transcript
                    // Background Trace Image Guide
                    traceImageGuide(geometry: geometry)

                    // Conditional Canvas Display
                    if isPracticeComplete, let finalDrawing = finalDrawingWithFeedback {
                        StaticCanvasView(drawing: finalDrawing)
                            .allowsHitTesting(false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        CanvasView(pkCanvasView: $pkCanvasView)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(isInteractionEnabled)
                            .opacity(isInteractionEnabled ? 1.0 : 0.7)
                            .overlay( // Show overlay message when disabled during processing
                                 !isInteractionEnabled && !isPracticeComplete && strokeInputController.currentStrokeIndex >= (character?.strokeCount ?? 0) ?
                                 Color.black.opacity(0.1).allowsHitTesting(false) : Color.clear.allowsHitTesting(false)
                            )
                    }

                    // ***** NEW: Real-time Transcript Overlay *****
                    if showRealtimeTranscript && !realtimeTranscript.isEmpty && !isPracticeComplete {
                        Text(realtimeTranscript)
                            .font(.title2)
                            .padding(8)
                            .background(.thinMaterial, in: Capsule()) // Use material background
                            .foregroundColor(.primary)
                            .transition(.opacity.combined(with: .scale(scale: 0.8))) // Add transition
                            .padding(.bottom, 20) // Padding from bottom edge
                            .allowsHitTesting(false) // Don't block canvas taps
                    }
                    // ********************************************

                } // End ZStack
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .padding()
                // Add Tap Gesture for Reset
                .contentShape(Rectangle())
                .onTapGesture {
                    if isPracticeComplete {
                        print("WritingPaneView tapped while complete - calling onTapToWriteAgain.")
                        onTapToWriteAgain()
                    } else {
                        print("WritingPaneView tapped while practicing - no action.")
                    }
                }
                // Animate transcript appearance/disappearance
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showRealtimeTranscript && !realtimeTranscript.isEmpty)

            } // End GeometryReader
        } // End Main VStack
    } // End Body

    // MARK: - Subview Builders (traceImageGuide unchanged)
    @ViewBuilder
    private func traceImageGuide(geometry: GeometryProxy) -> some View { /* ... as before ... */
        if let character = character {
            if let traceImage = characterDataManager.getCharacterImage(character, type: .trace) {
                Image(uiImage: traceImage).resizable().scaledToFit().opacity(0.15).frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.7).allowsHitTesting(false)
            } else { Image(systemName: "photo.fill").resizable().scaledToFit().opacity(0.05).foregroundColor(.secondary).frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.7).allowsHitTesting(false) }
        } else { Text("Select a character").font(.title2).foregroundColor(.secondary) }
    }
}

// MARK: - StrokeInfoBar (Unchanged)
struct StrokeInfoBar: View { /* ... as before ... */
    let character: Character?; let currentStrokeIndex: Int; let isPracticeComplete: Bool; let analysisHistory: [StrokeTimingData]
    var body: some View { VStack(alignment: .leading, spacing: 5) {
        Text("Vocalize your stroke while writing:").font(.subheadline).fontWeight(.bold).foregroundColor(.black).padding(.bottom, 4)
        Group { if isPracticeComplete { vocalizationFeedbackView() } else { strokeNamesView() } }.frame(height: 45)
    }}
    @ViewBuilder private func strokeNamesView() -> some View { /* ... */ ScrollViewReader { proxy in ScrollView(.horizontal, showsIndicators: false) { LazyHStack(spacing: 12) { if let strokes = character?.strokes, !strokes.isEmpty { ForEach(strokes.indices, id: \.self) { index in StrokeNamePill(number: index + 1, pinyin: strokes[index].type.basePinyinName, chineseName: strokes[index].name, isCurrent: index == currentStrokeIndex, isComplete: false).id(index) } } else { Text("...") } }.padding(.horizontal, 5) }.onChange(of: currentStrokeIndex) { _, newIndex in withAnimation { proxy.scrollTo(newIndex, anchor: .center) } }.onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { proxy.scrollTo(currentStrokeIndex, anchor: .center) } } } } }
    @ViewBuilder private func vocalizationFeedbackView() -> some View { /* ... */ ScrollView(.horizontal, showsIndicators: false) { LazyHStack(spacing: 12) { if let strokes = character?.strokes, !strokes.isEmpty { ForEach(strokes.indices, id: \.self) { index in let analysisData = analysisHistory.first { $0.strokeIndex == index }; StrokeNamePill(number: index + 1, pinyin: strokes[index].type.basePinyinName, chineseName: strokes[index].name, isCurrent: false, isComplete: true, wasCorrect: analysisData?.transcriptionMatched) } } else { Text("No analysis data.") } }.padding(.horizontal, 5) } }
}

// MARK: - StrokeNamePill (Unchanged)
struct StrokeNamePill: View { /* ... as before ... */
    let number: Int; let pinyin: String; let chineseName: String; let isCurrent: Bool; let isComplete: Bool; var wasCorrect: Bool? = nil
    private let textFontSize: Font = .headline
    var body: some View { HStack(spacing: 8) { Image(systemName: "speaker.wave.2.fill").font(textFontSize.weight(.regular)).foregroundColor(.secondary).onTapGesture { SpeechSynthesizer.speak(text: chineseName, language: "zh-CN") }; if isComplete { Image(systemName: iconName).foregroundColor(iconColor).font(textFontSize.weight(.semibold)) }; Text("\(number).").font(textFontSize).fontWeight(.medium).foregroundColor(isCurrent && !isComplete ? .blue : textColor); Text(chineseName).font(textFontSize).foregroundColor(textColor); Text(pinyin).font(textFontSize).foregroundColor(textColor).lineLimit(1); Spacer(); if isComplete { Button { print("Replay tapped") } label: { Image(systemName: "play.circle").font(textFontSize).foregroundColor(wasCorrect != nil ? .accentColor : .gray.opacity(0.5)) }.buttonStyle(.plain).disabled(wasCorrect == nil) } }.padding(.horizontal, 10).padding(.vertical, 6).background(backgroundMaterial).cornerRadius(15).overlay( Capsule().stroke(isCurrent && !isComplete ? Color.blue : Color.clear, lineWidth: 1.5) ).animation(.easeInOut(duration: 0.2), value: isCurrent).animation(.easeInOut(duration: 0.2), value: isComplete) }
    private var textColor: Color { if isComplete { switch wasCorrect { case true: return .green; case false: return .red; case nil: return .orange; default: return .gray } } else { return .primary } }
    private var backgroundMaterial: Material { if isComplete { return .thinMaterial } else { return isCurrent ? .regularMaterial : .ultraThinMaterial } }
    private var iconName: String { guard isComplete else { return "" }; switch wasCorrect { case true: return "checkmark.circle.fill"; case false: return "xmark.circle.fill"; case nil: return "questionmark.circle.fill"; default: return "exclamationmark.triangle.fill" } }
    private var iconColor: Color { guard isComplete else { return .clear }; switch wasCorrect { case true: return .green; case false: return .red; case nil: return .orange; default: return .gray } }
}

// MARK: - StaticCanvasView Helper (Unchanged)
struct StaticCanvasView: UIViewRepresentable { /* ... as before ... */
    let drawing: PKDrawing; func makeUIView(context: Context) -> PKCanvasView { let canvas = PKCanvasView(); canvas.drawing = drawing; canvas.backgroundColor = .clear; canvas.isOpaque = false; canvas.isUserInteractionEnabled = false; return canvas }; func updateUIView(_ uiView: PKCanvasView, context: Context) { if uiView.drawing != drawing { uiView.drawing = drawing } }
}
