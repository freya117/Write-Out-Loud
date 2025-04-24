// File: Views/WritingPaneView.swift
// VERSION: Added Tap-to-Reset, Interaction Control, Larger Fonts

import SwiftUI
import PencilKit

struct WritingPaneView: View {
    // MARK: - Bindings and State
    @Binding var pkCanvasView: PKCanvasView
    let character: Character?
    @ObservedObject var strokeInputController: StrokeInputController

    let currentStrokeIndex: Int
    let isPracticeComplete: Bool
    let analysisHistory: [StrokeTimingData]
    let finalDrawingWithFeedback: PKDrawing?

    // ***** NEW: Receive interaction state and reset action *****
    let isInteractionEnabled: Bool
    let onTapToWriteAgain: () -> Void
    // **********************************************************

    @EnvironmentObject var characterDataManager: CharacterDataManager

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // --- Stroke Info Bar (Increased Font Size happens in StrokeNamePill) ---
            StrokeInfoBar(
                character: character,
                currentStrokeIndex: currentStrokeIndex,
                isPracticeComplete: isPracticeComplete,
                analysisHistory: analysisHistory
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color(UIColor.systemGray6).opacity(0.7))

            Divider()

            // --- Main Writing Area ---
            GeometryReader { geometry in
                ZStack {
                    // --- Background Trace Image Guide (Unchanged) ---
                    traceImageGuide(geometry: geometry)

                    // --- Conditional Canvas Display ---
                    if isPracticeComplete, let finalDrawing = finalDrawingWithFeedback {
                        // --- Static Feedback Canvas (After Completion) ---
                        StaticCanvasView(drawing: finalDrawing)
                            .allowsHitTesting(false) // Always non-interactive
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // --- Interactive Drawing Canvas (During Practice) ---
                        CanvasView(pkCanvasView: $pkCanvasView)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            // ***** MODIFIED: Apply hit testing based on state *****
                            .allowsHitTesting(isInteractionEnabled)
                            // Dim the canvas visually when disabled
                            .opacity(isInteractionEnabled ? 1.0 : 0.7)
                            .overlay( // Show overlay message when disabled after completion attempt
                                 !isInteractionEnabled && !isPracticeComplete && strokeInputController.currentStrokeIndex >= (character?.strokeCount ?? 0) ?
                                 Color.black.opacity(0.1).allowsHitTesting(false) : Color.clear.allowsHitTesting(false) // Subtle overlay during processing
                            )
                            // ****************************************************
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .padding()
                // ***** MODIFIED: Add Tap Gesture for Reset *****
                .contentShape(Rectangle()) // Make the whole area tappable
                .onTapGesture {
                    if isPracticeComplete {
                        print("WritingPaneView tapped while complete - calling onTapToWriteAgain.")
                        onTapToWriteAgain() // Call the reset function passed from MainView
                    } else {
                        print("WritingPaneView tapped while practicing - no action.")
                    }
                }
                // **********************************************

            } // End GeometryReader
        } // End Main VStack
    } // End Body

    // MARK: - Subview Builders (traceImageGuide unchanged)
    @ViewBuilder
    private func traceImageGuide(geometry: GeometryProxy) -> some View { /* ... no changes ... */
        if let character = character {
            if let traceImage = characterDataManager.getCharacterImage(character, type: .trace) {
                Image(uiImage: traceImage)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.9)
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.7)
                    .allowsHitTesting(false)
            } else {
                Image(systemName: "photo.fill")
                    .resizable().scaledToFit().opacity(0.05).foregroundColor(.secondary)
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.7)
                    .allowsHitTesting(false)
            }
        } else {
            Text("Select a character").font(.title2).foregroundColor(.secondary)
        }
    }

    // MARK: - Feedback Drawing Logic (REMOVED - Handled in MainView)
}

// MARK: - StrokeInfoBar (Unchanged structure)
struct StrokeInfoBar: View { /* ... no changes ... */
    let character: Character?
    let currentStrokeIndex: Int
    let isPracticeComplete: Bool
    let analysisHistory: [StrokeTimingData]

    var body: some View {
        Group {
            if isPracticeComplete {
                vocalizationFeedbackView()
            } else {
                strokeNamesView()
            }
        }
        .frame(height: 50)
    }

