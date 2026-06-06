//
//  GalleryView.swift
//  PetHub
//

import PhotosUI
import Supabase
import SwiftUI

// MARK: - GalleryView

struct GalleryView: View {
    let room: PetRoom
    @State private var selectedPhoto: PhotoPost? = nil
    @State private var showCamera = false
    @State private var photos: [PhotoPost] = []

    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    init(room: PetRoom) {
        self.room = room
        _photos = State(initialValue: room.photos)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(room.accent.opacity(0.3))
                        Text("No photos yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color("AppWhiteText"))
                        Text("Tap the camera to capture a moment")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppBorder").opacity(1.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(
                                Array(photos.enumerated()),
                                id: \.element.id
                            ) { index, photo in
                                PhotoCell(photo: photo, index: index)
                                    .onTapGesture { selectedPhoto = photo }
                            }
                        }
                        .padding(.top, 2)
                        Spacer().frame(height: 100)
                    }
                }
            }

            // Camera FAB
            Button {
                showCamera = true
            } label: {
                ZStack {
                    Circle()
                        .fill(room.accent)
                        .frame(width: 52, height: 52)
                        .shadow(
                            color: room.accent.opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color("AppAccentText"))
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .task {
            await fetchPhotos()
        }
        // Pass a binding so PhotoDetailView can write comments back
        .sheet(item: $selectedPhoto) { photo in
            if let idx = photos.firstIndex(where: { $0.id == photo.id }) {
                PhotoDetailView(photo: $photos[idx], room: room)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CaptureAndPostView(
                accent: room.accent,
                onPost: { image, caption in
                    let newPhoto = PhotoPost(
                        id: UUID(),
                        image: image,
                        emoji: "📸",
                        backgroundHex: room.accentHex,
                        caption: caption,
                        postedBy: .me,
                        timestamp: Date(),
                        likeCount: 0,
                        comments: [],
                        isLiked: false
                    )
                    withAnimation { photos.insert(newPhoto, at: 0) }
                },
                roomId: room.id.uuidString
            )
        }
    }
    private func fetchPhotos() async {
        do {
            struct SupabasePhoto: Codable {
                let id: UUID
                let imageUrl: String
                let caption: String
                let createdAt: Date?

                enum CodingKeys: String, CodingKey {
                    case id
                    case imageUrl = "image_url"
                    case caption
                    case createdAt = "created_at"
                }
            }

            let fetched: [SupabasePhoto] =
                try await supabase
                .from("photo_posts")
                .select()
                .eq("room_id", value: room.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.photos = fetched.map { p in
                    PhotoPost(
                        id: p.id,
                        image: nil,
                        imageUrl: p.imageUrl,
                        emoji: "📸",
                        backgroundHex: room.accentHex,
                        caption: p.caption,
                        postedBy: .me,
                        timestamp: p.createdAt ?? Date(),
                        likeCount: 0,
                        comments: [],
                        isLiked: false
                    )
                }
            }
        } catch {
            print("Fetch photos error: \(error)")

        }
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

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
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage { onPick(img) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Cell

struct PhotoCell: View {
    let photo: PhotoPost
    let index: Int
    @State private var loadedImage: UIImage? = nil

    var isWide: Bool { index % 5 == 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let img = loadedImage ?? photo.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(photo.background)
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 6) {
                    Label("\(photo.likeCount)", systemImage: "heart.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color("AppText"))

                    if !photo.comments.isEmpty {
                        Label(
                            "\(photo.comments.count)",
                            systemImage: "bubble.left.fill"
                        )
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color("AppText"))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 7)
            }
        }
        .aspectRatio(isWide ? 2 : 1, contentMode: .fit)
        .gridCellColumns(isWide ? 2 : 1)
        .clipped()
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let urlString = photo.imageUrl, let url = URL(string: urlString)
        else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url)
        else { return }
        loadedImage = UIImage(data: data)
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    @Binding var photo: PhotoPost
    let room: PetRoom
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @FocusState private var commentFocused: Bool
    @State private var loadedImage: UIImage? = nil

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("AppDivider"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color("AppAdaptiveWhite").opacity(0.8))
                        }
                    }
                    Spacer()
                    Button {
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17))
                            .foregroundStyle(Color("AppWhiteText"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Photo
                ZStack {
                    if let img = loadedImage ?? photo.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(photo.background)
                            .frame(height: 300)
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding(.horizontal, 16)
                .task {
                    await loadImage()
                }

                // Author + like
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        MemberAvatar(member: photo.postedBy, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(photo.postedBy.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color("AppText"))
                            Text(photo.timestamp.relativeString())
                                .font(.system(size: 11))
                                .foregroundStyle(Color("AppWhiteText"))
                        }
                        Spacer()
                        Button {
                            withAnimation(
                                .spring(response: 0.3, dampingFraction: 0.5)
                            ) {
                                photo.isLiked.toggle()
                                photo.likeCount += photo.isLiked ? 1 : -1
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(
                                    systemName: photo.isLiked
                                        ? "heart.fill" : "heart"
                                )
                                .font(.system(size: 17))
                                .foregroundStyle(
                                    photo.isLiked
                                        ? Color(hex: "FF6B6B")
                                        : Color("AppSubtext")
                                )
                                Text("\(photo.likeCount)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color("AppWhiteText"))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.system(size: 14))
                            .foregroundStyle(Color("AppText"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider()
                    .background(Color("AppDivider"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                // Comments list
                ScrollView {
                    VStack(spacing: 0) {
                        if photo.comments.isEmpty {
                            Text("No comments yet. Be first!")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("AppPlaceholder"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(photo.comments) { comment in
                                CommentRow(message: comment)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Comment input — now actually posts
                HStack(spacing: 10) {
                    MemberAvatar(member: .me, size: 30)
                    TextField(
                        "",
                        text: $commentText,
                        prompt: Text("Add a comment…").foregroundStyle(
                            Color("AppPlaceholder")
                        )
                    )
                    .focused($commentFocused)
                    .foregroundStyle(Color("AppText"))
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("AppDivider"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        Color("AppBorder"),
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .onSubmit { submitComment() }

                    if !commentText.isEmpty {
                        Button {
                            submitComment()
                        } label: {
                            ZStack {
                                Circle().fill(Color(hex: "AA9DFF")).frame(
                                    width: 34,
                                    height: 34
                                )
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color("AppAccentText"))
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(Color("AppBackground"))
                        .overlay(
                            Rectangle()
                                .fill(Color("AppDivider").opacity(0.6))
                                .frame(height: 0.5),
                            alignment: .top
                        )
                )
            }
        }
        .animation(.easeInOut(duration: 0.15), value: commentText.isEmpty)
    }

    private func loadImage() async {
        guard let urlString = photo.imageUrl, let url = URL(string: urlString)
        else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url)
        else { return }
        loadedImage = UIImage(data: data)
    }
    // MARK: - Submit comment

    private func submitComment() {
        let trimmed = commentText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }

        let newComment = Message(
            sender: .me,
            content: .text(trimmed),
            isOwn: true
        )
        withAnimation(.easeIn(duration: 0.15)) {
            photo.comments.append(newComment)
        }
        commentText = ""
        commentFocused = false
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let sender = message.sender {
                MemberAvatar(member: sender, size: 28)
            }
            VStack(alignment: .leading, spacing: 3) {
                if let sender = message.sender {
                    Text(sender.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color("AppSubtext"))
                }
                if case .text(let text) = message.content {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppText"))
                }
                Text(message.timestamp.relativeString())
                    .font(.system(size: 10))
                    .foregroundStyle(Color("AppPlaceholder"))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    GalleryView(room: .mochi)
        .background(Color("AppBackground"))
}
