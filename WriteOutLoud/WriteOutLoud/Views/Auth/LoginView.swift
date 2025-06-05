import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var userManager: UserManager
    @State private var email: String = "test@example.com" // Pre-fill with test account
    @State private var password: String = "password123" // Pre-fill with test password
    @State private var isShowingRegistration = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo and Title
                Image("app_logo") // Add this to your assets
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .padding(.bottom, 20)
                
                Text("Write Out Loud")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // Test account info
                VStack(spacing: 5) {
                    Text("Test Account Credentials")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Email: test@example.com")
                        .font(.subheadline)
                    
                    Text("Password: password123")
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.bottom, 20)
                
                // Login Form
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .fontWeight(.medium)
                    
                    TextField("Enter your email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .fontWeight(.medium)
                    
                    SecureField("Enter your password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Error message
                if let error = userManager.authError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                // Login Button
                Button(action: {
                    let success = userManager.login(email: email, password: password)
                    if success {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        Text("Login")
                            .fontWeight(.semibold)
                        
                        if userManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.leading, 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(userManager.isLoading)
                .padding(.top, 20)
                
                // Registration Link
                Button("Don't have an account? Register") {
                    isShowingRegistration = true
                }
                .padding(.top, 15)
                .sheet(isPresented: $isShowingRegistration) {
                    RegisterView()
                        .environmentObject(userManager)
                }
                
                // Divider with "or" text
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4))
                    
                    Text("or")
                        .foregroundColor(Color(.systemGray))
                        .padding(.horizontal, 8)
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4))
                }
                .padding(.vertical, 15)
                
                // Skip Login Button
                Button(action: {
                    userManager.hideLoginOverlay()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Continue Without Login")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Extension to access tabBarController
extension UIViewController {
    var tabBarController: UITabBarController? {
        return self as? UITabBarController ?? parent?.tabBarController
    }
} 