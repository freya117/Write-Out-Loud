// File: Utils/PathUtils.swift
import Foundation
import UIKit
import CoreGraphics

/**
 Utility methods for path operations and transformations.
 Primarily used for stroke path processing.
 */
struct PathUtils {
    
    /// Scales a collection of points to fit a target rect
    /// - Parameters:
    ///   - points: The original points
    ///   - targetRect: The rectangle to scale points to
    ///   - maintainAspectRatio: Whether to preserve original aspect ratio
    /// - Returns: Array of scaled points
    static func scalePoints(_ points: [CGPoint], to targetRect: CGRect, maintainAspectRatio: Bool = true) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        
        // Find original bounds
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        
        let originalWidth = maxX - minX
        let originalHeight = maxY - minY
        
        // Calculate scale factors
        var scaleX = targetRect.width / originalWidth
        var scaleY = targetRect.height / originalHeight
        
        // Adjust for aspect ratio if needed
        if maintainAspectRatio {
            let scale = min(scaleX, scaleY)
            scaleX = scale
            scaleY = scale
        }
        
        // Scale and translate points
        return points.map { point in
            let scaledX = ((point.x - minX) * scaleX) + targetRect.minX
            let scaledY = ((point.y - minY) * scaleY) + targetRect.minY
            return CGPoint(x: scaledX, y: scaledY)
        }
    }
    
    /// Creates a UIBezierPath from an array of points
    /// - Parameters:
    ///   - points: The points to connect
    ///   - shouldClose: Whether to close the path
    ///   - smoothness: Optional smoothing factor (0-1, higher = smoother)
    /// - Returns: A UIBezierPath connecting the points
    static func createPath(from points: [CGPoint], shouldClose: Bool = false, smoothness: CGFloat? = nil) -> UIBezierPath {
        guard !points.isEmpty else { return UIBezierPath() }
        
        if let smoothness = smoothness, smoothness > 0, points.count > 2 {
            return createSmoothPath(from: points, shouldClose: shouldClose, smoothness: smoothness)
        }
        
        // Create standard path
        let path = UIBezierPath()
        path.move(to: points[0])
        
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        if shouldClose {
            path.close()
        }
        
        return path
    }
    
    /// Creates a smoothed path using Catmull-Rom spline interpolation
    private static func createSmoothPath(from points: [CGPoint], shouldClose: Bool, smoothness: CGFloat) -> UIBezierPath {
        guard points.count > 2 else { return createPath(from: points, shouldClose: shouldClose) }
        
        let path = UIBezierPath()
        
        // Create working array with start/end extensions if needed
        var workingPoints = points
        if shouldClose {
            // For closed paths, we wrap points around
            workingPoints.insert(points[points.count-1], at: 0)
            workingPoints.append(points[0])
            workingPoints.append(points[1])
        } else {
            // For open paths, we duplicate end points
            workingPoints.insert(points[0], at: 0)
            workingPoints.append(points[points.count-1])
        }
        
        // Start path
        path.move(to: workingPoints[1])
        
        // Catmull-Rom coefficient
        let alpha = smoothness * 0.5
        
        // Process segments (use n+1 points for n segments)
        for i in 1..<workingPoints.count-2 {
            let p0 = workingPoints[i-1]
            let p1 = workingPoints[i]
            let p2 = workingPoints[i+1]
            let p3 = workingPoints[i+2]
            
            // Calculate control points
            let d1 = sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
            let d2 = sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
            let d3 = sqrt(pow(p3.x - p2.x, 2) + pow(p3.y - p2.y, 2))
            
            let b1 = max(d1, 0.01)
            let b2 = max(d2, 0.01)
            let b3 = max(d3, 0.01)
            
            let k1 = b2 / (b1 + b2)
            let k2 = b2 / (b2 + b3)
            
            // First control point
            let c1x = p1.x + alpha * b2 * (1 - k1) * (p2.x - p0.x) / b1
            let c1y = p1.y + alpha * b2 * (1 - k1) * (p2.y - p0.y) / b1
            
            // Second control point
            let c2x = p2.x - alpha * b2 * k2 * (p3.x - p1.x) / b3
            let c2y = p2.y - alpha * b2 * k2 * (p3.y - p1.y) / b3
            
            // Add cubic curve segment
            path.addCurve(to: p2, controlPoint1: CGPoint(x: c1x, y: c1y), controlPoint2: CGPoint(x: c2x, y: c2y))
        }
        
        // Close the path if requested
        if shouldClose {
            path.close()
        }
        
        return path
    }
    
    /// Simplifies a path by reducing the number of points while preserving shape
    /// - Parameters:
    ///   - points: The original points
    ///   - tolerance: Distance tolerance (higher = fewer points)
    /// - Returns: Simplified array of points
    static func simplifyPath(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        // Implementation of Ramer-Douglas-Peucker algorithm
        func rdpRecursive(_ points: [CGPoint], start: Int, end: Int, epsilon: CGFloat) -> [Int] {
            if end - start <= 1 {
                return [start, end]
            }
            
            var dmax: CGFloat = 0
            var index = start
            
            let line = Line(p1: points[start], p2: points[end])
            
            for i in start+1..<end {
                let d = line.perpendicularDistance(to: points[i])
                if d > dmax {
                    index = i
                    dmax = d
                }
            }
            
            if dmax > epsilon {
                var result1 = rdpRecursive(points, start: start, end: index, epsilon: epsilon)
                let result2 = rdpRecursive(points, start: index, end: end, epsilon: epsilon)
                
                // Combine results (remove duplicate point)
                result1.removeLast()
                result1.append(contentsOf: result2)
                return result1
            } else {
                return [start, end]
            }
        }
        
        // Helper structure for line calculations
        struct Line {
            let p1: CGPoint
            let p2: CGPoint
            
            func perpendicularDistance(to point: CGPoint) -> CGFloat {
                // Handle case where line is a point
                if p1.x == p2.x && p1.y == p2.y {
                    return sqrt(pow(point.x - p1.x, 2) + pow(point.y - p1.y, 2))
                }
                
                // Calculate perpendicular distance
                let numerator = abs((p2.y - p1.y) * point.x - (p2.x - p1.x) * point.y + p2.x * p1.y - p2.y * p1.x)
                let denominator = sqrt(pow(p2.y - p1.y, 2) + pow(p2.x - p1.x, 2))
                return numerator / denominator
            }
        }
        
        // Get indices of points to keep
        let indices = rdpRecursive(points, start: 0, end: points.count - 1, epsilon: tolerance)
        
        // Return only the points at those indices
        return indices.map { points[$0] }
    }
    
    /// Resamples a path to have points at regular intervals
    /// - Parameters:
    ///   - points: The original points
    ///   - spacing: The desired spacing between points
    /// - Returns: Resampled array of points
    static func resamplePath(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        
        var result = [points[0]]
        var distance: CGFloat = 0
        
        for i in 1..<points.count {
            let prev = points[i-1]
            let current = points[i]
            
            let segmentLength = sqrt(pow(current.x - prev.x, 2) + pow(current.y - prev.y, 2))
            if segmentLength == 0 { continue }
            
            // Check if we need to add points within this segment
            while distance + segmentLength >= spacing {
                // Calculate interpolation ratio
                let ratio = (spacing - distance) / segmentLength
                
                // Interpolate new point
                let x = prev.x + ratio * (current.x - prev.x)
                let y = prev.y + ratio * (current.y - prev.y)
                result.append(CGPoint(x: x, y: y))
                
                // Update remaining distance
                distance = 0
            }
            
            // Update distance for next segment
            distance += segmentLength
        }
        
        // Add the last point if we didn't end exactly on a sample point
        if result.last != points.last {
            result.append(points.last!)
        }
        
        return result
    }
    
    /// Applies an affine transform to an array of points
    /// - Parameters:
    ///   - points: The original points
    ///   - transform: The transform to apply
    /// - Returns: Transformed array of points
    static func transformPoints(_ points: [CGPoint], with transform: CGAffineTransform) -> [CGPoint] {
        return points.map { $0.applying(transform) }
    }
    
    /// Calculates the length of a path formed by connecting points
    /// - Parameter points: The points forming the path
    /// - Returns: The total length of the path
    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        
        var length: CGFloat = 0
        for i in 1..<points.count {
            let p1 = points[i-1]
            let p2 = points[i]
            length += sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
        }
        
        return length
    }
    
    /// Finds the center point of a set of points
    /// - Parameter points: The input points
    /// - Returns: The centroid (average point)
    static func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }
    
    /// Calculates the bounding box of a set of points
    /// - Parameter points: The input points
    /// - Returns: A CGRect containing all points
    static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
