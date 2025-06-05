// File: Models/UserManager.swift
import Foundation
import Combine

class UserManager: ObservableObject {
    // Published properties for reactive UI updates
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?
    @Published var isLoading: Bool = false
    @Published var showLoginOverlay: Bool = false
    
    // User defaults keys
    private let currentUserKey = "currentUser"
    private let usersKey = "users"
    
    // In-memory cache of registered users
    private var users: [String: User] = [:]
    
    // Private variables
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadUsers()
        loadCurrentUser()
        
        // Add test account if it doesn't exist
        addTestAccount()
    }
    
    // MARK: - Test Account
    
    private func addTestAccount() {
        let testEmail = "test@example.com"
        let testPassword = "password123"
        
        // Check if test account already exists
        if users[testEmail] == nil {
            // Create test user with some progress data
            let testUser = User(
                id: "test-user-id",
                username: "TestUser",
                email: testEmail,
                characterProgress: [
                    "ren": CharacterProgress(characterId: "ren", attempts: 10, bestAccuracy: 0.92, lastPracticed: Date()),
                    "ri": CharacterProgress(characterId: "ri", attempts: 8, bestAccuracy: 0.85, lastPracticed: Date().addingTimeInterval(-86400)),
                    "kou": CharacterProgress(characterId: "kou", attempts: 5, bestAccuracy: 0.78, lastPracticed: Date().addingTimeInterval(-172800))
                ],
                streakDays: 7,
                lastActiveDate: Date(),
                completedLessons: ["lesson1", "lesson2", "lesson3"]
            )
            
            // Add to users dictionary
            users[testEmail] = testUser
            
            // Save users to UserDefaults
            saveUsers()
            
            print("Test account created: \nemail: \(testEmail)\npassword: \(testPassword)")
        }
    }
    
    // MARK: - Authentication Methods
    
    func toggleLoginOverlay() {
        showLoginOverlay.toggle()
    }
    
    func hideLoginOverlay() {
        showLoginOverlay = false
    }
    
    func register(username: String, email: String, password: String) -> Bool {
        // Basic validation
        if username.isEmpty || email.isEmpty || password.isEmpty {
            authError = "All fields are required"
            return false
        }
        
        // Validate email format
        if !isValidEmail(email) {
            authError = "Please enter a valid email address"
            return false
        }
        
        // Password strength check
        if password.count < 6 {
            authError = "Password must be at least 6 characters"
            return false
        }
        
        // Check if username or email already exists
        if users.values.contains(where: { $0.username == username }) {
            authError = "Username already exists"
            return false
        }
        
        if users.values.contains(where: { $0.email == email }) {
            authError = "Email already exists"
            return false
        }
        
        // Create new user
        let newUser = User(
            id: UUID().uuidString,
            username: username,
            email: email
        )
        
        // Add to users dictionary with email as key for easier lookup
        users[email] = newUser
        
        // Save users to UserDefaults
        saveUsers()
        
        // Log in the new user
        currentUser = newUser
        isAuthenticated = true
        saveCurrentUser()
        
        return true
    }
    
    func login(email: String, password: String) -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        // Basic validation
        if email.isEmpty || password.isEmpty {
            authError = "Email and password are required"
            return false
        }
        
        // Find user with matching email
        if let user = users[email] {
            currentUser = user
            isAuthenticated = true
            showLoginOverlay = false
            saveCurrentUser()
            return true
        } else {
            authError = "Invalid email or password"
            return false
        }
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: currentUserKey)
    }
    
    // MARK: - User Data Methods
    
    func updateUserProgress(characterId: String, accuracy: Double) {
        // If not authenticated, just return without updating
        guard isAuthenticated, let user = currentUser else { return }
        
        var updatedUser = user
        updatedUser.updateCharacterProgress(characterId: characterId, accuracy: accuracy)
        currentUser = updatedUser
        
        // Update in users dictionary
        users[user.email] = updatedUser
        
        // Save changes
        saveUsers()
        saveCurrentUser()
    }
    
    func completeLesson(lessonId: String) {
        // If not authenticated, just return without updating
        guard isAuthenticated, let user = currentUser else { return }
        
        var updatedUser = user
        updatedUser.completeLesson(lessonId: lessonId)
        currentUser = updatedUser
        
        // Update in users dictionary
        users[user.email] = updatedUser
        
        // Save changes
        saveUsers()
        saveCurrentUser()
    }
    
    // MARK: - Helper Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    // MARK: - Persistence Methods
    
    private func saveUsers() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: usersKey)
        }
    }
    
    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let decoded = try? JSONDecoder().decode([String: User].self, from: data) {
            users = decoded
        }
    }
    
    private func saveCurrentUser() {
        if let user = currentUser,
           let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: currentUserKey)
        }
    }
    
    private func loadCurrentUser() {
        if let data = UserDefaults.standard.data(forKey: currentUserKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = user
            isAuthenticated = true
        }
    }
} 