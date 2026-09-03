//
//  ActivityView.swift
//  PetHub
//

import Supabase
import SwiftUI

// MARK: - Activity Type

enum ActivityType {
    case roomJoined
    case roomLeft
    case photoAdded
    case photoLiked
    case photoCommented
    case possibleMatch
    case petFound
}

// MARK: - Supabase Activity Model

struct SupabaseActivity: Codable, Identifiable {
    let id: UUID
    let type: String
    let actorId: UUID
    let recipientId: UUID?
    let roomId: UUID?
    let photoId: UUID?
    let postId: UUID?
    let body: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case actorId = "actor_id"
        case recipientId = "recipient_id"
        case roomId = "room_id"
        case photoId = "photo_id"
        case postId = "post_id"
        case body
        case createdAt = "created_at"
    }
}

// MARK: - Notification Settings Model

struct RoomNotificationSetting: Codable {
    let roomId: UUID
    let notifyPhotos: Bool
    let notifyMessages: Bool
    let notifyReactions: Bool
    let notifyDM: Bool
    let notifyFoundPet: Bool

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case notifyPhotos = "notify_photos"
        case notifyMessages = "notify_messages"
        case notifyReactions = "notify_reactions"
        case notifyDM = "notify_dm"
        case notifyFoundPet = "notify_found_pet"
    }
}

// MARK: - Activity Item

struct ActivityItem: Identifiable {
    let id: UUID
    let type: ActivityType
    let actorId: UUID
    let actorName: String
    let actorAccentHex: String
    let roomId: UUID?
    let roomName: String
    let roomIcon: String
    let roomAccentHex: String
    let photoId: UUID?
    let postId: UUID?
    let timestamp: Date
    var detail: String
    var roomAccent: Color { Color(hex: roomAccentHex) }

    var destination: AppDestination? {
        switch type {
        case .roomJoined, .roomLeft:
            guard let roomId else { return nil }
            return .roomHome(roomId: roomId)
        case .photoAdded:
            guard let roomId else { return nil }
            return .roomPhotos(roomId: roomId)
        case .photoLiked, .photoCommented:
            guard let roomId, let photoId else { return nil }
            return .photoDetail(roomId: roomId, photoId: photoId)
        case .possibleMatch, .petFound:
            guard let postId else { return nil }
            return .lostFoundPost(postId: postId)
        }
    }
}

// MARK: - ActivityView

struct ActivityView: View {
    @EnvironmentObject private var store: RoomStore

    @State private var items: [ActivityItem] = []
    @State private var invitations: [RoomInvitation] = []
    @State private var invitationRooms: [UUID: PetRoom] = [:]
    @State private var invitationSenders: [UUID: UserProfile] = [:]
    @State private var isLoading = true

    @State private var roomNotificationSettings: [UUID: RoomNotificationSetting] = [:]

