//
//  RoomView.swift
//  PetHub
//

import SwiftUI
import Supabase

// MARK: - Room Tab

enum RoomTab { case photos, chat, settings }

// MARK: - RoomView

struct RoomView: View {
    let room: PetRoom
    var initialTab: RoomTab = .photos
    @State private var selectedTab: RoomTab
    @State private var dragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var currentRoom: PetRoom

    init(room: PetRoom, initialTab: RoomTab = .photos) {
        self.room = room
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
        _currentRoom = State(initialValue: room)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PHTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                RoomHeroHeader(room: currentRoom, onBack: { dismiss() })
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                RoomTabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                // Content
                ZStack {
                    switch selectedTab {
                    case .photos:
                        GalleryView(room: currentRoom)
                    case .chat:
                        PeopleView(room: currentRoom)
                    case .settings:
                        RoomSettingsView(room: currentRoom).environmentObject(store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await fetchMembers()
        }
        .offset(x: max(0, dragOffset))
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 && value.translation.width > abs(value.translation.height) {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .navigationBarHidden(true)
    }
    private func fetchMembers() async {
        do {
            struct RoomMemberRow: Codable {
                let userId: UUID
                let role: String
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case role
                }
            }

            let rows: [RoomMemberRow] = try await supabase
                .from("room_members")
                .select()
                .eq("room_id", value: room.id.uuidString)
                .execute()
                .value

            var fetchedMembers: [Member] = []
            for row in rows {
                let profiles: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: row.userId.uuidString)
                    .execute()
                    .value

                if let p = profiles.first {
                    fetchedMembers.append(Member(
                        id: row.userId,
                        name: p.name,
                        initials: String(p.name.prefix(1)),
                        accentHex: p.avatarAccentHex ?? "AA9DFF",
                        isOnline: false,
                        isOwner: row.role == "owner"
                    ))
                }
            }

            await MainActor.run {
                currentRoom.members = fetchedMembers
            }
        } catch {
            #if DEBUG
            print("InsideRoomView.swift:125 error:", error)
            #endif
        }
    }
}



struct RoomHeroHeader: View {
    let room: PetRoom
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PHTheme.text)
                        .frame(width: 40, height: 40)
                        .background(PHTheme.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PHTheme.border, lineWidth: 0.7))
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Image(systemName: room.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(room.accent)
                        .frame(width: 40, height: 40)
                        .background(room.accent.opacity(0.13))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(room.name)'s Room")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(PHTheme.text)
                            .lineLimit(1)
                        Text("\(max(room.members.count, 1)) members")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PHTheme.subtext)
                    }
                }

                Spacer()
            }

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(PHTheme.surface)
                    .overlay(
                        LinearGradient(
                            colors: [room.accent.opacity(0.20), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(PHTheme.border, lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)

                Image(systemName: room.icon)
                    .font(.system(size: 86, weight: .bold))
                    .foregroundStyle(room.accent.opacity(0.14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 22)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(room.breed)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(room.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(room.accent.opacity(0.13))
                            .clipShape(Capsule())

                        if !room.age.isEmpty {
                            Text(room.age)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PHTheme.subtext)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(PHTheme.surface2)
                                .clipShape(Capsule())
                        }
                    }

                    Text(room.name)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(PHTheme.text)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        MemberAvatarStack(members: room.members)
                        Text("Room is active")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PHTheme.subtext)
                        Circle()
                            .fill(PHTheme.success)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(18)
            }
            .frame(height: 164)
        }
    }
}

// MARK: - Lost Pet Room Banner

struct LostPetRoomBanner: View {
    let room: PetRoom
    let post: LostFoundPost
    let canSeeMatches: Bool
    let onViewPost: () -> Void

    private var daysMissingText: String {
        let days = Calendar.current.dateComponents([.day], from: post.createdAt, to: Date()).day ?? 0
        if days <= 0 { return "Reported today" }
        if days == 1 { return "Missing for 1 day" }
        return "Missing for \(days) days"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(PHTheme.danger.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PHTheme.danger)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(room.name.uppercased()) IS MISSING")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(PHTheme.danger)

                    Text(daysMissingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PHTheme.text)

                    if let location = post.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 11))
                            .foregroundStyle(PHTheme.subtext)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onViewPost) {
                    Text("View Lost Post")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(PHTheme.danger)
                        )
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: canSeeMatches ? "magnifyingglass.circle.fill" : "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(canSeeMatches ? "Pro Matches" : "Pro")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PHTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(PHTheme.text.opacity(0.07))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(PHTheme.danger.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(PHTheme.danger.opacity(0.35), lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Room Tab Bar

struct RoomTabBar: View {
    @Binding var selected: RoomTab

    var body: some View {
        HStack(spacing: 8) {
            RoomTabItem(label: "Photos", icon: "photo.on.rectangle", tab: .photos, selected: $selected)
            RoomTabItem(label: "Chat", icon: "bubble.left.and.bubble.right.fill", tab: .chat, selected: $selected)
            RoomTabItem(label: "Settings", icon: "slider.horizontal.3", tab: .settings, selected: $selected)
        }
        .padding(5)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(PHTheme.border, lineWidth: 0.7))
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
    }
}

struct RoomTabItem: View {
    let label: String
    let icon: String
    let tab: RoomTab
    @Binding var selected: RoomTab

    private var isActive: Bool { selected == tab }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                selected = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(isActive ? PHTheme.background : PHTheme.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isActive ? PHTheme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Member Avatar Stack

struct MemberAvatarStack: View {
    let members: [Member]
    private var displayed: [Member] { Array(members.prefix(3)) }
    private var overflow: Int { max(0, members.count - 3) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(displayed.enumerated()), id: \.element.id) { i, member in
                MemberAvatar(member: member, size: 26)
                    .overlay(
                        Circle()
                            .stroke(PHTheme.background, lineWidth: 1.5)
                    )
                    .offset(x: CGFloat(i) * -8)
                    .zIndex(Double(displayed.count - i))
            }
            if overflow > 0 {
                ZStack {
                    Circle()
                        .fill(PHTheme.border)
                        .frame(width: 26, height: 26)
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PHTheme.subtext)
                }
                .overlay(Circle().stroke(PHTheme.background, lineWidth: 1.5))
                .offset(x: CGFloat(displayed.count) * -8)
            }
        }
        .padding(.trailing, CGFloat(displayed.count - 1) * 8)
    }
}

// MARK: - Member Avatar (reusable)

struct MemberAvatar: View {
    let member: Member
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(member.accent.opacity(0.18))
                .frame(width: size, height: size)
            Text(member.initials)
                .font(.system(size: size * 0.33, weight: .semibold))
                .foregroundStyle(member.accent)
        }
    }
}

// MARK: - Preview
//
//#Preview {
//    RoomView(room: .mochi)
//}
