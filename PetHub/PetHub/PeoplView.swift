//
//  PeopleView.swift
//  PetHub
//

import Supabase
import SwiftUI

// MARK: - PeopleView

struct PeopleView: View {
    let room: PetRoom
    @State private var openThread: ChatDestination? = nil
    @State private var currentUserId: UUID? = nil
    @State private var lastDMMessages: [UUID: String] = [:]

    private var dmMembers: [Member] {
        room.members.filter { $0.id != currentUserId }
    }

    enum ChatDestination: Identifiable {
        case group
        case dm(DMThread)

        var id: String {
            switch self {
            case .group: return "group"
            case .dm(let t): return t.id.uuidString
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Group section
                PeopleSectionLabel(title: "Group")
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                Button {
                    openThread = .group
                } label: {
                    GroupChatRow(room: room)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // MARK: DMs section
                PeopleSectionLabel(title: "Direct messages")
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 4)

                if dmMembers.isEmpty {
                    Text("No other members yet")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppPlaceholder"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(dmMembers) { member in
                            Button {
                                openThread = .dm(
                                    DMThread(
                                        id: UUID(),
                                        participant: member,
                                        messages: [],
                                        unreadCount: 0
                                    )
                                )
                            } label: {
                                DMRow(
                                    thread: DMThread(
                                        id: member.id,
                                        participant: member,
                                        messages: [],
                                        unreadCount: 0
                                    ),
                                    lastMessagePreview: lastDMMessages[member.id] ?? ""
                                )
                            }
                            .buttonStyle(.plain)

                            if member.id != dmMembers.last?.id {
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
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 100)
            }
        }
        .task {
            if let session = try? await supabase.auth.session {
                currentUserId = session.user.id
                await fetchLastDMMessages()
            }
        }
        .sheet(item: $openThread) { destination in
            switch destination {
            case .group:
                ChatView(
                    title: "\(room.name)'s Room",
                    subtitle: "\(room.members.count) members",
                    accentHex: room.accentHex,
                    roomId: room.id.uuidString,
                    messages: room.groupMessages,
                    isGroup: true,
                    members: room.members
                )
            case .dm(let thread):
                ChatView(
                    title: thread.participant.name,
                    subtitle: thread.participant.isOnline ? "Active now" : "Offline",
                    accentHex: thread.participant.accentHex,
                    roomId: room.id.uuidString,
                    recipientId: thread.participant.id.uuidString,
                    messages: thread.messages,
                    isGroup: false,
                    members: [thread.participant]
                )
            }
        }
    }

    private func fetchLastDMMessages() async {
        guard let currentUserId = currentUserId else { return }

        for member in room.members where member.id != currentUserId {
            struct DMMsg: Codable {
                let body: String?
                let imageUrl: String?
                enum CodingKeys: String, CodingKey {
                    case body
                    case imageUrl = "image_url"
                }
            }

            let msgs: [DMMsg] = (try? await supabase
                .from("dm_messages")
                .select()
                .eq("room_id", value: room.id.uuidString)
                .or("and(sender_id.eq.\(currentUserId),recipient_id.eq.\(member.id.uuidString)),and(sender_id.eq.\(member.id.uuidString),recipient_id.eq.\(currentUserId.uuidString))")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value) ?? []

            let preview = msgs.first?.body ?? (msgs.first?.imageUrl != nil ? "📷 Photo" : "")
            await MainActor.run {
                lastDMMessages[member.id] = preview
            }
        }
    }
}

// MARK: - Section Label

struct PeopleSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(Color("AppSubtext"))
    }
}

// MARK: - Group Chat Row

struct GroupChatRow: View {
    let room: PetRoom

    private var memberNames: String {
        let names = room.members.map { $0.name }
        if names.isEmpty { return "No members yet" }
        let preview = names.prefix(3).joined(separator: ", ")
        if names.count > 3 { return "\(preview) +\(names.count - 3) more" }
        return preview
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(room.accent.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(room.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(room.name)'s Room")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
                Text(memberNames)
                    .font(.system(size: 11))
                    .foregroundStyle(Color("AppWhiteText"))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color("AppDivider"))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(room.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(room.accent.opacity(0.14), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - DM Row

struct DMRow: View {
    let thread: DMThread
    var lastMessagePreview: String = ""

    private var preview: String {
        lastMessagePreview.isEmpty ? "No messages yet" : lastMessagePreview
    }

    private var isEmpty: Bool { lastMessagePreview.isEmpty }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                MemberAvatar(member: thread.participant, size: 44)

                if thread.participant.isOnline {
                    Circle()
                        .fill(Color(hex: "06D6A0"))
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color("AppSurface2"), lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(thread.participant.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppText"))

                Text(preview)
                    .font(.system(size: 12))
                    .foregroundStyle(isEmpty ? Color("AppPlaceholder") : Color("AppSubtext"))
                    .italic(isEmpty)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(Color("AppDivider"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Preview

#Preview {
    PeopleView(room: .mochi)
        .background(Color("AppBackground"))
}
