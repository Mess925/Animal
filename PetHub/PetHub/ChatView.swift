//
//  ChatView.swift
//  PetHub
//

import SwiftUI
import PhotosUI

// MARK: - ChatView

struct ChatView: View {
    let title: String
    let subtitle: String
    let accentHex: String
    let messages: [Message]
    let isGroup: Bool
    let members: [Member]

    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var replyingTo: Message? = nil
    @State private var allMessages: [Message]
    @State private var showPhotoPicker = false
    @FocusState private var inputFocused: Bool
    @State private var selectedImage: UIImage? = nil

    private var accent: Color { Color(hex: accentHex) }

    init(title: String, subtitle: String, accentHex: String, messages: [Message], isGroup: Bool, members: [Member]) {
        self.title = title
        self.subtitle = subtitle
        self.accentHex = accentHex
        self.messages = messages
        self.isGroup = isGroup
        self.members = members
        _allMessages = State(initialValue: messages)
    }

    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()

            VStack(spacing: 0) {
                ChatTopBar(
                    title: title,
                    subtitle: subtitle,
                    accentHex: accentHex,
                    isGroup: isGroup,
                    members: members,
                    onDismiss: { dismiss() }
                )

                Divider().background(Color.white.opacity(0.05))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Text("TODAY")
                                .font(.system(size: 10))
                                .tracking(0.8)
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.vertical, 14)

                            ForEach(allMessages) { message in
                                MessageBubble(
                                    message: message,
                                    isGroup: isGroup,
                                    onReply: { replyingTo = message }
                                )
                                .id(message.id)
                            }

                            Spacer().frame(height: 8).id("bottom")
                        }
                        .padding(.horizontal, 14)
                    }
                    .onChange(of: allMessages.count) {
                        withAnimation { proxy.scrollTo("bottom") }
                    }
                    .onAppear { proxy.scrollTo("bottom") }
                }

                if let reply = replyingTo {
                    ReplyPreviewBar(message: reply, accentHex: accentHex) {
                        replyingTo = nil
                    }
                }

                if let image = selectedImage {
                    HStack {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                selectedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .offset(x: 6, y: -6)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "161618"))
                }

                ChatInputBar(
                    text: $messageText,
                    accentHex: accentHex,
                    hasSelectedImage: selectedImage != nil,
                    isFocused: _inputFocused,
                    onSend: sendMessage,
                    onPhotoTap: { showPhotoPicker = true }
                )
            } // ← closes VStack
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPhotoPicker) {
            PHPickerView { image in
                selectedImage = image
            }
        }
    }

    private func sendMessage() {
        if let image = selectedImage {
            let newMsg = Message(
                sender: .me,
                content: .photo("📸"),
                isOwn: true,
                image: image
            )
            withAnimation(.easeIn(duration: 0.15)) {
                allMessages.append(newMsg)
            }
            selectedImage = nil
            messageText = ""
            replyingTo = nil
            return
        }

        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newMsg = Message(
            sender: .me,
            content: .text(trimmed),
            isOwn: true
        )
        withAnimation(.easeIn(duration: 0.15)) {
            allMessages.append(newMsg)
        }
        messageText = ""
        replyingTo = nil
    }
}

// MARK: - Chat Top Bar

struct ChatTopBar: View {
    let title: String
    let subtitle: String
    let accentHex: String
    let isGroup: Bool
    let members: [Member]
    let onDismiss: () -> Void

    private var accent: Color { Color(hex: accentHex) }

    var body: some View {
        HStack(spacing: 12) {
            Button { onDismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }

            if isGroup {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(accent)
                }
            } else if let member = members.first {
                ZStack(alignment: .bottomTrailing) {
                    MemberAvatar(member: member, size: 38)
                    if member.isOnline {
                        Circle()
                            .fill(Color(hex: "06D6A0"))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color(hex: "0D0D0E"), lineWidth: 1.5))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "F0EDE6"))