    private var todayItems: [ActivityItem] {
        items.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var earlierItems: [ActivityItem] {
        items.filter { !Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PHTheme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(PHTheme.accent)
                } else if items.isEmpty && invitations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(PHTheme.subtext)

                        Text("No activity yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(PHTheme.subtext)

                        Text("Likes, comments, messages, and important room alerts will appear here")
                            .font(.system(size: 13))
                            .foregroundStyle(PHTheme.placeholder)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Activity")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(PHTheme.text)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 24)

                            if !invitations.isEmpty {
                                ActivitySectionLabel(title: "Room Invites")
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)

                                VStack(spacing: 10) {
                                    ForEach(invitations) { invitation in
                                        RoomInvitationRow(
                                            invitation: invitation,
                                            room: invitationRooms[invitation.roomId],
                                            sender: invitationSenders[invitation.invitedBy],
                                            onAccept: {
                                                Task { await respondToInvitation(invitation, accepted: true) }
                                            },
                                            onDecline: {
                                                Task { await respondToInvitation(invitation, accepted: false) }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 28)
                            }

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
                    .refreshable {
                        await fetchActivities()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await fetchActivities()
        }
    }

    private func fetchActivities() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let user = try await supabase.auth.session.user
            let roomIds = store.rooms.map { $0.id.uuidString }

            await loadNotificationSettings(userId: user.id.uuidString)
            await loadPendingInvitations(userId: user.id.uuidString)

            let roomActivities: [SupabaseActivity]

            if roomIds.isEmpty {
                roomActivities = []
            } else {
                roomActivities = try await supabase
                    .from("activities")
                    .select()
                    .in("room_id", values: roomIds)
                    .order("created_at", ascending: false)
                    .limit(80)
                    .execute()
                    .value
            }

            let personalActivities: [SupabaseActivity] =
                try await supabase
                    .from("activities")
                    .select()
                    .eq("recipient_id", value: user.id.uuidString)
                    .order("created_at", ascending: false)
                    .limit(80)
                    .execute()
                    .value

            let activities = (roomActivities + personalActivities)
                .reduce(into: [UUID: SupabaseActivity]()) { partial, activity in
                    partial[activity.id] = activity
                }
                .values
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(80)

            var result: [ActivityItem] = []

            for activity in activities {
                let shouldShow = shouldShowActivity(activity, currentUserId: user.id)

                guard shouldShow else {
                    continue
                }

                let profiles: [UserProfile] =
                    try await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: activity.actorId.uuidString)
                        .execute()
                        .value

                let actorName = profiles.first?.name ?? "Someone"
                let actorAccent = profiles.first?.avatarAccentHex ?? "AA9DFF"

                let room = store.rooms.first {
                    $0.id.uuidString == activity.roomId?.uuidString
                }

                let roomName = room?.name ?? "PetHub"
                let roomIcon = room?.icon ?? "pawprint.fill"
                let roomAccentHex = room?.accentHex ?? "AA9DFF"

                let detail: String
                let activityType: ActivityType

                switch activity.type {
                case "room_joined":
                    detail = activity.body ?? "\(actorName) joined \(roomName)'s room"
                    activityType = .roomJoined

                case "room_left":
                    detail = activity.body ?? "\(actorName) left \(roomName)'s room"
                    activityType = .roomLeft

                case "photo_added", "photo_posted":
                    detail = activity.body ?? "\(actorName) added a new photo to \(roomName)'s room"
                    activityType = .photoAdded

                case "photo_liked", "like":
                    detail = activity.body ?? "\(actorName) liked your photo"
                    activityType = .photoLiked

                case "photo_commented", "comment":
                    detail = activity.body ?? "\(actorName) commented on your photo"
                    activityType = .photoCommented

                case "possible_match", "found_pet_match":
                    // `body` on this type is a dedupe key (contains raw post ids),
                    // not display text — always show the friendly message.
                    detail = "Possible match found for your lost pet"
                    activityType = .possibleMatch

                case "pet_found", "found_your_pet":
                    detail = activity.body ?? "\(actorName) may have found your pet"
                    activityType = .petFound

                default:
                    continue
                }

                result.append(
                    ActivityItem(
                        id: activity.id,
                        type: activityType,
                        actorId: activity.actorId,
                        actorName: actorName,
                        actorAccentHex: actorAccent,
                        roomId: activity.roomId,
                        roomName: roomName,
                        roomIcon: roomIcon,
                        roomAccentHex: roomAccentHex,
                        photoId: activity.photoId,
                        postId: activity.postId,
                        timestamp: activity.createdAt,
                        detail: detail
                    )
                )
            }

            await MainActor.run {
                items = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func loadPendingInvitations(userId: String) async {
        do {
            let pending: [RoomInvitation] = try await supabase
                .from("room_invitations")
                .select()
                .eq("invited_user_id", value: userId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            var rooms: [UUID: PetRoom] = [:]
            var senders: [UUID: UserProfile] = [:]

            for invitation in pending {
                if let existingRoom = store.rooms.first(where: { $0.id == invitation.roomId }) {
                    rooms[invitation.roomId] = existingRoom
                } else {
                    let fetchedRooms: [SupabaseRoom] = try await supabase
                        .from("rooms")
                        .select()
                        .eq("id", value: invitation.roomId.uuidString)
                        .execute()
                        .value
                    if let fetchedRoom = fetchedRooms.first {
                        rooms[invitation.roomId] = fetchedRoom.toPetRoom(isOwned: false)
                    }
                }

                let profiles: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: invitation.invitedBy.uuidString)
                    .execute()
                    .value
                if let sender = profiles.first {
                    senders[invitation.invitedBy] = sender
                }
            }

            await MainActor.run {
                invitations = pending
                invitationRooms = rooms
                invitationSenders = senders
            }
        } catch {
            await MainActor.run {
                invitations = []
                invitationRooms = [:]
                invitationSenders = [:]
            }
        }
    }

    private func respondToInvitation(_ invitation: RoomInvitation, accepted: Bool) async {
        do {
            let currentUser = try await supabase.auth.session.user

            if accepted {
                let existing: [RoomMembership] = try await supabase
                    .from("room_members")
                    .select()
                    .eq("room_id", value: invitation.roomId.uuidString)
                    .eq("user_id", value: currentUser.id.uuidString)
                    .execute()
                    .value

                if existing.isEmpty {
                    try await supabase
                        .from("room_members")
                        .insert([
                            "room_id": invitation.roomId.uuidString.lowercased(),
                            "user_id": currentUser.id.uuidString.lowercased(),
                            "role": "member"
                        ])
                        .execute()
                }
            }

            try await supabase
                .from("room_invitations")
                .update(["status": accepted ? "accepted" : "declined"])
                .eq("id", value: invitation.id.uuidString)
                .execute()

            if accepted {
                let roomName = invitationRooms[invitation.roomId]?.name ?? "a room"
                try? await supabase
                    .from("activities")
                    .insert([
                        "type": "room_joined",
                        "actor_id": currentUser.id.uuidString,
                        "room_id": invitation.roomId.uuidString,
                        "body": "Joined \(roomName)"
                    ])
                    .execute()
            }

            await store.fetchRooms()
            await fetchActivities()
        } catch {
            #if DEBUG
            print("Invitation response error:", error)
            #endif
        }
    }

    private func loadNotificationSettings(userId: String) async {
        do {
            let rows: [RoomNotificationSetting] =
                try await supabase
                    .from("room_notification_settings")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                    .value

            let dictionary = Dictionary(
                uniqueKeysWithValues: rows.map { ($0.roomId, $0) }
            )

            await MainActor.run {
                roomNotificationSettings = dictionary
            }
        } catch {
            await MainActor.run {
                roomNotificationSettings = [:]
            }
        }
    }

    private func shouldShowActivity(
        _ activity: SupabaseActivity,
        currentUserId: UUID
    ) -> Bool {
        if activity.actorId == currentUserId {
            return false
        }

        let setting: RoomNotificationSetting?

        if let roomId = activity.roomId {
            setting = roomNotificationSettings[roomId]
        } else {
            setting = nil
        }

        switch activity.type {
        case "room_joined", "room_left":
            return true

        case "photo_added", "photo_posted":
            return setting?.notifyPhotos ?? true

        case "room_message", "message":
            return setting?.notifyMessages ?? true

        case "photo_liked", "like", "photo_commented", "comment", "mention":
            return setting?.notifyReactions ?? true

        case "direct_message", "dm":
            return setting?.notifyDM ?? true

        case "possible_match", "found_pet_match", "pet_found", "found_your_pet":
            return setting?.notifyFoundPet ?? true

        default:
            return false
        }
    }

    @ViewBuilder
    private func activityCard(items: [ActivityItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                ActivityRow(item: item)

                if item.id != items.last?.id {
                    Divider()
                        .background(PHTheme.divider)
                        .padding(.leading, 68)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(PHTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(PHTheme.divider, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Room Invitation Row

struct RoomInvitationRow: View {
    let invitation: RoomInvitation
    let room: PetRoom?
    let sender: UserProfile?
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: sender?.avatarAccentHex ?? "AA9DFF").opacity(0.18))
                        .frame(width: 44, height: 44)

                    Text(String((sender?.name ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: sender?.avatarAccentHex ?? "AA9DFF"))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(sender?.name ?? "Someone") invited you to join \(room?.name ?? "a room")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PHTheme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Accept only if you know this person. You will not join until you accept.")
                        .font(.system(size: 12))
                        .foregroundStyle(PHTheme.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PHTheme.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(PHTheme.surface))
                }
                .buttonStyle(.plain)

                Button(action: onAccept) {
                    Text("Accept")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PHTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(PHTheme.accent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(PHTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(PHTheme.divider, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Section Label

struct ActivitySectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(PHTheme.subtext)
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color(hex: item.actorAccentHex).opacity(0.18))
                        .frame(width: 44, height: 44)

                    Text(String(item.actorName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: item.actorAccentHex))
                }

                ZStack {
                    Circle()
                        .fill(PHTheme.surface2)
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
                    .foregroundStyle(PHTheme.text)
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
                        .foregroundStyle(PHTheme.placeholder)
                        .font(.system(size: 10))

                    Text(item.timestamp.relativeString())
                        .font(.system(size: 11))
                        .foregroundStyle(PHTheme.subtext)
                }
            }

            Spacer()

            if item.destination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PHTheme.placeholder)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let destination = item.destination else { return }
            AppRouter.shared.route(to: destination)
        }
    }

    private var badgeIcon: String {
        switch item.type {
        case .roomJoined:
            return "person.fill.badge.plus"
        case .roomLeft:
            return "rectangle.portrait.and.arrow.right"
        case .photoAdded:
            return "photo.fill"
        case .photoLiked:
            return "heart.fill"
        case .photoCommented:
            return "bubble.left.fill"
        case .possibleMatch:
            return "magnifyingglass.circle.fill"
        case .petFound:
            return "pawprint.fill"
        }
    }

    private var badgeColor: Color {
        switch item.type {
        case .roomJoined:
            return PHTheme.success
        case .roomLeft:
            return PHTheme.danger
        case .photoAdded:
            return PHTheme.accent
        case .photoLiked:
            return PHTheme.accent3
        case .photoCommented:
            return PHTheme.accent2
        case .possibleMatch:
            return PHTheme.warning
        case .petFound:
            return PHTheme.success
        }
    }
}

// MARK: - Lost Found Placeholder

struct LostFoundPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 48))
                    .foregroundStyle(PHTheme.danger)

                Text("Lost & Found")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PHTheme.text)

                Text("Coming soon")
                    .font(.system(size: 14))
                    .foregroundStyle(PHTheme.subtext)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityView()
}
