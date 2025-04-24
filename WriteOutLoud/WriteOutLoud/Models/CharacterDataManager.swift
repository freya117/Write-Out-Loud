// File: Models/CharacterDataManager.swift
// VERSION: Updated sample data to include strokeCount

import Foundation
import UIKit // For CGPoint, CGRect, UIImage
import Combine
import CoreGraphics // For CGPoint, CGRect

class CharacterDataManager: ObservableObject {
    @Published var characters: [Character] = []
    @Published var currentCharacter: Character?
    @Published var errorLoadingData: String? = nil
    private let characterDataSourceFilename: String

    init(dataSourceFilename: String = "characters") {
        self.characterDataSourceFilename = dataSourceFilename

        // Try loading from JSON FIRST
        if !loadCharacterDataFromJSON() {
            // If JSON fails, THEN load samples
            print("JSON loading failed or file not found. Loading sample characters.")
            loadSampleCharacters() // Uses updated Character init
            if !characters.isEmpty {
                 errorLoadingData = nil
            } else {
                 errorLoadingData = "Failed to load character data from JSON and sample data is unavailable."
            }
        } else {
             errorLoadingData = nil
        }


        // Set initial character
        if let firstValidCharacter = characters.first(where: { !$0.strokes.isEmpty }) {
             if let firstIndex = characters.firstIndex(of: firstValidCharacter) {
                 currentCharacter = firstValidCharacter
             } else {
                 currentCharacter = firstValidCharacter
             }
        } else if !characters.isEmpty {
             currentCharacter = characters[0]
        } else {
            print("CharacterDataManager initialized, but no characters were loaded.")
            if errorLoadingData == nil { errorLoadingData = "No character data available." }
        }
        print("CharacterDataManager initialized. Loaded \(characters.count) characters. Current character: \(currentCharacter?.character ?? "None"). Error: \(errorLoadingData ?? "None")")
    }

