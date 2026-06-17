//
//  GalleryView.swift
//  PetHub
//

import PhotosUI
import Supabase
import SwiftUI

// MARK: - Photo Like Model

struct PhotoLike: Codable {
    let id: UUID
    let photoId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
    }
}

// MARK: - Photo Comment Model

struct PhotoComment: Codable, Identifiable {
    let id: UUID
    let photoId: UUID
    let userId: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
        case body
        case createdAt = "created_at"
    }
}

// MARK: - GalleryView

struct GalleryView: View {
    let room: PetRoom
    @State private var selectedPhoto: PhotoPost? = nil
    @State private var showCamera = false
    @State private var photos: [PhotoPost] = []
    @State private var showUpgradeSheet = false
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

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
                            .foregroundStyle(PHTheme.subtext)
                        Text("Tap the camera to capture a moment")
                            .font(.system(size: 13))
                            .foregroundStyle(PHTheme.placeholder)
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
                        .foregroundStyle(PHTheme.accent)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .task {
            await fetchPhotos()
        }
        .sheet(isPresented: $showUpgradeSheet) { UpgradeView() }
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
                roomId: room.id.uuidString,
                onShowUpgrade: { showUpgradeSheet = true }
            )
            .environmentObject(subscriptionManager)
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
    @State private var likeCount = 0
    @State private var commentCount = 0

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
                    Label("\(likeCount)", systemImage: "heart.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)

                    if commentCount > 0 {
                        Label(
                            "\(commentCount)",
                            systemImage: "bubble.left.fill"
                        )
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
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
            await fetchCounts()
        }
    }

    private func loadImage() async {
        guard let urlString = photo.imageUrl, let url = URL(string: urlString)
        else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url)
        else { return }
        loadedImage = UIImage(data: data)
    }

    private func fetchCounts() async {
        do {
            let likes: [PhotoLike] =
                try await supabase
                .from("photo_likes")
                .select()
                .eq("photo_id", value: photo.id.uuidString)
                .execute()
                .value
            likeCount = likes.count

            let comments: [PhotoComment] =
                try await supabase
                .from("photo_comments")
                .select()
                .eq("photo_id", value: photo.id.uuidString)
                .execute()
                .value
            commentCount = comments.count
        } catch {
        }
    }
}

