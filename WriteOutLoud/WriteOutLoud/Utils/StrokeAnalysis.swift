// File: Utils/StrokeAnalysis.swift
import Foundation
import CoreGraphics
// import UIKit // Keep for hypot if needed, or use sqrt(pow(dx,2)+pow(dy,2))

/**
 Provides stroke analysis capabilities for evaluating handwritten strokes.
 */
struct StrokeAnalysis {

    /// Calculates the accuracy of a drawn stroke compared to the expected stroke path
    /// - Parameters:
    ///   - drawnPoints: Array of points representing the user's drawn stroke
    ///   - expectedStroke: The Stroke object containing the expected path data
    /// - Returns: Accuracy score between 0 and 100
    static func calculateAccuracy(drawnPoints: [CGPoint], expectedStroke: Stroke) -> Double {
        print("\n===== STROKE ANALYSIS: \(expectedStroke.name) (Type: \(expectedStroke.type)) =====")
        
        // Ensure we have drawn points to analyze
        guard !drawnPoints.isEmpty else {
            print("No drawn points to analyze")
            return 0.0
        }

        // Get expected path from the stroke
        // *** FIXED: Use expectedStroke.path ***
        let expectedPathPoints = expectedStroke.path
        guard !expectedPathPoints.isEmpty else {
             print("Expected stroke has no path points")
             return 0.0
        }

        // Ensure both paths have enough points for analysis
        guard drawnPoints.count >= 2, expectedPathPoints.count >= 2 else {
             print("Not enough points for analysis (drawn: \(drawnPoints.count), expected: \(expectedPathPoints.count))")
             return 10.0 // Return low score
        }

        print("Drawn points: \(drawnPoints.count), Expected points: \(expectedPathPoints.count)")

        // 1. Normalize/scale both points to same coordinate space (0.0-1.0)
        let normalizedDrawnPoints = normalizePoints(drawnPoints)
        let normalizedExpectedPoints = normalizePoints(expectedPathPoints)

        // Ensure normalization didn't fail
        guard !normalizedDrawnPoints.isEmpty, !normalizedExpectedPoints.isEmpty else {
             print("Normalization resulted in empty points.")
             return 0.0
        }

        // 2. Calculate shape/contour similarity (e.g., using average distance after resampling)
        let shapeSimilarity = calculateShapeSimilarity(
            drawn: normalizedDrawnPoints,
            expected: normalizedExpectedPoints
        )

        // 3. Calculate direction similarity (using start-to-end vectors)
        let directionSimilarity = calculateDirectionSimilarity(
            drawn: normalizedDrawnPoints,
            expected: normalizedExpectedPoints
        )

        // 4. Calculate start/end position accuracy with increased tolerance for simple strokes
        var positionAccuracy = calculatePositionAccuracy(
            drawnStart: normalizedDrawnPoints.first!, // Safe to force unwrap after checks
            drawnEnd: normalizedDrawnPoints.last!,   // Safe to force unwrap after checks
            expectedStart: normalizedExpectedPoints.first!, // Safe to force unwrap after checks
            expectedEnd: normalizedExpectedPoints.last!,    // Safe to force unwrap after checks
            strokeType: expectedStroke.type
        )

        // 5. Calculate stroke proportion similarity (aspect ratio comparison)
        let proportionSimilarity = calculateProportionSimilarity(
            drawn: normalizedDrawnPoints,
            expected: normalizedExpectedPoints
        )

        // 6. Calculate final weighted score
        // Adjust weights based on stroke type
        var shapeWeight = 0.35
        var directionWeight = 0.3 
        var positionWeight = 0.25
        var proportionWeight = 0.1
        
        // For basic strokes, reduce dependency on position
        if expectedStroke.type == .heng || expectedStroke.type == .shu {
            print("Using adjusted weights for basic stroke: \(expectedStroke.type)")
            shapeWeight = 0.4      // Increase shape importance 
            directionWeight = 0.35  // Increase direction importance
            positionWeight = 0.15   // Reduce position weight
            proportionWeight = 0.1  // Keep proportion the same
            
            // Apply a position boost for basic strokes to avoid low scores
            let positionBoost = max(0.0, 0.5 - positionAccuracy) * 0.5 // Add up to 0.25 to position score
            if positionBoost > 0 {
                print("Applied position boost of +\(String(format: "%.2f", positionBoost)) for basic stroke")
                // Apply the boost to position accuracy
                let boostedPositionAccuracy = min(1.0, positionAccuracy + positionBoost)
                print("Position accuracy boosted from \(String(format: "%.2f", positionAccuracy)) to \(String(format: "%.2f", boostedPositionAccuracy))")
                // Replace position accuracy with boosted value
                positionAccuracy = Double(boostedPositionAccuracy)
            }
        }
        
        let weightedScore =
            (shapeSimilarity * shapeWeight) +
            (directionSimilarity * directionWeight) +
            (positionAccuracy * positionWeight) +
            (proportionSimilarity * proportionWeight)

        // Return score in 0-100 range, clamped
        let finalScore = max(0.0, min(1.0, weightedScore)) // Clamp score between 0 and 1 first
        print("Final Score Breakdown:")
        print("  Shape (\(String(format: "%.2f", shapeWeight * 100))%): \(String(format: "%.2f", shapeSimilarity))")
        print("  Direction (\(String(format: "%.2f", directionWeight * 100))%): \(String(format: "%.2f", directionSimilarity))")
        print("  Position (\(String(format: "%.2f", positionWeight * 100))%): \(String(format: "%.2f", positionAccuracy))")
        print("  Proportion (\(String(format: "%.2f", proportionWeight * 100))%): \(String(format: "%.2f", proportionSimilarity))")
        print("  Weighted Score = \(String(format: "%.2f", finalScore))")
        print("  FINAL PERCENTAGE = \(String(format: "%.1f", finalScore * 100))")
        print("===== END ANALYSIS =====\n")
        return finalScore * 100.0
    }

