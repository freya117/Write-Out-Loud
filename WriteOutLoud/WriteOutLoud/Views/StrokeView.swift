// File: Views/StrokeView.swift
import SwiftUI

/**
 Draws a single stroke path, potentially animating its drawing progress.
 */
struct StrokeView: View {
    let stroke: Stroke
    /// Controls the drawing progress (0.0 to 1.0) for static display.
    var animationProgress: CGFloat = 1.0 // Default to fully drawn
    /// If true, animates the drawing progress on appear or when this flag changes.
    var isAnimating: Bool = false
    /// Duration for the drawing animation if isAnimating is true.
    var duration: TimeInterval = 0.5

    /// Internal state to manage the actual animation value, driven by isAnimating flag.
    @State private var internalProgress: CGFloat = 0.0

    var body: some View {
        GeometryReader { geometry in
            // geometry.size is CGSize
            let currentSize: CGSize = geometry.size

            // Create the path using scaled points
            strokePath(in: currentSize) // Pass CGSize to strokePath
                // Apply trimming based on internalProgress
                .trim(from: 0, to: internalProgress)
                // Apply stroke styling
                .stroke(style: StrokeStyle(
                    // Pass CGSize to calculateLineWidth
                    lineWidth: calculateLineWidth(size: currentSize),
                    lineCap: .round,
                    lineJoin: .round
                ))
        }
         // Use appear and onChange to manage the animation based on isAnimating
         .onAppear {
              // Set initial state: 0 if animating starts immediately, full progress otherwise
              internalProgress = isAnimating ? 0.0 : animationProgress
              if isAnimating {
                   // Need a slight delay to ensure the view is ready for animation
                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                       withAnimation(.linear(duration: duration)) {
                           internalProgress = 1.0
                       }
                   }
              }
         }
         // Use new onChange syntax
         .onChange(of: isAnimating) { oldIsAnimating, newIsAnimating in
             handleAnimationChange(isNowAnimating: newIsAnimating)
         }
         .onChange(of: animationProgress) { oldProgress, newStaticProgress in
              // Ensure static progress updates are reflected if isAnimating is false
              if !isAnimating {
                   // Use explicit animation with zero duration for immediate update
                   withAnimation(.linear(duration: 0)) {
                       internalProgress = newStaticProgress
                   }
              }
         }
         .onChange(of: stroke.id) { oldId, newId in
             // Reset state when the stroke itself changes, re-applying current animation state
             handleAnimationChange(isNowAnimating: isAnimating)
         }
    }

    /// Creates the Path object for the stroke, scaled to the given size.
    /// - Parameter size: The target CGSize to scale the path into.
    private func strokePath(in size: CGSize) -> Path {
        // Convert CGSize to CGRect with origin at (0,0)
        let rect = CGRect(origin: .zero, size: size)
        
        // Now pass the CGRect to PathUtils.scalePoints
        let scaledPoints = PathUtils.scalePoints(stroke.path, to: rect)
        
        guard !scaledPoints.isEmpty else { return Path() }
        var path = Path()
        // Handle single point case after scaling
        if scaledPoints.count == 1 {
             path.move(to: scaledPoints[0])
             // Optionally draw a small circle or dot for single points
             path.addArc(center: scaledPoints[0], radius: 1, startAngle: .zero, endAngle: .degrees(360), clockwise: true)
        } else {
             path.move(to: scaledPoints[0])
             for i in 1..<scaledPoints.count {
                 path.addLine(to: scaledPoints[i])
             }
        }
        return path
    }

    /// Calculate dynamic line width based on view size
    /// - Parameter size: The CGSize of the view to base the line width on.
    private func calculateLineWidth(size: CGSize) -> CGFloat { // Expects CGSize
         let baseSize = min(size.width, size.height)
         // Ensure line width is reasonable, adjust multiplier as needed
         return max(2.0, min(15.0, baseSize * 0.03))
    }

    /// Handles changes to the isAnimating state or stroke ID
    private func handleAnimationChange(isNowAnimating: Bool) {
        if isNowAnimating {
            internalProgress = 0.0 // Reset before starting animation
            // Use a slight delay to ensure view is ready for animation after state change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.linear(duration: duration)) {
                    internalProgress = 1.0 // Animate to full
                }
            }
        } else {
             // Stop animation: Jump immediately to the static progress value
             withAnimation(.linear(duration: 0)) {
                  internalProgress = animationProgress
             }
        }
    }
}