    private func loadCharacterDataFromJSON() -> Bool {
        print("Attempting to load character data from JSON: \(characterDataSourceFilename).json")
        guard let url = Bundle.main.url(forResource: characterDataSourceFilename, withExtension: "json") else {
            print("Error: \(characterDataSourceFilename).json not found in bundle.")
            self.errorLoadingData = "Data file not found."
            return false
        }

        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Uses updated Character Codable which expects strokeCount
            let loadedCharacters = try decoder.decode([Character].self, from: jsonData)

            DispatchQueue.main.async {
                self.characters = loadedCharacters
                print("Successfully loaded and decoded \(loadedCharacters.count) characters from JSON. IDs: \(loadedCharacters.map { $0.id })")

                if self.currentCharacter == nil {
                   if let firstValidCharacter = self.characters.first(where: { !$0.strokes.isEmpty }) {
                        self.currentCharacter = firstValidCharacter
                   } else if !self.characters.isEmpty {
                        self.currentCharacter = self.characters[0]
                   }
                }
                self.errorLoadingData = nil
                if self.currentCharacter == nil && !self.characters.isEmpty {
                    self.currentCharacter = self.characters[0]
                }
            }
            return true
        } catch let decodingError as DecodingError {
            let detailedError = detailedDecodingError(decodingError)
            print("Error decoding \(characterDataSourceFilename).json: \(detailedError)")
            DispatchQueue.main.async {
                self.errorLoadingData = "Error decoding character data: \(detailedError)"
                self.characters = []
                self.currentCharacter = nil
            }
            return false
        } catch {
            print("Error loading data from \(characterDataSourceFilename).json: \(error)")
             DispatchQueue.main.async {
                self.errorLoadingData = "Failed to load character data: \(error.localizedDescription)"
                self.characters = []
                self.currentCharacter = nil
            }
            return false
        }
    }

    // Load Sample Characters (Added strokeCount to initializers)
    private func loadSampleCharacters() {
        print("Loading sample characters...")

        // Sample "口"
        let sampleKouStrokes = [
             Stroke(order: 1, type: .shu, name: "竖", path: [CGPoint(x: 100, y: 100), CGPoint(x: 100, y: 400)], boundingBox: CGRect(x: 100, y: 100, width: 0, height: 300), startTime: 0.0, endTime: 0.3),
             Stroke(order: 2, type: .hengzhe, name: "横折", path: [CGPoint(x: 100, y: 100), CGPoint(x: 400, y: 100), CGPoint(x: 400, y: 400)], boundingBox: CGRect(x: 100, y: 100, width: 300, height: 300), startTime: 0.35, endTime: 0.7),
             Stroke(order: 3, type: .heng, name: "横", path: [CGPoint(x: 100, y: 400), CGPoint(x: 400, y: 400)], boundingBox: CGRect(x: 100, y: 400, width: 300, height: 0), startTime: 0.75, endTime: 1.0)
         ]
        // *** Added strokeCount: 3 ***
        let sampleKou = Character(id: "口", character: "口", pinyin: "kǒu", meaning: "mouth", strokeCount: 3, strokes: sampleKouStrokes, normalImageName: "kou_normal", traceImageName: "kou_trace", animationImageName: "kou_order")

        // Sample "人"
        let sampleRenStrokes = [
             Stroke(order: 1, type: .pie, name: "撇", path: [CGPoint(x: 250, y: 100), CGPoint(x: 100, y: 400)], boundingBox: CGRect(x: 100, y: 100, width: 150, height: 300), startTime: 0.0, endTime: 0.45),
             Stroke(order: 2, type: .na, name: "捺", path: [CGPoint(x: 250, y: 100), CGPoint(x: 400, y: 400)], boundingBox: CGRect(x: 250, y: 100, width: 150, height: 300), startTime: 0.5, endTime: 1.0)
         ]
         // *** Added strokeCount: 2 ***
         let sampleRen = Character(id: "人", character: "人", pinyin: "rén", meaning: "person", strokeCount: 2, strokes: sampleRenStrokes, normalImageName: "ren_normal", traceImageName: "ren_trace", animationImageName: "ren_order")

        // Sample "日"
        let sampleRiStrokes = [
            Stroke(order: 1, type: .shu, name: "竖", path: [CGPoint(x: 100.0, y: 100.0), CGPoint(x: 100.0, y: 400.0)], boundingBox: CGRect(x:100.0, y:100.0, width:0.0, height:300.0), startTime: 0.0, endTime: 0.2),
            Stroke(order: 2, type: .hengzhe, name: "横折", path: [CGPoint(x: 100.0, y: 100.0), CGPoint(x: 400.0, y: 100.0), CGPoint(x: 400.0, y: 400.0)], boundingBox: CGRect(x:100.0, y:100.0, width:300.0, height:300.0), startTime: 0.25, endTime: 0.55),
            Stroke(order: 3, type: .heng, name: "横", path: [CGPoint(x: 100.0, y: 250.0), CGPoint(x: 400.0, y: 250.0)], boundingBox: CGRect(x:100.0, y:250.0, width:300.0, height:0.0), startTime: 0.6, endTime: 0.8),
            Stroke(order: 4, type: .heng, name: "横", path: [CGPoint(x: 100.0, y: 400.0), CGPoint(x: 400.0, y: 400.0)], boundingBox: CGRect(x:100.0, y:400.0, width:300.0, height:0.0), startTime: 0.85, endTime: 1.0)
        ]
         // *** Added strokeCount: 4 ***
        let sampleRi = Character(id: "日", character: "日", pinyin: "rì", meaning: "sun/day", strokeCount: 4, strokes: sampleRiStrokes, normalImageName: "ri_normal", traceImageName: "ri_trace", animationImageName: "ri_order")


         DispatchQueue.main.async {
             self.characters = [sampleKou, sampleRen, sampleRi]
             if self.currentCharacter == nil {
                 if let firstValidCharacter = self.characters.first(where: { !$0.strokes.isEmpty }) {
                    self.currentCharacter = firstValidCharacter
                 } else if !self.characters.isEmpty {
                    self.currentCharacter = self.characters[0]
                 }
             }
             print("Loaded \(self.characters.count) sample characters.")
         }
    }


    // Provides detailed error information for decoding errors (Keep this)
    private func detailedDecodingError(_ error: DecodingError) -> String {
        var message = "Decoding Error: "
        switch error {
        case .typeMismatch(let type, let context):
            message += "Type mismatch for type '\(type)'."
            message += " Context: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            message += "Value not found for type '\(type)'."
            message += " Context: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            message += "Key not found: '\(key.stringValue)'."
            message += " Context: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
        case .dataCorrupted(let context):
            message += "Data corrupted."
            message += " Context: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
        @unknown default:
            message += error.localizedDescription
        }
        return message
    }


    func selectCharacter(withId id: String) {
         DispatchQueue.main.async {
             if let character = self.characters.first(where: { $0.id == id }) {
                 self.currentCharacter = character
                 print("Selected character: \(character.character)")
             } else {
                 print("Character with ID \(id) not found.")
             }
         }
     }

    // MARK: - Image Loading Function (Keep existing)
    func getCharacterImage(_ character: Character?, type: CharacterImageType) -> UIImage? {
        guard let character = character else { return nil }
        let imageName: String
        switch type {
        case .normal: imageName = character.normalImageName
        case .trace: imageName = character.traceImageName
        case .animation: imageName = character.animationImageName // GIF name
        }
        guard !imageName.isEmpty else { return UIImage(systemName: "questionmark.square.dashed") }
        if let image = UIImage(named: imageName) {
            return image
        } else {
            print("Error: Image named '\(imageName)' NOT FOUND in Asset Catalog.")
            return UIImage(systemName: "photo.fill")
        }
    }

    // MARK: - GIF Loading Function (Keep existing)
    func getCharacterGifData(_ character: Character?) -> Data? {
        guard let character = character else {
            return nil
        }
        let gifName = character.animationImageName
        guard !gifName.isEmpty else {
            print("Warning: animationImageName is empty for character '\(character.character)'. Cannot load GIF.")
            return nil
        }
        guard let url = Bundle.main.url(forResource: gifName, withExtension: "gif") else {
            print("Error: GIF file named '\(gifName).gif' NOT FOUND in the application bundle. Make sure it's added to the project and target.")
            return nil
        }
        do {
            let gifData = try Data(contentsOf: url)
            return gifData
        } catch {
            print("Error reading data from GIF file '\(gifName).gif': \(error)")
            return nil
        }
    }

    /// Enum defining the different types of character images used in the app.
    enum CharacterImageType {
        case normal, trace, animation
    }
} // End of class CharacterDataManager