                HStack(spacing: 4) {
                    if !isGroup, let member = members.first, member.isOnline {
                        Circle()
                            .fill(Color(hex: "06D6A0"))
                            .frame(width: 6, height: 6)
                    }
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(
                            !isGroup && members.first?.isOnline == true
                                ? Color(hex: "06D6A0")
                                : Color.white.opacity(0.3)
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .padding(.top, 4)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isGroup: Bool
    let onReply: () -> Void

    @State private var showActions = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isOwn {
                Spacer(minLength: 60)
            } else if isGroup, let sender = message.sender {
                MemberAvatar(member: sender, size: 28)
                    .padding(.bottom, 2)
            } else {
                Spacer().frame(width: 0)
            }

            VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 4) {
                if isGroup && !message.isOwn, let sender = message.sender {
                    Text(sender.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(sender.accent.opacity(0.8))
                        .padding(.leading, 4)
                }

                Group {
                    switch message.content {
                    case .text(let text):
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundStyle(message.isOwn ? Color.black.opacity(0.85) : Color(hex: "F0EDE6"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        message.isOwn
                                            ? Color(hex: message.sender?.accentHex ?? "AA9DFF")
                                            : Color.white.opacity(0.08)
                                    )
                            )

                    case .photo:
                        if let img = message.image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 160)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 180, height: 140)
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.white.opacity(0.2))
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .onLongPressGesture { showActions = true }
                .confirmationDialog("", isPresented: $showActions) {
                    Button("Reply") { onReply() }
                    Button("React ❤️") {}
                    Button("Copy") {}
                    Button("Cancel", role: .cancel) {}
                }

                if !message.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(message.reactions.keys.sorted()), id: \.self) { emoji in
                            if let count = message.reactions[emoji] {
                                Text("\(emoji) \(count)")
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.07))
                                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                    )
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                        }
                    }
                }

                Text(message.timestamp.timeString())
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.horizontal, 4)
            }

            if !message.isOwn {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Reply Reference

struct ReplyReference: View {
    let message: Message
    let isOwn: Bool

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: message.sender?.accentHex ?? "AA9DFF").opacity(0.6))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.sender?.name ?? "")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: message.sender?.accentHex ?? "AA9DFF").opacity(0.8))

                Group {
                    switch message.content {
                    case .text(let t): Text(t).lineLimit(1)
                    case .photo: Label("Photo", systemImage: "photo")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Reply Preview Bar

struct ReplyPreviewBar: View {
    let message: Message
    let accentHex: String
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color(hex: accentHex))
                .frame(width: 2)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(message.sender?.name ?? "message")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: accentHex))

                Group {
                    switch message.content {
                    case .text(let t): Text(t).lineLimit(1)
                    case .photo: Label("Photo", systemImage: "photo")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
            }

            Spacer()

            Button { onCancel() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "161618"))
        .overlay(Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5), alignment: .top)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    let accentHex: String
    let hasSelectedImage: Bool           // ← fix: was missing from the original
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    let onPhotoTap: () -> Void

    private var accent: Color { Color(hex: accentHex) }
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasSelectedImage
    }

    var body: some View {
        HStack(spacing: 8) {
            Button { onPhotoTap() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.5))
                        .frame(width: 38, height: 38)
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            TextField(
                "",
                text: $text,
                prompt: Text("Message…").foregroundStyle(Color.white.opacity(0.2))
            )
            .focused($isFocused)
            .foregroundStyle(Color(hex: "F0EDE6"))
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                    )
            )

            // ← fix: was a Button wrapping another Button; collapsed into one
            Button {
                if canSend { onSend() }
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? accent : Color.white.opacity(0.07))
                        .frame(width: 38, height: 38)
                    Image(systemName: canSend ? "arrow.up" : "mic.fill")
                        .font(.system(size: text.isEmpty ? 15 : 16, weight: .semibold))
                        .foregroundStyle(text.isEmpty ? Color.white.opacity(0.3) : Color.black.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.25), value: text.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(hex: "0D0D0E"))
                .overlay(Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - PHPicker for chat

struct PHPickerView: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    if let img = image as? UIImage { self.onPick(img) }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView(
        title: "Mochi's Room",
        subtitle: "4 members",
        accentHex: "AA9DFF",
        messages: PetRoom.mochi.groupMessages,
        isGroup: true,
        members: PetRoom.mochi.members
    )
}