    @ViewBuilder
    private func strokeNamesView() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let strokes = character?.strokes, !strokes.isEmpty {
                        ForEach(strokes.indices, id: \.self) { index in
                            StrokeNamePill( /* Pass props */
                                number: index + 1,
                                pinyin: strokes[index].type.basePinyinName,
                                chineseName: strokes[index].name,
                                isCurrent: index == currentStrokeIndex,
                                isComplete: false
                            ).id(index)
                        }
                    } else { Text("...").font(.caption).foregroundColor(.secondary) }
                }
                .padding(.horizontal, 5)
            }
            .onChange(of: currentStrokeIndex) { _, newIndex in withAnimation { proxy.scrollTo(newIndex, anchor: .center) } }
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { proxy.scrollTo(currentStrokeIndex, anchor: .center) } } }
        }
    }

    @ViewBuilder
    private func vocalizationFeedbackView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let strokes = character?.strokes, !strokes.isEmpty {
                    ForEach(strokes.indices, id: \.self) { index in
                        let analysisData = analysisHistory.first { $0.strokeIndex == index }
                        StrokeNamePill( /* Pass props */
                            number: index + 1,
                            pinyin: strokes[index].type.basePinyinName,
                            chineseName: strokes[index].name,
                            isCurrent: false,
                            isComplete: true,
                            wasCorrect: analysisData?.transcriptionMatched
                        )
                    }
                } else { Text("No analysis data.").font(.caption).foregroundColor(.secondary) }
            }
             .padding(.horizontal, 5)
        }
    }
}

// MARK: - StrokeNamePill (MODIFIED Font Size)
struct StrokeNamePill: View {
    let number: Int
    let pinyin: String
    let chineseName: String
    let isCurrent: Bool
    let isComplete: Bool
    var wasCorrect: Bool? = nil

    var body: some View {
        HStack(spacing: 5) {
            if isComplete {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.callout.weight(.semibold)) // Slightly larger/bolder icon
                    .frame(width: 18) // Ensure space for icon
            }

            // Number
            Text("\(number).")
                .font(.headline) // << LARGER FONT
                .fontWeight(.medium)
                .foregroundColor(isCurrent && !isComplete ? .blue : .primary)

            // Pinyin
            Text(pinyin)
                .font(.headline) // << LARGER FONT
                .foregroundColor(textColor)

            // Chinese Name
            Text(chineseName)
                .font(.headline) // << LARGER FONT
                .foregroundColor(textColor)
                .fixedSize()
        }
        .padding(.horizontal, 12) // Adjust padding if needed
        .padding(.vertical, 6)
        .background(backgroundMaterial)
        .cornerRadius(15)
        .overlay( Capsule().stroke(isCurrent && !isComplete ? Color.blue : Color.clear, lineWidth: 1.5) )
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isComplete)
    }

    // textColor, backgroundMaterial, iconName, iconColor computed properties remain the same
    private var textColor: Color {
        if isComplete {
            switch wasCorrect {
            case true: return .primary
            case false: return .red
            case nil: return .orange
            default: return .gray
            }
        } else { return .primary }
    }
    private var backgroundMaterial: Material {
        if isComplete { return .thinMaterial }
        else { return isCurrent ? .regularMaterial : .ultraThinMaterial }
    }
    private var iconName: String {
        guard isComplete else { return "" }
        switch wasCorrect {
        case true: return "checkmark.circle.fill"; case false: return "xmark.circle.fill";
        case nil: return "questionmark.circle.fill"; default: return "exclamationmark.triangle.fill"
        }
    }
    private var iconColor: Color {
         guard isComplete else { return .clear }
         switch wasCorrect {
         case true: return .green; case false: return .red;
         case nil: return .orange; default: return .gray
         }
     }
}

// MARK: - StaticCanvasView Helper (Unchanged)
struct StaticCanvasView: UIViewRepresentable { /* ... no changes ... */
    let drawing: PKDrawing
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView(); canvas.drawing = drawing; canvas.backgroundColor = .clear
        canvas.isOpaque = false; canvas.isUserInteractionEnabled = false; return canvas
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing { uiView.drawing = drawing }
    }
}
