//
//  RoomView.swift
//  PetHub
//

import Combine
import Supabase
import SwiftUI

// MARK: - Debug Logging

private func phLog(_ message: String) {
    #if DEBUG
    #endif
}

// MARK: - Room Activity (file-scope, replaces duplicate local struct)

private struct RoomActivity: Codable {
    let createdAt: Date
    let body: String?
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case body
    }
}

// MARK: - Room Store

class RoomStore: ObservableObject {
    @Published var rooms: [PetRoom] = []
    @Published var memberCounts: [UUID: Int] = [:]
    @Published var isInRoom: Bool = false

    func add(_ room: PetRoom) {
        rooms.append(room)
    }

    func fetchRooms() async {
        do {
            let user = try await supabase.auth.session.user
            phLog("Fetching rooms for user: \(user.id)")

            let ownedRooms: [SupabaseRoom] =
                try await supabase
                .from("rooms")
                .select()
                .eq("owner_id", value: user.id.uuidString)
                .execute()
                .value
            phLog("Owned rooms: \(ownedRooms.count)")

            let memberships: [RoomMembership] =
                try await supabase
                .from("room_members")
                .select()
                .eq("user_id", value: user.id.uuidString.lowercased())
                .eq("role", value: "member")
                .execute()
                .value
            phLog("Memberships: \(memberships.count)")

            let memberRoomIds = memberships.map { $0.roomId.uuidString }

            var memberRooms: [SupabaseRoom] = []
            if !memberRoomIds.isEmpty {
                memberRooms =
                    try await supabase
                    .from("rooms")
                    .select()
                    .in("id", values: memberRoomIds)
                    .execute()
                    .value
            }

            var allRooms: [PetRoom] =
                ownedRooms.map { $0.toPetRoom(isOwned: true) }
                + memberRooms.map { $0.toPetRoom(isOwned: false) }

            // Fetch the real member count for each room.
            // Do not use placeholder values like "12 members" in the UI.
            var fetchedMemberCounts: [UUID: Int] = [:]

            try await withThrowingTaskGroup(of: (UUID, Int).self) { group in
                for room in allRooms {
                    let roomId = room.id
                    group.addTask {
                        struct RoomMemberCountRow: Codable {
                            let userId: UUID

                            enum CodingKeys: String, CodingKey {
                                case userId = "user_id"
                            }
                        }

                        let members: [RoomMemberCountRow] =
                            try await supabase
                            .from("room_members")
                            .select("user_id")
                            .eq("room_id", value: roomId.uuidString)
                            .execute()
                            .value

                        return (roomId, max(members.count, 1))
                    }
                }

                for try await (roomId, count) in group {
                    fetchedMemberCounts[roomId] = count
                }
            }

            // Fetch last activity for all rooms concurrently instead of serially
            try await withThrowingTaskGroup(of: (Int, Date?, String?).self) {
                group in
                for (i, room) in allRooms.enumerated() {
                    let roomId = room.id.uuidString
                    group.addTask {
                        async let lastMsg: [RoomActivity] =
                            (try? await supabase
                                .from("messages")
                                .select("created_at, body")
                                .eq("room_id", value: roomId)
                                .order("created_at", ascending: false)
                                .limit(1)
                                .execute()
                                .value) ?? []

                        async let lastPhoto: [RoomActivity] =
                            (try? await supabase
                                .from("photo_posts")
                                .select("created_at")
                                .eq("room_id", value: roomId)
                                .order("created_at", ascending: false)
                                .limit(1)
                                .execute()
                                .value) ?? []

                        async let lastActivity: [RoomActivity] =
                            (try? await supabase
                                .from("activities")
                                .select("created_at")
                                .eq("room_id", value: roomId)
                                .order("created_at", ascending: false)
                                .limit(1)
                                .execute()
                                .value) ?? []

                        let (msg, photo, act) = try await (
                            lastMsg, lastPhoto, lastActivity
                        )

                        let latestDate = [
                            msg.first?.createdAt, photo.first?.createdAt,
                            act.first?.createdAt,
                        ]
                        .compactMap { $0 }
                        .max()

                        return (i, latestDate, msg.first?.body)
                    }
                }

                for try await (i, latestDate, lastBody) in group {
                    allRooms[i].lastActivity = latestDate ?? Date.distantPast
                    allRooms[i].lastMessage = lastBody ?? ""
                }
            }

            let sorted = allRooms.sorted { $0.lastActivity > $1.lastActivity }
            await MainActor.run {
                self.rooms = sorted
                self.memberCounts = fetchedMemberCounts
            }

        } catch {
            phLog("Fetch rooms error: \(error)")
        }
    }
}

