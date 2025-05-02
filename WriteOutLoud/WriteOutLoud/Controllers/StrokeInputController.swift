// File: Controllers/StrokeInputController.swift
// VERSION: Fixed access level for 'character' property

import Foundation
import PencilKit
import SwiftUI
import Combine
import CoreGraphics

// Delegate protocol definition (Unchanged)
protocol StrokeInputDelegate {
    func strokeBegan(at time: Date, strokeType: StrokeType)
    func strokeUpdated(points: [CGPoint])
    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int)
    func allStrokesCompleted()
}

class StrokeInputController: NSObject, ObservableObject, PKCanvasViewDelegate {

    // Published properties (Unchanged)
    @Published var isDrawing: Bool = false
    @Published var currentStrokeUserPath: [CGPoint] = []
    @Published private(set) var currentStrokeIndex: Int = 0

    // Internal State
    // ***** MODIFIED: Removed 'private' access control *****
    var character: Character? // Allow access from Coordinator
    // ****************************************************
    private var canvasView: PKCanvasView?
    private(set) var strokeStartTime: Date?
    private var currentStrokePointsAccumulator: [CGPoint] = []
    private var currentStrokeID: UUID = UUID()

    // Delegate (Unchanged)
    var delegate: StrokeInputDelegate?

    // Setup and Control methods (Unchanged)
    func setup(with canvasView: PKCanvasView, for character: Character) {
        self.canvasView = canvasView
        self.character = character // Store the character
        self.currentStrokeIndex = 0 // Reset index
        self.isDrawing = false
        self.currentStrokeUserPath = []
        self.currentStrokePointsAccumulator = []
        self.strokeStartTime = nil
        self.currentStrokeID = UUID()

        canvasView.delegate = self
        canvasView.drawing = PKDrawing() // Ensure canvas is cleared on setup
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 10) // Default tool
        canvasView.drawingPolicy = .anyInput
        canvasView.isUserInteractionEnabled = true
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        print("StrokeInputController setup for character: \(character.character) (Strokes: \(character.strokeCount)). Initial index: \(self.currentStrokeIndex)")
        // Prepare for the first stroke immediately after setup
        prepareForStroke(index: 0)
    }

    deinit { }

    // Clears the canvas (Unchanged)
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

     // Prepare internal state for a specific stroke index (Unchanged)
     func prepareForStroke(index: Int) {
         guard let currentCharacter = self.character else { return }
         guard index < currentCharacter.strokeCount else { return }
         guard let stroke = currentCharacter.strokes[safe: index] else { return }
         DispatchQueue.main.async {
             print("   prepareForStroke: About to set currentStrokeIndex from \(self.currentStrokeIndex) to \(index)")
             self.currentStrokeIndex = index
             print("Prepared for stroke index \(index) (Stroke \(index + 1) of \(currentCharacter.strokeCount)): Type=\(stroke.type.rawValue), Name=\(stroke.name)")
         }
     }

    // Check completion and advance index (Unchanged)
    func checkCompletionAndAdvance(indexJustCompleted: Int) -> Bool {
        guard let currentCharacter = self.character else { return false }
        let strokeCount = currentCharacter.strokeCount
        let lastStrokeIndex = strokeCount > 0 ? strokeCount - 1 : -1

        print("-----------------------------------------")
        print(">>> checkCompletionAndAdvance called <<<")
        print("   Character: '\(currentCharacter.character)', StrokeCount: \(strokeCount)")
        print("   Index Just Completed: \(indexJustCompleted)")
        print("   Last Stroke Index: \(lastStrokeIndex)")
        print("   Current Internal Index BEFORE check: \(self.currentStrokeIndex)")
        print("-----------------------------------------")

        if strokeCount > 0 && indexJustCompleted == lastStrokeIndex {
            print("   Completion Check: Last stroke completed.")
            print("   >>> Calling allStrokesCompleted delegate <<<")
            delegate?.allStrokesCompleted() // Signal completion
            return false // Indicate completion
        }
        else if indexJustCompleted < lastStrokeIndex {
            let nextIndex = indexJustCompleted + 1
            print("   Completion Check: More strokes remain.")
            DispatchQueue.main.async {
                print("   Updating internal currentStrokeIndex to: \(nextIndex)")
                self.currentStrokeIndex = nextIndex
            }
            return true // Indicate more strokes remain
        }
        else {
            print("   Completion Check: Failed (Unexpected state).")
            print("   >>> Warning: Calling allStrokesCompleted anyway. <<<")
            delegate?.allStrokesCompleted()
            return false // Indicate completion/error
        }
    }


    // MARK: - PKCanvasViewDelegate Methods (Unchanged)
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
         guard let startTime = strokeStartTime,
               let character = self.character,
               let expectedStroke = character.strokes[safe: currentStrokeIndex], // Use current index
               isDrawing else {
             isDrawing = false; strokeStartTime = nil
             print("Stroke ended, but state was invalid. Ignoring.")
             return
         }

         let endTime = Date()
         let duration = endTime.timeIntervalSince(startTime)
         let currentStrokeIDCopy = currentStrokeID
         isDrawing = false // Mark as not drawing anymore for this stroke

         print("DEBUG: canvasViewDidEndUsingTool - Checking canvas drawing for stroke index \(currentStrokeIndex)...")
         // Capture points directly from the last stroke added to the canvas drawing
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
         delegate?.strokeEnded(
             at: endTime,
             drawnPoints: finalPoints,
             expectedStroke: expectedStroke,
             strokeIndex: self.currentStrokeIndex // Pass the index that was just drawn
         )

         strokeStartTime = nil
         // Canvas is NOT cleared here by the controller. MainView/Coordinator handles visual clearing.
     }


    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // This can be noisy. Only update if needed for live feedback (which we aren't using).
        // guard isDrawing, let currentPencilKitStroke = canvasView.drawing.strokes.last else { return }
        // let currentPoints = currentPencilKitStroke.path.map { $0.location }
        // if !currentPoints.isEmpty {
        //     currentStrokePointsAccumulator = currentPoints
        //     delegate?.strokeUpdated(points: currentStrokePointsAccumulator)
        // }
    }

} // End of class StrokeInputController
