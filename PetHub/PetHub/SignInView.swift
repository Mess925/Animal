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

    @AppStorage("isLoggedIn") var isLoggedIn = false
    @State private var isSigningIn = false
    @State private var authError: String?
    @State private var showForgotPassword = false

    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    private var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSignIn: Bool {
        isValidEmail(cleanedEmail) && !password.isEmpty && !isSigningIn
    }

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
            Color("AppBackground").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Headline
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome back")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppSubtext"))

                        Text(greeting)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color("AppText"))
                            .lineSpacing(2)

                        Text("Your pets missed you")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("AppSubtext").opacity(0.7))
                    }
                    .padding(.bottom, 32)

                    // MARK: Fields
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

                    // MARK: Forgot Password
                    HStack {
                        Spacer()
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot password?")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "AA9DFF").opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 16)

                    if let authError {
                        Text(authError)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "E25718"))
                            .padding(.bottom, 12)
                    }

                    // MARK: Sign In CTA
                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSigningIn {
                                ProgressView()
                                    .tint(Color("AppAccentText"))
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Spacer()
                        }
                        .foregroundStyle(Color("AppAccentText"))
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canSignIn ? Color(hex: "AA9DFF") : Color("AppDivider"))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSignIn)
                    .padding(.bottom, 16)

                    // MARK: Divider
                    AuthDivider()
                        .padding(.bottom, 16)

                    // MARK: Apple
                    Button {
                        signInWithApple()
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
                                        .stroke(Color("AppBorder"), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)

                    // MARK: Sign Up Link
                    HStack(spacing: 4) {
                        Spacer()
                        Text("Don't have an account?")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("AppSubtext"))
                        NavigationLink(destination: SignUpView()) {
                            Text("Create one")
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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: cleanedEmail)
        }
    }

    private func signInWithApple() {
        print("Apple Sign In tapped")
    }

    private func signIn() async {
        authError = nil

        guard isValidEmail(cleanedEmail) else {
            authError = "Please enter a valid email address."
            return
        }

        guard !password.isEmpty else {
            authError = "Please enter your password."
            return
        }

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await supabase.auth.signIn(email: cleanedEmail, password: password)
            isLoggedIn = true
            print("Signed in successfully!")
        } catch {
            authError = friendlyAuthError(error)
            print("Sign in error: \(error)")
        }
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    @FocusState private var emailFocused: Bool

    init(prefilledEmail: String = "") {
        _email = State(initialValue: prefilledEmail)
    }

    private var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSend: Bool {
        isValidEmail(cleanedEmail) && !isSending
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("AppDivider"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color("AppAdaptiveWhite").opacity(0.8))
                        }
                    }
                    .disabled(isSending)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                Text("Reset Password")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
                    .padding(.horizontal, 20)

                Text("Enter your email and we'll send you a password reset link.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("AppSubtext"))
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    AuthField(
                        label: "Email",
                        placeholder: "Enter your email",
                        text: $email,
                        isFocused: $emailFocused,
                        isSecure: false
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "E25718"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if didSend {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "7EC8C8"))
                            Text("Reset link sent. Check your inbox and spam folder.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("AppSubtext"))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "7EC8C8").opacity(0.10))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)

                Button {
                    Task { await sendResetEmail() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                                .tint(Color("AppAccentText"))
                        } else {
                            Text(didSend ? "Send Again" : "Send Reset Link")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Spacer()
                    }
                    .foregroundStyle(Color("AppAccentText"))
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(canSend ? Color(hex: "AA9DFF") : Color("AppDivider"))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer()
            }
        }
    }

    private func sendResetEmail() async {
        errorMessage = nil
        didSend = false

        guard isValidEmail(cleanedEmail) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            try await supabase.auth.resetPasswordForEmail(cleanedEmail)
            didSend = true
        } catch {
            errorMessage = friendlyAuthError(error)
            print("Forgot password error: \(error)")
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
                .foregroundStyle(Color("AppSubtext").opacity(0.7))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(Color("AppPlaceholder"))
                        .padding(.horizontal, 16)
                }

                if isSecure {
                    SecureField("", text: $text)
                        .focused(isFocused)
                        .font(.system(size: 15))
                        .foregroundStyle(Color("AppText"))
                        .textContentType(.password)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    TextField("", text: $text)
                        .focused(isFocused)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .font(.system(size: 15))
                        .foregroundStyle(Color("AppText"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("AppSurface"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isFocused.wrappedValue
                                    ? Color(hex: "AA9DFF").opacity(0.45)
                                    : Color("AppBorder"),
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
                .fill(Color("AppBorder"))
                .frame(height: 0.5)
            Text("or")
                .font(.system(size: 11))
                .foregroundStyle(Color("AppPlaceholder"))
            Rectangle()
                .fill(Color("AppBorder"))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Auth Helpers

func isValidEmail(_ email: String) -> Bool {
    let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    return email.range(of: pattern, options: .regularExpression) != nil
}

func friendlyAuthError(_ error: Error) -> String {
    let raw = String(describing: error).lowercased()

    if raw.contains("invalid login credentials") || raw.contains("invalid credentials") {
        return "Wrong email or password. Please try again."
    }

    if raw.contains("email not confirmed") || raw.contains("confirm") {
        return "Please verify your email before signing in."
    }

    if raw.contains("already registered") || raw.contains("already exists") {
        return "This email is already registered. Try signing in instead."
    }

    if raw.contains("rate limit") || raw.contains("too many") {
        return "Too many attempts. Please wait a moment and try again."
    }

    if raw.contains("network") || raw.contains("offline") {
        return "Network error. Please check your connection."
    }

    return "Something went wrong. Please try again."
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SignInView()
    }
}