// MARK: - Tab Enum

enum AppTab {
    case home, rooms, activity, profile
}

// MARK: - Root App Shell

struct MainTabView: View {
    @StateObject private var store = RoomStore()
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(selectedTab: $selectedTab)
                        .environmentObject(store)
                        .environmentObject(subscriptionManager)
                case .rooms:
                    RoomsView()
                        .environmentObject(store)
                        .environmentObject(subscriptionManager)
                case .activity:
                    ActivityView()
                        .environmentObject(store)
                case .profile:
                    ProfileView()
                        .environmentObject(store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !store.isInRoom {
                FloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.8),
                        value: store.isInRoom
                    )
            }
        }
        .task {
            await store.fetchRooms()
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 2) {
            TabBarItem(
                icon: "house.fill",
                label: "Home",
                tab: .home,
                selected: $selectedTab
            )
            TabBarItem(
                icon: "pawprint.fill",
                label: "Rooms",
                tab: .rooms,
                selected: $selectedTab
            )
            TabBarItem(
                icon: "bell.fill",
                label: "Activity",
                tab: .activity,
                selected: $selectedTab
            )
            TabBarItem(
                icon: "person.fill",
                label: "Profile",
                tab: .profile,
                selected: $selectedTab
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(scheme == .dark ? Color.black.opacity(0.86) : Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(scheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.14), radius: 26, x: 0, y: 16)
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let tab: AppTab
    @Binding var selected: AppTab

    private var isActive: Bool { selected == tab }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selected = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isActive ? 19 : 18, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(isActive ? PHTheme.background : PHTheme.subtext)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isActive ? PHTheme.text : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Binding var selectedTab: AppTab
    @State private var userName = ""
    @State private var lostFoundPosts: [LostFoundPost] = []
    @State private var isLoadingLostFound = true
    @State private var showCreateRoom = false
    @State private var showUpgradeSheet = false

    private var recentRooms: [PetRoom] {
        Array(
            store.rooms.sorted { $0.lastActivity > $1.lastActivity }.prefix(3)
        )
    }
    private var myRooms: [PetRoom] { store.rooms.filter { $0.isOwned } }
    private var joinedRooms: [PetRoom] { store.rooms.filter { !$0.isOwned } }
    private var featuredLostFound: [LostFoundPost] {
        Array(lostFoundPosts.filter { $0.isActive }.prefix(5))
    }

    var body: some View {
        NavigationStack {
            PHPage {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        HomeHeader(
                            userName: userName,
                            roomCount: store.rooms.count
                        )
                        .padding(.horizontal, PHTheme.pagePadding)
                        .padding(.top, 22)

                        VStack(alignment: .leading, spacing: 14) {
                            HomePetsHeader(onCreate: { openCreateRoom() })

                            if myRooms.isEmpty {
                                Button { openCreateRoom() } label: {
                                    HomeCreateFirstRoomCard()
                                }
                                .buttonStyle(.plain)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(myRooms.prefix(6)) { room in
                                            NavigationLink {
                                                RoomView(room: room)
                                                    .environmentObject(store)
                                                    .environmentObject(subscriptionManager)
                                                    .onAppear { store.isInRoom = true }
                                                    .onDisappear { store.isInRoom = false }
                                            } label: {
                                                HomePetBubble(room: room)
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        HomeCreateRoomTile(action: { openCreateRoom() })
                                    }
                                    .padding(.horizontal, PHTheme.pagePadding)
                                }
                                .padding(.horizontal, -PHTheme.pagePadding)
                            }
                        }
                        .padding(.horizontal, PHTheme.pagePadding)

                        VStack(alignment: .leading, spacing: 14) {
                            HomeSectionHeader(
                                title: "Lost & Found",
                                subtitle: "Tap the card to view community posts"
                            )

                            NavigationLink {
                                LostAndFoundView()
                                    .environmentObject(subscriptionManager)
                                    .environmentObject(store)
                            } label: {
                                HomeLostFoundOverviewCard(
                                    posts: featuredLostFound,
                                    isLoading: isLoadingLostFound
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, PHTheme.pagePadding)

                        VStack(alignment: .leading, spacing: 14) {
                            HomeSectionHeader(title: "Recent Activity", subtitle: "Latest room updates")

                            if recentRooms.isEmpty {
                                HomeEmptyCard(
                                    icon: "sparkles",
                                    title: "No updates yet",
                                    subtitle: "Room updates will show here once you add memories."
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(recentRooms) { room in
                                        NavigationLink {
                                            RoomView(room: room)
                                                .environmentObject(store)
                                                .environmentObject(subscriptionManager)
                                                .onAppear { store.isInRoom = true }
                                                .onDisappear { store.isInRoom = false }
                                        } label: {
                                            HomeRoomActivityRow(room: room)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, PHTheme.pagePadding)

                        if !joinedRooms.isEmpty {
                            HomeJoinedRoomsSection(joinedRooms: joinedRooms)
                                .environmentObject(store)
                                .environmentObject(subscriptionManager)
                                .padding(.horizontal, PHTheme.pagePadding)
                        }

                        Spacer().frame(height: 112)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showUpgradeSheet) { UpgradeView() }
            .sheet(isPresented: $showCreateRoom) {
                CreateRoomView { newRoom in store.add(newRoom) }
            }
        }
        .task {
            await store.fetchRooms()
            await fetchLostFoundPosts()
            await fetchUserName()
        }
    }

    private func openCreateRoom() {
        if myRooms.count >= subscriptionManager.maxRooms {
            showUpgradeSheet = true
        } else {
            showCreateRoom = true
        }
    }

    private func fetchUserName() async {
        do {
            let user = try await supabase.auth.session.user

            struct ProfileName: Decodable {
                let name: String?
            }

            let profile: ProfileName =
                try await supabase
                .from("profiles")
                .select("name")
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value

            await MainActor.run {
                userName = profile.name ?? "Pet Parent"
            }
        } catch {
            await MainActor.run {
                userName = "Pet Parent"
            }
        }
    }

    private func fetchLostFoundPosts() async {
        await MainActor.run { isLoadingLostFound = true }
        do {
            let fetched: [LostFoundPost] =
                try await supabase
                .from("lost_found")
                .select()
                .neq("status", value: "deleted")
                .order("created_at", ascending: false)
                .limit(8)
                .execute()
                .value
            await MainActor.run {
                lostFoundPosts = fetched
                isLoadingLostFound = false
            }
        } catch {
            await MainActor.run { isLoadingLostFound = false }
        }
    }
}

struct HomeJoinedRoomsSection: View {
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let joinedRooms: [PetRoom]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(
                title: "Joined Rooms",
                subtitle: "Rooms shared with you"
            )

            if joinedRooms.isEmpty {
                HomeEmptyCard(
                    icon: "person.2",
                    title: "No joined rooms yet",
                    subtitle:
                        "When someone invites you to a room, it will show here."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(joinedRooms) { room in
                            NavigationLink {
                                RoomView(room: room)
                                    .environmentObject(store)
                                    .environmentObject(subscriptionManager)
                                    .onAppear { store.isInRoom = true }
                                    .onDisappear { store.isInRoom = false }
                            } label: {
                                JoinedRoomChip(room: room)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PHTheme.pagePadding)
                }
                .padding(.horizontal, -PHTheme.pagePadding)
            }
        }
    }
}

struct HomeHeader: View {
    let userName: String
    let roomCount: Int

    var body: some View {
        PHCard(padding: 18, radius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                Text(greeting)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PHTheme.subtext)

                Text(displayName)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("A clean home for your pet rooms, photos, and memories.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(2)

                HomeMetricPill(
                    value: "\(roomCount)",
                    label: roomCount == 1 ? "Room" : "Rooms",
                    icon: "pawprint.fill",
                    color: PHTheme.accent
                )
            }
        }
    }

    private var displayName: String {
        userName.isEmpty ? "Pet Parent" : userName
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }
}

struct HomePetsHeader: View {
    let onCreate: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your Pets")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                Text("Tap a pet to open its room")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
            }
            Spacer()
        }
    }
}

struct HomePetBubble: View {
    let room: PetRoom

    private var detailText: String {
        if !room.breed.isEmpty { return room.breed }
        if !room.age.isEmpty { return room.age }
        return "Pet room"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(room.accent.opacity(0.13))
                Image(systemName: room.icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(room.accent)
            }
            .frame(height: 82)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(room.accent.opacity(0.18), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                    .lineLimit(1)
                Text(detailText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(width: 136)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(PHTheme.border, lineWidth: 0.7)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 7)
    }
}

struct HomeCreateRoomTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(PHTheme.brandGradient)
                    .clipShape(Circle())
                VStack(spacing: 3) {
                    Text("Create")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(PHTheme.text)
                    Text("New room")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PHTheme.subtext)
                }
            }
            .frame(width: 112, height: 144)
            .background(PHTheme.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                    .foregroundStyle(PHTheme.accent.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }
}

struct HomeCreateFirstRoomCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(PHTheme.brandGradient)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("Create your first pet room")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                Text("Add photos, notes, memories, and shared updates.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PHTheme.placeholder)
        }
        .padding(16)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PHTheme.border, lineWidth: 0.7)
        )
    }
}

