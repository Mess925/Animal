//
//  ChatView.swift
//  PetHub
//

import PhotosUI
import Supabase
import SwiftUI

// MARK: - ChatView

struct ChatView: View {
    let title: String
    let subtitle: String
    let accentHex: String
    let messages: [Message]
    let isGroup: Bool
    let members: [Member]
    let roomId: String
    let recipientId: String?
    let isLostFound: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var realtimeTask: Task<Void, Never>? = nil
    @State private var realtimeChannel: RealtimeChannelV2? = nil
    @State private var messageText = ""
    @State private var replyingTo: Message? = nil
    @State private var allMessages: [Message]
    @State private var showPhotoPicker = false
    @FocusState private var inputFocused: Bool
    @State private var selectedImage: UIImage? = nil

    private var accent: Color { Color(hex: accentHex) }

    init(
        title: String,
        subtitle: String,
        accentHex: String,
        roomId: String,
        recipientId: String? = nil,
        isLostFound: Bool = false,
        messages: [Message],
        isGroup: Bool,
        members: [Member]
    ) {

        self.title = title
        self.subtitle = subtitle
        self.accentHex = accentHex
        self.roomId = roomId
        self.recipientId = recipientId
        self.messages = messages
        self.isGroup = isGroup
        self.members = members
        self.isLostFound = isLostFound
        _allMessages = State(initialValue: [])
    }

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ChatTopBar(
                    title: title,
                    subtitle: subtitle,
                    accentHex: accentHex,
                    isGroup: isGroup,
                    members: members,
                    onDismiss: { dismiss() }
                )

