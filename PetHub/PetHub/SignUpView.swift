//
//  SignUpView.swift
//  PetHub
//
//  Created by Han Min Thant on 29/5/26.
//

import Supabase
import SwiftUI

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @AppStorage("needsUserOnboarding") var needsUserOnboarding = false
    @AppStorage("isLoggedIn") var isLoggedIn = false

    @FocusState private var nameFocused: Bool
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Headline
                    VStack(alignment: .leading, spacing: 6) {
                        Text("New here?")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppSubtext"))

                        Group {
                            Text("Join the ")
                                + Text("pack. 🐾")
                                .font(.custom("Georgia-Italic", size: 28))
                                .foregroundColor(Color(hex: "AA9DFF"))
                        }
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color("AppText"))
                        .lineSpacing(2)

                        Text("Create your account and get started")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("AppSubtext").opacity(0.7))
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
                            .foregroundStyle(Color("AppAccentText"))
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
                        .foregroundStyle(Color("AppText"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("AppSurface"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            Color("AppBorder"),
                                            lineWidth: 0.5
                                        )
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
                            .foregroundStyle(Color("AppSubtext"))
                        NavigationLink(destination: SignInView()) {
                            Text("Sign In")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(
                                    Color(hex: "AA9DFF").opacity(0.75)
                                )
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
    }

    private func signUp() async {
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            let user = response.user
            try await supabase
                .from("profiles")
                .insert([
                    "id": user.id.uuidString,
                    "name": name,
                    "username":
                        "@\(email.components(separatedBy: "@").first ?? "")",
                    "bio": "",
                    "avatar_emoji": "🧑",
                    "avatar_accent_hex": "AA9DFF",
                ])
                .execute()
            needsUserOnboarding = true
            isLoggedIn = true
        } catch {
        }
    }

    private func signUpWithApple() {
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
