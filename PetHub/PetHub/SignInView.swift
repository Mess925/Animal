//
//  SignInView.swift
//  PetHub
//
//  Created by Han Min Thant on 23/5/26.
//

import SwiftUI
import Supabase

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""

    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var greeting: AttributedString {
        var text = AttributedString("Good to see you, pet parent. 🐾")

        if let range = text.range(of: "pet parent. 🐾") {
            text[range].font = .custom("Georgia-Italic", size: 28)
            text[range].foregroundColor = Color(hex: "AA9DFF")
        }

        return text
    }

    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Headline
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome back")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.35))

                        Group {
                            Text("Good to see you, ")
                                + Text("pet parent. 🐾")
                                .font(.custom("Georgia-Italic", size: 28))
                                .foregroundColor(Color(hex: "AA9DFF"))
                        }
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "F0EDE6"))
                        .lineSpacing(2)

                        Text("Your pets missed you")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.28))
                    }
                    .padding(.bottom, 32)

                    // Fields
                    VStack(spacing: 10) {
                        AuthField(
                            label: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            isFocused: $emailFocused,
                            isSecure: false
                        )
                        AuthField(
                            label: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            isFocused: $passwordFocused,
                            isSecure: true
                        )
                    }
                    .padding(.bottom, 10)

                    // Forgot
                    HStack {
                        Spacer()
                        Button("Forgot password?") {}
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "AA9DFF").opacity(0.6))
                    }
                    .padding(.bottom, 24)

                    // Sign In CTA
                    Button {
                        Task { await signIn() }
                    } label: {
                        Text("Sign In")
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
                        signInWithApple()
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
                                        .stroke(
                                            Color.white.opacity(0.09),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)

                    // Sign up link
                    HStack(spacing: 4) {
                        Spacer()
                        Text("Don't have an account?")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.25))
                        NavigationLink(destination: SignUpView()) {
                            Text("Create one")
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
        .preferredColorScheme(.dark)
    }

    private func signInWithApple() {
        print("Apple Sign In tapped")
    }
    private func signIn() async {
        do {
            try await supabase.auth.signIn(email: email, password: password)
            print("Signed in successfully!")
        } catch {
            print("Sign in error: \(error)")
        }
    }
}

// MARK: - Shared Auth Field

struct AuthField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.28))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .padding(.horizontal, 16)
                }
                if isSecure {
                    SecureField("", text: $text)
                        .focused(isFocused)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "F0EDE6"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    TextField("", text: $text)
                        .focused(isFocused)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "F0EDE6"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "1C1C1F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isFocused.wrappedValue
                                    ? Color(hex: "AA9DFF").opacity(0.45)
                                    : Color.white.opacity(0.08),
                                lineWidth: 0.5
                            )
                    )
            )
        }
    }
}

// MARK: - Or Divider

struct AuthDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
            Text("or")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.22))
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SignInView()
    }
}
