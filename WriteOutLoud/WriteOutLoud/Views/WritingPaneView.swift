// File: Views/WritingPaneView.swift
// VERSION: Added Persistent Real-time Transcript below Info Bar

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

    // ***** ADDED BACK: Properties for Real-time Transcript *****
    let showRealtimeTranscript: Bool
    let realtimeTranscript: String
    // *********************************************************

    @EnvironmentObject var characterDataManager: CharacterDataManager

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // --- Stroke Info Bar (Top) ---
            StrokeInfoBar(
                character: character,
                currentStrokeIndex: currentStrokeIndex,
                isPracticeComplete: isPracticeComplete,
                analysisHistory: analysisHistory,
                showRealtimeTranscript: showRealtimeTranscript,
                realtimeTranscript: realtimeTranscript
            )
            .padding(.horizontal)
            .padding(.top, 8)

            // Separator between info/transcript and canvas
            Divider()

            // --- Main Writing Area ---
            GeometryReader { geometry in
                ZStack { // Keep ZStack for trace image + canvas
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
                            .overlay( // Overlay during processing
                                 !isInteractionEnabled && !isPracticeComplete && strokeInputController.currentStrokeIndex >= (character?.strokeCount ?? 0) ?
                                 Color.black.opacity(0.1).allowsHitTesting(false) : Color.clear.allowsHitTesting(false)
                            )
                    }
                } // End ZStack
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .padding() // Padding around the canvas area
                // Add Tap Gesture for Reset
                .contentShape(Rectangle())
                .onTapGesture {
                    if isPracticeComplete { onTapToWriteAgain() }
                }
            } // End GeometryReader
        } // End Main VStack
        .background(Color(UIColor.systemGray6).opacity(0.7)) // Background for the whole pane
    } // End Body

    // MARK: - Subview Builders

    // Trace Image (Smaller Size)
    @ViewBuilder
    private func traceImageGuide(geometry: GeometryProxy) -> some View {
        if let character = character {
            // Access character data manager through environment
            Group {
                if let traceImage = characterDataManager.getCharacterImage(character, type: .trace) {
                    Image(uiImage: traceImage)
                        .resizable()
                        .scaledToFit()
                        // Make the trace image smaller - only 70% of the available space
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.7)
                        .opacity(0.3)  // Keep trace image subtle
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2) // Center it
                } else {
                    // Placeholder if trace image not found
                    Image(systemName: "character.book.closed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80) // Smaller placeholder too
                        .opacity(0.3)
                        .foregroundColor(.gray)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2) // Center it
                }
            }
        } else {
            // Empty view if no character
            EmptyView()
        }
    }
}

// MARK: - StrokeInfoBar
struct StrokeInfoBar: View {
    let character: Character?; 
    let currentStrokeIndex: Int; 
    let isPracticeComplete: Bool; 
    let analysisHistory: [StrokeTimingData];
    let showRealtimeTranscript: Bool;
    let realtimeTranscript: String;
    
    // Fixed height for consistency
    private let transcriptAreaHeight: CGFloat = 80
    
