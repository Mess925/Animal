//
//  AppleSignin.swift
//  PetHub
//
//  Created by Han Min Thant on 16/6/26.
//

import Foundation
//
//  AppleSignIn.swift
//  PetHub
//
import AuthenticationServices
import CryptoKit
import Foundation
import Security
import Supabase
import SwiftUI
import UIKit
import Combine

@MainActor
final class AppleSignInHandler: NSObject, ObservableObject {
    var onSuccess: (() -> Void)?
    var onError: ((String) -> Void)?

    private var currentNonce: String?
    private var controller: ASAuthorizationController?

    func signIn() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        self.controller = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

extension AppleSignInHandler: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            onError?("Apple sign in failed. Please try again.")
            return
        }

        Task { @MainActor in
            do {
                let result = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )

                let user = result.user

                let appleName = [
                    credential.fullName?.givenName,
                    credential.fullName?.familyName
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

                let emailPrefix = user.email?
                    .components(separatedBy: "@")
                    .first

                let fallbackName = appleName.isEmpty
                    ? (emailPrefix ?? "PetHub User")
                    : appleName

                let fallbackUsername = "@\(emailPrefix ?? String(user.id.uuidString.prefix(8)))"

                try await supabase
                    .from("profiles")
                    .upsert([
                        "id": user.id.uuidString,
                        "name": fallbackName,
                        "username": fallbackUsername,
                        "bio": "",
                        "avatar_emoji": "🧑",
                        "avatar_accent_hex": "AA9DFF"
                    ])
                    .execute()

                onSuccess?()
            } catch {
                onError?("Apple sign in failed. Please try again.")
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if (error as? ASAuthorizationError)?.code == .canceled { return }
        onError?("Apple sign in failed. Please try again.")
    }
}

extension AppleSignInHandler: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension AppleSignInHandler {
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)

        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""

        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)

            if status == errSecSuccess && random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }

    func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
