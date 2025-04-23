// File: Models/CharacterDataManager.swift
import Foundation
import UIKit // For CGPoint, CGRect, UIImage
import Combine
import CoreGraphics // For CGPoint, CGRect

/**
 Manages loading and accessing Chinese character data.
 Tries to load character data from a JSON file ("characters.json").
 If the JSON file is not found or fails to load, it falls back to using
 hardcoded sample character data for development or testing purposes.
 */
class CharacterDataManager: ObservableObject {
    /// The list of available characters. Published for SwiftUI views.
    @Published var characters: [Character] = []
    /// The currently selected character for display or interaction. Published for SwiftUI views.
    @Published var currentCharacter: Character?
    /// Stores any error message encountered during data loading. Published for UI feedback.
    @Published var errorLoadingData: String? = nil

    // Dependency injection for the data source name (allows testing with different files)
    private let characterDataSourceFilename: String

    /// Initializes the data manager. Attempts to load from JSON first, then falls back to samples.
    /// - Parameter dataSourceFilename: The name of the JSON file (without extension) to load from. Defaults to "characters".
    init(dataSourceFilename: String = "characters") {
        self.characterDataSourceFilename = dataSourceFilename
        // Attempt to load from JSON first
        if !loadCharacterDataFromJSON() {
            // If JSON loading fails, load hardcoded sample data
            print("JSON loading failed or file not found. Loading sample characters.")
            loadSampleCharacters()
            errorLoadingData = nil // Clear any JSON loading error if samples loaded successfully
        }

        // Set the first character as the default current character if any exist and have strokes
        if let firstValidCharacter = characters.first(where: { !$0.strokes.isEmpty }) {
             currentCharacter = firstValidCharacter
             print("CharacterDataManager initialized. Current character: \(currentCharacter?.character ?? "None")")
        } else if !characters.isEmpty {
             // If characters exist but none have strokes, select the first one anyway
             currentCharacter = characters[0]
             print("CharacterDataManager initialized. Current character: \(currentCharacter?.character ?? "None") (Warning: Character may have no strokes defined)")
        } else {
            print("CharacterDataManager initialized, but no characters were loaded.")
            // errorLoadingData might already be set from JSON failure, or set a new one if samples also failed
            if errorLoadingData == nil {
                errorLoadingData = "No character data available (JSON failed and no samples)."
            }
        }
    }

    /// Attempts to load character data from the specified JSON file in the app bundle.
    /// - Returns: `true` if loading was successful, `false` otherwise.
    private func loadCharacterDataFromJSON() -> Bool {
        errorLoadingData = nil // Reset error status
        guard let url = Bundle.main.url(forResource: characterDataSourceFilename, withExtension: "json") else {
            let errorMessage = "Failed to locate '\(characterDataSourceFilename).json' in app bundle."
            print(errorMessage)
            // Don't set errorLoadingData here yet, as we might fall back to samples
            // errorLoadingData = errorMessage
            return false
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loadedCharacters = try decoder.decode([Character].self, from: data)

            if loadedCharacters.isEmpty {
                print("Loaded '\(characterDataSourceFilename).json' but it contained no characters.")
                // errorLoadingData = "Character data file is empty." // Consider this a failure? Or allow empty file?
                return false // Treat empty file as failure for fallback logic
            }

            self.characters = loadedCharacters
            print("Successfully loaded \(characters.count) characters from '\(characterDataSourceFilename).json'.")
            return true // Loading succeeded

        } catch let decodingError as DecodingError {
            let errorMessage = "Failed to decode '\(characterDataSourceFilename).json': \(decodingError)"
            print(errorMessage)
            print(detailedDecodingError(decodingError)) // Log detailed error
            errorLoadingData = "Error reading character data file." // User-friendly error
            return false // Loading failed
        } catch {
            let errorMessage = "An unexpected error occurred while loading '\(characterDataSourceFilename).json': \(error)"
            print(errorMessage)
            errorLoadingData = "Could not load character data." // User-friendly error
            return false // Loading failed
        }
    }

