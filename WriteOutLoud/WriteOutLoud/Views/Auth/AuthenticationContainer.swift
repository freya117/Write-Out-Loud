import SwiftUI

struct AuthenticationContainer: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var characterDataManager: CharacterDataManager
    
    var body: some View {
        // Always show TabView, regardless of authentication status
        TabView {
            // Main practice view
            MainView()
                .environmentObject(characterDataManager)
                .tabItem {
                    Label("Practice", systemImage: "pencil")
                }
            
            // Always show UserProfileView in the profile tab
            // The UserProfileView will handle showing the login overlay for non-authenticated users
            UserProfileView()
                .environmentObject(characterDataManager)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .onAppear {
            // Ensure login overlay is hidden when app starts
            userManager.hideLoginOverlay()
        }
    }
} 