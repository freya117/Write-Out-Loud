// File: Controllers/StrokeInputController.swift
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
    private var currentStrokePointsAccumulator: [CGPoint] = [] // Accumulates points during drawing

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

        canvasView.delegate = self
        canvasView.drawing = PKDrawing() // Clear previous drawing
        // Configure tool - maybe allow customization later
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 10) // Use system label color for visibility
        canvasView.drawingPolicy = .anyInput // Allow finger or Pencil
        canvasView.backgroundColor = .clear // Ensure guide behind is visible
        canvasView.isOpaque = false

        print("StrokeInputController setup for character: \(character.character)")
        // Prepare for the first stroke
        prepareForStroke(index: 0)
    }

    // Called internally or by coordinator to clear canvas for the next stroke
    func resetForNextStroke() {
        canvasView?.drawing = PKDrawing() // Clear the drawing
        isDrawing = false
        currentStrokeUserPath = []
        currentStrokePointsAccumulator = []
        strokeStartTime = nil

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
         // Future: Could set canvas tool color/width based on stroke type?
     }


    // Called by coordinator (MainView) to advance state
    func moveToNextStroke() {
        guard let character = character else {
            print("Error: Cannot move to next stroke, character data is missing.")
            return
        }

        // Check if we are not already past the last stroke
        if currentStrokeIndex < character.strokeCount - 1 {
             currentStrokeIndex += 1
             resetForNextStroke() // Clear canvas for the new stroke
             prepareForStroke(index: currentStrokeIndex) // Prepare state for the new stroke
             print("Moved to stroke index \(currentStrokeIndex)")
        } else if currentStrokeIndex == character.strokeCount - 1 {
            // We just finished the last stroke, move index past the end
             currentStrokeIndex += 1
             resetForNextStroke() // Clear canvas after last stroke
             print("All \(character.strokeCount) strokes completed for character '\(character.character)'")
             delegate?.allStrokesCompleted() // Notify delegate
        } else {
            // Index is already past the end
            print("Already past the last stroke.")
        }
    }

    // MARK: - PKCanvasViewDelegate Methods

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        guard let character = character, currentStrokeIndex < character.strokeCount else {
            print("Stroke began, but character not ready or already completed.")
            return
        }
        // Use safe subscript from Extensions.swift
        guard let expectedStroke = character.strokes[safe: currentStrokeIndex] else {
            print("Error: Could not get expected stroke for index \(currentStrokeIndex) on begin.")
            return
        }

        strokeStartTime = Date()
        currentStrokePointsAccumulator.removeAll() // Start accumulating points for the new stroke
        isDrawing = true
        print("Began stroke \(currentStrokeIndex + 1) ('\(expectedStroke.name)') at \(strokeStartTime!)")
        delegate?.strokeBegan(at: strokeStartTime!, strokeType: expectedStroke.type)
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
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
        isDrawing = false

        // Use the accumulated points
        let finalPoints = currentStrokePointsAccumulator
        guard !finalPoints.isEmpty else {
             print("Warning: Stroke ended with no points captured.")
             strokeStartTime = nil // Reset start time as the stroke was invalid
             // Do not call delegate? Or call with error/empty points? Let's not call.
             resetForNextStroke() // Clear the invalid (empty) drawing attempt
             return
        }

        // Use safe subscript from Extensions.swift
        guard let expectedStroke = character.strokes[safe: currentStrokeIndex] else {
            print("Error: Could not get expected stroke for index \(currentStrokeIndex) on stroke end.")
            strokeStartTime = nil // Reset as we can't proceed
            return
        }

        print("Ended stroke \(currentStrokeIndex + 1) ('\(expectedStroke.name)') at \(endTime). Duration: \(String(format: "%.2f", duration))s. Points: \(finalPoints.count)")

        // Update the published path for potential display (e.g., debugging)
        DispatchQueue.main.async {
            self.currentStrokeUserPath = finalPoints
        }

        // Notify the delegate with the captured data
        delegate?.strokeEnded(
            at: endTime,
            drawnPoints: finalPoints,
            expectedStroke: expectedStroke,
            strokeIndex: currentStrokeIndex // Pass the index of the stroke that just ended
        )

        // Do NOT automatically move to next stroke here. Let the coordinator (MainView) decide when.
        // Do NOT clear the canvas here. Let the coordinator call resetForNextStroke or moveToNextStroke.
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // Update the point accumulator while drawing
        guard isDrawing, let currentPencilKitStroke = canvasView.drawing.strokes.last else {
            // If not drawing, or if strokes array is empty, do nothing.
             // This can happen if the view updates for other reasons.
            return
        }
        // Extract points from the current PKStroke's path
        // Note: PKStroke points have force/azimuth/altitude, we only need location.
        currentStrokePointsAccumulator = currentPencilKitStroke.path.map { $0.location }

        // Optionally notify delegate about updated points for real-time effects
         delegate?.strokeUpdated(points: currentStrokePointsAccumulator)
    }

    // MARK: - Placeholder Accuracy Calculation
    // NOTE: This is a placeholder. StrokeAnalysis.calculateAccuracy should be used.
    static func calculateStrokeAccuracy_Placeholder(drawnPoints: [CGPoint], expectedStroke: Stroke) -> Double {
        guard drawnPoints.count >= 2, expectedStroke.path.count >= 2 else { return 10.0 } // Low score if not enough points

        let expectedStart = expectedStroke.path.first!
        let expectedEnd = expectedStroke.path.last!
        let drawnStart = drawnPoints.first!
        let drawnEnd = drawnPoints.last!

        // Normalize distances by the diagonal of the expected stroke's bounding box
        let size = max(expectedStroke.boundingBox.diagonal(), 1.0) // Use extension method, avoid division by zero

        // Calculate distance error for start/end points relative to size
        let startDistError = distance(drawnStart, expectedStart) / size
        let endDistError = distance(drawnEnd, expectedEnd) / size

        // Simple score based on distance (closer is better) - thresholding
        let threshold: CGFloat = 0.25 // Allow 25% deviation relative to size
        let startAccuracy = max(0.0, 1.0 - startDistError / threshold) * 100.0
        let endAccuracy = max(0.0, 1.0 - endDistError / threshold) * 100.0

        // Calculate direction similarity using vectors
        let drawnVector = CGPoint(x: drawnEnd.x - drawnStart.x, y: drawnEnd.y - drawnStart.y)
        let expectedVector = CGPoint(x: expectedEnd.x - expectedStart.x, y: expectedEnd.y - expectedStart.y)
        let directionAccuracy = calculateDirectionSimilarity(drawnVector, expectedVector) * 100.0 // 0-100 score

        // Simple length comparison (crude shape estimate)
        let drawnLength = pathLength(drawnPoints)
        let expectedLength = pathLength(expectedStroke.path)
        let lengthSimilarity = (drawnLength > 0 && expectedLength > 0) ? min(drawnLength, expectedLength) / max(drawnLength, expectedLength) : 0.0
        let shapeAccuracy = lengthSimilarity * 100.0 // Convert 0-1 ratio to 0-100 score

        // Weighted average (adjust weights as needed)
        let overallAccuracy = (startAccuracy * 0.20) + (endAccuracy * 0.20) + (directionAccuracy * 0.35) + (shapeAccuracy * 0.25)

        // Clamp final score
        let finalScore = max(0.0, min(100.0, overallAccuracy))
        // print("Placeholder Accuracy: Start=\(String(format: "%.1f", startAccuracy)) | End=\(String(format: "%.1f", endAccuracy)) | Dir=\(String(format: "%.1f", directionAccuracy)) | Shape=\(String(format: "%.1f", shapeAccuracy)) -> Overall=\(String(format: "%.1f", finalScore))")
        return finalScore
    }

    // MARK: - Private Static Helpers (Duplicated from StrokeAnalysis for placeholder)

    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }

    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0.0 }
        var totalDistance: CGFloat = 0.0
        for i in 0..<(points.count - 1) {
            totalDistance += distance(points[i], points[i+1])
        }
        return totalDistance
    }

    private static func calculateDirectionSimilarity(_ v1: CGPoint, _ v2: CGPoint) -> Double {
        let dotProduct = (v1.x * v2.x) + (v1.y * v2.y)
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)

        // Handle zero-length vectors
        guard mag1 > 0.001 && mag2 > 0.001 else {
            // If both are zero-length, consider them perfectly similar directionally? Or neutral? Let's say similar.
             return (mag1 < 0.001 && mag2 < 0.001) ? 1.0 : 0.0 // If only one is zero, dissimilar
        }

        let cosine = Double(dotProduct / (mag1 * mag2))
        // Clamp cosine to [-1, 1] due to potential floating point inaccuracies
        let clampedCosine = max(-1.0, min(1.0, cosine))
        // Convert cosine similarity [-1, 1] to score [0, 1]
        return (clampedCosine + 1.0) / 2.0
    }
}
