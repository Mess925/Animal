//
//  ActivityView.swift
//  PetHub
//

import Supabase
import SwiftUI

// MARK: - Activity Type

enum ActivityType {
    case photoPosted
    case comment
    case like
    case newMember
    case lostAnimal
}

// MARK: - Supabase Activity Model

struct SupabaseActivity: Codable, Identifiable {
    let id: UUID
    let type: String
    let actorId: UUID
    let roomId: UUID?
    let photoId: UUID?
    let body: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case actorId = "actor_id"
        case roomId = "room_id"
        case photoId = "photo_id"
        case body
        case createdAt = "created_at"
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
    

    private var todayItems: [ActivityItem] {
        items.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var earlierItems: [ActivityItem] {
        items.filter { !Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Color(hex: "AA9DFF"))
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(Color("AppSubtext"))
                        Text("No activity yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color("AppWhiteText"))
                        Text("Likes and comments will appear here")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppPlaceholder"))
                    }
                } else {
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
            }
            .navigationBarHidden(true)
        }
        .task {
            await fetchActivities()
        }
    }

    private func fetchActivities() async {
        isLoading = true
        do {
            let user = try await supabase.auth.session.user

            // Get all room IDs the user is part of
            let roomIds = store.rooms.map { $0.id.uuidString }
            guard !roomIds.isEmpty else {
                isLoading = false
                return
            }

            // Fetch activities for those rooms, excluding current user's own actions
            let activities: [SupabaseActivity] = try await supabase
                .from("activities")
                .select()
                .in("room_id", values: roomIds)
                .neq("actor_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            // Build activity items with actor names
            var result: [ActivityItem] = []
            for activity in activities {
                // Get actor name
                let profiles: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: activity.actorId.uuidString)
                    .execute()
                    .value
                let actorName = profiles.first?.name ?? "Someone"
                let actorAccent = profiles.first?.avatarAccentHex ?? "AA9DFF"

                // Get room info
                let room = store.rooms.first { $0.id.uuidString == activity.roomId?.uuidString }
                let roomName = room?.name ?? "Unknown"
                let roomIcon = room?.icon ?? "pawprint.fill"
                let roomAccentHex = room?.accentHex ?? "AA9DFF"

                let detail: String
                let activityType: ActivityType

                switch activity.type {
                case "like":
                    detail = "\(actorName) liked a photo"
                    activityType = .like
                case "comment":
                    detail = activity.body ?? "\(actorName) commented"
                    activityType = .comment
                case "photo_posted":
                    detail = "\(actorName) posted a new photo"
                    activityType = .photoPosted
                case "new_member":
                    detail = "\(actorName) joined \(roomName)'s room"
                    activityType = .newMember
                default:
                    detail = "\(actorName) did something"
                    activityType = .like
                }

                result.append(ActivityItem(
                    id: activity.id,
                    type: activityType,
                    actorName: actorName,
                    actorAccentHex: actorAccent,
                    roomName: roomName,
                    roomIcon: roomIcon,
                    roomAccentHex: roomAccentHex,
                    timestamp: activity.createdAt,
                    detail: detail
                ))
            }

            await MainActor.run {
                items = result
                isLoading = false
            }
        } catch {
            print("Fetch activities error: \(error)")
            isLoading = false
        }
    }

    @ViewBuilder
    private func activityCard(items: [ActivityItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                ActivityRow(item: item)
                if item.id != items.last?.id {
                    Divider()
                        .background(Color("AppDivider"))
                        .padding(.leading, 68)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("AppDivider"), lineWidth: 0.5)
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
            .foregroundStyle(Color("AppSubtext"))
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