struct AddPetBubble: View {
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showCreateRoom = false
    @State private var showUpgradeSheet = false

    var body: some View {
        Button {
            if store.rooms.filter({ $0.isOwned }).count
                >= subscriptionManager.maxRooms
            {
                showUpgradeSheet = true
            } else {
                showCreateRoom = true
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(PHTheme.surface)
                    RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                    ).foregroundStyle(PHTheme.border)
                    Image(systemName: "plus")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(PHTheme.subtext)
                }
                .frame(width: 62, height: 62)
                Text("Add Pet")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PHTheme.text)
            }
            .frame(width: 78)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUpgradeSheet) { UpgradeView() }
        .sheet(isPresented: $showCreateRoom) {
            CreateRoomView { newRoom in store.add(newRoom) }
        }
    }
}

struct HomeQuickAction: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(tint)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(PHTheme.text)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PHTheme.subtext)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(PHTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(
                    PHTheme.border,
                    lineWidth: 0.7
                )
            )
        }
        .buttonStyle(.plain)
    }
}

struct HomeMetricPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("Total rooms")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PHTheme.subtext)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(PHTheme.text)
                    Text(label.lowercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PHTheme.subtext)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PHTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PHTheme.border, lineWidth: 0.7)
        )
    }
}

struct HomeSectionHeader<Destination: View>: View {
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var destination: (() -> Destination)? = nil

