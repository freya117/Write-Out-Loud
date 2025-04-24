// File: Models/Character.swift
// VERSION: Added explicit strokeCount property

import Foundation
import UIKit // For CGPoint, CGRect (if used in Stroke)
import CoreGraphics // Also provides CGPoint, CGRect

struct Character: Identifiable, Codable, Equatable {
    let id: String
    let character: String
    let pinyin: String
    let meaning: String
    let strokeCount: Int // Added explicit property
    let strokes: [Stroke] // Assuming Stroke is Codable and Equatable

    // Filenames for resources
    let normalImageName: String
    let traceImageName: String
    let animationImageName: String // GIF base name

    // Computed property removed, using stored property now

    // MARK: - CodingKeys (Adjusted)
    enum CodingKeys: String, CodingKey {
        case id
        case character
        case pinyin
        case meaning
        case strokeCount // Added
        case strokes
        case normalImageName
        case traceImageName
        case animationImageName
    }

    // MARK: - Initializer (Adjusted)
    init(id: String, character: String, pinyin: String, meaning: String, strokeCount: Int, strokes: [Stroke], normalImageName: String, traceImageName: String, animationImageName: String) {
        self.id = id
        self.character = character
        self.pinyin = pinyin
        self.meaning = meaning
        self.strokeCount = strokeCount // Added
        self.strokes = strokes
        self.normalImageName = normalImageName
        self.traceImageName = traceImageName
        self.animationImageName = animationImageName
    }

     // MARK: - Decoder Initializer (Adjusted)
     init(from decoder: Decoder) throws {
         let container = try decoder.container(keyedBy: CodingKeys.self)
         id = try container.decode(String.self, forKey: .id)
         character = try container.decode(String.self, forKey: .character)
         pinyin = try container.decode(String.self, forKey: .pinyin)
         meaning = try container.decode(String.self, forKey: .meaning)
         strokeCount = try container.decode(Int.self, forKey: .strokeCount) // Decode strokeCount
         strokes = try container.decode([Stroke].self, forKey: .strokes)
         normalImageName = try container.decode(String.self, forKey: .normalImageName)
         traceImageName = try container.decode(String.self, forKey: .traceImageName)
         animationImageName = try container.decode(String.self, forKey: .animationImageName)

         // Optional: Add validation if needed
         // guard strokeCount == strokes.count else {
         //     throw DecodingError.dataCorruptedError(forKey: .strokeCount, in: container, debugDescription: "Explicit strokeCount (\(strokeCount)) does not match actual number of strokes (\(strokes.count)) for character \(character)")
         // }
     }

     // MARK: - Encoder (Adjusted)
     func encode(to encoder: Encoder) throws {
         var container = encoder.container(keyedBy: CodingKeys.self)
         try container.encode(id, forKey: .id)
         try container.encode(character, forKey: .character)
         try container.encode(pinyin, forKey: .pinyin)
         try container.encode(meaning, forKey: .meaning)
         try container.encode(strokeCount, forKey: .strokeCount) // Encode strokeCount
         try container.encode(strokes, forKey: .strokes)
         try container.encode(normalImageName, forKey: .normalImageName)
         try container.encode(traceImageName, forKey: .traceImageName)
         try container.encode(animationImageName, forKey: .animationImageName)
     }


    // MARK: - Equatable Conformance
    static func == (lhs: Character, rhs: Character) -> Bool {
        return lhs.id == rhs.id // Comparing by ID is usually sufficient
    }

    // MARK: - Empty Character Placeholder (Adjusted)
    /// Provides an empty Character instance for default initialization or placeholders.
    static var empty: Character {
        .init(id: "", character: "", pinyin: "", meaning: "", strokeCount: 0, strokes: [], normalImageName: "", traceImageName: "", animationImageName: "")
    }
}
