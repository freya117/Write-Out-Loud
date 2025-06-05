import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var localError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Create an Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.vertical, 30)
                    
                    // Username field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .fontWeight(.medium)
                        
                        TextField("Enter a username", text: $username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Email field
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
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .fontWeight(.medium)
                        
                        SecureField("Enter a password", text: $password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Confirm Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .fontWeight(.medium)
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Error message
                    if let error = localError ?? userManager.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.top, 5)
                    }
                    
                    // Register Button
                    Button(action: {
                        // Local validation
                        if password != confirmPassword {
                            localError = "Passwords do not match"
                            return
                        }
                        
                        localError = nil
                        let success = userManager.register(
                            username: username,
                            email: email,
                            password: password
                        )
                        
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack {
                            Text("Register")
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
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
            }
            .navigationBarTitle("Register", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
} 