    init(
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        destination: (() -> Destination)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.destination = destination
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
            }
            Spacer()
            if let actionTitle, let destination {
                NavigationLink(destination: destination()) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PHTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension HomeSectionHeader where Destination == EmptyView {
    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = nil
        self.destination = nil
    }
}


struct HomeLostFoundOverviewCard: View {
    let posts: [LostFoundPost]
    let isLoading: Bool

    private var lostCount: Int {
        posts.filter { $0.reportType == "lost" }.count
    }

    private var foundCount: Int {
        posts.filter { $0.reportType == "found" }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PHTheme.danger.opacity(0.12))
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(PHTheme.danger)
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 6) {
                Text(isLoading ? "Loading community posts…" : "Open Lost & Found")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(2)

                if !isLoading && !posts.isEmpty {
                    HStack(spacing: 8) {
                        LostFoundMiniPill(title: "Lost", count: lostCount, color: PHTheme.danger)
                        LostFoundMiniPill(title: "Found", count: foundCount, color: PHTheme.success)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .tint(PHTheme.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PHTheme.placeholder)
            }
        }
        .padding(16)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(PHTheme.border, lineWidth: 0.7)
        )
    }

    private var subtitle: String {
        if isLoading { return "Checking the latest lost and found alerts." }
        if posts.isEmpty { return "All quiet for now. Active alerts will appear here." }
        return "Tap to see nearby lost and found pets."
    }
}

struct LostFoundMiniPill: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count) \(title)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct HomeLostFoundTile: View {
    let post: LostFoundPost

    private var isLost: Bool { post.reportType == "lost" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        (isLost ? PHTheme.danger : PHTheme.success).opacity(
                            0.13
                        )
                    )
                    .frame(height: 118)

