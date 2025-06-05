// File: Models/User.swift
import Foundation
import Combine

// Struct to represent character practice progress
struct CharacterProgress: Codable, Identifiable, Equatable {
    var id: String { characterId }
    let characterId: String
    var attempts: Int
    var bestAccuracy: Double
    var lastPracticed: Date
    
    init(characterId: String, attempts: Int = 0, bestAccuracy: Double = 0, lastPracticed: Date = Date()) {
        self.characterId = characterId
        self.attempts = attempts
        self.bestAccuracy = bestAccuracy
        self.lastPracticed = lastPracticed
    }
}

// Main User model
class User: ObservableObject, Codable {
    @Published var id: String
    @Published var username: String
    @Published var email: String
    @Published var characterProgress: [String: CharacterProgress] // Map of character ID to progress
    @Published var streakDays: Int
    @Published var lastActiveDate: Date?
    @Published var completedLessons: Set<String>
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, characterProgress, streakDays, lastActiveDate, completedLessons
    }
    
    init(id: String = UUID().uuidString, 
         username: String = "", 
         email: String = "", 
         characterProgress: [String: CharacterProgress] = [:], 
         streakDays: Int = 0,
         lastActiveDate: Date? = nil,
         completedLessons: Set<String> = []) {
        self.id = id
        self.username = username
        self.email = email
        self.characterProgress = characterProgress
        self.streakDays = streakDays
        self.lastActiveDate = lastActiveDate
        self.completedLessons = completedLessons
    }
    
    // Add a new character progress or update existing one
    func updateCharacterProgress(characterId: String, accuracy: Double) {
        let now = Date()
        
        if var existing = characterProgress[characterId] {
            existing.attempts += 1
            existing.lastPracticed = now
            if accuracy > existing.bestAccuracy {
                existing.bestAccuracy = accuracy
            }
            characterProgress[characterId] = existing
        } else {
            characterProgress[characterId] = CharacterProgress(
                characterId: characterId,
                attempts: 1,
                bestAccuracy: accuracy,
                lastPracticed: now
            )
        }
        
        updateStreak(date: now)
    }
    
    // Update streak based on current date
    private func updateStreak(date: Date = Date()) {
        let calendar = Calendar.current
        
        if let lastDate = lastActiveDate {
            let isYesterday = calendar.isDateInYesterday(lastDate)
            let isToday = calendar.isDateInToday(lastDate)
            
            if isToday {
                // Already logged in today, no streak change
            } else if isYesterday {
                // Consecutive day, increase streak
                streakDays += 1
            } else {
                // Streak broken
                streakDays = 1
            }
        } else {
            // First login
            streakDays = 1
        }
        
        lastActiveDate = date
    }
    
    // Mark a lesson as completed
    func completeLesson(lessonId: String) {
        completedLessons.insert(lessonId)
    }
    
    // MARK: - Codable conformance
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        characterProgress = try container.decode([String: CharacterProgress].self, forKey: .characterProgress)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        lastActiveDate = try container.decodeIfPresent(Date.self, forKey: .lastActiveDate)
        completedLessons = try container.decode(Set<String>.self, forKey: .completedLessons)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(characterProgress, forKey: .characterProgress)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encode(lastActiveDate, forKey: .lastActiveDate)
        try container.encode(completedLessons, forKey: .completedLessons)
    }
} 