//
//  StepCreateRoomView.swift
//  PetHub
//

import Foundation
import Supabase
import SwiftUI

struct StepCreateRoomView: View {
    let onFinish: () -> Void

    @AppStorage("needsUserOnboarding") var needsUserOnboarding = false

    @State private var petName = ""
    @State private var breed = ""
    @State private var age = ""
    @State private var selectedIcon = "pawprint.fill"
    @State private var selectedAccent = "AA9DFF"
    @State private var isLoading = false

    @FocusState private var nameFocused: Bool
    @FocusState private var breedFocused: Bool
    @FocusState private var ageFocused: Bool

    let icons = [
        "pawprint.fill", "bird.fill", "fish.fill", "ant.fill", "hare.fill",
        "tortoise.fill",
    ]

    let accents = ["AA9DFF", "7EC8C8", "F4A84A", "E25718", "6EE7B7", "F472B6"]

    private var canFinish: Bool {
        !petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Step 3 of 3")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AppSubtext"))

                Group {
                    Text("Add your ")
                    Text("first pet. 🐾")
                        .font(.custom("Georgia-Italic", size: 28))
                        .foregroundColor(Color(hex: "AA9DFF"))
                }
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color("AppText"))

                Text("Create a room for your furry friend")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppSubtext").opacity(0.7))
            }
            .padding(.bottom, 32)

            VStack(spacing: 12) {
                AuthField(
                    label: "Pet Name",
                    placeholder: "e.g. Mochi",
                    text: $petName,
                    isFocused: $nameFocused,
                    isSecure: false
                )

                AuthField(
                    label: "Breed",
                    placeholder: "e.g. Shiba Inu",
                    text: $breed,
                    isFocused: $breedFocused,
                    isSecure: false
                )

                AuthField(
                    label: "Age",
                    placeholder: "e.g. 2 years old",
                    text: $age,
                    isFocused: $ageFocused,
                    isSecure: false
                )
            }
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("ICON")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color("AppSubtext").opacity(0.7))

                HStack(spacing: 12) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    selectedIcon == icon
                                    ? Color(hex: selectedAccent)
                                    : Color("AppSubtext")
                                )
                                .frame(width: 48, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            selectedIcon == icon
                                            ? Color(hex: selectedAccent).opacity(0.15)
                                            : Color("AppSurface")
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("COLOR")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color("AppSubtext").opacity(0.7))

                HStack(spacing: 12) {
                    ForEach(accents, id: \.self) { hex in
                        Button {
                            selectedAccent = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.white,
                                            lineWidth: selectedAccent == hex ? 2 : 0
                                        )
                                        .padding(2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 32)

            Button {
                Task { await completeOnboarding() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(Color("AppAccentText"))
                    } else {
                        Text("Let's Go! 🐾")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color("AppAccentText"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canFinish ? Color(hex: "AA9DFF") : Color(hex: "AA9DFF").opacity(0.4))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canFinish)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func completeOnboarding() async {
        guard canFinish else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await supabase.auth.session.user
            let roomId = UUID()

            try await supabase
                .from("rooms")
                .insert([
                    "id": roomId.uuidString,
                    "name": petName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "breed": breed.trimmingCharacters(in: .whitespacesAndNewlines),
                    "age": age.trimmingCharacters(in: .whitespacesAndNewlines),
                    "icon": selectedIcon,
                    "accent_hex": selectedAccent,
                    "owner_id": user.id.uuidString,
                ])
                .execute()

            try await supabase
                .from("profiles")
                .update(["is_onboarded": true])
                .eq("id", value: user.id.uuidString)
                .execute()

            needsUserOnboarding = false
            onFinish()

        } catch {
            print("Complete onboarding error: \(error)")
        }
    }
}
