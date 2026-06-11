//
//  StepCreateRoomView.swift
//  PetHub
//
//  Created by Han Min Thant on 4/6/26.
//

import Foundation
import Supabase
import SwiftUI

struct StepCreateRoomView: View {
    let onFinish: () -> Void

    @AppStorage("needsUserOnboarding") var needsUserOnboarding = false
    @State private var petName = ""
    @State private var breed = ""
    @State private var selectedIcon = "pawprint.fill"
    @State private var selectedAccent = "AA9DFF"

    @State private var isLoading = false

    @FocusState private var nameFocused: Bool
    @FocusState private var breedFocused: Bool

    let icons = [
        "pawprint.fill", "bird.fill", "fish.fill", "ant.fill", "hare.fill",
        "tortoise.fill",
    ]
    let accents = ["AA9DFF", "7EC8C8", "F4A84A", "E25718", "6EE7B7", "F472B6"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer()

            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Step 3 of 3")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AppSubtext"))

                Group {
                    Text("Add your ")
                        + Text("first pet. 🐾")
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

            // Fields
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
            }
            .padding(.bottom, 24)

            // Icon picker
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
                                                ? Color(hex: selectedAccent)
                                                    .opacity(0.15)
                                                : Color("AppSurface")
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 20)

            // Color picker
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
                                            lineWidth: selectedAccent == hex
                                                ? 2 : 0
                                        )
                                        .padding(2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 32)

            // Finish button
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
                        .fill(
                            (petName.isEmpty || isLoading)
                                ? Color(hex: "AA9DFF").opacity(0.4)
                                : Color(hex: "AA9DFF")
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(petName.isEmpty || isLoading)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private func completeOnboarding() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await supabase.auth.session.user
            let roomId = UUID()

            // 1. Create room
            try await supabase
                .from("rooms")
                .insert([
                    "id": roomId.uuidString,
                    "name": petName,
                    "breed": breed,
                    "age": "",
                    "icon": selectedIcon,
                    "accent_hex": selectedAccent,
                    "owner_id": user.id.uuidString,
                ])
                .execute()

            // 2. Mark profile as onboarded
            try await supabase
                .from("profiles")
                .update(["is_onboarded": true])
                .eq("id", value: user.id.uuidString)
                .execute()

            // 3. Done
            needsUserOnboarding = false
            onFinish()
        } catch {
            print("Complete onboarding error: \(error)")
        }
    }
}
