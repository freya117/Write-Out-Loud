// File: Utils/Extensions.swift
import Foundation
import CoreGraphics // For CGRect, CGFloat

// MARK: - CGRect Extension
extension CGRect {
    /// Calculates the length of the diagonal of the rectangle.
    /// - Returns: The length of the diagonal as a CGFloat. Returns 0 if width or height is negative.
    func diagonal() -> CGFloat {
        guard width >= 0, height >= 0 else { return 0.0 } // Handle invalid rects
        return sqrt(pow(width, 2) + pow(height, 2))
    }
}

// MARK: - Collection Extension (Safe Subscript)
// Keep this useful extension here as well
extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

