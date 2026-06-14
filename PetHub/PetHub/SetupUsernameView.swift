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
                    .foregroundStyle(Color("AppSubtext"))

                Group {
                    Text("Pick a ") +
                    Text("username. 🐾")
                        .font(.custom("Georgia-Italic", size: 28))
                        .foregroundColor(Color(hex: "AA9DFF"))
                }
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color("AppText"))

                Text("This is how others will find you")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppSubtext").opacity(0.7))
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
            Button {
                Task { await saveUsername() }
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("AppAccentText"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(username.isEmpty ? Color(hex: "AA9DFF").opacity(0.4) : Color(hex: "AA9DFF"))
                    )
            }
            .buttonStyle(.plain)
            .disabled(username.isEmpty)

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
        }
    }
}
