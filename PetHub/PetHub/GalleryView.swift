
//
//  GalleryView.swift
//  PetHub
//

import SwiftUI

// MARK: - GalleryView

struct GalleryView: View {
    let room: PetRoom
    @State private var selectedPhoto: PhotoPost? = nil
    @State private var showCamera = false

    // 3-column grid
    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(room.photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoCell(photo: photo, index: index)
                            .onTapGesture { selectedPhoto = photo }
                    }
                }
                .padding(.top, 2)

                Spacer().frame(height: 100)
            }

            // Camera FAB
            Button { showCamera = true } label: {
                ZStack {
                    Circle()
                        .fill(room.accent)
                        .frame(width: 52, height: 52)
                        .shadow(color: room.accent.opacity(0.4), radius: 12, x: 0, y: 4)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.black.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, room: room)
        }
    }
}

// MARK: - Photo Cell

struct PhotoCell: View {
    let photo: PhotoPost
    let index: Int

    // Every 5th photo spans 2 columns
    var isWide: Bool { index % 5 == 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Background
                Rectangle()
                    .fill(photo.background)

                // Emoji
                Text(photo.emoji)
                    .font(.system(size: isWide ? 56 : 38))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Stats
                HStack(spacing: 6) {
                    Label("\(photo.likeCount)", systemImage: "heart.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))

                    if !photo.comments.isEmpty {
                        Label("\(photo.comments.count)", systemImage: "bubble.left.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 7)
            }
        }
        .aspectRatio(isWide ? 2 : 1, contentMode: .fit)
        .gridCellColumns(isWide ? 2 : 1)
        .clipped()
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    let photo: PhotoPost
    let room: PetRoom
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isLiked: Bool
    @State private var likeCount: Int

    init(photo: PhotoPost, room: PetRoom) {
        self.photo = photo
        self.room = room
        _isLiked = State(initialValue: photo.isLiked)
        _likeCount = State(initialValue: photo.likeCount)
    }

    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    Button {} label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Photo
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(photo.background)
                        .frame(height: 300)
                    Text(photo.emoji)
                        .font(.system(size: 96))
                }
                .padding(.horizontal, 16)

                // Caption + actions
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        MemberAvatar(member: photo.postedBy, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(photo.postedBy.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "F0EDE6"))
                            Text(photo.timestamp.relativeString())
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        Spacer()

                        // Like button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                isLiked.toggle()
                                likeCount += isLiked ? 1 : -1
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 17))
                                    .foregroundStyle(isLiked ? Color(hex: "FF6B6B") : Color.white.opacity(0.4))
                                Text("\(likeCount)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "F0EDE6"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                // Comments
                ScrollView {
                    VStack(spacing: 0) {
                        if photo.comments.isEmpty {
                            Text("No comments yet. Be first!")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.2))
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

                // Comment input
                HStack(spacing: 10) {
                    MemberAvatar(member: .me, size: 30)

                    TextField(
                        "",
                        text: $commentText,
                        prompt: Text("Add a comment…").foregroundStyle(Color.white.opacity(0.2))
                    )
                    .foregroundStyle(Color(hex: "F0EDE6"))
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                            )
                    )

                    if !commentText.isEmpty {
                        Button {} label: {
                            ZStack {
                                Circle().fill(Color(hex: "AA9DFF")).frame(width: 34, height: 34)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.8))
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
                        .fill(Color(hex: "0D0D0E"))
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 0.5),
                            alignment: .top
                        )
                )
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.15), value: commentText.isEmpty)
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
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                if case .text(let text) = message.content {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "F0EDE6"))
                }
                Text(message.timestamp.relativeString())
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    GalleryView(room: .mochi)
        .background(Color(hex: "0D0D0E"))
        .preferredColorScheme(.dark)
}
