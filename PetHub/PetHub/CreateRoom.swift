//
//  CreateRoom.swift
//  PetHub
//

import Foundation
import SwiftUI
import UIKit
import Supabase

struct CreateRoomView: View {

    var onComplete: ((PetRoom) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var petName = ""
    @State private var petType = "Dog"
    @State private var breed = ""

    @State private var birthYear = ""
    @State private var birthMonth = ""

    @State private var bio = ""

    @State private var customPetType = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false

    @State private var selectedColor: Color = PHTheme.accent

    private let petTypes = ["Dog", "Cat", "Bird", "Rabbit", "Other"]

    private let roomColors: [(Color, String)] = [
        (PHTheme.accent, "AA9DFF"),
        (PHTheme.accent3, "FF6B6B"),
        (Color(hex: "4ECDC4"), "4ECDC4"),
        (Color(hex: "FFD166"), "FFD166"),
        (PHTheme.success, "06D6A0"),
        (Color(hex: "F72585"), "F72585"),
    ]

    private var displayPetType: String {
        petType == "Other" ? customPetType : petType
    }

    private var canCreate: Bool {
        !petName.trimmingCharacters(in: .whitespaces).isEmpty
            && !breed.trimmingCharacters(in: .whitespaces).isEmpty
            && !birthYear.trimmingCharacters(in: .whitespaces).isEmpty
            && !birthMonth.trimmingCharacters(in: .whitespaces).isEmpty
            && (petType != "Other"
                || !customPetType.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        ZStack {
            PHTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(PHTheme.divider.opacity(0.6))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "chevron.left")
                                        .foregroundStyle(PHTheme.textOnAccent)
                                }
                            }

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Create Room")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(PHTheme.text)

                            Text("Make a private space for your pet.")
                                .font(.system(size: 14))
                                .foregroundStyle(PHTheme.subtext)
                        }
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(selectedColor.opacity(0.12))
                            .frame(height: 220)

                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(selectedColor.opacity(0.18))
                                    .frame(width: 90, height: 90)

