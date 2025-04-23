// Stroke.swift
import Foundation
import UIKit // For CGPoint, CGRect
import CoreGraphics // Also provides CGPoint, CGRect

/**
 Represents a single stroke within a Chinese character.
 Includes its order, type, expected name, ideal path, and bounding box.
 Conforms to Identifiable and Codable for use in SwiftUI lists and JSON parsing.
 */
struct Stroke: Identifiable, Codable {
    /// Unique identifier for the stroke instance. Defaults to a new UUID.
    let id: UUID
    /// The 1-based order of this stroke within the character's sequence.
    let order: Int
    /// The basic classification of the stroke (e.g., horizontal, vertical).
    let type: StrokeType
    /// The specific Pinyin name expected to be vocalized for this stroke (e.g., "héng", "shùgōu").
    /// This might differ from `type.displayName` for compound strokes.
    let name: String
    /// An array of CGPoint values defining the key points of the ideal stroke path.
    /// Used for drawing reference animations and calculating accuracy.
    let path: [CGPoint]
    /// The bounding rectangle enclosing the ideal stroke path.
    /// Useful for scaling and positioning calculations.
    let boundingBox: CGRect

    // MARK: - CodingKeys
    /// Maps struct properties to JSON keys during encoding/decoding.
    enum CodingKeys: String, CodingKey {
        case id, order, type, name, path, boundingBox
    }

    // MARK: - Initializers
    /// Default initializer allowing manual creation of Stroke instances.
    init(id: UUID = UUID(), order: Int, type: StrokeType, name: String, path: [CGPoint], boundingBox: CGRect) {
        self.id = id
        self.order = order
        self.type = type
        self.name = name // Ensure JSON/data source provides the correct vocalization target name
        self.path = path
        self.boundingBox = boundingBox
    }

    /// Initializer for decoding a Stroke instance from JSON data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode properties, providing fallbacks or error handling where necessary
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID() // Use existing UUID or generate a new one
        order = try container.decode(Int.self, forKey: .order)
        type = try container.decode(StrokeType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)

        // Decode path points from an array of [x, y] number arrays in JSON
        let pathArrays = try container.decode([[Double]].self, forKey: .path)
        path = pathArrays.map { CGPoint(x: CGFloat($0[0]), y: CGFloat($0[1])) }

        // Decode bounding box from an [x, y, width, height] number array in JSON
        // *** Corrected the syntax here: removed extra ']' ***
        let boundingBoxArray = try container.decode([Double].self, forKey: .boundingBox)
        guard boundingBoxArray.count == 4 else {
            // Throw an error if the bounding box data is malformed
            throw DecodingError.dataCorruptedError(forKey: .boundingBox, in: container,
                                                   debugDescription: "Bounding box array must contain exactly 4 values (x, y, width, height). Found \(boundingBoxArray.count).")
        }
        boundingBox = CGRect(x: CGFloat(boundingBoxArray[0]),
                             y: CGFloat(boundingBoxArray[1]),
                             width: CGFloat(boundingBoxArray[2]),
                             height: CGFloat(boundingBoxArray[3]))
    }

    // MARK: - Encodable Conformance
    /// Encodes the Stroke instance into JSON format.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(order, forKey: .order)
        try container.encode(type, forKey: .type) // Encodes the rawValue (String) of the enum
        try container.encode(name, forKey: .name)

        // Encode path points as an array of [x, y] number arrays
        let pathArrays = path.map { [Double($0.x), Double($0.y)] }
        try container.encode(pathArrays, forKey: .path)

        // Encode bounding box as an [x, y, width, height] number array
        let boundingBoxArray = [Double(boundingBox.origin.x), Double(boundingBox.origin.y), Double(boundingBox.width), Double(boundingBox.height)]
        try container.encode(boundingBoxArray, forKey: .boundingBox)
    }
}

