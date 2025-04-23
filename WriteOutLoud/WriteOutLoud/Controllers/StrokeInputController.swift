// File: Controllers/StrokeInputController.swift
// VERSION: Simplified point capture for debugging "no points captured"

import Foundation
import PencilKit
import SwiftUI
import Combine
import CoreGraphics

// Delegate protocol definition
protocol StrokeInputDelegate {
    func strokeBegan(at time: Date, strokeType: StrokeType)
    func strokeUpdated(points: [CGPoint]) // Optional: for live drawing effects if needed
    func strokeEnded(at time: Date, drawnPoints: [CGPoint], expectedStroke: Stroke, strokeIndex: Int)
    func allStrokesCompleted()
}

class StrokeInputController: NSObject, ObservableObject, PKCanvasViewDelegate {

    // Published properties
    @Published var isDrawing: Bool = false
    @Published var currentStrokeUserPath: [CGPoint] = [] // Last completed user stroke path for display
    @Published var currentStrokeIndex: Int = 0 // 0-based index of the stroke being practiced

    // Internal State
    private var character: Character?
    private var canvasView: PKCanvasView?
    private(set) var strokeStartTime: Date?
    // Keep accumulator for strokeUpdated delegate, though not primary for strokeEnd in this version
    private var currentStrokePointsAccumulator: [CGPoint] = []
    // Keep timer infrastructure but disable start for this test
    private var pointCaptureTimer: Timer?
    private var currentStrokeID: UUID = UUID()

    // Delegate
    var delegate: StrokeInputDelegate?

    // Setup and Control methods
    func setup(with canvasView: PKCanvasView, for character: Character) {
        self.canvasView = canvasView
        self.character = character
        self.currentStrokeIndex = 0 // Start from the first stroke
        self.isDrawing = false
        self.currentStrokeUserPath = []
        self.currentStrokePointsAccumulator = []
        self.strokeStartTime = nil
        self.currentStrokeID = UUID() // Initial ID

        canvasView.delegate = self
        canvasView.drawing = PKDrawing() // Clear previous drawing
        // Configure tool - maybe allow customization later
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 10) // Use system label color for visibility
        canvasView.drawingPolicy = .anyInput // Allow finger or Pencil
        canvasView.isUserInteractionEnabled = true // Ensure interaction is enabled
        canvasView.backgroundColor = .clear // Ensure guide behind is visible
        canvasView.isOpaque = false

