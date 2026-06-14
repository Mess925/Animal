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
    @Published var isInRoom: Bool = false

    func add(_ room: PetRoom) {
        rooms.append(room)
    }

    func fetchRooms() async {
        do {
            let user = try await supabase.auth.session.user
            phLog("Fetching rooms for user: \(user.id)")

            let ownedRooms: [SupabaseRoom] = try await supabase
                .from("rooms")
                .select()
                .eq("owner_id", value: user.id.uuidString)
                .execute()
                .value
            phLog("Owned rooms: \(ownedRooms.count)")

            let memberships: [RoomMembership] = try await supabase
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
                memberRooms = try await supabase
                    .from("rooms")
                    .select()
                    .in("id", values: memberRoomIds)
                    .execute()
                    .value
            }

            var allRooms: [PetRoom] =
                ownedRooms.map { $0.toPetRoom(isOwned: true) }
                + memberRooms.map { $0.toPetRoom(isOwned: false) }

            // Fetch last activity for all rooms concurrently instead of serially
            try await withThrowingTaskGroup(of: (Int, Date?, String?).self) { group in
                for (i, room) in allRooms.enumerated() {
                    let roomId = room.id.uuidString
                    group.addTask {
                        async let lastMsg: [RoomActivity] = (try? await supabase
                            .from("messages")
                            .select("created_at, body")
                            .eq("room_id", value: roomId)
                            .order("created_at", ascending: false)
                            .limit(1)
                            .execute()
                            .value) ?? []

                        async let lastPhoto: [RoomActivity] = (try? await supabase
                            .from("photo_posts")
                            .select("created_at")
                            .eq("room_id", value: roomId)
                            .order("created_at", ascending: false)
                            .limit(1)
                            .execute()
                            .value) ?? []

                        async let lastActivity: [RoomActivity] = (try? await supabase
                            .from("activities")
                            .select("created_at")
                            .eq("room_id", value: roomId)
                            .order("created_at", ascending: false)
                            .limit(1)
                            .execute()
                            .value) ?? []

                        let (msg, photo, act) = try await (lastMsg, lastPhoto, lastActivity)

                        let latestDate = [msg.first?.createdAt, photo.first?.createdAt, act.first?.createdAt]
                            .compactMap { $0 }
                            .max()

                        return (i, latestDate, msg.first?.body)
                    }
                }

                for try await (i, latestDate, lastBody) in group {
                    allRooms[i].lastActivity = latestDate ?? Date.distantPast
                    allRooms[i].lastMessage  = lastBody ?? ""
                }
            }

            let sorted = allRooms.sorted { $0.lastActivity > $1.lastActivity }
            await MainActor.run { self.rooms = sorted }

        } catch {
            phLog("Fetch rooms error: \(error)")
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
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(icon: "house.fill",             label: "Rooms",    tab: .rooms,    selected: $selectedTab)
            TabBarItem(icon: "bolt.fill",              label: "Activity", tab: .activity, selected: $selectedTab)
            TabBarItem(icon: "person.crop.circle.fill", label: "Profile",  tab: .profile,  selected: $selectedTab)
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
                    .foregroundStyle(isActive ? Color(hex: "AA9DFF") : Color("AppWhiteText"))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isActive ? Color(hex: "AA9DFF") : Color("AppWhiteText"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isActive ? Color(hex: "AA9DFF").opacity(0.12) : Color.clear)
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
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
    @State private var selectedSegment: RoomsSegment = .myPets
    @State private var lostFoundPosts: [LostFoundPost] = []
    @State private var currentUserId: UUID? = nil
    @State private var isLoadingLostFound = false

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var myRooms: [PetRoom]     { store.rooms.filter { $0.isOwned } }
    private var memberRooms: [PetRoom] { store.rooms.filter { !$0.isOwned } }

    private var activeLostPosts: [LostFoundPost] {
        lostFoundPosts.filter { $0.reportType == "lost" && $0.isActive }
    }

    private var activeFoundPosts: [LostFoundPost] {
        lostFoundPosts.filter { $0.reportType == "found" && $0.isActive }
    }

    private var myActiveLostPosts: [LostFoundPost] {
        guard let currentUserId else { return [] }
        return activeLostPosts.filter { $0.userId == currentUserId }
    }

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
                            Text("\(store.rooms.count) room\(store.rooms.count == 1 ? "" : "s") active")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("AppWhiteText"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                        // Search
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

                        RoomsSegmentedControl(selectedSegment: $selectedSegment)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        if selectedSegment == .myPets {
                            LostRoomCard(
                                lostCount: activeLostPosts.count,
                                foundCount: activeFoundPosts.count,
                                myLostCount: myActiveLostPosts.count,
                                isLoading: isLoadingLostFound
                            )
                            .environmentObject(subscriptionManager)
                            .environmentObject(store)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 22)

                            RoomsSectionLabel(title: "My Pets")
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredMyRooms) { room in
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
                                            lastMessage: room.lastMessage
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                AddPetCard()
                                    .environmentObject(store)
                                    .environmentObject(subscriptionManager)
                            }
                            .padding(.horizontal, 16)

                        } else {
                            RoomsSectionLabel(title: "Joined Rooms")
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                            if filteredMemberRooms.isEmpty {
                                EmptyJoinedRoomsCard()
                                    .padding(.horizontal, 16)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filteredMemberRooms) { room in
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
                                                lastMessage: room.lastMessage
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer().frame(height: 110)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await store.fetchRooms()
                    await fetchLostFoundPosts()
                }
            }
        }
    }

    private func fetchLostFoundPosts() async {
        isLoadingLostFound = true
        do {
            async let userSession = supabase.auth.session
            async let fetched: [LostFoundPost] = supabase
                .from("lost_found")
                .select()
                .neq("status", value: "deleted")
                .order("created_at", ascending: false)
                .execute()
                .value

            let (session, results) = try await (userSession, fetched)

            await MainActor.run {
                currentUserId = session.user.id
                lostFoundPosts = results
                isLoadingLostFound = false
            }
        } catch {
            phLog("Fetch lost found summary error: \(error)")
            await MainActor.run { isLoadingLostFound = false }
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
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedSegment == segment ? Color("AppText") : Color("AppSubtext"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(selectedSegment == segment ? Color("AppSurface2") : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(Color("AppSurface"))
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(Color("AppBorder"), lineWidth: 0.5)
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
                .foregroundStyle(Color("AppPlaceholder"))
            Text("No joined rooms yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color("AppText"))
            Text("Rooms you join from other pet parents will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(Color("AppSubtext"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("AppBorder"), lineWidth: 0.5)
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
            .foregroundStyle(Color("AppSubtext"))
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
        if lostCount == 0 && foundCount == 0 { return "No active lost or found posts right now" }
        if myLostCount > 0 { return "You have \(myLostCount) active lost pet alert\(myLostCount == 1 ? "" : "s")" }
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
                            .fill(Color(hex: "E25718").opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: myLostCount > 0 ? "exclamationmark.triangle.fill" : "pawprint.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color(hex: "E25718"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(myLostCount > 0 ? "Your Lost Pet Alert" : "Lost & Found")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color("AppText"))
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Color("AppSubtext"))
                    }

                    Spacer()

                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else if myLostCount > 0 {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(Color(hex: "E25718"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color(hex: "E25718").opacity(0.15)))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("AppPlaceholder"))
                    }
                }

                if !isLoading && (lostCount > 0 || foundCount > 0) {
                    HStack(spacing: 10) {
                        LostFoundStatPill(title: "Lost",  count: lostCount,  icon: "exclamationmark.triangle.fill")
                        LostFoundStatPill(title: "Found", count: foundCount, icon: "checkmark.circle.fill")
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("AppSurface"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: "E25718").opacity(myLostCount > 0 ? 0.35 : 0.16), lineWidth: 0.8)
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
        .foregroundStyle(Color("AppText"))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color("AppSurface2"))
                .overlay(Capsule().stroke(Color("AppBorder"), lineWidth: 0.5))
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
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showCreateRoom = false
    @State private var showUpgradeSheet = false

    var body: some View {
        Button {
            if store.rooms.filter({ $0.isOwned }).count >= subscriptionManager.maxRooms {
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
