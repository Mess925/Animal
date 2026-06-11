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
    @State private var showReportLost = false
    @State private var showUpgrade = false
    @State private var activeLostPost: LostFoundPost? = nil
    @State private var selectedLostPost: LostFoundPost? = nil

    init(room: PetRoom, initialTab: RoomTab = .photos) {
        self.room = room
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
        _currentRoom = State(initialValue: room)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(Color("AppDivider"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color("AppAdaptiveWhite"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(room.name) 🐾")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color("AppText"))
                        Text("\(room.breed) · \(room.age)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color("AppWhiteText"))
                    }

                    Spacer()

                    if currentRoom.isOwned {
                        Button {
                            if subscriptionManager.canPostLostPet {
                                showReportLost = true
                            } else {
                                showUpgrade = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Report Lost")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color("AppAccentText"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "E25718"))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Member avatar stack
                    MemberAvatarStack(members: currentRoom.members)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)

                // Tab bar
                RoomTabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                if let activeLostPost {
                    LostPetRoomBanner(
                        room: currentRoom,
                        post: activeLostPost,
                        canSeeMatches: subscriptionManager.isPro,
                        onViewPost: { selectedLostPost = activeLostPost }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()
                    .background(Color("AppDivider").opacity(0.6))

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
            await fetchActiveLostPost()
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
        .navigationDestination(item: $selectedLostPost) { post in
            LostFoundDetailView(
                post: post,
                onPostUpdated: {
                    Task { await fetchActiveLostPost() }
                }
            )
            .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showReportLost) {
            AddLostFoundView(
                initialType: "lost",
                lockedType: "lost",
                initialAnimalType: currentRoom.breed.isEmpty ? currentRoom.name : currentRoom.breed,
                initialDescription: "Missing pet: \(currentRoom.name). Breed: \(currentRoom.breed). Age: \(currentRoom.age).",
                onComplete: {
                    Task { await fetchActiveLostPost() }
                }
            )
            .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
    }
    
    private func fetchActiveLostPost() async {
        do {
            let rows: [LostFoundPost] = try await supabase
                .from("lost_found_posts")
                .select()
                .eq("type", value: "lost")
                .eq("status", value: "active")
                .execute()
                .value

            let roomName = currentRoom.name.lowercased()
            let roomBreed = currentRoom.breed.lowercased()

            let matchedPost = rows.first { post in
                let animal = post.animalType.lowercased()
                let description = (post.description ?? "").lowercased()

                return animal.contains(roomName)
                    || animal.contains(roomBreed)
                    || description.contains(roomName)
                    || (!roomBreed.isEmpty && description.contains(roomBreed))
            }

            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    activeLostPost = matchedPost
                }
            }
        } catch {
            print("Fetch active lost post error: \(error)")
        }
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
            print("Fetch members error: \(error)")
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
                        .fill(Color(hex: "E25718").opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: "E25718"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(room.name.uppercased()) IS MISSING")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(Color(hex: "E25718"))

                    Text(daysMissingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("AppText"))

                    if let location = post.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 11))
                            .foregroundStyle(Color("AppWhiteText"))
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
                                .fill(Color(hex: "E25718"))
                        )
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: canSeeMatches ? "magnifyingglass.circle.fill" : "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(canSeeMatches ? "Pro Matches" : "Pro")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "AA9DFF"))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "AA9DFF").opacity(0.14))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "E25718").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "E25718").opacity(0.35), lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Room Tab Bar

struct RoomTabBar: View {
    @Binding var selected: RoomTab

    var body: some View {
        HStack(spacing: 2) {
            RoomTabItem(label: "Photos", tab: .photos, selected: $selected)
            RoomTabItem(label: "Chat", tab: .chat, selected: $selected)
            RoomTabItem(label: "Settings", tab: .settings, selected: $selected)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("AppDivider"))
        )
    }
}

struct RoomTabItem: View {
    let label: String
    let tab: RoomTab
    @Binding var selected: RoomTab

    private var isActive: Bool { selected == tab }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selected = tab
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Color(hex: "AA9DFF") : Color("AppSubtext"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Color(hex: "AA9DFF").opacity(0.15) : Color.clear)
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
                            .stroke(Color("AppBackground"), lineWidth: 1.5)
                    )
                    .offset(x: CGFloat(i) * -8)
                    .zIndex(Double(displayed.count - i))
            }
            if overflow > 0 {
                ZStack {
                    Circle()
                        .fill(Color("AppBorder"))
                        .frame(width: 26, height: 26)
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color("AppWhiteText"))
                }
                .overlay(Circle().stroke(Color("AppBackground"), lineWidth: 1.5))
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

#Preview {
    RoomView(room: .mochi)
}
