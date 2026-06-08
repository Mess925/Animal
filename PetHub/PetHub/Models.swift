//
//  Models.swift
//  PetHub
//

import SwiftUI

// MARK: - Member

struct Member: Identifiable, Equatable {
    let id: UUID
    let name: String
    let initials: String
    let accentHex: String
    var isOnline: Bool
    var isOwner: Bool

    var accent: Color { Color(hex: accentHex) }
}

// MARK: - Message

enum MessageContent: Equatable {
    case text(String)
    case photo(String) // emoji placeholder; swap for UIImage/URL later
}

// Lightweight snapshot used for reply previews — avoids recursive struct
struct ReplySnapshot {
    let id: UUID
    let senderName: String
    let senderAccentHex: String
    let content: MessageContent
}

struct Message: Identifiable {
    let id: UUID
    let sender: Member?
    let content: MessageContent
    let timestamp: Date
    var replyTo: ReplySnapshot?
    var reactions: [String: Int]
    var isOwn: Bool
    var image: UIImage? = nil

    init(
        id: UUID = UUID(),
        sender: Member?,
        content: MessageContent,
        timestamp: Date = Date(),
        replyTo: ReplySnapshot? = nil,
        reactions: [String: Int] = [:],
        isOwn: Bool = false,
        image: UIImage? = nil
    ) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.replyTo = replyTo
        self.reactions = reactions
        self.isOwn = isOwn
        self.image = image
    }

    // Convenience: snapshot self for use as a reply reference
    func asSnapshot() -> ReplySnapshot {
        ReplySnapshot(
            id: id,
            senderName: sender?.name ?? "",
            senderAccentHex: sender?.accentHex ?? "AA9DFF",
            content: content
        )
    }
}

// MARK: - DM Thread

struct DMThread: Identifiable {
    let id: UUID
    let participant: Member
    var messages: [Message]
    var unreadCount: Int

    var lastMessage: Message? { messages.last }
}

struct RoomMembership: Codable {
    let id: UUID
    let roomId: UUID
    let userId: UUID
    let role: String

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case role
    }
}

// MARK: - Photo Post

struct PhotoPost: Identifiable {
    let id: UUID
    var image: UIImage? = nil
    var imageUrl: String? = nil
    let emoji: String          // placeholder for real image
    let backgroundHex: String
    let caption: String
    let postedBy: Member
    let timestamp: Date
    var likeCount: Int
    var comments: [Message]
    var isLiked: Bool

    var background: Color { Color(hex: backgroundHex) }
}

// MARK: -Supabase Room

struct SupabaseRoom: Codable {
    let id: UUID
    let name: String
    let breed: String
    let age: String
    let icon: String
    let accentHex: String

    enum CodingKeys: String, CodingKey {
        case id, name, breed, age, icon
        case accentHex = "accent_hex"
    }

    func toPetRoom(isOwned: Bool = true) -> PetRoom {
        PetRoom(
            id: id,
            name: name,
            breed: breed,
            age: age,
            icon: icon,
            accentHex: accentHex,
            members: [],
            photos: [],
            groupMessages: [],
            dmThreads: [],
            isOwned: isOwned
        )
    }
}


// MARK: - Pet Room

struct PetRoom: Identifiable, Hashable {
    static func == (lhs: PetRoom, rhs: PetRoom) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID
    var name: String
    var breed: String
    var age: String
    var icon: String
    var accentHex: String
    var members: [Member]
    var photos: [PhotoPost]
    var groupMessages: [Message]
    var dmThreads: [DMThread]
    var isOwned: Bool = true
    var lastMessage: String =  ""
    var lastActivity: Date = Date.distantPast
    var accent: Color { Color(hex: accentHex) }
    var owner: Member? { members.first(where: { $0.isOwner }) }
}

// MARK: - Sample Data

extension Member {
    static let me = Member(id: UUID(), name: "Me", initials: "M", accentHex: "AA9DFF", isOnline: true, isOwner: true)
    static let sarah = Member(id: UUID(), name: "Sarah", initials: "S", accentHex: "7EC8C8", isOnline: true, isOwner: false)
    static let jake = Member(id: UUID(), name: "Jake", initials: "J", accentHex: "F4A84A", isOnline: false, isOwner: false)
    static let priya = Member(id: UUID(), name: "Priya", initials: "P", accentHex: "AA9DFF", isOnline: true, isOwner: false)
}

