//
//  WelcomeView.swift  (updated)
//  PetHub
//
//  Changes: PetRoomCard now navigates to RoomView.
//           Color(hex:) extension included here.
//

import Combine
import Supabase
import SwiftUI

// MARK: - Room Store

class RoomStore: ObservableObject {
    @Published var rooms: [PetRoom] = []
    @Published var isInRoom: Bool = false

    func add(_ room: PetRoom) {
        rooms.append(room)
    }

    func fetchRooms() async {
        do {
            let user = try await supabase.auth.session.user
            print("Fetching rooms for user: \(user.id)")

            let ownedRooms: [SupabaseRoom] =
                try await supabase
                .from("rooms")
                .select()
                .eq("owner_id", value: user.id.uuidString)
                .execute()
                .value
            print("Owned rooms: \(ownedRooms.count)")

            let memberships: [RoomMembership] =
                try await supabase
                .from("room_members")
                .select()
                .eq("user_id", value: user.id.uuidString.lowercased())
                .eq("role", value: "member")
                .execute()
                .value
            print("Memberships: \(memberships.count)")

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

            struct LastMessage: Codable {
                let createdAt: Date
                let body: String?
                enum CodingKeys: String, CodingKey {
                    case createdAt = "created_at"
                    case body
                }
            }

            for i in allRooms.indices {
                let roomId = allRooms[i].id.uuidString

                struct LastMessage: Codable {
                    let createdAt: Date
                    let body: String?
                    enum CodingKeys: String, CodingKey {
                        case createdAt = "created_at"
                        case body
                    }
                }

                // Get latest activity from messages, photos, comments, likes
                let lastMsg: [LastMessage] =
                    (try? await supabase.from("messages").select().eq(
                        "room_id",
                        value: roomId
                    ).order("created_at", ascending: false).limit(1).execute()
                        .value) ?? []

                allRooms[i].lastMessage = lastMsg.first?.body ?? ""  // ← after lastMsg

                let lastPhoto: [LastMessage] =
                    (try? await supabase.from("photo_posts").select().eq(
                        "room_id",
                        value: roomId
                    ).order("created_at", ascending: false).limit(1).execute()
                        .value) ?? []

                let lastActivity: [LastMessage] =
                    (try? await supabase.from("activities").select().eq(
                        "room_id",
                        value: roomId
                    ).order("created_at", ascending: false).limit(1).execute()
                        .value) ?? []

                let dates = [
                    lastMsg.first?.createdAt,
                    lastPhoto.first?.createdAt,
                    lastActivity.first?.createdAt,
                ].compactMap { $0 }

                allRooms[i].lastActivity = dates.max() ?? Date.distantPast
            }

            await MainActor.run {
                self.rooms = allRooms.sorted {
                    $0.lastActivity > $1.lastActivity
                }
            }
        } catch {
            print("Fetch rooms error: \(error)")
        }
    }
}
// MARK: - Tab Enum

enum AppTab {
    case rooms, activity, profile
}

// MARK: - Root App Shell

struct MainTabView: View {
    @StateObject private var store = RoomStore()
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab: AppTab = .rooms

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .rooms:
                    RoomsView()
                        .environmentObject(store)
                        .environmentObject(subscriptionManager)
                case .activity:
                    ActivityPlaceholderView()
                        .environmentObject(store)
                case .profile:
                    ProfilePlaceholderView()
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
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(
                icon: "house.fill",
                label: "Rooms",
                tab: .rooms,
                selected: $selectedTab
            )
            TabBarItem(
                icon: "bolt.fill",
                label: "Activity",
                tab: .activity,
                selected: $selectedTab
            )
            TabBarItem(
                icon: "person.crop.circle.fill",
                label: "Profile",
                tab: .profile,
                selected: $selectedTab
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color("AppSurface").opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color("AppBorder"), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 6)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isActive
                            ? Color(hex: "AA9DFF") : Color("AppWhiteText")
                    )
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        isActive
                            ? Color(hex: "AA9DFF") : Color("AppWhiteText")
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isActive
                            ? Color(hex: "AA9DFF").opacity(0.12) : Color.clear
                    )
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rooms View

struct RoomsView: View {
    @EnvironmentObject private var store: RoomStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var searchText = ""

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var myRooms: [PetRoom] { store.rooms.filter { $0.isOwned } }
    private var memberRooms: [PetRoom] { store.rooms.filter { !$0.isOwned } }