                if let imageUrl = post.imageUrl, let url = URL(string: imageUrl)
                {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(
                                systemName: isLost
                                    ? "exclamationmark.triangle.fill"
                                    : "checkmark.circle.fill"
                            )
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(
                                (isLost ? PHTheme.danger : PHTheme.success)
                                    .opacity(0.82)
                            )
                        }
                    }
                    .frame(height: 118)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    Image(
                        systemName: isLost
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(
                        (isLost ? PHTheme.danger : PHTheme.success).opacity(
                            0.82
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Text(isLost ? "LOST" : "FOUND")
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(isLost ? PHTheme.danger : PHTheme.success)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(PHTheme.surface.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(post.animalType.capitalized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PHTheme.text)
                    .lineLimit(1)
                Text(post.location ?? "Location not added")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(
                PHTheme.border,
                lineWidth: 0.7
            )
        )
    }
}

struct HomeRoomActivityRow: View {
    let room: PetRoom

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: room.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(room.accent)
                .frame(width: 42, height: 42)
                .background(room.accent.opacity(0.12))
                .clipShape(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PHTheme.text)
                Text(room.lastMessage.isEmpty ? "Open room" : room.lastMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PHTheme.placeholder)
        }
        .padding(14)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(
                PHTheme.border,
                lineWidth: 0.7
            )
        )
    }
}

struct HomeEmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(PHTheme.placeholder)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PHTheme.text)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(PHTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(
                PHTheme.border,
                lineWidth: 0.7
            )
        )
    }
}

struct HomeLoadingCard: View {
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().tint(PHTheme.accent)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PHTheme.subtext)
            Spacer()
        }
        .padding(18)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(
                PHTheme.border,
                lineWidth: 0.7
            )
        )
    }
}

// MARK: - Rooms View

enum RoomsSegment: String, CaseIterable {
    case myPets = "My Pets"
    case joinedRooms = "Joined Rooms"
}

struct RoomsView: View {
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var showCreateRoom = false
    @State private var showUpgradeSheet = false
    @State private var selectedSegment: RoomsSegment = .myPets

    private var myRooms: [PetRoom] { store.rooms.filter { $0.isOwned } }
    private var joinedRooms: [PetRoom] { store.rooms.filter { !$0.isOwned } }

    private var visibleRooms: [PetRoom] {
        let source = selectedSegment == .myPets ? myRooms : joinedRooms
        guard !searchText.isEmpty else { return source }
        return source.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.breed.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            PHPage {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                 
                        RoomsSegmentedControl(selectedSegment: $selectedSegment)
                            .padding(.horizontal, PHTheme.pagePadding)

                        RoomsTabContent(
                            title: selectedSegment == .myPets
                                ? (searchText.isEmpty ? "My Pets" : "Search Results")
                                : (searchText.isEmpty ? "Shared With Me" : "Search Results"),
                            emptyIcon: selectedSegment == .myPets ? "pawprint" : "person.2.slash",
                            emptyTitle: searchText.isEmpty
                                ? (selectedSegment == .myPets ? "No pets yet" : "No shared rooms yet")
                                : "No rooms found",
                            emptySubtitle: searchText.isEmpty
                                ? (selectedSegment == .myPets
                                   ? "Create your first pet room with the + button above."
                                   : "Rooms shared by other pet parents will appear here.")
                                : "Try searching a pet name or breed.",
                            rooms: visibleRooms
                        )
                        .environmentObject(store)
                        .environmentObject(subscriptionManager)

                        Spacer().frame(height: 110)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSearch) {
                RoomsSearchSheet(searchText: $searchText, rooms: store.rooms)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showUpgradeSheet) { UpgradeView() }
            .sheet(isPresented: $showCreateRoom) {
                CreateRoomView { newRoom in store.add(newRoom) }
            }
            .onAppear {
                Task { await store.fetchRooms() }
            }
        }
    }

    private func openCreateRoom() {
        if myRooms.count >= subscriptionManager.maxRooms {
            showUpgradeSheet = true
        } else {
            showCreateRoom = true
        }
    }
}