extension PetRoom {
    static let mochi: PetRoom = {
        let me = Member.me
        let sarah = Member.sarah
        let jake = Member.jake
        let priya = Member.priya

        let photos: [PhotoPost] = [
            PhotoPost(id: UUID(), emoji: "🐶", backgroundHex: "1a1530", caption: "Morning walk 🌤️", postedBy: me, timestamp: Date().addingTimeInterval(-3600), likeCount: 5, comments: [], isLiked: false),
            PhotoPost(id: UUID(), emoji: "🌿", backgroundHex: "0f2a1a", caption: "Garden sniff", postedBy: sarah, timestamp: Date().addingTimeInterval(-7200), likeCount: 3, comments: [], isLiked: true),
            PhotoPost(id: UUID(), emoji: "🦴", backgroundHex: "2a1a0f", caption: "Treat time!", postedBy: me, timestamp: Date().addingTimeInterval(-10800), likeCount: 8, comments: [], isLiked: false),
            PhotoPost(id: UUID(), emoji: "😴", backgroundHex: "1a1530", caption: "Nap mode", postedBy: jake, timestamp: Date().addingTimeInterval(-14400), likeCount: 12, comments: [], isLiked: true),
            PhotoPost(id: UUID(), emoji: "🏖️", backgroundHex: "0f1f2a", caption: "Beach day!!", postedBy: sarah, timestamp: Date().addingTimeInterval(-86400), likeCount: 20, comments: [], isLiked: false),
            PhotoPost(id: UUID(), emoji: "🎾", backgroundHex: "2a1a1a", caption: "Ball ball ball", postedBy: me, timestamp: Date().addingTimeInterval(-90000), likeCount: 6, comments: [], isLiked: false),
            PhotoPost(id: UUID(), emoji: "🌙", backgroundHex: "1a2a1a", caption: "Night walk", postedBy: priya, timestamp: Date().addingTimeInterval(-172800), likeCount: 4, comments: [], isLiked: false),
            PhotoPost(id: UUID(), emoji: "🛁", backgroundHex: "1a1530", caption: "Bath time 😅", postedBy: me, timestamp: Date().addingTimeInterval(-180000), likeCount: 9, comments: [], isLiked: true),
        ]

        let groupMessages: [Message] = [
            Message(sender: sarah, content: .text("omg he looks SO fluffy today 😭"), timestamp: Date().addingTimeInterval(-300), isOwn: false),
            Message(sender: jake, content: .text("need the oat shampoo link 😭"), timestamp: Date().addingTimeInterval(-240), isOwn: false),
            Message(sender: me, content: .text("yes!! the oat one 🛁"), timestamp: Date().addingTimeInterval(-200), isOwn: true),
            Message(sender: me, content: .text("he smells like a cloud lol"), timestamp: Date().addingTimeInterval(-195), isOwn: true),
        ]

        let sarahMessages: [Message] = [
            Message(sender: sarah, content: .photo("🐶"), timestamp: Date().addingTimeInterval(-600), isOwn: false),
            Message(sender: me, content: .text("look how happy he is 🥹"), timestamp: Date().addingTimeInterval(-580), isOwn: true),
            Message(sender: sarah, content: .text("omg he looks SO fluffy today 😭"), timestamp: Date().addingTimeInterval(-560), isOwn: false),
            Message(sender: me, content: .text("used the oat shampoo 🛁"), timestamp: Date().addingTimeInterval(-540), isOwn: true),
        ]

        let jakeMessages: [Message] = [
            Message(sender: jake, content: .text("can you send me the vet's number?"), timestamp: Date().addingTimeInterval(-3600), isOwn: false),
        ]

        return PetRoom(
            id: UUID(),
            name: "Mochi",
            breed: "Golden Retriever",
            age: "2y",
            icon: "dog.fill",
            accentHex: "AA9DFF",
            members: [me, sarah, jake, priya],
            photos: photos,
            groupMessages: groupMessages,
            dmThreads: [
                DMThread(id: UUID(), participant: sarah, messages: sarahMessages, unreadCount: 2),
                DMThread(id: UUID(), participant: jake, messages: jakeMessages, unreadCount: 0),
                DMThread(id: UUID(), participant: priya, messages: [], unreadCount: 0),
            ]
        )
    }()
}

// MARK: - Formatters

extension Date {
    func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: self)
    }

    func relativeString() -> String {
        let diff = Date().timeIntervalSince(self)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff/60))m ago" }
        if diff < 86400 { return "\(Int(diff/3600))h ago" }
        return "\(Int(diff/86400))d ago"
    }
}