    private var filteredMyRooms: [PetRoom] {
        if searchText.isEmpty { return myRooms }
        return myRooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.breed.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredMemberRooms: [PetRoom] {
        if searchText.isEmpty { return memberRooms }
        return memberRooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.breed.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rooms")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color("AppText"))
                            Text(
                                "\(store.rooms.count) room\(store.rooms.count == 1 ? "" : "s") active"
                            )
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppWhiteText"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color("AppPlaceholder"))
                            TextField("Search rooms...", text: $searchText)
                                .foregroundStyle(Color("AppText"))
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color("AppSurface"))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        // Lost & Found
                        RoomsSectionLabel(title: "Lost & Found")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        LostRoomCard()
                            .environmentObject(subscriptionManager)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)

                        // My Pets
                        RoomsSectionLabel(title: "My Pets")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredMyRooms) { room in
                                NavigationLink(
                                    destination:
                                        RoomView(room: room)
                                        .onAppear { store.isInRoom = true }
                                        .onDisappear { store.isInRoom = false }
                                ) {
                                    PetRoomCard(
                                        name: room.name,
                                        breed: room.breed,
                                        age: room.age,
                                        icon: room.icon,
                                        accentHex: room.accentHex,
                                        lastMessage: room.lastMessage
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            AddPetCard().environmentObject(store)
                        }
                        .padding(.horizontal, 16)

                        // Member Rooms
                        if !filteredMemberRooms.isEmpty {
                            RoomsSectionLabel(title: "Joined Rooms")
                                .padding(.horizontal, 20)
                                .padding(.top, 28)
                                .padding(.bottom, 12)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredMemberRooms) { room in
                                    NavigationLink(
                                        destination:
                                            RoomView(room: room)
                                            .onAppear { store.isInRoom = true }
                                            .onDisappear {
                                                store.isInRoom = false
                                            }
                                    ) {
                                        PetRoomCard(
                                            name: room.name,
                                            breed: room.breed,
                                            age: room.age,
                                            icon: room.icon,
                                            accentHex: room.accentHex,
                                            lastMessage: room.lastMessage
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 110)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task { await store.fetchRooms() }
            }
        }
    }
}

// MARK: - Section Label

struct RoomsSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(Color("AppSubtext"))
    }
}

// MARK: - Lost Room Card

struct LostRoomCard: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showLostFound = false
    @State private var showUpgrade = false

    var body: some View {
        Button {
            showLostFound = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(hex: "E25718").opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(hex: "E25718"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Lost Animals")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("AppText"))
                    Text("Community · 12 reports nearby")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("AppSubtext"))
                }

                Spacer()

                Text("12")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "E25718"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color(hex: "E25718").opacity(0.15))
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppPlaceholder"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("AppSurface"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                Color(hex: "E25718").opacity(0.2),
                                lineWidth: 0.5
                            )
                    )
            )
        }
        //        .sheet(isPresented: $showLostFound){
        //            Text("Test")
        //        }
        .sheet(isPresented: $showLostFound) {
            LostAndFoundView()
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pet Room Card

struct PetRoomCard: View {
    let name: String
    let breed: String
    let age: String
    let icon: String
    let accentHex: String
    var lastMessage: String = ""

    private var accent: Color { Color(hex: accentHex) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(accent.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundStyle(accent.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
                if !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(Color("AppPlaceholder"))
                        .lineLimit(1)
                } else {
                    Text("\(breed) · \(age)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("AppSubtext"))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color("AppSurface2"))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color("AppBorder"), lineWidth: 0.5)
        )
    }
}

// MARK: - Add Pet Ghost Card

struct AddPetCard: View {
    @EnvironmentObject private var store: RoomStore
    @State private var showCreateRoom = false
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
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
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color("AppPlaceholder"))
                Text("Create Room")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppPlaceholder"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 185)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("AppBorder").opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                            )
                            .foregroundStyle(Color("AppBorder"))
                    )
            )
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCreateRoom) {
            CreateRoomView { newRoom in
                store.add(newRoom)
            }
        }
    }
}

// MARK: - Placeholder Views

struct ActivityPlaceholderView: View {
    var body: some View {
        ActivityView()
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        ProfileView()
    }
}

// MARK: - Preview

#Preview {
    MainTabView(subscriptionManager: SubscriptionManager())
}
