//
//  CaptureAndPostView.swift
//  PetHub
//

import SwiftUI

struct CaptureAndPostView: View {
    @Environment(\.dismiss) private var dismiss
    var accent: Color
    var onPost: (UIImage, String) -> Void

    @State private var capturedImage: UIImage? = nil
    @State private var caption = ""

    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()

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
                                .foregroundStyle(Color.white.opacity(0.25))
                        )
                        .foregroundStyle(Color(hex: "F0EDE6"))
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "1C1C1F"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                        )

                        Button {
                            onPost(img, caption)
                            dismiss()
                        } label: {
                            Text("Post")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "1a1630"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(accent)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    Button {
                        capturedImage = nil
                    } label: {
                        Text("Retake")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 44)
                }

            } else {
                // Camera directly embedded
                CameraView(onCapture: { img in
                    capturedImage = img
                }, onCancel: {
                    dismiss()
                })
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
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

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onCapture: (UIImage) -> Void
        var onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                onCapture(img)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