                                if petType == "Other" {
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 28))
                                            .foregroundStyle(selectedColor)
                                    }
                                } else {
                                    Image(systemName: selectedPetIcon)
                                        .font(.system(size: 42))
                                        .foregroundStyle(selectedColor)
                                }
                            }
                            .onTapGesture {
                                if petType == "Other" {
                                    showImagePicker = true
                                }
                            }

                            VStack(spacing: 4) {
                                Text(petName.isEmpty ? "Your Pet" : petName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(PHTheme.text)

                                Text(breedAgePreview)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PHTheme.subtext)
                            }
                        }
                    }

                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Room Color")
                                .foregroundStyle(PHTheme.subtext)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(roomColors, id: \.1) { color, _ in
                                        Button {
                                            selectedColor = color
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                                }
                            }
                        }

                        CreateRoomInput(
                            title: "Pet Name",
                            placeholder: "e.g. Mochi",
                            text: $petName,
                            isRequired: true
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pet Type")
                                .foregroundStyle(PHTheme.subtext)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(petTypes, id: \.self) { type in
                                        Button {
                                            petType = type
                                            if type != "Other" {
                                                customPetType = ""
                                                selectedImage = nil
                                            }
                                        } label: {
                                            Text(type)
                                                .foregroundStyle(
                                                    petType == type ? .white : selectedColor
                                                )
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule().fill(
                                                        petType == type
                                                            ? selectedColor
                                                            : selectedColor.opacity(0.18)
                                                    )
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        if petType == "Other" {
                            CreateRoomInput(
                                title: "Custom Type",
                                placeholder: "e.g. Hamster",
                                text: $customPetType,
                                isRequired: true
                            )
                        }

                        HStack(spacing: 14) {
                            CreateRoomInput(
                                title: "Breed",
                                placeholder: "e.g. Golden Retriever",
                                text: $breed,
                                isRequired: true
                            )

                        }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                CreateRoomInput(
                                    title: "Birth Year",
                                    placeholder: "2022",
                                    text: $birthYear,
                                    isRequired: true,
                                    keyboardType: .numberPad
                                )

                                CreateRoomInput(
                                    title: "Month",
                                    placeholder: "6",
                                    text: $birthMonth,
                                    isRequired: true,
                                    keyboardType: .numberPad
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Bio")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PHTheme.subtext)

                                Text("optional")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PHTheme.placeholder)
                            }

                            ZStack(alignment: .topLeading) {
                                if bio.isEmpty {
                                    Text("Tell something about your pet...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(PHTheme.placeholder)
                                        .padding(.top, 14)
                                        .padding(.leading, 16)
                                }

                                TextEditor(text: $bio)
                                    .scrollContentBackground(.hidden)
                                    .foregroundStyle(PHTheme.text)
                                    .frame(height: 120)
                                    .padding(12)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(PHTheme.surface2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(PHTheme.divider, lineWidth: 0.5)
                                    )
                            )
                        }
                    }

                    Button {
                        guard canCreate else { return }
                        Task { await createRoom() }
                    } label: {
                        Text("Create Room")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canCreate ? PHTheme.accent : PHTheme.border)
                            .foregroundStyle(PHTheme.background)
                            .cornerRadius(20)
                    }
                    .disabled(!canCreate)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .onChange(of: birthYear) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue { birthYear = filtered }
        }
        .onChange(of: birthMonth) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue {
                birthMonth = filtered
                return
            }

            if let month = Int(filtered), month > 12 {
                birthMonth = "12"
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }

    private var selectedPetIcon: String {
        switch petType {
        case "Dog": return "dog.fill"
        case "Cat": return "cat.fill"
        case "Bird": return "bird.fill"
        case "Rabbit": return "hare.fill"
        default: return "pawprint.fill"
        }
    }

    private var calculatedAgeText: String {
        guard let year = Int(birthYear),
              let month = Int(birthMonth),
              month >= 1,
              month <= 12
        else {
            return ""
        }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        var years = currentYear - year
        var months = currentMonth - month

        if months < 0 {
            years -= 1
            months += 12
        }

        if years < 0 {
            return ""
        }

        var parts: [String] = []

        if years > 0 {
            parts.append("\(years) \(years == 1 ? "year" : "years")")
        }

        if months > 0 {
            parts.append("\(months) \(months == 1 ? "month" : "months")")
        }

        if parts.isEmpty {
            return "Less than 1 month"
        }

        return parts.joined(separator: " ")
    }

    private func createRoom() async {
        do {
            let user = try await supabase.auth.session.user
            let roomId = UUID()

            try await supabase
                .from("rooms")
                .insert([
                    "id": roomId.uuidString,
                    "name": petName,
                    "breed": breed,
                    "age": calculatedAgeText,
                    "birth_year": birthYear,
                    "birth_month": birthMonth,
                    "icon": selectedPetIcon,
                    "accent_hex": roomColors.first(where: { $0.0 == selectedColor })?.1 ?? "AA9DFF",
                    "owner_id": user.id.uuidString
                ])
                .execute()

            let newRoom = SupabaseRoom(
                id: roomId,
                name: petName,
                breed: breed,
                age: calculatedAgeText,
                birthYear: Int(birthYear) ?? 0,
                birthMonth: Int(birthMonth) ?? 0,
                icon: selectedPetIcon,
                accentHex: roomColors.first(where: { $0.0 == selectedColor })?.1 ?? "AA9DFF",
                imageUrl: nil
            )

            dismiss()
            onComplete?(newRoom.toPetRoom())
        } catch {
            #if DEBUG
            print("CreateRoom.swift createRoom error:", error)
            #endif
        }
    }

    private var breedAgePreview: String {
        let b = breed.isEmpty ? displayPetType : breed
        let a = calculatedAgeText.isEmpty ? "" : " · \(calculatedAgeText)"
        return b + a
    }
}

// MARK: - Input

struct CreateRoomInput: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isRequired: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboardType)
            .padding()
            .background(PHTheme.surface2)
            .cornerRadius(18)
            .foregroundStyle(PHTheme.text)
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate,
        UIImagePickerControllerDelegate
    {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }

            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    CreateRoomView()
}
