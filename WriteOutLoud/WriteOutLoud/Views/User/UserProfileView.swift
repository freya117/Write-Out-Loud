import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var characterDataManager: CharacterDataManager
    @State private var showingLogoutConfirmation = false
    @State private var showingLoginView = false
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    @State private var dailyGoal = 10 // Default daily goal (minutes)
    
    // Demo user for non-authenticated preview
    private let demoUser = User(
        id: "demo",
        username: "Demo User",
        email: "demo@example.com",
        characterProgress: [
            "ren": CharacterProgress(characterId: "ren", attempts: 5, bestAccuracy: 0.85, lastPracticed: Date()),
            "ri": CharacterProgress(characterId: "ri", attempts: 3, bestAccuracy: 0.7, lastPracticed: Date().addingTimeInterval(-86400)),
            "kou": CharacterProgress(characterId: "kou", attempts: 2, bestAccuracy: 0.6, lastPracticed: Date().addingTimeInterval(-172800))
        ],
        streakDays: 3,
        lastActiveDate: Date(),
        completedLessons: ["lesson1", "lesson2"]
    )
    
    // Dummy data for UI demonstration
    private let achievements = [
        Achievement(id: "first_character", title: "First Character", description: "Complete your first character", icon: "star.fill", isUnlocked: true),
        Achievement(id: "five_streak", title: "5-Day Streak", description: "Practice for 5 consecutive days", icon: "flame.fill", isUnlocked: true),
        Achievement(id: "ten_characters", title: "Character Collection", description: "Learn 10 different characters", icon: "character.book.closed.fill", isUnlocked: false),
        Achievement(id: "perfect_score", title: "Perfect Score", description: "Get 100% accuracy on a character", icon: "checkmark.seal.fill", isUnlocked: false)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 25) {
                        // User header with edit button
                        ZStack(alignment: .topTrailing) {
                            userHeader(isDemo: !userManager.isAuthenticated)
                            
                            if userManager.isAuthenticated {
                                Button(action: {
                                    showingEditProfile = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                        .padding()
                                }
                            }
                        }
                        
                        // Tab selector for different profile sections
                        Picker("Profile Sections", selection: $selectedTab) {
                            Text("Stats").tag(0)
                            Text("Progress").tag(1)
                            Text("Achievements").tag(2)
                            Text("Goals").tag(3)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // Content based on selected tab
                        switch selectedTab {
                        case 0:
                            statsSection(isDemo: !userManager.isAuthenticated)
                        case 1:
                            progressSection(isDemo: !userManager.isAuthenticated)
                        case 2:
                            achievementsSection
                        case 3:
                            goalsSection(isDemo: !userManager.isAuthenticated)
                        default:
                            statsSection(isDemo: !userManager.isAuthenticated)
                        }
                        
                        Divider()
                            .padding(.vertical)
                        
                        // Settings and Logout buttons
                        if userManager.isAuthenticated {
                            VStack(spacing: 15) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    HStack {
                                        Image(systemName: "gear")
                                            .foregroundColor(.primary)
                                        Text("Settings")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showingLogoutConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundColor(.red)
                                        Text("Logout")
                                            .foregroundColor(.red)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Login button for non-authenticated users
                            Button(action: {
                                userManager.toggleLoginOverlay()
                            }) {
                                HStack {
                                    Image(systemName: "person.fill.badge.plus")
                                        .foregroundColor(.blue)
                                    Text("Sign In / Create Account")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Login overlay for non-authenticated users - only show when showLoginOverlay is true
                if !userManager.isAuthenticated && userManager.showLoginOverlay {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        VStack(spacing: 15) {
                            Text("Sign in to access your profile")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text("Track your progress, earn achievements, and more")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                
                            HStack(spacing: 15) {
                                Button(action: {
                                    showingLoginView = true
                                }) {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showingLoginView = true
                                }) {
                                    Text("Create Account")
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.top, 5)
                            
                            Button(action: {
                                userManager.hideLoginOverlay()
                            }) {
                                Text("Continue Without Login")
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.4))
                    .edgesIgnoringSafeArea(.all)
                }
            }
            .navigationTitle(userManager.isAuthenticated ? "Your Profile" : "Profile")
            .toolbar {
                if userManager.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            userManager.toggleLoginOverlay()
                        }) {
                            Image(systemName: "person.circle")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLoginView) {
                LoginView()
                    .environmentObject(userManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(userManager)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(userManager)
            }
            .alert(isPresented: $showingLogoutConfirmation) {
                Alert(
                    title: Text("Logout"),
                    message: Text("Are you sure you want to logout?"),
                    primaryButton: .destructive(Text("Logout")) {
                        userManager.logout()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Good for iPad consistency
    }
    
    // Benefit row for non-authenticated users
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // User header section
    private func userHeader(isDemo: Bool) -> some View {
        VStack(spacing: 15) {
            // User avatar (placeholder circle)
            Circle()
                .fill(Color.blue)
                .frame(width: 100, height: 100)
                .overlay(
                    Text(String((isDemo ? demoUser.username : userManager.currentUser?.username ?? "User").prefix(1).uppercased()))
                        .foregroundColor(.white)
                        .font(.system(size: 40, weight: .bold))
                )

            // Username
            Text(isDemo ? demoUser.username : userManager.currentUser?.username ?? "User")
                .font(.title)
                .fontWeight(.bold)

            // Email
            Text(isDemo ? demoUser.email : userManager.currentUser?.email ?? "No email provided")
                .font(.subheadline)
                .foregroundColor(.secondary)
                
            // Membership status
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text(isDemo ? "Demo Account" : "Active Member")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
    }

    // Stats section with cards
    private func statsSection(isDemo: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Stats")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 15) {
                // Days streak card
                statsCard(
                    title: "Streak",
                    value: "\(isDemo ? demoUser.streakDays : userManager.currentUser?.streakDays ?? 0) days",
                    icon: "flame.fill",
                    color: .orange
                )

                // Characters practiced
                statsCard(
                    title: "Characters",
                    value: "\(isDemo ? demoUser.characterProgress.count : userManager.currentUser?.characterProgress.count ?? 0) learned",
                    icon: "character.book.closed.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            HStack(spacing: 15) {
                // Lessons completed
                statsCard(
                    title: "Lessons",
                    value: "\(isDemo ? demoUser.completedLessons.count : userManager.currentUser?.completedLessons.count ?? 0) completed",
                    icon: "book.fill",
                    color: .blue
                )
                
                // Average accuracy
                statsCard(
                    title: "Avg. Accuracy",
                    value: "\(calculateAverageAccuracy(isDemo: isDemo))%",
                    icon: "checkmark.circle.fill",
                    color: .purple
                )
            }
            .padding(.horizontal)
            
            // Weekly activity chart
            VStack(alignment: .leading) {
                Text("Weekly Activity")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(Double.random(in: 0.2...1.0)))
                                .frame(height: CGFloat(Int.random(in: 10...80)))
                            Text(weekdayLetter(for: day))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 100)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // Single stat card
    private func statsCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // Learning progress section
    private func progressSection(isDemo: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Learning Progress")
                .font(.headline)
                .padding(.horizontal)

            let progressMap = isDemo ? demoUser.characterProgress : userManager.currentUser?.characterProgress ?? [:]
            
            if !progressMap.isEmpty {
                ForEach(progressMap.values.sorted(by: { $0.lastPracticed > $1.lastPracticed })) { item in
                    characterProgressRow(progress: item)
                }
                
                // Add a "View All" button if there are many characters
                if progressMap.count > 5 {
                    Button(action: {
                        // Action to view all characters
                    }) {
                        Text("View All Characters")
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 15) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No characters practiced yet")
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        // Action to start practicing
                    }) {
                        Text("Start Practicing")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // Achievements section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Achievements")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(achievements) { achievement in
                achievementRow(achievement: achievement)
            }
            
            Button(action: {
                // Action to view all achievements
            }) {
                Text("View All Achievements")
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
    
    // Achievement row
    private func achievementRow(achievement: Achievement) -> some View {
        HStack(spacing: 15) {
            // Achievement icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .foregroundColor(achievement.isUnlocked ? .white : .gray)
                    .font(.system(size: 24))
            }
            
            // Achievement details
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Locked/unlocked status
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Goals section
    private func goalsSection(isDemo: Bool) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Your Goals")
                .font(.headline)
                .padding(.horizontal)
            
            // Daily practice goal
            VStack(alignment: .leading, spacing: 10) {
                Text("Daily Practice Goal")
                    .font(.headline)
                
                HStack {
                    Text("\(dailyGoal) minutes")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        // Action to edit daily goal
                    }) {
                        Text("Edit")
                            .foregroundColor(.blue)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 10)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(7) / CGFloat(dailyGoal) * geometry.size.width, geometry.size.width), height: 10)
                            .foregroundColor(.blue)
                    }
                    .cornerRadius(45)
                }
                .frame(height: 10)
                
                Text("7 of \(dailyGoal) minutes completed today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Character mastery goal
            VStack(alignment: .leading, spacing: 10) {
                Text("Character Mastery Goal")
                    .font(.headline)
                
                HStack {
                    Text("50 characters")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        // Action to edit character goal
                    }) {
                        Text("Edit")
                            .foregroundColor(.blue)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 10)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        let progress = isDemo ? demoUser.characterProgress.count : userManager.currentUser?.characterProgress.count ?? 0
                        Rectangle()
                            .frame(width: min(CGFloat(progress) / 50 * geometry.size.width, geometry.size.width), height: 10)
                            .foregroundColor(.green)
                    }
                    .cornerRadius(45)
                }
                .frame(height: 10)
                
                let progress = isDemo ? demoUser.characterProgress.count : userManager.currentUser?.characterProgress.count ?? 0
                Text("\(progress) of 50 characters mastered")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }

    // Single character progress row
    private func characterProgressRow(progress: CharacterProgress) -> some View {
        HStack {
            if let characterData = characterDataManager.getCharacterById(progress.characterId) {
                VStack(alignment: .center) {
                    Text(characterData.character) // Uses .character (lowercase)
                        .font(.system(size: 32))

                    Text(characterData.pinyin)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)
            } else {
                Text(progress.characterId.prefix(1))
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Accuracy: \(Int(progress.bestAccuracy * 100))%")
                    .fontWeight(.medium)

                Text("Attempts: \(progress.attempts)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Last practiced: \(formattedDate(progress.lastPracticed))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            CircularProgressView(progress: progress.bestAccuracy)
                .frame(width: 50, height: 50)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Helper methods
    private func calculateAverageAccuracy(isDemo: Bool) -> Int {
        let progressMap = isDemo ? demoUser.characterProgress : userManager.currentUser?.characterProgress ?? [:]
        
        guard !progressMap.isEmpty else {
            return 0
        }
        
        let totalAccuracy = progressMap.values.reduce(0.0) { $0 + $1.bestAccuracy }
        return Int((totalAccuracy / Double(progressMap.count)) * 100)
    }
    
    private func weekdayLetter(for index: Int) -> String {
        let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
        return weekdays[index]
    }

    // Helper to format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Circular progress indicator
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 5)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress) // Animate based on progress value

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
        }
    }

    var progressColor: Color {
        if progress < 0.4 {
            return .red
        } else if progress < 0.7 {
            return .orange
        } else {
            return .green
        }
    }
}

// Achievement model
struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
}

// Settings View
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userManager: UserManager
    @State private var notificationsEnabled = true
    @State private var soundEnabled = true
    @State private var hapticFeedbackEnabled = true
    @State private var darkModeEnabled = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        NavigationLink(destination: Text("Notification Settings")) {
                            Text("Notification Settings")
                        }
                    }
                }
                
                Section(header: Text("Feedback")) {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                    Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                }
                
                Section(header: Text("Account")) {
                    NavigationLink(destination: Text("Privacy Settings")) {
                        Text("Privacy Settings")
                    }
                    
                    NavigationLink(destination: Text("Data & Storage")) {
                        Text("Data & Storage")
                    }
                    
                    Button(action: {
                        // Action to delete account
                    }) {
                        Text("Delete Account")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("About")) {
                    NavigationLink(destination: Text("Help & Support")) {
                        Text("Help & Support")
                    }
                    
                    NavigationLink(destination: Text("Terms of Service")) {
                        Text("Terms of Service")
                    }
                    
                    NavigationLink(destination: Text("Privacy Policy")) {
                        Text("Privacy Policy")
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Edit Profile View
struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userManager: UserManager
    @State private var username: String = ""
    @State private var email: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Picture")) {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(username.prefix(1).uppercased()))
                                    .foregroundColor(.white)
                                    .font(.system(size: 40, weight: .bold))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                            )
                            .shadow(radius: 3)
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    Button(action: {
                        // Action to change profile picture
                    }) {
                        Text("Change Profile Picture")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Personal Information")) {
                    TextField("Username", text: $username)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section {
                    Button(action: {
                        // Action to save profile changes
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Save Changes")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Load current user data
                if let user = userManager.currentUser {
                    username = user.username
                    email = user.email
                }
            }
        }
    }
}

// MARK: - Preview
// It's good practice to add a preview, but it will require mock data
// for UserManager and CharacterDataManager.

// struct UserProfileView_Previews: PreviewProvider {
// static var previews: some View {
// // Create mock UserManager
// let mockUserManager = UserManager()
// // TODO: Populate mockUserManager.currentUser with sample data including characterProgress
//
// // Create mock CharacterDataManager
// let mockCharDataManager = CharacterDataManager()
// // TODO: Populate mockCharDataManager with sample characters that match IDs in characterProgress
//
// UserProfileView()
// .environmentObject(mockUserManager)
// .environmentObject(mockCharDataManager)
// }
// }

// You will also need to ensure the following:
// 1. `UserManager` is an `ObservableObject` and has a `@Published var currentUser: User?`
// 2. The `User` struct/class has:
//    - `username: String`
//    - `email: String?` (or `String` if always present)
//    - `streakDays: Int?` (or `Int`)
//    - `characterProgress: [String: CharacterProgress]` (or similar dictionary type)
// 3. `CharacterProgress` struct/class has:
//    - `characterId: String`
//    - `bestAccuracy: Double`
//    - `attempts: Int`
//    - `lastPracticed: Date`
// 4. `CharacterDataManager` has a method `getCharacterById(_ id: String) -> YourAppCharacterType?`
//    where `YourAppCharacterType` is your `Character` model (which has `.character` and `.pinyin`).