    var body: some View { 
        VStack(alignment: .leading, spacing: 5) {
            Text("Vocalize your stroke while writing:").font(.subheadline).fontWeight(.bold).foregroundColor(.primary).padding(.bottom, 4)
            
            // Transcript container - always present to maintain stable layout
            VStack(spacing: 0) {
                if showRealtimeTranscript {
                    // Current transcription (listening mode)
                    if !isPracticeComplete && currentStrokeIndex < (character?.strokeCount ?? 0) {
                        realtimeTranscriptArea()
                    }
                    
                    // Historical transcription summary (always shown when available)
                    if !analysisHistory.isEmpty {
                        transcriptionHistoryView()
                    }
                    
                    // Show placeholder if no content
                    if (isPracticeComplete || currentStrokeIndex >= (character?.strokeCount ?? 0)) && analysisHistory.isEmpty {
                        emptyTranscriptPlaceholder()
                    }
                } else {
                    // Show empty space when transcript is toggled off
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: transcriptAreaHeight) // Fixed height container
            .padding(.vertical, 5)
            .padding(.horizontal, 5)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
            .padding(.bottom, 5)
            
            Group { 
                if isPracticeComplete { 
                    vocalizationFeedbackView() 
                } else { 
                    strokeNamesView() 
                } 
            }.frame(height: 45) // Keep height for single-line pills
        }
    }
    
    // Empty placeholder to maintain consistent height
    @ViewBuilder
    private func emptyTranscriptPlaceholder() -> some View {
        Text("No transcription available")
            .font(.callout)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // Current transcript view (for active listening)
    @ViewBuilder
    private func realtimeTranscriptArea() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                Text("Listening for stroke \(currentStrokeIndex + 1): ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(realtimeTranscript.isEmpty ? "Listening..." : realtimeTranscript)
                    .font(.callout)
                    .foregroundColor(realtimeTranscript.isEmpty ? .secondary : .primary)
                    .id(realtimeTranscript) // Ensure redraw on change
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }
    
    // Historical transcript view (numbered list of what was said)
    @ViewBuilder
    private func transcriptionHistoryView() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your spoken strokes:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Use a more unique identifier by creating a compound ID with index and hash of transcript
                // This resolves the "ID occurs multiple times" error
                let uniqueEntries = createUniqueHistoryEntries(from: analysisHistory)
                
                ForEach(uniqueEntries, id: \.id) { entry in
                    HStack(alignment: .top, spacing: 4) {
                        // Stroke number
                        Text("\(entry.strokeIndex + 1).")
                            .font(.callout)
                            .fontWeight(.medium)
                        
                        // Expected vs actual
                        VStack(alignment: .leading) {
                            if let expectedName = character?.strokes[safe: entry.strokeIndex]?.name {
                                Text("Expected: \(expectedName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(entry.transcript)
                                .font(.callout)
                                .foregroundColor(entry.color)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }
    
    // Helper struct to ensure unique entries in the history view
    private struct TranscriptHistoryEntry: Identifiable {
        let id: String
        let strokeIndex: Int
        let transcript: String
        let color: Color
    }

    // Helper method to create unique entries from analysis history
    private func createUniqueHistoryEntries(from history: [StrokeTimingData]) -> [TranscriptHistoryEntry] {
        // Group by stroke index and take the latest entry for each stroke
        let groupedByIndex = Dictionary(grouping: history, by: { $0.strokeIndex })
        
        return groupedByIndex.map { index, entries in
            // Use the most recent entry for each stroke index
            guard let latestEntry = entries.max(by: { $0.strokeEndTime < $1.strokeEndTime }) else {
                // Fallback if no entries (shouldn't happen)
                return TranscriptHistoryEntry(
                    id: "stroke-\(index)-empty",
                    strokeIndex: index,
                    transcript: "No data",
                    color: .gray
                )
            }
            
            // Color based ONLY on speech recognition result (transcriptionMatched)
            // This ensures transcript colors match the pronunciation feedback, not stroke accuracy
            let color: Color
            if latestEntry.transcriptionMatched == true {
                color = Color.green // Use explicit Color.green to ensure consistency
            } else if latestEntry.transcriptionMatched == false {
                color = Color.red // Use explicit Color.red to ensure consistency
            } else {
                color = Color.gray // Use gray for transcripts with nil match status
            }
            
            // Make transcript display more user-friendly
            let displayTranscript: String
            if let transcript = latestEntry.finalTranscription, !transcript.isEmpty {
                displayTranscript = transcript
            } else {
                displayTranscript = "No speech detected"
            }
            
            // Create a unique entry with appropriate color
            return TranscriptHistoryEntry(
                id: "stroke-\(index)-\(latestEntry.strokeEndTime.timeIntervalSince1970)",
                strokeIndex: index,
                transcript: displayTranscript,
                color: color
            )
        }.sorted(by: { $0.strokeIndex < $1.strokeIndex })
    }
    
    // Helper to get color based on transcription match
    private func getTranscriptionColor(_ matched: Bool?) -> Color {
        // Be more explicit about color choices to ensure they show correctly
        if matched == true {
            return Color.green
        } else if matched == false {
            return Color.red
        } else {
            return Color.gray // Changed from orange to gray for consistency
        }
    }
    
    @ViewBuilder private func strokeNamesView() -> some View { /* ... */ ScrollViewReader { proxy in ScrollView(.horizontal, showsIndicators: false) { LazyHStack(spacing: 12) { if let strokes = character?.strokes, !strokes.isEmpty { ForEach(strokes.indices, id: \.self) { index in StrokeNamePill(number: index + 1, pinyin: strokes[index].type.basePinyinName, chineseName: strokes[index].name, isCurrent: index == currentStrokeIndex, isComplete: false).id(index) } } else { Text("...") } }.padding(.horizontal, 5) }.onChange(of: currentStrokeIndex) { _, newIndex in withAnimation { proxy.scrollTo(newIndex, anchor: .center) } }.onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { proxy.scrollTo(currentStrokeIndex, anchor: .center) } } } } }
    @ViewBuilder private func vocalizationFeedbackView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                if let strokes = character?.strokes, !strokes.isEmpty {
                    ForEach(strokes.indices, id: \.self) { index in
                        // Find the most recent analysis data for this stroke
                        let analysisData = analysisHistory
                            .filter { $0.strokeIndex == index }
                            .max(by: { $0.strokeEndTime < $1.strokeEndTime })
                        
                        // Debug the match status and accuracy
                        if let data = analysisData {
                            let _ = print("Stroke \(index+1) match status: \(String(describing: data.transcriptionMatched)), accuracy: \(String(format: "%.1f", data.strokeAccuracy))")
                        }
                        
                        // Default to true if we have a transcript but no match status
                        let speechWasCorrect: Bool? = if let data = analysisData {
                            // If we have a definitive false, use it
                            if data.transcriptionMatched == false {
                                false
                            } else if data.finalTranscription?.isEmpty == false {
                                // If we have a transcript but no definitive match status, assume it was correct
                                true
                            } else {
                                // Otherwise use the original value (nil or true)
                                data.transcriptionMatched
                            }
                        } else {
                            nil
                        }
                        
                        // Determine if the stroke was drawn accurately based on strokeAccuracy
                        let strokeIsAccurate: Bool? = if let data = analysisData {
                            // 60.0 is the same threshold used in MainView for coloring
                            data.strokeAccuracy >= 60.0
                        } else {
                            nil
                        }
                        
                        // Pass both speech correctness and stroke accuracy to the pill
                        StrokeNamePill(
                            number: index + 1,
                            pinyin: strokes[index].type.basePinyinName,
                            chineseName: strokes[index].name,
                            isCurrent: false,
                            isComplete: true,
                            speechWasCorrect: speechWasCorrect,
                            strokeIsAccurate: strokeIsAccurate
                        )
                    }
                } else {
                    Text("No analysis data.")
                }
            }.padding(.horizontal, 5)
        }
    }
}

// MARK: - StrokeNamePill
struct StrokeNamePill: View {
    let number: Int
    let pinyin: String
    let chineseName: String
    let isCurrent: Bool
    let isComplete: Bool
    var speechWasCorrect: Bool? = nil
    var strokeIsAccurate: Bool? = nil
    private let textFontSize: Font = .headline
    