        print("StrokeInputController setup for character: \(character.character)")
        // Prepare for the first stroke
        prepareForStroke(index: 0)
    }

    deinit {
        stopPointCaptureTimer() // Still good practice to invalidate timer on deinit
    }

    // Called internally or by coordinator to clear canvas for the next stroke OR on failure
    func resetForNextStroke() {
        stopPointCaptureTimer() // Stop timer if it was running
        canvasView?.drawing = PKDrawing() // Clear the drawing
        isDrawing = false
        currentStrokeUserPath = []
        currentStrokePointsAccumulator = []
        strokeStartTime = nil
        currentStrokeID = UUID() // Generate new ID for next stroke

        if let char = character, currentStrokeIndex < char.strokes.count {
            // Use safe subscript from Extensions.swift
            if let strokeName = char.strokes[safe: currentStrokeIndex]?.name {
                 print("Resetting canvas for stroke \(currentStrokeIndex + 1) ('\(strokeName)')")
            } else {
                 print("Resetting canvas for stroke \(currentStrokeIndex + 1) (Name missing)")
            }
        } else {
            print("Resetting canvas (no next stroke or character loaded).")
        }
    }

     // Prepare internal state for a specific stroke index (e.g., highlighting, expected type)
     private func prepareForStroke(index: Int) {
          guard let character = character, let stroke = character.strokes[safe: index] else {
                print("Cannot prepare for stroke index \(index), character or stroke data missing.")
                return
          }
          print("Prepared for stroke \(index + 1): Type=\(stroke.type.rawValue), Name=\(stroke.name)")
     }

    // Called by coordinator (MainView) to advance state
    func moveToNextStroke() {
        guard let character = character else {
            print("Error: Cannot move to next stroke, character data is missing.")
            return
        }

        if currentStrokeIndex < character.strokeCount - 1 {
             currentStrokeIndex += 1
             resetForNextStroke() // Clear canvas for the new stroke
             prepareForStroke(index: currentStrokeIndex) // Prepare state for the new stroke
             print("Moved to stroke index \(currentStrokeIndex)")
        } else if currentStrokeIndex == character.strokeCount - 1 {
             currentStrokeIndex += 1
             resetForNextStroke() // Clear canvas after last stroke
             print("All \(character.strokeCount) strokes completed for character '\(character.character)'")
             delegate?.allStrokesCompleted() // Notify delegate
        } else {
            print("Already past the last stroke.")
        }
    }

    // MARK: - Point Capture Timer Methods (Keep definition but disable start)

    private func startPointCaptureTimer() {
        stopPointCaptureTimer()
        print("DEBUG: Starting point capture timer.")
        pointCaptureTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
             guard let self = self,
                   self.isDrawing,
                   let canvasView = self.canvasView,
                   !canvasView.drawing.strokes.isEmpty,
                   let currentStroke = canvasView.drawing.strokes.last else {
                 return
             }
             print("DEBUG: Point capture timer FIRED.") // Keep log for future debugging
             let currentPoints = currentStroke.path.map { $0.location }
             print("DEBUG: Timer found \(currentPoints.count) points in canvas.drawing.strokes.last")
             if !currentPoints.isEmpty {
                 self.currentStrokePointsAccumulator = currentPoints
                 self.delegate?.strokeUpdated(points: self.currentStrokePointsAccumulator)
             }
        }
    }

    private func stopPointCaptureTimer() {
        pointCaptureTimer?.invalidate()
        pointCaptureTimer = nil
    }

    // MARK: - PKCanvasViewDelegate Methods

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        guard let character = character, currentStrokeIndex < character.strokeCount else {
            print("Stroke began, but character not ready or already completed.")
            return
        }
        guard let expectedStroke = character.strokes[safe: currentStrokeIndex] else {
            print("Error: Could not get expected stroke for index \(currentStrokeIndex) on begin.")
            return
        }

        strokeStartTime = Date()
        currentStrokeID = UUID() // Generate new unique ID for this stroke session
        currentStrokePointsAccumulator.removeAll() // Still clear accumulator here
        isDrawing = true

        // *** TIMER START COMMENTED OUT FOR SIMPLIFIED TEST ***
        // startPointCaptureTimer()
        // *** END TIMER COMMENT OUT ***

        print("Began stroke \(currentStrokeIndex + 1) ('\(expectedStroke.name)') at \(strokeStartTime!) with ID \(currentStrokeID)")
        delegate?.strokeBegan(at: strokeStartTime!, strokeType: expectedStroke.type)
    }

    // *** THIS METHOD CONTAINS THE SIMPLIFIED POINT CAPTURE LOGIC ***
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        // Stop the point capture timer if it was running (good practice even if we didn't start it this time)
        stopPointCaptureTimer()

        guard let startTime = strokeStartTime,
              let character = character,
              currentStrokeIndex < character.strokeCount, // Ensure we are expecting a stroke
              isDrawing // Ensure we were actually drawing
        else {
            isDrawing = false // Reset drawing state if ended unexpectedly
            strokeStartTime = nil
            print("Stroke ended, but state was invalid (no start time, char complete, or wasn't drawing).")
            return
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let currentStrokeIDCopy = currentStrokeID // Store for logging
        isDrawing = false

        // --- SIMPLIFIED POINT CAPTURE ---
        // Try to get the last stroke directly from the canvas drawing object
        guard let finalStrokeFromCanvas = canvasView.drawing.strokes.last else {
            print("ERROR: No stroke object found in canvasView.drawing at stroke end for ID \(currentStrokeIDCopy).")
            strokeStartTime = nil
            resetForNextStroke() // Reset because we found no stroke object
            return
        }
        // Extract points directly from the stroke object found on the canvas
        let finalPoints = finalStrokeFromCanvas.path.map { $0.location }
        print("DEBUG [Simplified]: Points captured directly from canvas stroke: \(finalPoints.count) for ID \(currentStrokeIDCopy)")
        // --- END SIMPLIFIED POINT CAPTURE ---


        // Now check if points were actually extracted
        guard !finalPoints.isEmpty else {
             print("Warning [Simplified]: Stroke ended, found a stroke object, but it contained no points for ID \(currentStrokeIDCopy).")
             strokeStartTime = nil // Reset start time as the stroke was invalid
             resetForNextStroke() // Clear the invalid (empty) drawing attempt and prepare for retry
             return
        }

        // --- Rest of the success logic ---
        guard let expectedStroke = character.strokes[safe: currentStrokeIndex] else {
            print("Error: Could not get expected stroke for index \(currentStrokeIndex) on stroke end.")
            strokeStartTime = nil // Reset as we can't proceed
            return
        }

        print("Ended stroke \(currentStrokeIndex + 1) ('\(expectedStroke.name)') at \(endTime). Duration: \(String(format: "%.2f", duration))s. Points: \(finalPoints.count), ID: \(currentStrokeIDCopy)")

        // Update the published path for potential display
        DispatchQueue.main.async {
            self.currentStrokeUserPath = finalPoints
        }

        // Save the data to persistent storage if needed (Keep this if you added it)
         saveStrokeData(points: finalPoints, strokeID: currentStrokeIDCopy)

        // Notify the delegate with the captured data
        delegate?.strokeEnded(
            at: endTime,
            drawnPoints: finalPoints, // Use the points read directly from canvas
            expectedStroke: expectedStroke,
            strokeIndex: currentStrokeIndex
        )
        // --- End of success logic ---
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // This method is less critical in the simplified approach but can remain
        guard isDrawing, let currentPencilKitStroke = canvasView.drawing.strokes.last else {
            return
        }
        // Keep updating the accumulator for the 'strokeUpdated' delegate if used
        currentStrokePointsAccumulator = currentPencilKitStroke.path.map { $0.location }
        // Optionally notify delegate about updated points for real-time effects
         delegate?.strokeUpdated(points: currentStrokePointsAccumulator)
    }

    // MARK: - Data Persistence (Keep if you added it)
    private func saveStrokeData(points: [CGPoint], strokeID: UUID) {
        // Implement persistence logic here if needed
        guard let character = character, currentStrokeIndex < character.strokeCount else { return }
        let pointsData = points.map { [$0.x, $0.y] }
        let strokeData: [String: Any] = [
            "characterID": character.id,
            "characterName": character.character,
            "strokeIndex": currentStrokeIndex,
            "strokeID": strokeID.uuidString,
            "timestamp": Date().timeIntervalSince1970,
            "points": pointsData
        ]
        var savedStrokes = UserDefaults.standard.array(forKey: "SavedStrokes") as? [[String: Any]] ?? []
        savedStrokes.append(strokeData)
        UserDefaults.standard.set(savedStrokes, forKey: "SavedStrokes")
    }

    // MARK: - Stroke Accuracy Calculation Methods (Keep your original methods)
    // ... (Placeholder or your actual static accuracy methods) ...
    static func calculateStrokeAccuracy_Placeholder(drawnPoints: [CGPoint], expectedStroke: Stroke) -> Double {
         // ... your implementation ...
         return 50.0 // Example placeholder return
     }
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
         // ... your implementation ...
         return 0.0
     }
    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        // ... your implementation ...
        return 0.0
    }
    private static func calculateDirectionSimilarity(_ v1: CGPoint, _ v2: CGPoint) -> Double {
        // ... your implementation ...
        return 0.0
    }

}
