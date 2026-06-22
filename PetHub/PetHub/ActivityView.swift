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
    let body: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case actorId = "actor_id"
        case recipientId = "recipient_id"
        case roomId = "room_id"
        case photoId = "photo_id"
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
    let actorName: String
    let actorAccentHex: String
    let roomName: String
    let roomIcon: String
    let roomAccentHex: String
    let timestamp: Date
    var detail: String
    var roomAccent: Color { Color(hex: roomAccentHex) }
}

// MARK: - ActivityView

struct ActivityView: View {
    @EnvironmentObject private var store: RoomStore

    @State private var items: [ActivityItem] = []
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
                } else if items.isEmpty {
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
                    detail = activity.body ?? "Possible match found for your lost pet"
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
                        actorName: actorName,
                        actorAccentHex: actorAccent,
                        roomName: roomName,
                        roomIcon: roomIcon,
                        roomAccentHex: roomAccentHex,
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