    var body: some View {
        HStack(spacing: 8) {
            // Speaker icon to pronounce the stroke name
            Image(systemName: "speaker.wave.2.fill")
                .font(textFontSize.weight(.regular))
                .foregroundColor(.secondary)
                .onTapGesture {
                    // Add a small delay to ensure audio session is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        SpeechSynthesizer.speak(text: chineseName, language: "zh-CN")
                    }
                }
            
            // Status icon for completed strokes - now shows SPEECH status
            if isComplete {
                Image(systemName: speechIconName)
                    .foregroundColor(speechIconColor)
                    .font(textFontSize.weight(.semibold))
            }
            
            // Stroke number
            Text("\(number).")
                .font(textFontSize)
                .fontWeight(.medium)
                .foregroundColor(isCurrent && !isComplete ? .blue : .primary)
            
            // Chinese name with color based on speech correctness
            Text(chineseName)
                .font(textFontSize)
                .foregroundColor(isComplete ? speechTextColor : .primary)
            
            // Pinyin pronunciation with color based on speech correctness
            Text(pinyin)
                .font(textFontSize)
                .foregroundColor(isComplete ? speechTextColor : .primary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundMaterial)
        .cornerRadius(15)
        .overlay(
            Capsule().stroke(isCurrent && !isComplete ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isComplete)
    }
    
    // Speech text color (used for Chinese name and pinyin when complete)
    private var speechTextColor: Color {
        switch speechWasCorrect {
        case true: return Color.green
        case false: return Color.red
        case nil: return Color.gray
        default: return Color.gray
        }
    }
    
    private var backgroundMaterial: Material {
        if isComplete {
            return .thinMaterial
        } else {
            return isCurrent ? .regularMaterial : .ultraThinMaterial
        }
    }
    
    // Speech icon name (checkmark/x/question for speech correctness)
    private var speechIconName: String {
        guard isComplete else { return "" }
        switch speechWasCorrect {
        case true: return "checkmark.circle.fill"
        case false: return "xmark.circle.fill"
        case nil: return "questionmark.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    // Speech icon color
    private var speechIconColor: Color {
        guard isComplete else { return .clear }
        switch speechWasCorrect {
        case true: return Color.green
        case false: return Color.red
        case nil: return Color.gray
        default: return Color.gray
        }
    }
}

// MARK: - StaticCanvasView Helper (Unchanged)
struct StaticCanvasView: UIViewRepresentable { /* ... as before ... */
    let drawing: PKDrawing; func makeUIView(context: Context) -> PKCanvasView { let canvas = PKCanvasView(); canvas.drawing = drawing; canvas.backgroundColor = .clear; canvas.isOpaque = false; canvas.isUserInteractionEnabled = false; return canvas }; func updateUIView(_ uiView: PKCanvasView, context: Context) { if uiView.drawing != drawing { uiView.drawing = drawing } }
}