                Divider().background(PHTheme.divider.opacity(0.6))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Text("TODAY")
                                .font(.system(size: 10))
                                .tracking(0.8)
                                .foregroundStyle(PHTheme.placeholder)
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
                                    .background(
                                        Circle().fill(.black.opacity(0.5))
                                    )
                            }
                            .offset(x: 6, y: -6)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(PHTheme.surface2)
                }

                ChatInputBar(
                    text: $messageText,
                    accentHex: accentHex,
                    hasSelectedImage: selectedImage != nil,
                    isFocused: _inputFocused,
                    onSend: sendMessage,
                    onPhotoTap: { showPhotoPicker = true }
                )
            }
        }
        .task {
            await fetchMessages()

            realtimeTask?.cancel()

            realtimeTask = Task {
                await subscribeToMessages()
            }
        }
        .onDisappear {
            realtimeTask?.cancel()
            realtimeTask = nil

            if let channel = realtimeChannel {
                Task {
                    await channel.unsubscribe()
                }
            }

            realtimeChannel = nil
        }
        .sheet(isPresented: $showPhotoPicker) {
            PHPickerView { image in
                selectedImage = image
            }
        }
    }
    
    private func subscribeToMessages() async {
        do {
            let channel: RealtimeChannelV2
            let changes: AsyncStream<AnyAction>

            if let recipientId = recipientId {
                let user = try await supabase.auth.session.user
                let myId = user.id.uuidString.lowercased()
                let ids = [myId, recipientId.lowercased()].sorted()

                channel = supabase.realtimeV2.channel("dm:\(ids[0]):\(ids[1])")
                changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "dm_messages"
                )

            } else if isLostFound {
                channel = supabase.realtimeV2.channel("lf-messages-\(roomId)")

                changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "lost_found_messages"
                )

            } else {
                channel = supabase.realtimeV2.channel("room-messages-\(roomId)")

                changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "messages",
                    filter: "room_id=eq.\(roomId.lowercased())"
                )
            }

            await MainActor.run {
                realtimeChannel = channel
            }

            await channel.subscribe()

            for await _ in changes {
                if Task.isCancelled { break }
                await fetchMessages()
            }

            await channel.unsubscribe()

        } catch {
            #if DEBUG
            print("ChatView.swift:227 error:", error)
            #endif
        }
    }

    private func fetchMessages() async {
        do {
            let user = try await supabase.auth.session.user

            if let recipientId = recipientId {
                // DM messages
                struct DMMessage: Codable {
                    let id: UUID
                    let body: String?
                    let senderId: UUID
                    let createdAt: Date
                    let imageUrl: String?
                    enum CodingKeys: String, CodingKey {
                        case id, body
                        case senderId = "sender_id"
                        case createdAt = "created_at"
                        case imageUrl = "image_url"
                    }
                }

                let fetched: [DMMessage] =
                    try await supabase
                    .from("dm_messages")
                    .select()
                    .eq("room_id", value: roomId)
                    .or(
                        "and(sender_id.eq.\(user.id.uuidString),recipient_id.eq.\(recipientId)),and(sender_id.eq.\(recipientId),recipient_id.eq.\(user.id.uuidString))"
                    )
                    .order("created_at", ascending: true)
                    .execute()
                    .value

                await MainActor.run {
                    allMessages = fetched.map { m in
                        let isOwn = m.senderId == user.id
                        if let imageUrl = m.imageUrl {
                            return Message(
                                id: m.id,
                                sender: isOwn ? .me : members.first,
                                content: .photo(imageUrl),
                                timestamp: m.createdAt,
                                isOwn: isOwn
                            )
                        } else {
                            return Message(
                                id: m.id,
                                sender: isOwn ? .me : members.first,
                                content: .text(m.body ?? ""),
                                timestamp: m.createdAt,
                                isOwn: isOwn
                            )
                        }
                    }
                }
            } else {
                // Group messages
                struct SupabaseMessage: Codable {
                    let id: UUID
                    let body: String?
                    let senderId: UUID
                    let createdAt: Date
                    let imageUrl: String?
                    enum CodingKeys: String, CodingKey {
                        case id, body
                        case senderId = "sender_id"
                        case createdAt = "created_at"
                        case imageUrl = "image_url"
                    }
                }
                let fetched: [SupabaseMessage] =
                    try await supabase
                    .from("messages")
                    .select()
                    .eq("room_id", value: roomId)
                    .order("created_at", ascending: true)
                    .execute()
                    .value

                await MainActor.run {
                    allMessages = fetched.map { m in
                        let isOwn = m.senderId == user.id

                        let sender = isOwn
                            ? Member.me
                            : members.first { $0.id == m.senderId }

                        if let imageUrl = m.imageUrl {
                            return Message(
                                id: m.id,
                                sender: sender,
                                content: .photo(imageUrl),
                                timestamp: m.createdAt,
                                isOwn: isOwn
                            )
                        } else {
                            return Message(
                                id: m.id,
                                sender: sender,
                                content: .text(m.body ?? ""),
                                timestamp: m.createdAt,
                                isOwn: isOwn
                            )
                        }
                    }
                }
            }

            if isLostFound {
                struct LFMessage: Codable {
                    let id: UUID
                    let body: String?
                    let senderId: UUID
                    let createdAt: Date
                    enum CodingKeys: String, CodingKey {
                        case id, body
                        case senderId = "sender_id"
                        case createdAt = "created_at"
                    }
                }
                let fetched: [LFMessage] =
                    try await supabase
                    .from("lost_found_messages")
                    .select()
                    .eq("post_id", value: roomId)
                    .or(
                        "and(sender_id.eq.\(user.id.uuidString),recipient_id.eq.\(recipientId ?? "")),and(sender_id.eq.\(recipientId ?? ""),recipient_id.eq.\(user.id.uuidString))"
                    )
                    .order("created_at", ascending: true)
                    .execute()
                    .value
                await MainActor.run {
                    allMessages = fetched.map { m in
                        let isOwn = m.senderId == user.id
                        return Message(
                            id: m.id,
                            sender: isOwn ? .me : members.first,
                            content: .text(m.body ?? ""),
                            timestamp: m.createdAt,
                            isOwn: isOwn
                        )
                    }
                }
                return
            }
        } catch {
            #if DEBUG
            print("ChatView.swift:375 error:", error)
            #endif
        }
    }

    private func sendMessageToSupabase(_ text: String) async {
        do {
            let user = try await supabase.auth.session.user

            if let recipientId = recipientId {
                try await supabase
                    .from("dm_messages")
                    .insert([
                        "sender_id": user.id.uuidString,
                        "recipient_id": recipientId,
                        "body": text,
                        "room_id": roomId,
                    ])
                    .execute()
            } else {
                try await supabase
                    .from("messages")
                    .insert([
                        "room_id": roomId,
                        "sender_id": user.id.uuidString,
                        "body": text,
                    ])
                    .execute()
            }
            if isLostFound {
                try await supabase
                    .from("lost_found_messages")
                    .insert([
                        "post_id": roomId,
                        "sender_id": user.id.uuidString,
                        "recipient_id": recipientId ?? "",
                        "body": text,
                    ])
                    .execute()
            }
        } catch {
            #if DEBUG
            print("ChatView.swift:414 error:", error)
            #endif
        }

    }

    private func sendMessage() {
        if let image = selectedImage {
            Task { await sendImageMessage(image) }
            return
        }
        let trimmed = messageText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }
        Task { await sendMessageToSupabase(trimmed) }
        messageText = ""
        replyingTo = nil
    }

    private func sendImageMessage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        do {
            let user = try await supabase.auth.session.user
            let fileName = "\(UUID().uuidString).jpg"
            let path = "chat/\(roomId)/\(fileName)"

            try await supabase.storage
                .from("photos")
                .upload(
                    path,
                    data: data,
                    options: .init(contentType: "image/jpeg")
                )

            let url = try supabase.storage
                .from("photos")
                .getPublicURL(path: path)

            let table = recipientId != nil ? "dm_messages" : "messages"
            var insert: [String: String] = [
                "sender_id": user.id.uuidString,
                "image_url": url.absoluteString,
            ]
            if let recipientId = recipientId {
                insert["recipient_id"] = recipientId
                insert["room_id"] = roomId
            } else {
                insert["room_id"] = roomId
            }

            try await supabase.from(table).insert(insert).execute()

            await MainActor.run {
                selectedImage = nil
            }
        } catch {
            #if DEBUG
            print("ChatView.swift:469 error:", error)
            #endif
        }
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
            Button {
                onDismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(PHTheme.divider)
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PHTheme.text)
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
                            .fill(PHTheme.success)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle().stroke(
                                    PHTheme.background,
                                    lineWidth: 1.5
                                )
                            )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PHTheme.text)

                HStack(spacing: 4) {
                    if !isGroup, let member = members.first, member.isOnline {
                        Circle()
                            .fill(PHTheme.success)
                            .frame(width: 6, height: 6)
                    }
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(
                            !isGroup && members.first?.isOnline == true
                                ? PHTheme.success
                                : PHTheme.subtext
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
    
    private var fallbackPhoto: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(PHTheme.divider)
                .frame(width: 180, height: 140)

            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundStyle(PHTheme.placeholder)
        }
    }

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

            VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 4)
            {
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
                            .foregroundStyle(
                                message.isOwn
                                    ? PHTheme.accent : PHTheme.text
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        message.isOwn
                                            ? Color(
                                                hex: message.sender?.accentHex
                                                    ?? "AA9DFF"
                                            )
                                            : PHTheme.border
                                    )
                            )

                    case .photo(let value):
                        if let img = message.image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 160)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                        } else if value.hasPrefix("http"),
                                  let url = URL(string: value) {

                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(PHTheme.divider)
                                            .frame(width: 200, height: 160)
                                        ProgressView()
                                    }

                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 200, height: 160)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 16))

                                case .failure:
                                    fallbackPhoto

                                @unknown default:
                                    fallbackPhoto
                                }
                            }

                        } else {
                            fallbackPhoto
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
                        ForEach(
                            Array(message.reactions.keys.sorted()),
                            id: \.self
                        ) { emoji in
                            if let count = message.reactions[emoji] {
                                Text("\(emoji) \(count)")
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(PHTheme.border)
                                            .overlay(
                                                Capsule().stroke(
                                                    PHTheme.border,
                                                    lineWidth: 0.5
                                                )
                                            )
                                    )
                                    .foregroundStyle(
                                        PHTheme.textOnAccent.opacity(0.8)
                                    )
                            }
                        }
                    }
                }

                Text(message.timestamp.timeString())
                    .font(.system(size: 9))
                    .foregroundStyle(PHTheme.placeholder)
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
                .fill(
                    Color(hex: message.sender?.accentHex ?? "AA9DFF").opacity(
                        0.6
                    )
                )
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.sender?.name ?? "")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        Color(hex: message.sender?.accentHex ?? "AA9DFF")
                            .opacity(0.8)
                    )

                Group {
                    switch message.content {
                    case .text(let t): Text(t).lineLimit(1)
                    case .photo: Label("Photo", systemImage: "photo")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(PHTheme.subtext)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(
            RoundedRectangle(cornerRadius: 8).fill(
                PHTheme.divider.opacity(0.6)
            )
        )
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
                .foregroundStyle(PHTheme.subtext)
            }

            Spacer()

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(PHTheme.subtext)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(PHTheme.surface2)
        .overlay(
            Rectangle().fill(PHTheme.divider.opacity(0.6)).frame(
                height: 0.5
            ),
            alignment: .top
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    let accentHex: String
    let hasSelectedImage: Bool  // ← fix: was missing from the original
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    let onPhotoTap: () -> Void

    private var accent: Color { Color(hex: accentHex) }
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || hasSelectedImage
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onPhotoTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(PHTheme.divider)
                        .overlay(
                            Circle().stroke(PHTheme.border, lineWidth: 0.5)
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundStyle(PHTheme.subtext)
                }
            }
            .buttonStyle(.plain)

            TextField(
                "",
                text: $text,
                prompt: Text("Message…").foregroundStyle(
                    PHTheme.placeholder
                )
            )
            .focused($isFocused)
            .foregroundStyle(PHTheme.text)
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(PHTheme.divider)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(PHTheme.border, lineWidth: 0.5)
                    )
            )

            // ← fix: was a Button wrapping another Button; collapsed into one
            Button {
                if canSend { onSend() }
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? accent : PHTheme.divider)
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSend ? PHTheme.textOnAccent : PHTheme.subtext)
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.25), value: text.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(PHTheme.background)
                .overlay(
                    Rectangle().fill(PHTheme.divider.opacity(0.6)).frame(
                        height: 0.5
                    ),
                    alignment: .top
                )
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

    func updateUIViewController(
        _ uiViewController: PHPickerViewController,
        context: Context
    ) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                provider.canLoadObject(ofClass: UIImage.self)
            else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    if let img = image as? UIImage { self.onPick(img) }
                }
            }
        }
    }
}

// MARK: - Preview

//#Preview {
//    ChatView(
//        title: "Mochi's Room",
//        subtitle: "4 members",
//        accentHex: "AA9DFF",
//        roomId: "preview",
//        messages: PetRoom.mochi.groupMessages,
//        isGroup: true,
//        members: PetRoom.mochi.members
//    )
//}
