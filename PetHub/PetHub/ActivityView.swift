//
//  ActivityView.swift
//  PetHub
//

import SwiftUI

// MARK: - Activity Type

enum ActivityType {
    case photoPosted
    case comment
    case like
    case newMember
    case lostAnimal
}

// MARK: - Activity Destination

enum ActivityDestination {
    case photo(room: PetRoom, photo: PhotoPost)
    case roomGallery(room: PetRoom)
    case roomPeople(room: PetRoom)
    case lostFound
}

// MARK: - Activity Item

struct ActivityItem: Identifiable {
    let id: UUID
    let type: ActivityType
    let actor: Member
    let roomName: String
    let roomIcon: String
    let roomAccentHex: String
    let timestamp: Date
    var detail: String
    var photoEmoji: String?
    var destination: ActivityDestination

    var roomAccent: Color { Color(hex: roomAccentHex) }
}

// MARK: - Sample Data

extension ActivityItem {
    static let samples: [ActivityItem] = {
        let room = PetRoom.mochi
        let photos = room.photos

        return [
            ActivityItem(
                id: UUID(), type: .photoPosted,
                actor: .sarah, roomName: "Mochi", roomIcon: "dog.fill", roomAccentHex: "AA9DFF",
                timestamp: Date().addingTimeInterval(-120),
                detail: "Sarah posted a new photo",
                photoEmoji: "🐶",
                destination: .photo(room: room, photo: photos[0])
            ),
            ActivityItem(
                id: UUID(), type: .comment,
                actor: .jake, roomName: "Mochi", roomIcon: "dog.fill", roomAccentHex: "AA9DFF",
                timestamp: Date().addingTimeInterval(-600),
                detail: "omg he looks SO fluffy today 😭",
                photoEmoji: "🐶",
                destination: .photo(room: room, photo: photos[0])
            ),
            ActivityItem(
                id: UUID(), type: .like,
                actor: .priya, roomName: "Mochi", roomIcon: "dog.fill", roomAccentHex: "AA9DFF",
                timestamp: Date().addingTimeInterval(-1200),
                detail: "Priya liked your photo",
                photoEmoji: "🏖️",
                destination: .photo(room: room, photo: photos[4])
            ),
            ActivityItem(
                id: UUID(), type: .lostAnimal,
                actor: Member(id: UUID(), name: "Community", initials: "!", accentHex: "E25718", isOnline: false, isOwner: false),
                roomName: "Lost & Found", roomIcon: "mappin.and.ellipse", roomAccentHex: "E25718",
                timestamp: Date().addingTimeInterval(-2400),
                detail: "Golden Retriever reported missing 0.4 km away",
                photoEmoji: "🐕",
                destination: .lostFound
            ),
            ActivityItem(
                id: UUID(), type: .newMember,
                actor: .priya, roomName: "Mochi", roomIcon: "dog.fill", roomAccentHex: "AA9DFF",
                timestamp: Date().addingTimeInterval(-7200),
                detail: "Priya joined Mochi's room",
                photoEmoji: nil,
                destination: .roomPeople(room: room)
            ),
            ActivityItem(
                id: UUID(), type: .comment,
                actor: .sarah, roomName: "Mochi", roomIcon: "dog.fill", roomAccentHex: "AA9DFF",
                timestamp: Date().addingTimeInterval(-10800),
                detail: "can you send me the oat shampoo link?",
                photoEmoji: "🛁",
                destination: .photo(room: room, photo: photos[7])
            ),
            ActivityItem(
                id: UUID(), type: .like,
                actor: .jake, roomName: "Mochi", roomIcon: "dog.fill", roomAccentHex: "AA9DFF",
                timestamp: Date().addingTimeInterval(-14400),
                detail: "Jake liked your photo",
                photoEmoji: "🎾",
                destination: .photo(room: room, photo: photos[5])
            ),
            ActivityItem(
                id: UUID(), type: .lostAnimal,
                actor: Member(id: UUID(), name: "Community", initials: "!", accentHex: "E25718", isOnline: false, isOwner: false),
                roomName: "Lost & Found", roomIcon: "mappin.and.ellipse", roomAccentHex: "E25718",
                timestamp: Date().addingTimeInterval(-86400),
                detail: "Tabby cat found near Orchard Road",
                photoEmoji: "🐈",
                destination: .lostFound
            ),
            ActivityItem(
                id: UUID(), type: .photoPosted,
                actor: .jake, roomName: "Mochi", roomIcon: "dog.fill", roomAccentHex: "AA9DFF",
                timestamp: Date().addingTimeInterval(-90000),
                detail: "Jake posted a new photo",
                photoEmoji: "😴",
                destination: .photo(room: room, photo: photos[3])
            ),
        ]
    }()
}