struct RoomsIconButton: View {
    let icon: String
    let action: () -> Void
    var isPrimary = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isPrimary ? .white : PHTheme.text)
                .frame(width: 42, height: 42)
                .background(isPrimary ? PHTheme.brandGradient : LinearGradient(colors: [PHTheme.surface], startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(isPrimary ? Color.clear : PHTheme.border, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
    }
}

struct RoomsMiniStat: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PHTheme.accent)
                .frame(width: 28, height: 28)
                .background(PHTheme.accent.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PHTheme.subtext)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(PHTheme.surface2.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(PHTheme.border, lineWidth: 0.6))
    }
}


struct RoomsTabContent: View {
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let title: String
    let emptyIcon: String
    let emptyTitle: String
    let emptySubtitle: String
    let rooms: [PetRoom]

    private let columns = [GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoomsSectionLabel(title: title)
                .padding(.horizontal, PHTheme.pagePadding)

            if rooms.isEmpty {
                HomeEmptyCard(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
                .padding(.horizontal, PHTheme.pagePadding)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(rooms) { room in
                        NavigationLink(
                            destination:
                                RoomView(room: room)
                                .environmentObject(store)
                                .environmentObject(subscriptionManager)
                                .onAppear { store.isInRoom = true }
                                .onDisappear { store.isInRoom = false }
                        ) {
                            PetRoomCard(
                                name: room.name,
                                breed: room.breed,
                                age: room.age,
                                icon: room.icon,
                                accentHex: room.accentHex,
                                memberCount: store.memberCounts[room.id]
                                    ?? max(room.members.count, 1),
                                lastMessage: room.lastMessage
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct JoinedRoomChip: View {
    let room: PetRoom

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: room.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(room.accent)
                .frame(width: 30, height: 30)
                .background(room.accent.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(room.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PHTheme.text)
                    .lineLimit(1)
                Text(room.breed)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PHTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(PHTheme.border, lineWidth: 0.7))
    }
}

struct RoomsSearchSheet: View {
    @Binding var searchText: String
    let rooms: [PetRoom]
    @Environment(\.dismiss) private var dismiss

    private var results: [PetRoom] {
        guard !searchText.isEmpty else { return rooms }
        return rooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.breed.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        PHPage {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Search")
                        .font(
                            .system(size: 28, weight: .black, design: .rounded)
                        )
                        .foregroundStyle(PHTheme.text)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PHTheme.text)
                            .frame(width: 34, height: 34)
                            .background(PHTheme.surface2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                PHSearchField(
                    placeholder: "Search rooms, pets, breeds…",
                    text: $searchText
                )

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(results) { room in
                            HStack(spacing: 12) {
                                Image(systemName: room.icon)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(room.accent)
                                    .frame(width: 42, height: 42)
                                    .background(room.accent.opacity(0.12))
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 14,
                                            style: .continuous
                                        )
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(room.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(PHTheme.text)
                                    Text(room.breed)
                                        .font(
                                            .system(size: 12, weight: .medium)
                                        )
                                        .foregroundStyle(PHTheme.subtext)
                                }
                                Spacer()
                                Text(room.isOwned ? "Mine" : "Joined")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(
                                        room.isOwned
                                            ? PHTheme.accent : PHTheme.accent2
                                    )
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        (room.isOwned
                                            ? PHTheme.accent : PHTheme.accent2)
                                            .opacity(0.12)
                                    )
                                    .clipShape(Capsule())
                            }
                            .padding(13)
                            .background(PHTheme.surface)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                ).stroke(PHTheme.border, lineWidth: 0.7)
                            )
                        }
                    }
                }
                Spacer()
            }
            .padding(PHTheme.pagePadding)
        }
    }
}

// MARK: - Rooms Segmented Control

