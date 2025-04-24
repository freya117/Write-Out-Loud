// File: Models/Stroke.swift
import Foundation
import UIKit // For CGPoint, CGRect
import CoreGraphics // Also provides CGPoint, CGRect

/**
 Represents a single stroke within a Chinese character.
 Includes its order, type, name, path, bounding box, and timing info.
 Conforms to Identifiable, Codable, and Equatable.
 */
struct Stroke: Identifiable, Codable, Equatable {
    /// Unique identifier for the stroke instance. Defaults to a new UUID.
    let id: UUID
    /// The 1-based order of this stroke within the character's sequence.
    let order: Int
    /// The basic classification of the stroke.
    let type: StrokeType
    /// The specific Pinyin name expected to be vocalized for this stroke.
    let name: String
    /// An array of CGPoint values defining the key points of the ideal stroke path.
    let path: [CGPoint]
    /// The bounding rectangle enclosing the ideal stroke path.
    let boundingBox: CGRect
    /// The start time of the stroke within a reference animation/timing sequence (in seconds).
    let startTime: Double
    /// The end time of the stroke within a reference animation/timing sequence (in seconds).
    let endTime: Double

    // MARK: - CodingKeys (Ensure all properties are included)
    enum CodingKeys: String, CodingKey {
        case id // Optional: Can let Codable handle default UUID or decode if present
        case order
        case type // Maps JSON "type" to Swift 'type'
        case name // Maps JSON "name" to Swift 'name'
        case path
        case boundingBox
        case startTime // Added
        case endTime   // Added
    }

    // MARK: - Initializers
    /// Default initializer allowing manual creation of Stroke instances.
    init(id: UUID = UUID(), order: Int, type: StrokeType, name: String, path: [CGPoint], boundingBox: CGRect, startTime: Double, endTime: Double) {
        self.id = id
        self.order = order
        self.type = type
        self.name = name
        self.path = path
        self.boundingBox = boundingBox
        self.startTime = startTime
        self.endTime = endTime
    }

    /// Initializer for decoding a Stroke instance from JSON data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode properties, providing fallbacks or error handling where necessary
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        order = try container.decode(Int.self, forKey: .order)
        type = try container.decode(StrokeType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        startTime = try container.decode(Double.self, forKey: .startTime)
        endTime = try container.decode(Double.self, forKey: .endTime)

        // Decode path points
        let pathArrays = try container.decode([[Double]].self, forKey: .path)
        path = pathArrays.map { CGPoint(x: CGFloat($0[0]), y: CGFloat($0[1])) }

        // Decode bounding box
        // *** CORRECTED THIS LINE ***
        let boundingBoxArray = try container.decode([Double].self, forKey: .boundingBox) // Removed extra ']'
        // *** END CORRECTION ***

        guard boundingBoxArray.count == 4 else {
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
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)

        // Encode path points
        let pathArrays = path.map { [Double($0.x), Double($0.y)] }
        try container.encode(pathArrays, forKey: .path)

        // Encode bounding box
        let boundingBoxArray = [Double(boundingBox.origin.x), Double(boundingBox.origin.y), Double(boundingBox.width), Double(boundingBox.height)]
        try container.encode(boundingBoxArray, forKey: .boundingBox)
    }

    // MARK: - Equatable Conformance
    static func == (lhs: Stroke, rhs: Stroke) -> Bool {
        // Compare by ID is usually sufficient, but include other relevant properties if needed
        return lhs.id == rhs.id &&
               lhs.order == rhs.order &&
               lhs.type == rhs.type // Add other comparisons if strict equality needed
    }
}