// MARK: - ActivityView

struct ActivityView: View {

    @State private var navigationPath = NavigationPath()
    @State private var presentedPhoto: PhotoPost? = nil
    @State private var presentedRoom: PetRoom? = nil
    @State private var presentedRoomTab: RoomTab = .gallery
    @State private var showLostFound = false

    private var todayItems: [ActivityItem] {
        ActivityItem.samples.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var earlierItems: [ActivityItem] {
        ActivityItem.samples.filter { !Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        Text("Activity")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color("AppText"))
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 24)

                        if !todayItems.isEmpty {
                            ActivitySectionLabel(title: "Today")
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)

                            activityCard(items: todayItems)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 28)
                        }

                        if !earlierItems.isEmpty {
                            ActivitySectionLabel(title: "Earlier")
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)

                            activityCard(items: earlierItems)
                                .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 110)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: PetRoom.self) { room in
                RoomView(room: room, initialTab: presentedRoomTab)
            }
        }
        // ← Wrap the photo in a local @State so PhotoDetailView gets a Binding
        .sheet(item: $presentedPhoto) { photo in
            PhotoDetailSheetWrapper(photo: photo, room: PetRoom.mochi)
        }
        .sheet(isPresented: $showLostFound) {
            LostFoundPlaceholderView()
        }
    }

    private func handle(_ destination: ActivityDestination) {
        switch destination {
        case .photo(_, let photo):
            presentedPhoto = photo
        case .roomGallery(let room):
            presentedRoomTab = .gallery
            navigationPath.append(room)
        case .roomPeople(let room):
            presentedRoomTab = .people
            navigationPath.append(room)
        case .lostFound:
            showLostFound = true
        }
    }

    @ViewBuilder
    private func activityCard(items: [ActivityItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                ActivityRow(item: item) {
                    handle(item.destination)
                }
                if item.id != items.last?.id {
                    Divider()
                        .background(Color("AppDivider"))
                        .padding(.leading, 68)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSerface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("AppDivider"), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - PhotoDetailSheetWrapper
// Owns a @State copy of the photo so PhotoDetailView gets a valid Binding.
// Changes (likes, comments) are local to this sheet session — fine until
// you wire up a shared store later.

private struct PhotoDetailSheetWrapper: View {
    @State private var photo: PhotoPost
    let room: PetRoom

    init(photo: PhotoPost, room: PetRoom) {
        _photo = State(initialValue: photo)
        self.room = room
    }

    var body: some View {
        PhotoDetailView(photo: $photo, room: room)
    }
}

// MARK: - Section Label

struct ActivitySectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(Color("AppSubtext"))
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let item: ActivityItem
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(alignment: .top, spacing: 12) {

                ZStack(alignment: .bottomTrailing) {
                    if item.type == .lostAnimal {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "E25718").opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: "E25718"))
                        }
                    } else {
                        MemberAvatar(member: item.actor, size: 44)
                    }

                    ZStack {
                        Circle()
                            .fill(Color("AppSurface2"))
                            .frame(width: 20, height: 20)
                        Image(systemName: badgeIcon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(badgeColor)
                    }
                    .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppText"))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: item.roomIcon)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(item.roomAccent)
                            Text(item.roomName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(item.roomAccent.opacity(0.9))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(item.roomAccent.opacity(0.1)))

                        Text("·")
                            .foregroundStyle(Color("AppPlaceholder"))
                            .font(.system(size: 10))

                        Text(item.timestamp.relativeString())
                            .font(.system(size: 11))
                            .foregroundStyle(Color("AppSubtext"))
                    }
                }

                Spacer()

                if let emoji = item.photoEmoji {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(item.roomAccent.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Text(emoji)
                            .font(.system(size: 22))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var badgeIcon: String {
        switch item.type {
        case .photoPosted:  return "photo.fill"
        case .comment:      return "bubble.left.fill"
        case .like:         return "heart.fill"
        case .newMember:    return "person.fill.badge.plus"
        case .lostAnimal:   return "exclamationmark"
        }
    }

    private var badgeColor: Color {
        switch item.type {
        case .photoPosted:  return Color(hex: "AA9DFF")
        case .comment:      return Color(hex: "7EC8C8")
        case .like:         return Color(hex: "FF6B6B")
        case .newMember:    return Color(hex: "06D6A0")
        case .lostAnimal:   return Color(hex: "E25718")
        }
    }
}

// MARK: - Lost Found Placeholder

struct LostFoundPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: "E25718"))
                Text("Lost & Found")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
                Text("Coming soon")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("AppWhiteText"))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityView()
}
