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
                    .foregroundStyle(PHTheme.subtext)

                Group {
                    Text("Your ")
                        + Text("profile. \(avatarEmoji.isEmpty ? "🧑" : avatarEmoji)")
                        .font(.custom("Georgia-Italic", size: 28))
                        .foregroundColor(PHTheme.accent)
                }
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PHTheme.text)

                Text("Tell the pack a little about yourself")
                    .font(.system(size: 12))
                    .foregroundStyle(PHTheme.subtext.opacity(0.7))
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
                                                ? PHTheme.accent.opacity(
                                                    0.2
                                                ) : PHTheme.surface
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    avatarEmoji == emoji
                                                        ? PHTheme.accent
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
                    .foregroundStyle(PHTheme.subtext.opacity(0.7))

                ZStack(alignment: .topLeading) {
                    if bio.isEmpty {
                        Text("Tell people about yourself…")
                            .font(.system(size: 15))
                            .foregroundStyle(PHTheme.placeholder)
                            .padding(.top, 14)
                            .padding(.leading, 16)
                    }
                    TextEditor(text: $bio)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(PHTheme.text)
                        .frame(height: 100)
                        .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PHTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    PHTheme.border,
                                    lineWidth: 0.5
                                )
                        )
                )
            }
            .padding(.bottom, 32)

            // Next button
            PHButton("Continue", icon: "arrow.right") {
                Task { await saveProfile() }
            }

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
            #if DEBUG
            print("StepProfileView.swift:134 error:", error)
            #endif
        }
    }
}
