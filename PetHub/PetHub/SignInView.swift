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
            Color("AppBackground").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // MARK: Top bar
                HStack {
                    if step != .enterEmail {
                        Button {
                            withAnimation { goBack() }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color("AppDivider"))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color("AppAdaptiveWhite").opacity(0.8))
                            }
                        }
                        .disabled(isLoading)
                    }

                    Spacer()

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
                    .disabled(isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // MARK: Content
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

    // MARK: - Step 1: Email

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Reset Password")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color("AppText"))
                .padding(.horizontal, 20)

            Text("Enter your email and we'll send you a 6-digit code.")
                .font(.system(size: 14))
                .foregroundStyle(Color("AppSubtext"))
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)

            AuthField(
                label: "Email",
                placeholder: "Enter your email",
                text: $email,
                isFocused: $emailFocused,
                isSecure: false
            )
            .padding(.horizontal, 20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "E25718"))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            ctaButton(
                label: "Send Code",
                canProceed: isValidEmail(cleanedEmail) && !isLoading
            ) {
                Task { await sendOTP() }
            }
        }
    }

    // MARK: - Step 2: OTP

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Check your email")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color("AppText"))
                .padding(.horizontal, 20)

            Text("We sent a 6-digit code to **\(cleanedEmail)**. Enter it below.")
                .font(.system(size: 14))
                .foregroundStyle(Color("AppSubtext"))
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 6) {
                Text("CODE")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color("AppSubtext").opacity(0.7))
                    .padding(.horizontal, 20)

                TextField("", text: $otpCode)
                    .focused($otpFocused)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color("AppText"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color("AppSurface"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        otpFocused
                                            ? Color(hex: "AA9DFF").opacity(0.45)
                                            : Color("AppBorder"),
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .padding(.horizontal, 20)
                    .onChange(of: otpCode) { _, val in
                        otpCode = String(val.filter(\.isNumber).prefix(8))
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "E25718"))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            // Resend
            Button {
                Task { await sendOTP() }
            } label: {
                Text("Resend code")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "AA9DFF").opacity(0.75))
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

    // MARK: - Step 3: New Password

    private var newPasswordStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Password")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color("AppText"))
                .padding(.horizontal, 20)

            Text("Choose a strong password for your account.")
                .font(.system(size: 14))
                .foregroundStyle(Color("AppSubtext"))
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)

            VStack(spacing: 10) {
                AuthField(
                    label: "New Password",
                    placeholder: "At least 8 characters",
                    text: $newPassword,
                    isFocused: $passwordFocused,
                    isSecure: true
                )

                AuthField(
                    label: "Confirm Password",
                    placeholder: "Repeat your password",
                    text: $confirmPassword,
                    isFocused: $confirmFocused,
                    isSecure: true
                )
            }
            .padding(.horizontal, 20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "E25718"))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            if didSucceed {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "7EC8C8"))
                    Text("Password updated! You can now sign in.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppSubtext"))
                        .lineSpacing(3)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "7EC8C8").opacity(0.10))
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

    // MARK: - Shared CTA Button

    private func ctaButton(label: String, canProceed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView().tint(Color("AppAccentText"))
                } else {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
            }
            .foregroundStyle(Color("AppAccentText"))
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(canProceed ? Color(hex: "AA9DFF") : Color("AppDivider"))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canProceed)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Actions

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
            isResettingPassword = true  // ← move this here, before the call
            try await supabase.auth.verifyOTP(
                email: cleanedEmail,
                token: otpCode,
                type: .magiclink
            )
            showChangePassword = true
        } catch {
            isResettingPassword = false  // ← reset it if it fails
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
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )
            didSucceed = true
        } catch {
            errorMessage = friendlyAuthError(error)
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
