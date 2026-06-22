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
    @State private var hasAcceptedTerms = false
    @StateObject private var appleHandler = AppleSignInHandler()
    
    @AppStorage("needsUserOnboarding") var needsUserOnboarding = false
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @AppStorage("isSigningUpWithApple") private var isSigningUpWithApple = false
    
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
        && hasAcceptedTerms
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
                    
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            hasAcceptedTerms.toggle()
                        } label: {
                            Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(hasAcceptedTerms ? PHTheme.accent : PHTheme.subtext)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 4) {
                            Text("I agree to the")
                                .font(.system(size: 13))
                                .foregroundStyle(PHTheme.subtext)

                            NavigationLink(destination: TermsOfServiceView()) {
                                Text("Terms of Service")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PHTheme.accent)
                            }
                        }

                        Spacer()
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
                    .disabled(!hasAcceptedTerms || isCreating)
                    .opacity(hasAcceptedTerms ? 1 : 0.55)
                    
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
            authError = "Please enter your name, a valid email, an 8+ character password, and accept the Terms of Service."
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

        guard hasAcceptedTerms else {
            authError = "Please accept the Terms of Service before continuing."
            return
        }

        isSigningUpWithApple = true  // block the listener

        appleHandler.onSuccess = { profileExists in
            isSigningUpWithApple = false

            if profileExists {
                Task { try? await supabase.auth.signOut() }
                authError = "This Apple account already exists. Please sign in instead."
                return
            }

            needsUserOnboarding = true
            isLoggedIn = true
        }
        appleHandler.onError = { message in
            isSigningUpWithApple = false
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
