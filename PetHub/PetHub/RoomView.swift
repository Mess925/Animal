//
//  WelcomeView.swift  (updated)
//  PetHub
//
//  Changes: PetRoomCard now navigates to RoomView.
//           Color(hex:) extension included here.
//

import Combine
import SwiftUI
import Supabase

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
            let fetched: [SupabaseRoom] = try await supabase
                .from("rooms")
                .select()
                .eq("owner_id", value: user.id.uuidString)
                .execute()
                .value
            await MainActor.run {
                self.rooms = fetched.map { $0.toPetRoom() }
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
    @State private var selectedTab: AppTab = .rooms

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .rooms: RoomsView().environmentObject(store)
                case .activity: ActivityPlaceholderView()
                case .profile: ProfilePlaceholderView().environmentObject(store)
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

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

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

                        // Lost & Found
                        RoomsSectionLabel(title: "Lost & Found")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        LostRoomCard()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)

                        // My Pets
                        RoomsSectionLabel(title: "My Pets")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.rooms) { room in
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
                                        accentHex: room.accentHex
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            AddPetCard().environmentObject(store)
                        }
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 110)
                    }
                }
            }
            .navigationBarHidden(true)
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
    var body: some View {
        Button {
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
                Text("\(breed) · \(age)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color("AppSubtext"))
                    .lineLimit(1)
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

    var body: some View {
        Button {
            showCreateRoom = true
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

#Preview { MainTabView() }