    /// Loads hardcoded sample character data into the `characters` array.
    private func loadSampleCharacters() {
        // --- Sample Character: 口 (kǒu) ---
        // Adjusted coordinates slightly for a more centered appearance in a hypothetical 120x120 box
        let kouStrokes = [
            Stroke(id: UUID(), order: 1, type: .shu, name: "shù",
                   path: [CGPoint(x: 30, y: 20), CGPoint(x: 30, y: 100)], // Vertical left
                   boundingBox: CGRect(x: 25, y: 15, width: 10, height: 90)),
            Stroke(id: UUID(), order: 2, type: .heng, name: "héngzhé", // Combined name
                   path: [CGPoint(x: 30, y: 20), CGPoint(x: 90, y: 20), CGPoint(x: 90, y: 100)], // Top H + Right V
                   boundingBox: CGRect(x: 25, y: 15, width: 70, height: 90)),
            Stroke(id: UUID(), order: 3, type: .heng, name: "héng",
                   path: [CGPoint(x: 30, y: 100), CGPoint(x: 90, y: 100)], // Bottom H
                   boundingBox: CGRect(x: 25, y: 95, width: 70, height: 10))
        ]
        let kouCharacter = Character(
            id: "sample-kou", // Unique ID
            character: "口",
            pinyin: "kǒu",
            meaning: "mouth",
            strokes: kouStrokes,
            difficulty: 1,
            tags: ["HSK1", "basic", "radical"],
            // Assumes images named like 'char_kou_normal', etc. exist in Assets.xcassets
            normalImageName: "char_kou_normal",
            traceImageName: "char_kou_trace",
            animationImageName: "char_kou_anim"
        )

        // --- Sample Character: 日 (rì) ---
        let riStrokes = [
             Stroke(id: UUID(), order: 1, type: .shu, name: "shù",
                    path: [CGPoint(x: 30, y: 20), CGPoint(x: 30, y: 100)], // Left V
                    boundingBox: CGRect(x: 25, y: 15, width: 10, height: 90)),
             Stroke(id: UUID(), order: 2, type: .heng, name: "héngzhé",
                    path: [CGPoint(x: 30, y: 20), CGPoint(x: 90, y: 20), CGPoint(x: 90, y: 100)], // Top H + Right V
                    boundingBox: CGRect(x: 25, y: 15, width: 70, height: 90)),
             Stroke(id: UUID(), order: 3, type: .heng, name: "héng",
                    path: [CGPoint(x: 30, y: 60), CGPoint(x: 90, y: 60)], // Middle H
                    boundingBox: CGRect(x: 25, y: 55, width: 70, height: 10)),
             Stroke(id: UUID(), order: 4, type: .heng, name: "héng",
                    path: [CGPoint(x: 30, y: 100), CGPoint(x: 90, y: 100)], // Bottom H
                    boundingBox: CGRect(x: 25, y: 95, width: 70, height: 10))
        ]
        let riCharacter = Character(
             id: "sample-ri",
             character: "日",
             pinyin: "rì",
             meaning: "sun/day",
             strokes: riStrokes,
             difficulty: 1,
             tags: ["HSK1", "basic", "time"],
             normalImageName: "char_ri_normal",
             traceImageName: "char_ri_trace",
             animationImageName: "char_ri_anim"
        )

        // --- Sample Character: 人 (rén) ---
         let renStrokes = [
             Stroke(id: UUID(), order: 1, type: .pie, name: "piě",
                    path: [CGPoint(x: 60, y: 20), CGPoint(x: 30, y: 100)], // Left falling
                    boundingBox: CGRect(x: 25, y: 15, width: 40, height: 90)),
             Stroke(id: UUID(), order: 2, type: .na, name: "nà",
                    path: [CGPoint(x: 60, y: 20), CGPoint(x: 90, y: 100)], // Right falling
                    boundingBox: CGRect(x: 55, y: 15, width: 40, height: 90))
         ]
         let renCharacter = Character(
             id: "sample-ren",
             character: "人",
             pinyin: "rén",
             meaning: "person",
             strokes: renStrokes,
             difficulty: 1,
             tags: ["HSK1", "basic"],
             normalImageName: "char_ren_normal",
             traceImageName: "char_ren_trace",
             animationImageName: "char_ren_anim"
         )

        // Assign the sample characters to the published array
        self.characters = [kouCharacter, riCharacter, renCharacter]
        print("Loaded \(self.characters.count) sample characters.")
    }

    /// Selects a character by its ID and updates the `currentCharacter`.
    /// - Parameter id: The unique identifier of the character to select.
    func selectCharacter(withId id: String) {
        if let character = characters.first(where: { $0.id == id }) {
            // Only update if the selected character is actually different
            if currentCharacter?.id != character.id {
                 currentCharacter = character
                 print("Selected character: \(character.character)")
            }
        } else {
            print("Warning: Character with ID '\(id)' not found.")
            // Optionally reset currentCharacter to nil or keep the previous one?
            // currentCharacter = nil
        }
    }

    /// Retrieves a UIImage for a given character and image type.
    /// *** Basic Implementation: Assumes images are in Asset Catalog. ***
    /// - Parameters:
    ///   - character: The character for which to get the image.
    ///   - type: The type of image requested (normal, trace, animation).
    /// - Returns: A UIImage instance, or nil if the character or image is not found.
    func getCharacterImage(_ character: Character?, type: CharacterImageType) -> UIImage? {
        guard let character = character else { return nil }

        let imageName: String
        switch type {
        case .normal:
            imageName = character.normalImageName
        case .trace:
            imageName = character.traceImageName
        case .animation:
            // Animation might require different handling (e.g., loading a GIF or image sequence)
            // For now, assume it's a single representative image name like the others.
            imageName = character.animationImageName
        }

        // --- Basic Implementation ---
        // Attempt to load the image from the Asset Catalog using the provided name.
        print("Attempting to load image from Assets: \(imageName)")
        if let image = UIImage(named: imageName) {
            return image
        } else {
            // Return a default system placeholder if the named asset isn't found
            print("Warning: Image '\(imageName)' not found in Asset Catalog. Returning system placeholder.")
            // You might want a custom placeholder image in your assets instead.
            return UIImage(systemName: "photo")
        }
        // --- End Basic Implementation ---
    }

    /// Enum defining the different types of character images used in the app.
    enum CharacterImageType {
        case normal      // Full-color reference image
        case trace       // Grey trace-over image
        case animation   // Stroke order animation image/frames (may need special handling)
    }

    // MARK: - Private Helpers

    /// Provides detailed error information for JSON decoding errors.
    private func detailedDecodingError(_ error: DecodingError) -> String {
        var details = "Decoding Error Details:\n"
        switch error {
        case .typeMismatch(let type, let context):
            details += "Type mismatch for type \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))\nDebug Description: \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            details += "Value not found for type \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))\nDebug Description: \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            details += "Key not found: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))\nDebug Description: \(context.debugDescription)"
        case .dataCorrupted(let context):
            details += "Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))\nDebug Description: \(context.debugDescription)"
        @unknown default:
            details += "Unknown decoding error encountered: \(error.localizedDescription)"
        }
        return details
    }
}
