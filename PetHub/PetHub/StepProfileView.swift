//
//  StepProfileView.swift
//  PetHub
//
//  Created by Han Min Thant on 4/6/26.
//

import Foundation
import Supabase
import SwiftUI

struct StepProfileView: View {
    @Binding var bio: String
    @Binding var avatarEmoji: String
    let onNext: () -> Void

    let emojis = ["🧑", "👩", "👨", "🧔", "👱", "🧕", "👴", "👵"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer()

            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Step 2 of 3")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AppSubtext"))

                Group {
                    Text("Your ")
                        + Text("profile. 🧑")
                        .font(.custom("Georgia-Italic", size: 28))
                        .foregroundColor(Color(hex: "AA9DFF"))
                }
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color("AppText"))

                Text("Tell the pack a little about yourself")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppSubtext").opacity(0.7))
            }
            .padding(.bottom, 32)

            // Avatar picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            avatarEmoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(
                                            avatarEmoji == emoji
                                                ? Color(hex: "AA9DFF").opacity(
                                                    0.2
                                                ) : Color("AppSurface")
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    avatarEmoji == emoji
                                                        ? Color(hex: "AA9DFF")
                                                        : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 24)

            // Bio
            VStack(alignment: .leading, spacing: 6) {
                Text("BIO")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color("AppSubtext").opacity(0.7))

                ZStack(alignment: .topLeading) {
                    if bio.isEmpty {
                        Text("Tell people about yourself…")
                            .font(.system(size: 15))
                            .foregroundStyle(Color("AppPlaceholder"))
                            .padding(.top, 14)
                            .padding(.leading, 16)
                    }
                    TextEditor(text: $bio)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Color("AppText"))
                        .frame(height: 100)
                        .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color("AppSurface"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    Color("AppBorder"),
                                    lineWidth: 0.5
                                )
                        )
                )
            }
            .padding(.bottom, 32)

            // Next button
            Button {
                Task { await saveProfile() }
            } label: {
                Text("Continue")
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

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func saveProfile() async {
        do {
            let user = try await supabase.auth.session.user
            try await supabase
                .from("profiles")
                .update(["bio": bio, "avatar_emoji": avatarEmoji])
                .eq("id", value: user.id.uuidString)
                .execute()
            onNext()
        } catch {
            print("Save profile error: \(error)")
        }
    }
}
