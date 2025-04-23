// Character.swift
import Foundation
import UIKit

struct Character: Identifiable, Codable {
    let id: String
    let character: String
    let pinyin: String
    let meaning: String
    let strokes: [Stroke]
    let difficulty: Int
    let tags: [String]
    
    // Filenames for resources
    let normalImageName: String
    let traceImageName: String
    let animationImageName: String
    
    // Computed properties
    var strokeCount: Int {
        return strokes.count
    }
}
