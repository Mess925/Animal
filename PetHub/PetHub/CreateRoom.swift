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
    @State private var age = ""
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
            && !age.trimmingCharacters(in: .whitespaces).isEmpty
            && (petType != "Other"
                || !customPetType.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        ZStack {
            PHTheme.background
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
                                        .fill(PHTheme.divider.opacity(0.6))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "chevron.left")
                                        .foregroundStyle(
                                            PHTheme.textOnAccent
                                        )
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

                    // Preview Card
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

                    // Form
                    VStack(spacing: 18) {

                        // Colors
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

                        // Pet Name
                        CreateRoomInput(
                            title: "Pet Name",
                            placeholder: "e.g. Mochi",
                            text: $petName,
                            isRequired: true
                        )

                        // Pet Type
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
                                                    petType == type
                                                        ? PHTheme.accent
                                                        : .white.opacity(0.45)
                                                )
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule().fill(
                                                        Color.white.opacity(
                                                            0.05
                                                        )
                                                    )
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        // Custom type
                        if petType == "Other" {
                            CreateRoomInput(
                                title: "Custom Type",
                                placeholder: "e.g. Hamster",
                                text: $customPetType,
                                isRequired: true
                            )
                        }

                        // Breed + Age
                        HStack(spacing: 14) {
                            CreateRoomInput(
                                title: "Breed",
                                placeholder: "e.g. Golden Retriever",
                                text: $breed,
                                isRequired: true
                            )

                            CreateRoomInput(
                                title: "Age",
                                placeholder: "e.g. 2",
                                text: $age,
                                isRequired: true,
                                keyboardType: .numberPad
                            )
                        }

                        // Bio
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Bio").font(
                                    .system(size: 12, weight: .medium)
                                ).foregroundStyle(PHTheme.subtext)
                                Text("optional").font(.system(size: 10))
                                    .foregroundStyle(PHTheme.placeholder)
                            }
                            ZStack(alignment: .topLeading) {
                                if bio.isEmpty {
                                    Text("Tell something about your pet...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(
                                            PHTheme.placeholder
                                        ).padding(.top, 14).padding(
                                            .leading,
                                            16
                                        )
                                }
                                TextEditor(text: $bio).scrollContentBackground(
                                    .hidden
                                ).foregroundStyle(PHTheme.text).frame(
                                    height: 120
                                ).padding(12)
                            }.background(
                                RoundedRectangle(cornerRadius: 22).fill(
                                    PHTheme.surface2
                                ).overlay(
                                    RoundedRectangle(cornerRadius: 22).stroke(
                                        PHTheme.divider,
                                        lineWidth: 0.5
                                    )
                                )
                            )
                        }
                    }

                    // Create Button
                    Button {
                        guard canCreate else { return }
                        Task { await createRoom() }
                    } label: {
                        Text("Create Room")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                canCreate
                                    ? PHTheme.accent
                                    : PHTheme.border
                            )
                            .foregroundStyle(
                                canCreate ? .white : PHTheme.placeholder
                            )
                            .cornerRadius(20)
                    }
                    .disabled(!canCreate)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .onChange(of: age) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue { age = filtered }
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
                    "age": age,
                    "icon": selectedPetIcon,
                    "accent_hex": roomColors.first(where: { $0.0 == selectedColor })?.1 ?? "AA9DFF",
                    "owner_id": user.id.uuidString
                ])
                .execute()

            // Add owner to room_members ← THIS WAS REMOVED
//            try await supabase
//                .from("room_members")
//                .insert([
//                    "room_id": roomId.uuidString,
//                    "user_id": user.id.uuidString,
//                    "role": "owner"
//                ])
//                .execute()

            let newRoom = SupabaseRoom(
                id: roomId,
                name: petName,
                breed: breed,
                age: age,
                icon: selectedPetIcon,
                accentHex: roomColors.first(where: { $0.0 == selectedColor })?.1 ?? "AA9DFF",
                imageUrl: nil
            )
            dismiss()
            onComplete?(newRoom.toPetRoom())
        } catch {
            #if DEBUG
            print("CreateRoom.swift:353 error:", error)
            #endif
        }
    }
    
    private var breedAgePreview: String {
        let b = breed.isEmpty ? displayPetType : breed
        let a = age.isEmpty ? "" : " · \(age)"
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
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
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
