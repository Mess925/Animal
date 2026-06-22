//
//  SetupUsernameView.swift
//  PetHub
//
//  Created by Han Min Thant on 4/6/26.
//

import Foundation
import SwiftUI
import Supabase

struct StepUsernameView: View {
    @Binding var username: String
    let onNext: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer()

            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Step 1 of 3")
                    .font(.system(size: 13))
                    .foregroundStyle(PHTheme.subtext)

                Group {
                    Text("Pick a ") +
                    Text("username. 🐾")
                        .font(.custom("Georgia-Italic", size: 28))
                        .foregroundColor(PHTheme.accent)
                }
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PHTheme.text)

                Text("This is how others will find you")
                    .font(.system(size: 12))
                    .foregroundStyle(PHTheme.subtext.opacity(0.7))
            }
            .padding(.bottom, 32)

            // Input
            AuthField(
                label: "Username",
                placeholder: "@yourname",
                text: $username,
                isFocused: $isFocused,
                isSecure: false
            )
            .padding(.bottom, 32)

            // Next button
            PHButton(
                "Continue",
                icon: "arrow.right",
                isDisabled: username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await saveUsername() }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func saveUsername() async {
        do {
            let user = try await supabase.auth.session.user
            try await supabase
                .from("profiles")
                .update(["username": username])
                .eq("id", value: user.id.uuidString)
                .execute()
            onNext()
        } catch {
            #if DEBUG
            print("SetupUsernameView.swift:77 error:", error)
            #endif
        }
    }
}
