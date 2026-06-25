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
    @State private var notifyDM = true
    @State private var notifyFoundPet = true
    @State private var isLoadingNotificationSettings = true

    @State private var selectedAccent: Color
    @State private var showDeleteAlert = false
    @State private var showLeaveAlert = false
    @State private var showAddMember = false
    @State private var members: [Member]

    private let colorOptions: [(Color, String)] = [
        (PHTheme.accent, "AA9DFF"),
        (PHTheme.accent3, "FF6B6B"),
        (Color(hex: "4ECDC4"), "4ECDC4"),
        (Color(hex: "FFD166"), "FFD166"),
        (PHTheme.success, "06D6A0"),
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

                        if let imageUrl = room.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: room.icon)
                                    .font(.system(size: 28))
                                    .foregroundStyle(selectedAccent)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            Image(systemName: room.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(selectedAccent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(room.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(PHTheme.text)
                        Text("\(room.breed) · \(room.age)")
                            .font(.system(size: 12))
                            .foregroundStyle(PHTheme.subtext)
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
                    RoundedRectangle(cornerRadius: 28)
                        .fill(selectedAccent.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(selectedAccent.opacity(0.12), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // MARK: Notifications
                SettingsSectionLabel(title: "Notifications")
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                SettingsCard {
                    if isLoadingNotificationSettings {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(PHTheme.accent)

                            Text("Loading notification settings…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PHTheme.subtext)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    } else {
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
                            iconColor: PHTheme.accent2,
                            label: "Chat messages",
                            sublabel: "New messages in room",
                            isOn: $notifyMessages
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "heart.fill",
                            iconColor: PHTheme.warning,
                            label: "Reactions & comments",
                            sublabel: "Likes and comments on photos",
                            isOn: $notifyReactions
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "paperplane.fill",
                            iconColor: PHTheme.accent,
                            label: "Direct messages",
                            sublabel: "Private messages from members",
                            isOn: $notifyDM
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "pawprint.fill",
                            iconColor: PHTheme.success,
                            label: "Found your pet",
                            sublabel: "Possible found-pet matches",
                            isOn: $notifyFoundPet
                        )
                    }
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
                                Task {
                                    await removeMember(member)
                                }
                            }
                        )

                        if member.id != members.last?.id {
                            SettingsDivider()
                        }
                    }

                    SettingsDivider()

                    Button {
                        showAddMember = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                    )
                                    .foregroundStyle(PHTheme.divider)
                                    .frame(width: 38, height: 38)

                                Image(systemName: "plus")
                                    .font(.system(size: 14))
                                    .foregroundStyle(PHTheme.subtext)
                            }

                            Text("Invite someone")
                                .font(.system(size: 14))
                                .foregroundStyle(PHTheme.subtext)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // MARK: Danger zone
                SettingsSectionLabel(title: "Room actions")
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                SettingsCard {
                    if isOwner {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(PHTheme.danger.opacity(0.1))
                                        .frame(width: 34, height: 34)

                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(PHTheme.danger)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete room")
                                        .font(.system(size: 14))
                                        .foregroundStyle(PHTheme.danger)

                                    Text("Permanently removes this pet room")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PHTheme.subtext)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            showLeaveAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(PHTheme.danger.opacity(0.1))
                                        .frame(width: 34, height: 34)

                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(PHTheme.danger)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Leave room")
                                        .font(.system(size: 14))
                                        .foregroundStyle(PHTheme.danger)

                                    Text("Remove this room from Joined Rooms")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PHTheme.subtext)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 100)
            }
        }
        .sheet(isPresented: $showEditRoom, onDismiss: {
            if let updatedRoom = store.rooms.first(where: { $0.id == room.id }) {
                selectedAccent = Color(hex: updatedRoom.accentHex)
            }
        }) {
            EditRoomView(room: room)
                .environmentObject(store)
        }
        .task {
            await fetchMembers()
            await checkOwner()
            await loadNotificationSettings()
        }
        .onChange(of: notifyPhotos) { _, _ in
            saveNotificationSettingsIfReady()
        }
        .onChange(of: notifyMessages) { _, _ in
            saveNotificationSettingsIfReady()
        }
        .onChange(of: notifyReactions) { _, _ in
            saveNotificationSettingsIfReady()
        }
        .onChange(of: notifyDM) { _, _ in
            saveNotificationSettingsIfReady()
        }
        .onChange(of: notifyFoundPet) { _, _ in
            saveNotificationSettingsIfReady()
        }
        .sheet(isPresented: $showAddMember, onDismiss: {
            Task {
                await fetchMembers()
            }
        }) {
            InviteMemberView(room: room)
        }
        .alert("Delete Room?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await deleteRoom() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All photos and messages in \(room.name)'s room will be permanently deleted.")
        }
        .alert("Leave Room?", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) {
                Task { await leaveRoom() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will stop seeing \(room.name)'s room in Joined Rooms.")
        }
    }

    private func saveNotificationSettingsIfReady() {
        guard !isLoadingNotificationSettings else { return }

        Task {
            await saveNotificationSettings()
        }
    }

    private func checkOwner() async {
        do {
            let user = try await supabase.auth.session.user

            let rows: [RoomMembership] =
                try await supabase
                .from("room_members")
                .select()
                .eq("room_id", value: room.id.uuidString)
                .eq("user_id", value: user.id.uuidString)
                .execute()
                .value

            await MainActor.run {
                isOwner = rows.first?.role == "owner"
            }
        } catch {
            await MainActor.run {
                isOwner = false
            }
        }
    }

    private func loadNotificationSettings() async {
        await MainActor.run {
            isLoadingNotificationSettings = true
        }

        do {
            let user = try await supabase.auth.session.user

            struct NotificationSettingsRow: Codable {
                let notifyPhotos: Bool
                let notifyMessages: Bool
                let notifyReactions: Bool
                let notifyDM: Bool
                let notifyFoundPet: Bool

                enum CodingKeys: String, CodingKey {
                    case notifyPhotos = "notify_photos"
                    case notifyMessages = "notify_messages"
                    case notifyReactions = "notify_reactions"
                    case notifyDM = "notify_dm"
                    case notifyFoundPet = "notify_found_pet"
                }
            }

            let rows: [NotificationSettingsRow] =
                try await supabase
                .from("room_notification_settings")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .eq("room_id", value: room.id.uuidString)
                .execute()
                .value

            if let row = rows.first {
                await MainActor.run {
                    notifyPhotos = row.notifyPhotos
                    notifyMessages = row.notifyMessages
                    notifyReactions = row.notifyReactions
                    notifyDM = row.notifyDM
                    notifyFoundPet = row.notifyFoundPet
                    isLoadingNotificationSettings = false
                }
            } else {
                await MainActor.run {
                    isLoadingNotificationSettings = false
                }

                await saveNotificationSettings()
            }
        } catch {
            await MainActor.run {
                isLoadingNotificationSettings = false
            }
        }
    }

    private func saveNotificationSettings() async {
        do {
            let user = try await supabase.auth.session.user

            struct NotificationSettingsUpsert: Codable {
                let userId: String
                let roomId: String
                let notifyPhotos: Bool
                let notifyMessages: Bool
                let notifyReactions: Bool
                let notifyDM: Bool
                let notifyFoundPet: Bool
                let updatedAt: String

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case roomId = "room_id"
                    case notifyPhotos = "notify_photos"
                    case notifyMessages = "notify_messages"
                    case notifyReactions = "notify_reactions"
                    case notifyDM = "notify_dm"
                    case notifyFoundPet = "notify_found_pet"
                    case updatedAt = "updated_at"
                }
            }

            let payload = NotificationSettingsUpsert(
                userId: user.id.uuidString,
                roomId: room.id.uuidString,
                notifyPhotos: notifyPhotos,
                notifyMessages: notifyMessages,
                notifyReactions: notifyReactions,
                notifyDM: notifyDM,
                notifyFoundPet: notifyFoundPet,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("room_notification_settings")
                .upsert(payload, onConflict: "user_id,room_id")
                .execute()
        } catch {
            #if DEBUG
            print("RoomSettingsView.swift:476 error:", error)
            #endif
        }
    }

    private func removeMember(_ member: Member) async {
        do {
            guard !member.isOwner else { return }

            try await supabase
                .from("room_members")
                .delete()
                .eq("room_id", value: room.id.uuidString)
                .eq("user_id", value: member.id.uuidString)
                .execute()

            await MainActor.run {
                withAnimation {
                    members.removeAll { $0.id == member.id }
                }
            }
        } catch {
            #if DEBUG
            print("RoomSettingsView.swift:496 error:", error)
            #endif
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
                            avatarUrl: p.avatarUrl,
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
            #if DEBUG
            print("RoomSettingsView.swift:548 error:", error)
            #endif
        }
    }

    private func leaveRoom() async {
        do {
            let user = try await supabase.auth.session.user

            try? await supabase
                .from("activities")
                .insert([
                    "type": "room_left",
                    "actor_id": user.id.uuidString,
                    "room_id": room.id.uuidString
                ])
                .execute()

            try await supabase
                .from("room_members")
                .delete()
                .eq("room_id", value: room.id.uuidString)
                .eq("user_id", value: user.id.uuidString)
                .execute()

            await MainActor.run {
                store.rooms.removeAll { $0.id == room.id }
                dismiss()
            }
        } catch {
            #if DEBUG
            print("RoomSettingsView.swift:576 error:", error)
            #endif
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
                dismiss()
            }
        } catch {
            #if DEBUG
            print("RoomSettingsView.swift:592 error:", error)
            #endif
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
            .foregroundStyle(PHTheme.subtext)
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
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

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(PHTheme.divider)
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
                    .foregroundStyle(PHTheme.text)

                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: 11))
                        .foregroundStyle(PHTheme.subtext)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(PHTheme.accent)
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
                    .foregroundStyle(PHTheme.text)

                Text(member.isOwner ? "Owner" : "Member")
                    .font(.system(size: 11))
                    .foregroundStyle(PHTheme.subtext)
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
                        .foregroundStyle(PHTheme.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(PHTheme.danger.opacity(0.1))
                                .overlay(
                                    Capsule().stroke(
                                        PHTheme.danger.opacity(0.2),
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

//#Preview {
//    RoomSettingsView(room: .mochi)
//        .background(PHTheme.background)
//}