    /// Normalizes points to a 0.0-1.0 coordinate space based on their bounding box
    private static func normalizePoints(_ points: [CGPoint]) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        // Handle single point case - return it centered at (0.5, 0.5)
        if points.count == 1 { return [CGPoint(x: 0.5, y: 0.5)] }

        // Find bounding box
        var minX: CGFloat = points[0].x
        var minY: CGFloat = points[0].y
        var maxX: CGFloat = points[0].x
        var maxY: CGFloat = points[0].y

        // Iterate starting from the second point if it exists
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        let width = maxX - minX
        let height = maxY - minY

        // Prevent division by zero if width or height is effectively zero
        // If dimension is zero, scaling is 1 and offset calculation handles centering
        let scaleX = width > 0.001 ? 1.0 / width : 1.0
        let scaleY = height > 0.001 ? 1.0 / height : 1.0

        // Normalize all points to 0-1 range
        return points.map { point in
            let normX = (point.x - minX) * scaleX
            let normY = (point.y - minY) * scaleY
            // Handle cases where width/height was zero - center the points
            return CGPoint(
                x: width > 0.001 ? normX : 0.5,
                y: height > 0.001 ? normY : 0.5
            )
        }
    }

    /// Calculate shape similarity using average distance between resampled paths
    /// with tolerance for stroke width
    private static func calculateShapeSimilarity(drawn: [CGPoint], expected: [CGPoint]) -> Double {
        // Resample both paths to have the same number of points
        let sampleCount = 50 // Number of points to resample to
        let resampledDrawn = resamplePath(drawn, targetCount: sampleCount)
        let resampledExpected = resamplePath(expected, targetCount: sampleCount)

        // Ensure resampling didn't fail
        guard resampledDrawn.count == sampleCount, resampledExpected.count == sampleCount else {
            print("Error: Resampling failed.")
            return 0.0 // Low score if resampling fails
        }

        // Calculate minimum distance from each drawn point to any expected point
        // This is more tolerant of slight deviations than direct point-to-point comparison
        var totalDistance: CGFloat = 0
        for i in 0..<sampleCount {
            let drawnPoint = resampledDrawn[i]
            
            // Find closest expected point to this drawn point
            var minDistance = CGFloat.greatestFiniteMagnitude
            // Check nearby points (within a window) to account for slight shifts
            let windowSize = 5 // Check 5 points before and after
            let rangeStart = max(0, i - windowSize)
            let rangeEnd = min(sampleCount - 1, i + windowSize)
            
            for j in rangeStart...rangeEnd {
                let expectedPoint = resampledExpected[j]
                let dist = distance(drawnPoint, expectedPoint)
                minDistance = min(minDistance, dist)
            }
            
            totalDistance += minDistance
        }

        let averageDistance = totalDistance / CGFloat(sampleCount)

        // Convert to similarity score (0-1)
        // Maximum possible distance in normalized space is sqrt(2) (~1.414)
        let maxDistance: CGFloat = sqrt(2.0)
        // Score is 1 if distance is 0, decreases linearly to 0 as distance approaches maxDistance
        // Add tolerance factor (0.8) to be more lenient
        let similarity = 1.0 - (averageDistance / (maxDistance * 0.8))

        return min(1.0, max(0.0, Double(similarity))) // Clamp between 0 and 1
    }

    /// Calculate similarity in stroke direction using start-to-end vectors
    private static func calculateDirectionSimilarity(drawn: [CGPoint], expected: [CGPoint]) -> Double {
        // Need at least 2 points to calculate direction
        guard drawn.count >= 2 && expected.count >= 2 else {
            return 0.5 // Neutral score if not enough points
        }

        // Calculate overall direction vector for both strokes
        let drawnStart = drawn.first!
        let drawnEnd = drawn.last!
        let expectedStart = expected.first!
        let expectedEnd = expected.last!

        let drawnVector = CGPoint(x: drawnEnd.x - drawnStart.x, y: drawnEnd.y - drawnStart.y)
        let expectedVector = CGPoint(x: expectedEnd.x - expectedStart.x, y: expectedEnd.y - expectedStart.y)

        // Calculate vector dot product and magnitudes
        let dotProduct = drawnVector.x * expectedVector.x + drawnVector.y * expectedVector.y
        let drawnMag = magnitude(drawnVector)
        let expectedMag = magnitude(expectedVector)

        // Calculate cosine similarity if magnitudes are non-zero
        if drawnMag > 0.001 && expectedMag > 0.001 { // Use epsilon for float comparison
            let cosine = dotProduct / (drawnMag * expectedMag)
            // Convert cosine similarity [-1..1] to similarity score [0..1]
            let similarity = (max(-1.0, min(1.0, cosine)) + 1.0) / 2.0 // Clamp cosine just in case
            return Double(similarity)
        } else if drawnMag < 0.001 && expectedMag < 0.001 {
             // If both vectors are essentially zero length, consider them similar directionally
             return 1.0
        } else {
            // One vector has length, the other doesn't - low similarity
            return 0.0
        }
    }

    /// Calculate accuracy of start and end positions with adjusted tolerance based on stroke type
    private static func calculatePositionAccuracy(
        drawnStart: CGPoint, drawnEnd: CGPoint,
        expectedStart: CGPoint, expectedEnd: CGPoint,
        strokeType: StrokeType
    ) -> Double {
        // Calculate distances between start points and end points in normalized space
        let startDistance = distance(drawnStart, expectedStart)
        let endDistance = distance(drawnEnd, expectedEnd)
        
        // Print position debugging info
        print("Position Analysis Debug - Type: \(strokeType)")
        print("  Expected Start: (\(String(format: "%.2f", expectedStart.x)), \(String(format: "%.2f", expectedStart.y)))")
        print("  Drawn Start:    (\(String(format: "%.2f", drawnStart.x)), \(String(format: "%.2f", drawnStart.y)))")
        print("  Start Distance: \(String(format: "%.2f", startDistance))")
        print("  Expected End:   (\(String(format: "%.2f", expectedEnd.x)), \(String(format: "%.2f", expectedEnd.y)))")
        print("  Drawn End:      (\(String(format: "%.2f", drawnEnd.x)), \(String(format: "%.2f", drawnEnd.y)))")
        print("  End Distance:   \(String(format: "%.2f", endDistance))")

        // Adjust threshold based on stroke type
        // Simple strokes like horizontal/vertical lines should have more tolerance
        var threshold: CGFloat = 0.25 // Default threshold
        
        // Increase tolerance for basic strokes that are more common and simpler
        switch strokeType {
        case .heng, .shu, .pie, .na:
            threshold = 0.5 // Much more tolerance for basic strokes (horizontal, vertical, etc.)
        case .hengzhe, .shuzhe:
            threshold = 0.4 // More tolerance for compound strokes
        default:
            threshold = 0.3 // Default for other strokes
        }
        
        // For very simple horizontal and vertical strokes, check positional alignment on the relevant axis only
        var startAccuracy: CGFloat = 0.0
        var endAccuracy: CGFloat = 0.0
        
        if strokeType == .heng {
            // For horizontal strokes, care more about y-position than x-position
            let startYDistance = abs(drawnStart.y - expectedStart.y)
            let endYDistance = abs(drawnEnd.y - expectedEnd.y)
            startAccuracy = max(0.0, 1.0 - (startYDistance / threshold))
            endAccuracy = max(0.0, 1.0 - (endYDistance / threshold))
            print("  Using horizontal stroke special handling")
            print("  Start Y-Distance: \(String(format: "%.2f", startYDistance))")
            print("  End Y-Distance: \(String(format: "%.2f", endYDistance))")
        } else if strokeType == .shu {
            // For vertical strokes, care more about x-position than y-position
            let startXDistance = abs(drawnStart.x - expectedStart.x)
            let endXDistance = abs(drawnEnd.x - expectedEnd.x)
            startAccuracy = max(0.0, 1.0 - (startXDistance / threshold))
            endAccuracy = max(0.0, 1.0 - (endXDistance / threshold))
            print("  Using vertical stroke special handling")
            print("  Start X-Distance: \(String(format: "%.2f", startXDistance))")
            print("  End X-Distance: \(String(format: "%.2f", endXDistance))")
        } else {
            // For other strokes, use normal Euclidean distance
            startAccuracy = max(0.0, 1.0 - (startDistance / threshold))
            endAccuracy = max(0.0, 1.0 - (endDistance / threshold))
        }

        // Average the two accuracy scores
        let averageAccuracy = (startAccuracy + endAccuracy) / 2.0
        print("  Threshold: \(String(format: "%.2f", threshold))")
        print("  Start Accuracy: \(String(format: "%.2f", startAccuracy))")
        print("  End Accuracy: \(String(format: "%.2f", endAccuracy))")
        print("  Average Position Accuracy: \(String(format: "%.2f", averageAccuracy))")

        return min(1.0, max(0.0, Double(averageAccuracy))) // Clamp 0-1
    }

    /// Calculate similarity in stroke proportions (aspect ratio)
    private static func calculateProportionSimilarity(drawn: [CGPoint], expected: [CGPoint]) -> Double {
        // Calculate bounding box for both normalized paths
        let drawnBounds = getBounds(drawn)
        let expectedBounds = getBounds(expected)

        // Calculate aspect ratios (width / height), handle zero height
        let drawnAspectRatio = drawnBounds.width / max(drawnBounds.height, 0.001) // Avoid division by zero
        let expectedAspectRatio = expectedBounds.width / max(expectedBounds.height, 0.001) // Avoid division by zero

        // Calculate proportion similarity as ratio of smaller to larger aspect ratio
        // Handle zero aspect ratios (e.g., perfectly vertical/horizontal lines)
        if max(drawnAspectRatio, expectedAspectRatio) < 0.001 {
             return 1.0 // Both are essentially lines with no width/height ratio, consider similar
        }
        let proportionSimilarity = min(drawnAspectRatio, expectedAspectRatio) / max(drawnAspectRatio, expectedAspectRatio, 0.001) // Avoid division by zero

        return min(1.0, max(0.0, Double(proportionSimilarity))) // Clamp 0-1
    }

    // MARK: - Helper Functions

    /// Calculate Euclidean distance between two points
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return hypot(p2.x - p1.x, p2.y - p1.y) // hypot is sqrt(x*x + y*y)
    }

     /// Calculate magnitude (length) of a vector represented by CGPoint
     private static func magnitude(_ vector: CGPoint) -> CGFloat {
         return hypot(vector.x, vector.y)
     }

    /// Calculate total length of a path defined by points.
    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0.0 }
        var totalDistance: CGFloat = 0.0
        for i in 0..<(points.count - 1) {
            totalDistance += distance(points[i], points[i+1])
        }
        return totalDistance
    }

    /// Resample path to have targetCount points using linear interpolation
    private static func resamplePath(_ points: [CGPoint], targetCount: Int) -> [CGPoint] {
        guard points.count >= 2 else { return points } // Cannot resample < 2 points
        guard targetCount > 1 else { return points.first.map { [$0] } ?? [] } // Return first point if target is 1

        let totalLen = pathLength(points)
        // If path has zero length, return array of first point repeated
        if totalLen <= 0 { return Array(repeating: points[0], count: targetCount) }

        let interval = totalLen / CGFloat(targetCount - 1) // Distance between resampled points
        var resampledPoints = [points[0]] // Start with the first point
        var currentDist: CGFloat = 0.0 // Distance covered along the original path

        var segmentIndex = 0 // Index of the start point of the current segment
        var distIntoSegment: CGFloat = 0.0 // Distance covered within the current segment

        for i in 1..<targetCount { // For each point we need to generate (excluding the first)
            let targetDist = CGFloat(i) * interval

            // Find the segment where the target distance falls
            while segmentIndex < points.count - 1 {
                let p1 = points[segmentIndex]
                let p2 = points[segmentIndex + 1]
                let segmentLen = distance(p1, p2)

                // Check if target point is within the current segment or before it
                if currentDist + segmentLen >= targetDist {
                    distIntoSegment = targetDist - currentDist
                    let ratio = segmentLen > 0 ? distIntoSegment / segmentLen : 0 // Avoid division by zero
                    let newX = p1.x + (p2.x - p1.x) * ratio
                    let newY = p1.y + (p2.y - p1.y) * ratio
                    resampledPoints.append(CGPoint(x: newX, y: newY))
                    break // Found the point for this iteration
                } else {
                    // Move to the next segment
                    currentDist += segmentLen
                    segmentIndex += 1
                    // If we reach the end, break loop
                    if segmentIndex >= points.count - 1 { break }
                }
            }
            // If loop finished without finding point (e.g., due to floating point issues at the very end)
            // append the last point of the original path.
            if resampledPoints.count <= i {
                 resampledPoints.append(points.last!)
            }
        }
        // Ensure the final point count matches targetCount, duplicating last point if necessary
        while resampledPoints.count < targetCount {
             resampledPoints.append(points.last!)
        }
        // Trim excess points if any somehow occurred (shouldn't happen with this logic)
        return Array(resampledPoints.prefix(targetCount))
    }

    /// Get bounding rectangle for a set of points
    private static func getBounds(_ points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
