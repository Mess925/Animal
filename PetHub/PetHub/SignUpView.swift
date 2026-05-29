//
//  SignUpView.swift
//  PetHub
//
//  Created by Han Min Thant on 29/5/26.
//

import SwiftUI

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""

    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    @FocusState private var nameFocused: Bool

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
                            Text("Join the")
                            Text("pack. 🐾")
                                .font(.custom("Georgia-Italic", size: 30))
                                .foregroundStyle(Color(hex: "AA9DFF"))
                        }
                        .padding(.bottom, 28)
                        VStack(spacing: 10) {
                            AuthenticationField(
                                title: "Name",
                                placeholder: "Enter your name",
                                text: $name,
                                isFocused: $nameFocused
                            )

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

                        // Primary CTA
                        AppButton("Sign Up", style: .primary) {
                            signUp()
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 12)

                        // Divider
                        OrDivider()
                            .padding(.bottom, 12)

                        // Secondary buttons
                        VStack(spacing: 8) {
                            AppButton(
                                "Sign Up with Apple",
                                style: .secondary,
                                icon: "apple.logo"
                            ) {
                                signUpWithApple()
                            }

                            AppNavButton(
                                "Sign Up with Email",
                                style: .secondary,
                                icon: "envelope",
                                destination: EmailSignInView()
                            )
                        }
                        .padding(.bottom, 28)

                        // Sign up link
                        HStack {
                            Spacer()
                            Text("Already have an Account?")
                                .foregroundStyle(Color.white.opacity(0.22))
                                .font(.system(size: 11))
                            NavigationLink(destination: SignInView()) {
                                (Text("Sign In")
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

    private func signUp() {
        print("🐾 A new pet parent has joined the family")
        // Add your auth logic here
    }

    private func signUpWithApple() {
        print("Apple Sign Up tapped")
        // Add ASAuthorizationAppleIDProvider logic here
    }
}

#Preview {
    SignUpView()
}
