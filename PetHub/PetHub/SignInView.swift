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
    @StateObject private var appleHandler = AppleSignInHandler()
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    @AppStorage("needsUserOnboarding") var needsUserOnboarding = false
    
    private var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSignIn: Bool {
        isValidEmail(cleanedEmail) && !password.isEmpty && !isSigningIn
    }

    var body: some View {
        PHPage {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    AuthHeroCard(
                        eyebrow: "WELCOME BACK",
                        title: "Good to see you again",
                        subtitle: "Sign in to continue caring for your pets.",
                        icon: "pawprint.fill"
                    )
                    .padding(.top, 18)

                    PHCard(padding: 20) {
                        VStack(spacing: 18) {
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
                                placeholder: "Enter your password",
                                text: $password,
                                isFocused: $passwordFocused,
                                isSecure: true,
                                keyboardType: .default,
                                textContentType: .password
                            )
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot password?")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PHTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, -8)

                    if let authError {
                        AuthErrorBanner(message: authError)
                    }

                    PHButton(
                        "Sign In",
                        icon: "arrow.right",
                        isLoading: isSigningIn,
                        isDisabled: !canSignIn
                    ) {
                        Task { await signIn() }
                    }

                    AuthDivider()

                    AuthSocialButton(title: "Continue with Apple", systemImage: "apple.logo") {
                        signInWithApple()
                    }

                    HStack(spacing: 4) {
                        Spacer()
                        Text("Don't have an account?")
                            .font(.system(size: 13))
                            .foregroundStyle(PHTheme.subtext)
                        NavigationLink(destination: SignUpView()) {
                            Text("Create one")
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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: cleanedEmail)
        }
    }

    private func signInWithApple() {
        authError = nil

        appleHandler.onSuccess = { profileExists in
            needsUserOnboarding = !profileExists
            isLoggedIn = true
        }

        appleHandler.onError = { message in
            authError = message
        }

        appleHandler.signIn()
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
        } catch {
            authError = friendlyAuthError(error)
        }
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    enum Step {
        case enterEmail, enterOTP, enterNewPassword
    }

    @State private var step: Step = .enterEmail
    @State private var email: String
    @State private var otpCode = ""
    @State private var newPassword = ""
    @AppStorage("isResettingPassword") var isResettingPassword = false
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @State private var showChangePassword = false
    @FocusState private var emailFocused: Bool
    @FocusState private var otpFocused: Bool
    @FocusState private var passwordFocused: Bool
    @FocusState private var confirmFocused: Bool

    init(prefilledEmail: String = "") {
        _email = State(initialValue: prefilledEmail)
    }

    private var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if step != .enterEmail {
                        Button {
                            withAnimation { goBack() }
                        } label: {
                            CircleIconButton(systemName: "chevron.left")
                        }
                        .disabled(isLoading)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        CircleIconButton(systemName: "xmark")
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                switch step {
                case .enterEmail:
                    emailStep
                case .enterOTP:
                    otpStep
                case .enterNewPassword:
                    newPasswordStep
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView(skipCurrentPassword: true, onDismissAll: {
                dismiss()
            })
        }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle(title: "Reset Password", subtitle: "Enter your email and we'll send you a 6-digit code.")

            AuthField(
                label: "Email",
                placeholder: "Enter your email",
                text: $email,
                isFocused: $emailFocused,
                isSecure: false,
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )
            .padding(.horizontal, 20)

            if let errorMessage {
                InlineError(message: errorMessage)
            }

            ctaButton(
                label: "Send Code",
                canProceed: isValidEmail(cleanedEmail) && !isLoading
            ) {
                Task { await sendOTP() }
            }
        }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle(title: "Check your email", subtitle: "We sent a 6-digit code to \(cleanedEmail). Enter it below.")

            VStack(alignment: .leading, spacing: 8) {
                Text("CODE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(otpFocused ? PHTheme.accent : PHTheme.subtext)

                TextField("", text: $otpCode)
                    .focused($otpFocused)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PHTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(PHTheme.surface.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(otpFocused ? PHTheme.accent.opacity(0.75) : PHTheme.border, lineWidth: 0.9)
                    )
                    .onChange(of: otpCode) { _, val in
                        otpCode = String(val.filter(\.isNumber).prefix(8))
                    }
            }
            .padding(.horizontal, 20)

            if let errorMessage {
                InlineError(message: errorMessage)
            }

            Button {
                Task { await sendOTP() }
            } label: {
                Text("Resend code")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PHTheme.accent)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ctaButton(
                label: "Verify",
                canProceed: otpCode.count == 8 && !isLoading
            ) {
                Task { await verifyOTP() }
            }
        }
    }

    private var newPasswordStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle(title: "New Password", subtitle: "Choose a strong password for your account.")

            VStack(spacing: 14) {
                AuthField(
                    label: "New Password",
                    placeholder: "At least 8 characters",
                    text: $newPassword,
                    isFocused: $passwordFocused,
                    isSecure: true,
                    textContentType: .newPassword
                )

                AuthField(
                    label: "Confirm Password",
                    placeholder: "Repeat your password",
                    text: $confirmPassword,
                    isFocused: $confirmFocused,
                    isSecure: true,
                    textContentType: .newPassword
                )
            }
            .padding(.horizontal, 20)

            if let errorMessage {
                InlineError(message: errorMessage)
            }

            if didSucceed {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PHTheme.accent2)
                    Text("Password updated! You can now sign in.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PHTheme.subtext)
                        .lineSpacing(3)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(PHTheme.accent2.opacity(0.10))
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            ctaButton(
                label: didSucceed ? "Done" : "Update Password",
                canProceed: newPassword.count >= 8 && newPassword == confirmPassword && !isLoading
            ) {
                if didSucceed {
                    dismiss()
                } else {
                    Task { await updatePassword() }
                }
            }
        }
    }

    private func ctaButton(label: String, canProceed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canProceed ? PHTheme.accent : PHTheme.subtext.opacity(0.25))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canProceed)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private func goBack() {
        errorMessage = nil
        switch step {
        case .enterOTP: step = .enterEmail
        case .enterNewPassword: step = .enterOTP
        default: break
        }
    }

    private func sendOTP() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.signInWithOTP(email: cleanedEmail, shouldCreateUser: false)
            withAnimation { step = .enterOTP }
        } catch {
            errorMessage = friendlyAuthError(error)
        }
    }

    private func verifyOTP() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            isResettingPassword = true
            try await supabase.auth.verifyOTP(
                email: cleanedEmail,
                token: otpCode,
                type: .magiclink
            )
            showChangePassword = true
        } catch {
            isResettingPassword = false
            errorMessage = friendlyAuthError(error)
        }
    }

    private func updatePassword() async {
        errorMessage = nil

        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }

        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            didSucceed = true
        } catch {
            errorMessage = friendlyAuthError(error)
        }
    }
}

