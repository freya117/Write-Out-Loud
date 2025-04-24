// File: Controllers/StrokeInputController.swift
// VERSION: Enhanced stroke tracking and error handling

import Foundation
import PencilKit
import SwiftUI
import Combine
import CoreGraphics

// Delegate protocol definition
protocol StrokeInputDelegate {
    func strokeBegan(at time: Date, strokeType: StrokeType)
    func strokeUpdated(points: [CGPoint])
    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int)
    func allStrokesCompleted()
}

class StrokeInputController: NSObject, ObservableObject, PKCanvasViewDelegate {

    // Published properties
    @Published var isDrawing: Bool = false
    @Published var currentStrokeUserPath: [CGPoint] = []
    // Publicly readable index of the stroke the user is *expected* to draw next (0-based)
    @Published private(set) var currentStrokeIndex: Int = 0

    // Internal State
    private var character: Character? // Store the character being worked on
    private var canvasView: PKCanvasView?
    private(set) var strokeStartTime: Date?
    private var currentStrokePointsAccumulator: [CGPoint] = []
    private var currentStrokeID: UUID = UUID()

    // Tracking state
    private var strokesCompleted: Int = 0
    private var maxStrokes: Int = 0

    // Delegate
    var delegate: StrokeInputDelegate?

    // Setup and Control methods
    func setup(with canvasView: PKCanvasView, for character: Character) {
        self.canvasView = canvasView
        self.character = character // Store the character
        self.currentStrokeIndex = 0 // Reset index
        self.isDrawing = false
        self.currentStrokeUserPath = []
        self.currentStrokePointsAccumulator = []
        self.strokeStartTime = nil
        self.currentStrokeID = UUID()
        self.strokesCompleted = 0
        self.maxStrokes = character.strokeCount

        canvasView.delegate = self
        canvasView.drawing = PKDrawing() // Ensure canvas is cleared on setup
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 10)
        canvasView.drawingPolicy = .anyInput
        canvasView.isUserInteractionEnabled = true
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        print("StrokeInputController setup for character: \(character.character) (Strokes: \(character.strokeCount)). Initial index: \(self.currentStrokeIndex)")
        // Prepare for the first stroke immediately after setup
        prepareForStroke(index: 0)
    }

    deinit { }

    // Clears the canvas
    func resetCanvas() {
        DispatchQueue.main.async {
            self.canvasView?.drawing = PKDrawing()
            self.isDrawing = false
            self.currentStrokeUserPath = []
            self.currentStrokePointsAccumulator = []
            self.strokeStartTime = nil
            self.currentStrokeID = UUID()
            print("Canvas reset.")
        }
    }

    // Prepare internal state for a specific stroke index
    // This method ONLY sets the currentStrokeIndex.
    func prepareForStroke(index: Int) { // Made public for MainView to call
        guard let currentCharacter = self.character else {
            print("Cannot prepare for stroke index \(index), character is nil.")
            return
        }
        guard index < currentCharacter.strokeCount else {
            print("Cannot prepare for stroke index \(index), index out of bounds (Count: \(currentCharacter.strokeCount)).")
            return
        }
        guard let stroke = currentCharacter.strokes[safe: index] else {
            print("Cannot prepare for stroke index \(index), stroke data missing.")
            return
        }
        // Explicitly set the internal index on the main thread
        DispatchQueue.main.async {
            print("     prepareForStroke: About to set currentStrokeIndex from \(self.currentStrokeIndex) to \(index)")
            self.currentStrokeIndex = index
            print("Prepared for stroke index \(index) (Stroke \(index + 1) of \(currentCharacter.strokeCount)): Type=\(stroke.type.rawValue), Name=\(stroke.name)")
        }
    }

    // Enhanced completion check with better error handling and logging
    func checkCompletionAndAdvance(indexJustCompleted: Int) -> Bool {
        guard let currentCharacter = self.character else {
            print("!!! checkCompletionAndAdvance ERROR: self.character is NIL.")
            return false // Cannot advance
        }
        let strokeCount = currentCharacter.strokeCount
        let lastStrokeIndex = strokeCount > 0 ? strokeCount - 1 : -1

        print("-----------------------------------------")
        print(">>> checkCompletionAndAdvance called <<<")
        print("    Character: '\(currentCharacter.character)', StrokeCount: \(strokeCount)")
        print("    Index Just Completed (Passed In): \(indexJustCompleted)") // Use passed-in index
        print("    Last Stroke Index: \(lastStrokeIndex)")
        print("    Current Internal Index BEFORE check: \(self.currentStrokeIndex)")
        print("    Strokes completed so far: \(self.strokesCompleted + 1) of \(self.maxStrokes)")
        print("-----------------------------------------")

        // Update completion counter
        self.strokesCompleted += 1
        
        // Check if the stroke just completed was the *actual* last stroke
        if strokeCount > 0 && indexJustCompleted == lastStrokeIndex {
            print("    Completion Check: \(indexJustCompleted) == \(lastStrokeIndex) -> TRUE")
            print("    >>> Calling allStrokesCompleted delegate <<<")
            self.strokesCompleted = 0 // Reset counter for next character
            delegate?.allStrokesCompleted() // Signal completion
            return false // Indicate completion
        }
        // Check if there are more strokes remaining
        else if indexJustCompleted < lastStrokeIndex {
            let nextIndex = indexJustCompleted + 1
            print("    Completion Check: \(indexJustCompleted) < \(lastStrokeIndex) -> TRUE")
            // Update internal index for the *next* stroke SYNCHRONOUSLY
            print("    Updating internal currentStrokeIndex to: \(nextIndex)")

            // Critical change: Update the index synchronously and verify
            self.currentStrokeIndex = nextIndex
            print("    Verification: currentStrokeIndex is now \(self.currentStrokeIndex)")
            
            // Double-check that we have valid stroke data for the next index
            if let nextStroke = currentCharacter.strokes[safe: nextIndex] {
                print("    Next stroke validated: '\(nextStroke.name)' at index \(nextIndex)")
            } else {
                print("    !!! WARNING: Could not validate next stroke data for index \(nextIndex)")
            }
            
            return true // Indicate more strokes remain
        }
        // Handle unexpected states
        else {
            print("    Completion Check: Failed (Index: \(indexJustCompleted), LastIndex: \(lastStrokeIndex), Count: \(strokeCount)).")
            print("    >>> Warning: Unexpected state. Calling allStrokesCompleted anyway. <<<")
            self.strokesCompleted = 0 // Reset counter
            delegate?.allStrokesCompleted()
            return false // Indicate completion/error
        }
    }


    // MARK: - PKCanvasViewDelegate Methods (Enhanced with better error handling)

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        guard let character = self.character, currentStrokeIndex < character.strokeCount else {
            print("Stroke began, but character not ready or already completed. Current index: \(currentStrokeIndex)")
            return
        }
        guard let expectedStroke = character.strokes[safe: currentStrokeIndex] else {
            print("Error: Could not get expected stroke for index \(currentStrokeIndex) on begin.")
            return
        }

        strokeStartTime = Date()
        currentStrokeID = UUID()
        currentStrokePointsAccumulator.removeAll()
        isDrawing = true

        print("Began stroke \(currentStrokeIndex + 1) ('\(expectedStroke.name)') at \(strokeStartTime!) with ID \(currentStrokeID)")
        delegate?.strokeBegan(at: strokeStartTime!, strokeType: expectedStroke.type)
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        // Enhanced validation and logging for debugging
        guard isDrawing else {
            print("Stroke ended, but isDrawing was false. Ignoring.")
            return
        }
        
        guard let startTime = strokeStartTime else {
            print("Stroke ended, but startTime was nil. Ignoring.")
            isDrawing = false
            return
        }
        
        guard let character = self.character else {
            print("Stroke ended, but character is nil. Ignoring.")
            isDrawing = false
            strokeStartTime = nil
            return
        }
        
        guard currentStrokeIndex < character.strokeCount else {
            print("Stroke ended, but currentStrokeIndex (\(currentStrokeIndex)) is out of bounds. Ignoring.")
            isDrawing = false
            strokeStartTime = nil
            return
        }
        
        guard let expectedStroke = character.strokes[safe: currentStrokeIndex] else {
            print("Stroke ended, but could not get expected stroke for index \(currentStrokeIndex). Ignoring.")
            isDrawing = false
            strokeStartTime = nil
            return
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let currentStrokeIDCopy = currentStrokeID
        let currentIndexCopy = currentStrokeIndex // Save index for delegate call
        isDrawing = false // Mark as not drawing anymore for this stroke

        print("DEBUG: canvasViewDidEndUsingTool - Checking canvas drawing for stroke index \(currentStrokeIndex)...")
        guard let lastPkStroke = canvasView.drawing.strokes.last else {
            print("Warning [Direct Capture]: Stroke ended, but PKCanvasView.drawing contains NO strokes. ID: \(currentStrokeIDCopy)")
            strokeStartTime = nil
            return
        }

        let finalPoints = lastPkStroke.path.map { $0.location }
        print("DEBUG: Points captured DIRECTLY from last PKStroke at stroke end: \(finalPoints.count) for ID \(currentStrokeIDCopy)")

        guard !finalPoints.isEmpty else {
            print("Warning [Direct Capture]: Stroke ended, last PKStroke existed but had NO points. ID: \(currentStrokeIDCopy)")
            strokeStartTime = nil
            return
        }

        print("Ended stroke \(currentStrokeIndex + 1) ('\(expectedStroke.name)') at \(endTime). Duration: \(String(format: "%.2f", duration))s. Points: \(finalPoints.count), ID: \(currentStrokeIDCopy)")

        DispatchQueue.main.async {
            self.currentStrokeUserPath = finalPoints
        }

        // Call delegate, passing the index of the stroke that just finished
        // IMPORTANT: Use the saved copy of currentStrokeIndex
        delegate?.strokeEnded(
            at: endTime,
            drawnPoints: finalPoints,
            expectedStroke: expectedStroke,
            strokeIndex: currentIndexCopy // Pass the index that was just drawn
        )

        strokeStartTime = nil
        // Canvas is NOT cleared here. MainView clears it via resetCanvas() in moveToNextStrokeAction.
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard isDrawing, let currentPencilKitStroke = canvasView.drawing.strokes.last else {
            return
        }
        let currentPoints = currentPencilKitStroke.path.map { $0.location }
        if !currentPoints.isEmpty {
            currentStrokePointsAccumulator = currentPoints
            delegate?.strokeUpdated(points: currentStrokePointsAccumulator)
        }
    }

} // End of class StrokeInputController