struct CommentWithName: Identifiable {
    let id: UUID
    let body: String
    let createdAt: Date
    let userName: String
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    @Binding var photo: PhotoPost
    let room: PetRoom
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @FocusState private var commentFocused: Bool
    @State private var loadedImage: UIImage? = nil
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var commentsWithNames: [CommentWithName] = []

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(PHTheme.divider)
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    PHTheme.textOnAccent.opacity(0.8)
                                )
                        }
                    }
                    Spacer()
                    Button {
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17))
                            .foregroundStyle(PHTheme.subtext)
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
                        ProgressView().tint(.white)
                    }
                }
                .padding(.horizontal, 16)

                // Author + like
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        MemberAvatar(member: photo.postedBy, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(photo.postedBy.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PHTheme.text)
                            Text(photo.timestamp.relativeString())
                                .font(.system(size: 11))
                                .foregroundStyle(PHTheme.subtext)
                        }
                        Spacer()
                        Button {
                            Task { await toggleLike() }
                        } label: {
                            HStack(spacing: 5) {
                                Image(
                                    systemName: isLiked ? "heart.fill" : "heart"
                                )
                                .font(.system(size: 17))
                                .foregroundStyle(
                                    isLiked
                                        ? PHTheme.accent3
                                        : PHTheme.subtext
                                )
                                Text("\(likeCount)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(PHTheme.subtext)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.system(size: 14))
                            .foregroundStyle(PHTheme.text)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider()
                    .background(PHTheme.divider)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                // Comments list
                ScrollView {
                    VStack(spacing: 0) {
                        if commentsWithNames.isEmpty {
                            Text("No comments yet. Be first!")
                                .font(.system(size: 13))
                                .foregroundStyle(PHTheme.placeholder)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(commentsWithNames) { comment in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(PHTheme.accent.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(
                                                String(
                                                    comment.userName.prefix(1)
                                                ).uppercased()
                                            )
                                            .font(
                                                .system(
                                                    size: 11,
                                                    weight: .semibold
                                                )
                                            )
                                            .foregroundStyle(
                                                PHTheme.accent
                                            )
                                        )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(comment.userName)
                                            .font(
                                                .system(
                                                    size: 11,
                                                    weight: .semibold
                                                )
                                            )
                                            .foregroundStyle(
                                                PHTheme.subtext
                                            )
                                        Text(comment.body)
                                            .font(.system(size: 13))
                                            .foregroundStyle(PHTheme.text)
                                        Text(comment.createdAt.relativeString())
                                            .font(.system(size: 10))
                                            .foregroundStyle(
                                                PHTheme.placeholder
                                            )
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Comment input
                HStack(spacing: 10) {
                    MemberAvatar(member: .me, size: 30)
                    TextField(
                        "",
                        text: $commentText,
                        prompt: Text("Add a comment…").foregroundStyle(
                            PHTheme.placeholder
                        )
                    )
                    .focused($commentFocused)
                    .foregroundStyle(PHTheme.text)
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(PHTheme.divider)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(PHTheme.border, lineWidth: 0.5)
                            )
                    )
                    .onSubmit { submitComment() }

                    if !commentText.isEmpty {
                        Button {
                            submitComment()
                        } label: {
                            ZStack {
                                Circle().fill(PHTheme.accent).frame(
                                    width: 34,
                                    height: 34
                                )
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PHTheme.accent)
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
                        .fill(PHTheme.background)
                        .overlay(
                            Rectangle()
                                .fill(PHTheme.divider.opacity(0.6))
                                .frame(height: 0.5),
                            alignment: .top
                        )
                )
            }
        }
        .task {
            await loadImage()
            await fetchLikesAndComments()
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

    private func fetchLikesAndComments() async {
        do {
            let user = try await supabase.auth.session.user

            let likes: [PhotoLike] =
                try await supabase
                .from("photo_likes")
                .select()
                .eq("photo_id", value: photo.id.uuidString)
                .execute()
                .value

            likeCount = likes.count
            isLiked = likes.contains { $0.userId == user.id }

            let fetched: [PhotoComment] =
                try await supabase
                .from("photo_comments")
                .select()
                .eq("photo_id", value: photo.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Fetch names for each comment
            var result: [CommentWithName] = []
            for comment in fetched {
                let profiles: [UserProfile] =
                    try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: comment.userId.uuidString)
                    .execute()
                    .value
                let name = profiles.first?.name ?? "Unknown"
                result.append(
                    CommentWithName(
                        id: comment.id,
                        body: comment.body,
                        createdAt: comment.createdAt,
                        userName: name
                    )
                )
            }

            await MainActor.run {
                commentsWithNames = result
            }
        } catch {
        }
    }

    private func toggleLike() async {
        do {
            let user = try await supabase.auth.session.user
            if isLiked {
                try await supabase
                    .from("photo_likes")
                    .delete()
                    .eq("photo_id", value: photo.id.uuidString)
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                isLiked = false
                likeCount -= 1
            } else {
                try await supabase
                    .from("photo_likes")
                    .insert([
                        "photo_id": photo.id.uuidString,
                        "user_id": user.id.uuidString,
                    ])
                    .execute()

                // Insert activity
                try await supabase
                    .from("activities")
                    .insert([
                        "type": "like",
                        "actor_id": user.id.uuidString,
                        "room_id": room.id.uuidString,
                        "photo_id": photo.id.uuidString,
                    ])
                    .execute()

                isLiked = true
                likeCount += 1
            }
        } catch {
        }
    }

    private func postComment(_ text: String) async {
        do {
            let user = try await supabase.auth.session.user
            try await supabase
                .from("photo_comments")
                .insert([
                    "photo_id": photo.id.uuidString,
                    "user_id": user.id.uuidString,
                    "body": text,
                ])
                .execute()

            // Add this
            try await supabase
                .from("activities")
                .insert([
                    "type": "comment",
                    "actor_id": user.id.uuidString,
                    "room_id": room.id.uuidString,
                    "photo_id": photo.id.uuidString,
                    "body": text,
                ])
                .execute()

            await fetchLikesAndComments()
        } catch {
        }
    }

    private func submitComment() {
        let trimmed = commentText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }
        Task { await postComment(trimmed) }
        commentText = ""
        commentFocused = false
    }
}

// MARK: - Comment Row (kept for compatibility)

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
                        .foregroundStyle(PHTheme.subtext)
                }
                if case .text(let text) = message.content {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(PHTheme.text)
                }
                Text(message.timestamp.relativeString())
                    .font(.system(size: 10))
                    .foregroundStyle(PHTheme.placeholder)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

//#Preview {
//    GalleryView(room: .mochi)
//        .background(PHTheme.background)
//}