// MARK: - Shared Auth UI

struct AuthHeroCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                ZStack {
                    Circle()
                        .fill(PHTheme.accent.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(PHTheme.accent)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(PHTheme.accent)

                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineSpacing(3)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(PHTheme.surface)
                .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(PHTheme.border.opacity(0.9), lineWidth: 0.8)
        )
    }
}

struct AuthField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(isFocused.wrappedValue ? PHTheme.accent : PHTheme.subtext)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PHTheme.placeholder)
                        .padding(.horizontal, 16)
                }

                if isSecure {
                    SecureField("", text: $text)
                        .focused(isFocused)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PHTheme.text)
                        .textContentType(textContentType)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                } else {
                    TextField("", text: $text)
                        .focused(isFocused)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                        .autocorrectionDisabled(keyboardType == .emailAddress)
                        .textContentType(textContentType)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PHTheme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
            }
            .background(PHTheme.background.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isFocused.wrappedValue ? PHTheme.accent.opacity(0.85) : PHTheme.border, lineWidth: isFocused.wrappedValue ? 1.1 : 0.8)
            )
            .shadow(color: isFocused.wrappedValue ? PHTheme.accent.opacity(0.10) : Color.black.opacity(0.025), radius: 14, x: 0, y: 7)
            .animation(.easeInOut(duration: 0.18), value: isFocused.wrappedValue)
        }
    }
}

struct AuthDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(PHTheme.border)
                .frame(height: 0.7)
            Text("or")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PHTheme.placeholder)
            Rectangle()
                .fill(PHTheme.border)
                .frame(height: 0.7)
        }
    }
}

struct AuthSocialButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(PHTheme.text)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(PHTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PHTheme.border, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .lineSpacing(2)
        }
        .foregroundStyle(PHTheme.danger)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PHTheme.danger.opacity(0.10))
        )
    }
}

private struct CircleIconButton: View {
    let systemName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(PHTheme.surface)
                .frame(width: 38, height: 38)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PHTheme.text)
        }
    }
}

private struct SheetTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(PHTheme.text)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PHTheme.subtext)
                .lineSpacing(4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }
}

private struct InlineError: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(PHTheme.danger)
            .padding(.horizontal, 20)
            .padding(.top, 8)
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
