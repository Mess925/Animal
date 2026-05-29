//
//  ContentView.swift
//  personal
//
//  Created by Han Min Thant on 23/5/26.
//

import SwiftUI

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""

    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "0D0D0E").ignoresSafeArea()

                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Headline
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back,")
                            Text("pet parent. 🐾")
                                .font(.custom("Georgia-Italic", size: 30))
                                .foregroundStyle(Color(hex: "AA9DFF"))

                            Text("Your pets missed you")
                        }
                        .padding(.bottom, 28)

                        // Fields
                        VStack(spacing: 10) {
                            AuthenticationField(
                                title: "Email",
                                placeholder: "Enter your email",
                                text: $email,
                                isFocused: $emailFocused
                            )

                            AuthenticationField(
                                title: "Password",
                                placeholder: "Enter your password",
                                text: $password,
                                isSecure: true,
                                isFocused: $passwordFocused
                            )
                        }
                        .padding(.bottom, 10)

                        // Forgot password
                        HStack {
                            Spacer()
                            Button("Forgot password?") {}
                                .font(.system(size: 10.5))
                                .foregroundStyle(
                                    Color(hex: "AA9DFF").opacity(0.55)
                                )
                        }
                        .padding(.bottom, 22)

                        // Primary CTA
                        AppButton("Sign In", style: .primary) {
                            signIn()
                        }
                        .padding(.bottom, 12)

                        // Divider
                        OrDivider()
                            .padding(.bottom, 12)

                        // Secondary buttons
                        VStack(spacing: 8) {
                            AppButton(
                                "Sign In with Apple",
                                style: .secondary,
                                icon: "apple.logo"
                            ) {
                                signInWithApple()
                            }

                            AppNavButton(
                                "Sign In with Email",
                                style: .secondary,
                                icon: "envelope",
                                destination: EmailSignInView()
                            )
                        }
                        .padding(.bottom, 28)

                        // Sign up link
                        HStack {
                            Spacer()
                            Text("Don't have an account? ")
                                .foregroundStyle(Color.white.opacity(0.22))
                                .font(.system(size: 11))
                            NavigationLink(destination: SignUpView()) {
                                (Text("Create one")
                                    .foregroundStyle(
                                        Color(hex: "AA9DFF").opacity(0.7)
                                    ))
                                    .font(.system(size: 11))
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Actions

    private func signIn() {
        print("Signing in with \(email)")
        // Add your auth logic here
    }

    private func signInWithApple() {
        print("Apple Sign In tapped")
        // Add ASAuthorizationAppleIDProvider logic here
    }
}

// MARK: - Placeholder Destination Views
// Replace these with your real views

struct EmailSignInView: View {
    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()
            Text("Email Sign In")
                .foregroundStyle(Color(hex: "F0EDE6"))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    SignInView()
}
