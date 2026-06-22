//
//  CaptureAndPostView.swift
//  PetHub
//

import Supabase
import SwiftUI

struct CaptureAndPostView: View {
    @Environment(\.dismiss) private var dismiss
    var accent: Color
    var onPost: (UIImage, String) -> Void
    var roomId: String
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    var onShowUpgrade: (() -> Void)? = nil

    @State private var capturedImage: UIImage? = nil
    @State private var caption = ""
    @State private var isUploading = false

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            if let img = capturedImage {
                // Caption screen
                VStack(spacing: 0) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 420)
                        .clipped()
                        .ignoresSafeArea(edges: .top)

                    Spacer()

                    VStack(spacing: 16) {
                        TextField(
                            "",
                            text: $caption,
                            prompt: Text("Add a caption…")
                                .foregroundStyle(PHTheme.subtext)
                        )
                        .foregroundStyle(PHTheme.text)
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(PHTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            PHTheme.border,
                                            lineWidth: 0.5
                                        )
                                )
                        )

                        Button {
                            Task { await uploadAndPost(img) }
                        } label: {
                            Group {
                                if isUploading {
                                    ProgressView()
                                        .tint(PHTheme.accent)
                                } else {
                                    Text("Post")
                                        .font(
                                            .system(size: 15, weight: .semibold)
                                        )
                                        .foregroundStyle(PHTheme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(accent)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    Button {
                        capturedImage = nil
                    } label: {
                        Text("Retake")
                            .font(.system(size: 13))
                            .foregroundStyle(PHTheme.subtext)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 44)
                }

            } else {
                // Camera directly embedded
                CameraView(
                    onCapture: { img in
                        capturedImage = img
                    },
                    onCancel: {
                        dismiss()
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
    
    private func uploadAndPost(_ image: UIImage) async {
        isUploading = true
        
        let hasUnlimitedPhotos = await MainActor.run { subscriptionManager.hasUnlimitedPhotos }
        let maxPhotos = await MainActor.run { subscriptionManager.maxPhotosTotal }
        
        do {
            let user = try await supabase.auth.session.user

            if !hasUnlimitedPhotos {
                struct PhotoCount: Codable { let id: UUID }
                let photos: [PhotoCount] = try await supabase
                    .from("photo_posts")
                    .select()
                    .eq("posted_by", value: user.id.uuidString)
                    .execute()
                    .value

                if photos.count >= maxPhotos {
                    await MainActor.run { isUploading = false }
                    onShowUpgrade?()
                    return
                }
            }

            // Compress image
            guard let data = image.jpegData(compressionQuality: 0.7) else { return }

            // Upload to Supabase Storage
            let fileName = "\(UUID().uuidString).jpg"
            let path = "rooms/\(roomId)/\(fileName)"

            try await supabase.storage
                .from("photos")
                .upload(path, data: data, options: .init(contentType: "image/jpeg"))

            // Get public URL
            let url = try supabase.storage
                .from("photos")
                .getPublicURL(path: path)

            // Save to photos table
            let photoId = UUID().uuidString

            try await supabase
                .from("photo_posts")
                .insert([
                    "id": photoId,
                    "room_id": roomId,
                    "image_url": url.absoluteString,
                    "caption": caption,
                    "posted_by": user.id.uuidString,
                ])
                .execute()

            // Activity V1: photoAdded
            try await supabase
                .from("activities")
                .insert([
                    "type": "photo_added",
                    "actor_id": user.id.uuidString,
                    "room_id": roomId,
                    "photo_id": photoId,
                    "body": "A new photo was added"
                ])
                .execute()

            onPost(image, caption)
            dismiss()
        } catch {
            #if DEBUG
            print("CaptureAndPostView.swift:184 error:", error)
            #endif
        }
        isUploading = false
    }
}

// MARK: - Inline Camera (no nesting)

struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        var onCapture: (UIImage) -> Void
        var onCancel: () -> Void

        init(
            onCapture: @escaping (UIImage) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                onCapture(img)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