struct RoomsSegmentedControl: View {
    @Binding var selectedSegment: RoomsSegment

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RoomsSegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(
                        .spring(response: 0.28, dampingFraction: 0.82)
                    ) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            selectedSegment == segment
                                ? .white : PHTheme.subtext
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(
                                    selectedSegment == segment
                                        ? PHTheme.coolGradient
                                        : LinearGradient(
                                            colors: [.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(PHTheme.surface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(PHTheme.border, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Empty Joined Rooms Card

struct EmptyJoinedRoomsCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(PHTheme.placeholder)
            Text("No joined rooms yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PHTheme.text)
            Text("Rooms you join from other pet parents will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(PHTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PHTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(PHTheme.border, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Section Label

struct RoomsSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(PHTheme.subtext)
    }
}

// MARK: - Lost Room Card

struct LostRoomCard: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var store: RoomStore

    let lostCount: Int
    let foundCount: Int
    let myLostCount: Int
    let isLoading: Bool

    private var subtitle: String {
        if isLoading { return "Loading latest lost and found posts..." }
        if lostCount == 0 && foundCount == 0 {
            return "No active lost or found posts right now"
        }
        if myLostCount > 0 {
            return
                "You have \(myLostCount) active lost pet alert\(myLostCount == 1 ? "" : "s")"
        }
        return "\(lostCount) lost • \(foundCount) found active posts"
    }

    var body: some View {
        NavigationLink {
            LostAndFoundView()
                .environmentObject(subscriptionManager)
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .tabBar)
                .onAppear { store.isInRoom = true }
                .onDisappear { store.isInRoom = false }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(PHTheme.danger.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(
                            systemName: myLostCount > 0
                                ? "exclamationmark.triangle.fill"
                                : "pawprint.fill"
                        )
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(PHTheme.danger)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            myLostCount > 0
                                ? "Your Lost Pet Alert" : "Lost & Found"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PHTheme.text)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(PHTheme.subtext)
                    }

                    Spacer()

                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else if myLostCount > 0 {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(PHTheme.danger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(PHTheme.danger.opacity(0.15))
                            )
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(PHTheme.placeholder)
                    }
                }

                if !isLoading && (lostCount > 0 || foundCount > 0) {
                    HStack(spacing: 10) {
                        LostFoundStatPill(
                            title: "Lost",
                            count: lostCount,
                            icon: "exclamationmark.triangle.fill"
                        )
                        LostFoundStatPill(
                            title: "Found",
                            count: foundCount,
                            icon: "checkmark.circle.fill"
                        )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(PHTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                PHTheme.danger.opacity(
                                    myLostCount > 0 ? 0.35 : 0.16
                                ),
                                lineWidth: 0.8
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct LostFoundStatPill: View {
    let title: String
    let count: Int
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text("\(count) \(title)")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(PHTheme.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(PHTheme.surface2)
                .overlay(Capsule().stroke(PHTheme.border, lineWidth: 0.5))
        )
    }
}

// MARK: - Pet Room Card

struct PetRoomCard: View {
    let name: String
    let breed: String
    let age: String
    let icon: String
    let accentHex: String
    let memberCount: Int
    var lastMessage: String = ""

    private var accent: Color { Color(hex: accentHex) }
    private var detailText: String {
        if !breed.isEmpty { return breed }
        if !age.isEmpty { return age }
        return "Pet room"
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(accent.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(accent)

                if !lastMessage.isEmpty {
                    Circle()
                        .fill(PHTheme.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(PHTheme.surface, lineWidth: 2))
                        .offset(x: -7, y: -7)
                }
            }
            .frame(width: 64, height: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(PHTheme.border, lineWidth: 0.7)
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(PHTheme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PHTheme.placeholder)
                }

                Text(detailText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Label("\(memberCount)", systemImage: "person.2.fill")
                    Text("•")
                    Text(lastMessage.isEmpty ? "Open room" : lastMessage)
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PHTheme.muted)
            }
        }
        .padding(12)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PHTheme.border.opacity(0.9), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 7)
    }
}

// MARK: - Add Pet Ghost Card

struct AddPetCard: View {
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showCreateRoom = false
    @State private var showUpgradeSheet = false

    var body: some View {
        Button {
            if store.rooms.filter({ $0.isOwned }).count
                >= subscriptionManager.maxRooms
            {
                showUpgradeSheet = true
            } else {
                showCreateRoom = true
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(PHTheme.brandGradient)
                    .clipShape(Circle())
                Text("Create Room")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PHTheme.text)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(PHTheme.surface.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(
                                style: StrokeStyle(
                                    lineWidth: 1.2,
                                    dash: [7, 5]
                                )
                            )
                            .foregroundStyle(PHTheme.accent.opacity(0.45))
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
        .sheet(isPresented: $showCreateRoom) {
            CreateRoomView { newRoom in
                store.add(newRoom)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sm = SubscriptionManager()
    return MainTabView(subscriptionManager: sm)
        .task { sm.tier = .pro }
}
