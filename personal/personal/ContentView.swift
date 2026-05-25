//
//  ContentView.swift
//  personal
//
//  Created by Han Min Thant on 23/5/26.
//

import SwiftUI

// MARK: - Authentication Field

struct AuthenticationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "AA9DFF").opacity(0.7))

            HStack(spacing: 10) {
                Image(systemName: isSecure ? "lock" : "envelope")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "AA9DFF").opacity(0.5))
                    .frame(width: 16)

                Group {
                    if isSecure {
                        SecureField(
                            title,
                            text: $text,
                            prompt: Text(placeholder)
                                .foregroundStyle(Color.white.opacity(0.2))
                        )
                    } else {
                        TextField(
                            title,
                            text: $text,
                            prompt: Text(placeholder)
                                .foregroundStyle(Color.white.opacity(0.2))
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(isFocused ? Color(hex: "F0EDE6") : Color(hex: "F0EDE6").opacity(0.6))
            }
            .focused($isFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Color(hex: "AA9DFF").opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Divider

struct OrDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
            Text("OR")
                .font(.system(size: 10, weight: .regular))
                .tracking(0.5)
                .foregroundStyle(Color.white.opacity(0.2))
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var email = ""
    @State private var password = ""

    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "0D0D0E").ignoresSafeArea()

                // Ambient orbs
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "8B7EEO").opacity(0.12), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: -100, y: -120)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "6450A0").opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .offset(x: geo.size.width - 80, y: geo.size.height - 180)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Headline
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome")
                                .font(.custom("Georgia", size: 30))
                                .fontWeight(.light)
                                .foregroundStyle(Color(hex: "F0EDE6"))
                            Text("back.")
                                .font(.custom("Georgia-Italic", size: 30))
                                .fontWeight(.light)
                                .foregroundStyle(Color(hex: "AA9DFF"))

                            Text("Sign in to continue your journey")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundStyle(Color(hex: "F0EDE6").opacity(0.38))
                                .padding(.top, 6)
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
                            Button("Forgot password?") { }
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color(hex: "AA9DFF").opacity(0.55))
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
                            AppButton("Sign In with Apple", style: .secondary, icon: "apple.logo") {
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
                            NavigationLink(destination: SignUpView()) {
                                (
                                    Text("Don't have an account? ")
                                        .foregroundStyle(Color.white.opacity(0.22))
                                    + Text("Create one")
                                        .foregroundStyle(Color(hex: "AA9DFF").opacity(0.7))
                                )
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

struct SignUpView: View {
    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()
            Text("Sign Up")
                .foregroundStyle(Color(hex: "F0EDE6"))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
