//
//  SignUpView.swift
//  PetHub
//
//  Created by Han Min Thant on 29/5/26.
//

import SwiftUI
import Supabase

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    @FocusState private var nameFocused: Bool
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Headline
                    VStack(alignment: .leading, spacing: 6) {
                        Text("New here?")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.35))

                        Group {
                            Text("Join the ") +
                            Text("pack. 🐾")
                                .font(.custom("Georgia-Italic", size: 28))
                                .foregroundColor(Color(hex: "AA9DFF"))
                        }
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "F0EDE6"))
                        .lineSpacing(2)

                        Text("Create your account and get started")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.28))
                    }
                    .padding(.bottom, 32)

                    // Fields
                    VStack(spacing: 10) {
                        AuthField(
                            label: "Name",
                            placeholder: "Enter your name",
                            text: $name,
                            isFocused: $nameFocused,
                            isSecure: false
                        )
                        AuthField(
                            label: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            isFocused: $emailFocused,
                            isSecure: false
                        )
                        AuthField(
                            label: "Password",
                            placeholder: "Create a password",
                            text: $password,
                            isFocused: $passwordFocused,
                            isSecure: true
                        )
                    }
                    .padding(.bottom, 24)

                    // Create Account CTA
                    Button {
                        Task { await signUp() }
                    } label: {
                        Text("Create Account")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "1a1630"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "AA9DFF"))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)

                    // Divider
                    AuthDivider()
                        .padding(.bottom, 16)

                    // Apple
                    Button {
                        signUpWithApple()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 15, weight: .medium))
                            Text("Continue with Apple")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "F0EDE6"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "1C1C1F"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)

                    // Sign in link
                    HStack(spacing: 4) {
                        Spacer()
                        Text("Already have an account?")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.25))
                        NavigationLink(destination: SignInView()) {
                            Text("Sign In")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "AA9DFF").opacity(0.75))
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(false)
        .preferredColorScheme(.dark)
    }
    
    private func signUp() async {
        do {
            try await supabase.auth.signUp(email: email, password: password)
            print("Signed up successfully!")
        } catch {
            print("Sign up error: \(error)")
        }
    }

    private func signUpWithApple() {
        print("Apple Sign Up tapped")
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
