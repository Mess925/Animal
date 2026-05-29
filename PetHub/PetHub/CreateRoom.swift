//
//  CreateRoom.swift
//  PetHub
//
//  Created by Han Min Thant on 29/5/26.
//

import Foundation
import SwiftUI

struct CreateRoomView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var petName = ""
    @State private var petType = "Dog"
    @State private var breed = ""
    @State private var age = ""
    @State private var bio = ""
    @State private var selectedColor: Color = Color(hex: "AA9DFF")

    private let petTypes = ["Dog", "Cat", "Bird", "Rabbit", "Other"]
    private let roomColors: [Color] = [
        Color(hex: "AA9DFF"),
        Color(hex: "FF6B6B"),
        Color(hex: "4ECDC4"),
        Color(hex: "FFD166"),
        Color(hex: "06D6A0"),
        Color(hex: "F72585"),
    ]

    var body: some View {
        ZStack {
            Color(hex: "0D0D0E")
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {

                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 38, height: 38)

                                    Image(systemName: "chevron.left")
                                        .font(
                                            .system(size: 15, weight: .medium)
                                        )
                                        .foregroundStyle(
                                            Color.white.opacity(0.8)
                                        )
                                }
                            }

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Create Room")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(Color(hex: "F0EDE6"))

                            Text("Make a private space for your pet.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                    }
                    .padding(.top, 10)

                    // Pet Preview Card
                    VStack(spacing: 0) {

                        ZStack {
                            RoundedRectangle(cornerRadius: 24).fill(
                                selectedColor.opacity(0.12)
                            )
                            .frame(height: 220)

                            VStack(spacing: 14) {

                                ZStack {
                                    Circle()
                                        .fill(selectedColor.opacity(0.18))
                                        .frame(width: 90, height: 90)

                                    Image(systemName: selectedPetIcon)
                                        .font(.system(size: 42))
                                        .foregroundStyle(selectedColor)
                                }

                                VStack(spacing: 4) {
                                    Text(petName.isEmpty ? "Your Pet" : petName)
                                        .font(
                                            .system(size: 20, weight: .semibold)
                                        )
                                        .foregroundStyle(Color(hex: "F0EDE6"))

                                    Text(
                                        breed.isEmpty
                                            ? petType
                                            : "\(breed) · \(petType)"
                                    )
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                }
                            }
                        }
                    }

                    // Form
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Room Color")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(roomColors, id: \.self) { color in

                                        let active = color == selectedColor

                                        Button {
                                            withAnimation(
                                                .spring(response: 0.25)
                                            ) {
                                                selectedColor = color
                                            }
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 28, height: 28)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            active
                                                                ? Color.white
                                                                    .opacity(
                                                                        0.8
                                                                    )
                                                                : Color.clear,
                                                            lineWidth: 1.5
                                                        )
                                                        .padding(3)
                                                )
                                                .scaleEffect(
                                                    active ? 1.05 : 1.0
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        CreateRoomInput(
                            title: "Pet Name",
                            placeholder: "Mochi",
                            text: $petName
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pet Type")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(petTypes, id: \.self) { type in

                                        let active = petType == type

                                        Button {
                                            withAnimation(
                                                .spring(response: 0.25)
                                            ) {
                                                petType = type
                                            }
                                        } label: {
                                            Text(type)
                                                .font(
                                                    .system(
                                                        size: 13,
                                                        weight: .medium
                                                    )
                                                )
                                                .foregroundStyle(
                                                    active
                                                        ? Color(hex: "AA9DFF")
                                                        : Color.white.opacity(
                                                            0.45
                                                        )
                                                )
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule()
                                                        .fill(
                                                            active
                                                                ? Color(
                                                                    hex:
                                                                        "AA9DFF"
                                                                ).opacity(0.12)
                                                                : Color.white
                                                                    .opacity(
                                                                        0.04
                                                                    )
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 14) {

                            CreateRoomInput(
                                title: "Breed",
                                placeholder: "Golden Retriever",
                                text: $breed
                            )

                            CreateRoomInput(
                                title: "Age",
                                placeholder: "2y",
                                text: $age
                            )
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bio")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))

                            ZStack(alignment: .topLeading) {

                                if bio.isEmpty {
                                    Text("Tell something about your pet...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(
                                            Color.white.opacity(0.2)
                                        )
                                        .padding(.top, 14)
                                        .padding(.leading, 16)
                                }

                                TextEditor(text: $bio)
                                    .scrollContentBackground(.hidden)
                                    .foregroundStyle(Color(hex: "F0EDE6"))
                                    .frame(height: 120)
                                    .padding(12)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(hex: "171719"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(
                                                Color.white.opacity(0.06),
                                                lineWidth: 0.5
                                            )
                                    )
                            )
                        }
                    }

                    // Create Button
                    Button {

                    } label: {
                        HStack {
                            Spacer()

                            Text("Create Room")
                                .font(.system(size: 15, weight: .semibold))

                            Spacer()
                        }
                        .foregroundStyle(Color.black)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "AA9DFF"))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var selectedPetIcon: String {
        switch petType {
        case "Dog":
            return "dog.fill"
        case "Cat":
            return "cat.fill"
        case "Bird":
            return "bird.fill"
        case "Rabbit":
            return "hare.fill"
        default:
            return "pawprint.fill"
        }
    }
}

// MARK: - Input

struct CreateRoomInput: View {

    let title: String
    let placeholder: String

    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))

            TextField(
                "",
                text: $text,
                prompt:
                    Text(placeholder)
                    .foregroundStyle(Color.white.opacity(0.2))
            )
            .foregroundStyle(Color(hex: "F0EDE6"))
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "171719"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                Color.white.opacity(0.06),
                                lineWidth: 0.5
                            )
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    CreateRoomView()
}
