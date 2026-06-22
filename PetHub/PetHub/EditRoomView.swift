//
//  EditRoomView.swift
//  PetHub
//
//  Created by Han Min Thant on 6/6/26.
//

import Foundation
import SwiftUI
import Supabase

struct EditRoomView: View {
    let room: PetRoom
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RoomStore

    @State private var petName: String
    @State private var breed: String
    @State private var age: String
    @State private var selectedIcon: String
    @State private var selectedAccent: String
    @State private var isLoading = false

    let icons = ["pawprint.fill", "bird.fill", "fish.fill", "ant.fill", "hare.fill", "tortoise.fill", "dog.fill", "cat.fill"]
    let accents = ["AA9DFF", "7EC8C8", "F4A84A", "E25718", "6EE7B7", "F472B6", "FF6B6B", "06D6A0"]

    init(room: PetRoom) {
        self.room = room
        _petName = State(initialValue: room.name)
        _breed = State(initialValue: room.breed)
        _age = State(initialValue: room.age)
        _selectedIcon = State(initialValue: room.icon)
        _selectedAccent = State(initialValue: room.accentHex)
    }

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Nav
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(PHTheme.surface)
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PHTheme.text)
                        }
                    }
                    Spacer()
                    Button {
                        Task { await saveRoom() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(PHTheme.accent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Group {
                                Text("Edit ") +
                                Text("\(room.name)'s room 🐾")
                                    .font(.custom("Georgia-Italic", size: 28))
                                    .foregroundColor(Color(hex: selectedAccent))
                            }
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(PHTheme.text)
                        }
                        .padding(.horizontal, 24)

                        // Fields
                        VStack(spacing: 12) {
                            ProfileInputField(title: "Pet Name", placeholder: "e.g. Mochi", text: $petName)
                            ProfileInputField(title: "Breed", placeholder: "e.g. Golden Retriever", text: $breed)
                            ProfileInputField(title: "Age", placeholder: "e.g. 2", text: $age, keyboardType: .numberPad)
                        }
                        .padding(.horizontal, 24)

                        // Icon picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ICON")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(PHTheme.subtext)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(icons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(selectedIcon == icon ? Color(hex: selectedAccent) : PHTheme.subtext)
                                                .frame(width: 48, height: 48)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(selectedIcon == icon ? Color(hex: selectedAccent).opacity(0.15) : PHTheme.surface)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Color picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COLOR")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(PHTheme.subtext)

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
                                                    .stroke(Color.white, lineWidth: selectedAccent == hex ? 2 : 0)
                                                    .padding(2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: age) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue { age = filtered }
        }
    }

    private func saveRoom() async {
        isLoading = true
        do {
            try await supabase
                .from("rooms")
                .update([
                    "name": petName,
                    "breed": breed,
                    "age": age,
                    "icon": selectedIcon,
                    "accent_hex": selectedAccent
                ])
                .eq("id", value: room.id.uuidString)
                .execute()

            await MainActor.run {
                if let idx = store.rooms.firstIndex(where: { $0.id == room.id }) {
                    store.rooms[idx].name = petName
                    store.rooms[idx].breed = breed
                    store.rooms[idx].age = age
                    store.rooms[idx].icon = selectedIcon
                    store.rooms[idx].accentHex = selectedAccent
                }
            }
            dismiss()
        } catch {
            #if DEBUG
            print("EditRoomView.swift:192 error:", error)
            #endif
        }
        isLoading = false
    }
}
