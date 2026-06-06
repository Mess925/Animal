//
//  RoomSettingsView.swift
//  PetHub
//

import Supabase
import SwiftUI

// MARK: - RoomSettingsView

struct RoomSettingsView: View {
    let room: PetRoom

    @State private var isOwner = false
    @State private var showEditRoom = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RoomStore
    @State private var notifyPhotos = true
    @State private var notifyMessages = true
    @State private var notifyReactions = false
    @State private var selectedAccent: Color
    @State private var showDeleteAlert = false
    @State private var showAddMember = false
    @State private var members: [Member]

    private let colorOptions: [(Color, String)] = [
        (Color(hex: "AA9DFF"), "AA9DFF"),
        (Color(hex: "FF6B6B"), "FF6B6B"),
        (Color(hex: "4ECDC4"), "4ECDC4"),
        (Color(hex: "FFD166"), "FFD166"),
        (Color(hex: "06D6A0"), "06D6A0"),
        (Color(hex: "F72585"), "F72585"),
    ]

    init(room: PetRoom) {
        self.room = room
        _selectedAccent = State(initialValue: room.accent)
        _members = State(initialValue: room.members)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Pet banner
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedAccent.opacity(0.12))
                            .frame(width: 60, height: 60)
                        Image(systemName: room.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(selectedAccent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(room.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color("AppText"))
                        Text("\(room.breed) · \(room.age)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("AppSubtext"))
                    }

                    Spacer()

                    Button {
                        showEditRoom = true
                    } label: {
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedAccent.opacity(0.12))
                                    .overlay(
                                        Capsule().stroke(
                                            selectedAccent.opacity(0.25),
                                            lineWidth: 0.5
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedAccent.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    selectedAccent.opacity(0.12),
                                    lineWidth: 0.5
                                )
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // MARK: Room color
                SettingsSectionLabel(title: "Room color")
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.1) { color, hex in
                        let isSelected = selectedAccent == color
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                selectedAccent = color
                            }
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.white.opacity(
                                                isSelected ? 0.9 : 0
                                            ),
                                            lineWidth: 2
                                        )
                                        .padding(3)
                                )
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: isSelected)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                // MARK: Notifications
                SettingsSectionLabel(title: "Notifications")
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                SettingsCard {
                    SettingsToggleRow(
                        icon: "bell.fill",
                        iconColor: selectedAccent,
                        label: "New photos",
                        sublabel: "When someone posts a photo",
                        isOn: $notifyPhotos
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        icon: "bubble.left.fill",
                        iconColor: Color(hex: "7EC8C8"),
                        label: "Chat messages",
                        sublabel: "New messages in room",
                        isOn: $notifyMessages
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        icon: "heart.fill",
                        iconColor: Color(hex: "F4A84A"),
                        label: "Reactions & comments",
                        sublabel: nil,
                        isOn: $notifyReactions
                    )
                }
                .padding(.horizontal, 16)

                // MARK: Members
                SettingsSectionLabel(title: "Members · \(members.count)")
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                SettingsCard {
                    ForEach(members) { member in
                        MemberSettingsRow(
                            member: member,
                            accentColor: selectedAccent,
                            canRemove: isOwner && !member.isOwner,
                            onRemove: {
                                withAnimation {
                                    members.removeAll { $0.id == member.id }
                                }
                            }
                        )
                        if member.id != members.last?.id {
                            SettingsDivider()
                        }
                    }

                    // Add member
                    SettingsDivider()
                    Button {
                        showAddMember = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        style: StrokeStyle(
                                            lineWidth: 1,
                                            dash: [4, 3]
                                        )
                                    )
                                    .foregroundStyle(Color("AppDivider"))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "plus")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color("AppSubtext"))
                            }
                            Text("Invite someone")
                                .font(.system(size: 14))
                                .foregroundStyle(Color("AppWhiteText"))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // MARK: Danger zone
                if isOwner {
                    SettingsSectionLabel(title: "Danger zone")
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 12)

                    SettingsCard {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: "E25718").opacity(0.1))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: "E25718"))
                                }
                                Text("Delete room")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: "E25718"))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 100)
            }
        }
        .sheet(isPresented: $showEditRoom) {
            EditRoomView(room: room).environmentObject(store)
        }
        .task {
            await fetchMembers()
            let user = try? await supabase.auth.session.user
            isOwner = room.members.first(where: { $0.isOwner })?.id == user?.id
            // or check from room_members
            if let userId = user?.id {
                let rows: [RoomMembership] =
                    (try? await supabase
                        .from("room_members")
                        .select()
                        .eq("room_id", value: room.id.uuidString)
                        .eq("user_id", value: userId.uuidString)
                        .execute()
                        .value) ?? []
                isOwner = rows.first?.role == "owner"  // need role in RoomMembership
            }
        }
        .sheet(isPresented: $showAddMember) {
            InviteMemberView(room: room)
        }
        .alert("Delete Room?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await deleteRoom() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "All photos and messages in \(room.name)'s room will be permanently deleted."
            )
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

            let rows: [RoomMemberRow] =
                try await supabase
                .from("room_members")
                .select()
                .eq("room_id", value: room.id.uuidString)
                .execute()
                .value

            var fetchedMembers: [Member] = []

            for row in rows {
                let profiles: [UserProfile] =
                    try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: row.userId.uuidString)
                    .execute()
                    .value

                if let p = profiles.first {
                    fetchedMembers.append(
                        Member(
                            id: row.userId,
                            name: p.name,
                            initials: String(p.name.prefix(1)),
                            accentHex: p.avatarAccentHex ?? "AA9DFF",
                            isOnline: false,
                            isOwner: row.role == "owner"
                        )
                    )
                }
            }

            await MainActor.run {
                members = fetchedMembers
            }
        } catch {
            print("Fetch members error: \(error)")
        }
    }

    private func deleteRoom() async {
        do {
            try await supabase
                .from("rooms")
                .delete()
                .eq("id", value: room.id.uuidString)
                .execute()
            await MainActor.run {
                store.rooms.removeAll { $0.id == room.id }
            }
            dismiss()
        } catch {
            print("Delete room error: \(error)")
        }
    }
}

// MARK: - Helpers

struct SettingsSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(Color("AppSubtext"))
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) { content }
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

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("AppDivider"))
            .frame(height: 0.5)
            .padding(.leading, 62)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let sublabel: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("AppText"))
                if let sub = sublabel {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(Color("AppWhiteText"))
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Color(hex: "AA9DFF"))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

struct MemberSettingsRow: View {
    let member: Member
    let accentColor: Color
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MemberAvatar(member: member, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("AppText"))
                Text(member.isOwner ? "Owner" : "Member")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("AppWhiteText"))
            }

            Spacer()

            if member.isOwner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(accentColor.opacity(0.7))
            } else if canRemove {
                Button {
                    onRemove()
                } label: {
                    Text("Remove")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "E25718"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(hex: "E25718").opacity(0.1))
                                .overlay(
                                    Capsule().stroke(
                                        Color(hex: "E25718").opacity(0.2),
                                        lineWidth: 0.5
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    RoomSettingsView(room: .mochi)
        .background(Color("AppBackground"))
}
