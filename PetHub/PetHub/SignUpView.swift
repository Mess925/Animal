//
//  SignUpView.swift
//  PetHub
//

import Supabase
import SwiftUI

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isCreating = false
    @State private var authError: String?
    @StateObject private var appleHandler = AppleSignInHandler()
    
    @AppStorage("needsUserOnboarding") var needsUserOnboarding = false
    @AppStorage("isLoggedIn") var isLoggedIn = false
    
    @FocusState private var nameFocused: Bool
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    
    private var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canCreate: Bool {
        !cleanedName.isEmpty
        && isValidEmail(cleanedEmail)
        && password.count >= 8
        && !isCreating
    }
    
    var body: some View {
        PHPage {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    AuthHeroCard(
                        eyebrow: "NEW HERE?",
                        title: "Create your PetHub account",
                        subtitle: "Start with your profile, then set up your first pet room.",
                        icon: "person.crop.circle.badge.plus"
                    )
                    .padding(.top, 18)
                    
                    PHCard(padding: 20) {
                        VStack(spacing: 18) {
                            AuthField(
                                label: "Name",
                                placeholder: "Enter your name",
                                text: $name,
                                isFocused: $nameFocused,
                                isSecure: false,
                                keyboardType: .default,
                                textContentType: .name
                            )
                            
                            AuthField(
                                label: "Email",
                                placeholder: "Enter your email",
                                text: $email,
                                isFocused: $emailFocused,
                                isSecure: false,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                            
                            AuthField(
                                label: "Password",
                                placeholder: "At least 8 characters",
                                text: $password,
                                isFocused: $passwordFocused,
                                isSecure: true,
                                keyboardType: .default,
                                textContentType: .newPassword
                            )
                        }
                    }
                    
                    if let authError {
                        AuthErrorBanner(message: authError)
                    }
                    
                    PHButton(
                        "Create Account",
                        icon: "pawprint.fill",
                        isLoading: isCreating,
                        isDisabled: !canCreate
                    ) {
                        Task { await signUp() }
                    }
                    
                    AuthDivider()
                    
                    AuthSocialButton(title: "Continue with Apple", systemImage: "apple.logo") {
                        signUpWithApple()
                    }
                    
                    HStack(spacing: 4) {
                        Spacer()
                        Text("Already have an account?")
                            .font(.system(size: 13))
                            .foregroundStyle(PHTheme.subtext)
                        NavigationLink(destination: SignInView()) {
                            Text("Sign In")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PHTheme.accent)
                        }
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, PHTheme.pagePadding)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(false)
    }
    
    private func signUp() async {
        authError = nil
        
        guard canCreate else {
            authError = "Please enter your name, a valid email, and an 8+ character password."
            return
        }
        
        isCreating = true
        defer { isCreating = false }
        
        do {
            let response = try await supabase.auth.signUp(
                email: cleanedEmail,
                password: password
            )
            
            let user = response.user
            try await supabase
                .from("profiles")
                .insert([
                    "id": user.id.uuidString,
                    "name": cleanedName,
                    "username": "@\(cleanedEmail.components(separatedBy: "@").first ?? "")",
                    "bio": "",
                    "avatar_emoji": "🧑",
                    "avatar_accent_hex": "AA9DFF",
                ])
                .execute()
            
            needsUserOnboarding = true
            isLoggedIn = true
        } catch {
            authError = friendlyAuthError(error)
        }
    }
    
    private func signUpWithApple() {
        authError = nil
        
        appleHandler.onSuccess = {
            needsUserOnboarding = true
            isLoggedIn = true
        }
        
        appleHandler.onError = { message in
            authError = message
        }
        
        appleHandler.signIn()
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
