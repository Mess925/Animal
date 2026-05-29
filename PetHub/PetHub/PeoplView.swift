
//
//  PeopleView.swift
//  PetHub
//

import SwiftUI

// MARK: - PeopleView

struct PeopleView: View {
    let room: PetRoom
    @State private var openThread: ChatDestination? = nil

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

                Button { openThread = .group } label: {
                    GroupChatRow(room: room)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // MARK: DMs section
                PeopleSectionLabel(title: "Direct messages")
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 4)

                VStack(spacing: 0) {
                    ForEach(room.dmThreads) { thread in
                        Button {
                            openThread = .dm(thread)
                        } label: {
                            DMRow(thread: thread)
                        }
                        .buttonStyle(.plain)

                        if thread.id != room.dmThreads.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.04))
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "161618"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)

                Spacer().frame(height: 100)
            }
        }
        .sheet(item: $openThread) { destination in
            switch destination {
            case .group:
                ChatView(
                    title: "\(room.name)'s Room",
                    subtitle: "\(room.members.count) members",
                    accentHex: room.accentHex,
                    messages: room.groupMessages,
                    isGroup: true,
                    members: room.members
                )
            case .dm(let thread):
                ChatView(
                    title: thread.participant.name,
                    subtitle: thread.participant.isOnline ? "Active now" : "Offline",
                    accentHex: thread.participant.accentHex,
                    messages: thread.messages,
                    isGroup: false,
                    members: [thread.participant]
                )
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
            .foregroundStyle(Color.white.opacity(0.25))
    }
}

// MARK: - Group Chat Row

struct GroupChatRow: View {
    let room: PetRoom

    private var totalUnread: Int {
        // In real app, track unread group messages
        3
    }

    private var memberNames: String {
        let names = room.members.map { $0.name == "Me" ? "You" : $0.name }
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
                    .foregroundStyle(Color(hex: "F0EDE6"))
                Text(memberNames)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .lineLimit(1)
            }

            Spacer()

            if totalUnread > 0 {
                Text("\(totalUnread)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(room.accent))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.15))
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

    private var lastMessagePreview: String {
        guard let msg = thread.lastMessage else { return "No messages yet" }
        switch msg.content {
        case .text(let t): return t
        case .photo: return "📷 Photo"
        }
    }

    private var isEmpty: Bool { thread.messages.isEmpty }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                MemberAvatar(member: thread.participant, size: 44)

                if thread.participant.isOnline {
                    Circle()
                        .fill(Color(hex: "06D6A0"))
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color(hex: "161618"), lineWidth: 2))
                }
            }

            // Name + preview
            VStack(alignment: .leading, spacing: 3) {
                Text(thread.participant.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "F0EDE6"))

                Text(lastMessagePreview)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        isEmpty
                            ? Color.white.opacity(0.2)
                            : Color.white.opacity(thread.unreadCount > 0 ? 0.55 : 0.3)
                    )
                    .italic(isEmpty)
                    .lineLimit(1)
            }

            Spacer()

            // Right side: time + unread
            VStack(alignment: .trailing, spacing: 5) {
                if let last = thread.lastMessage {
                    Text(last.timestamp.relativeString())
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.2))
                }

                if thread.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(thread.participant.accent)
                            .frame(width: 20, height: 20)
                        Text("\(thread.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.12))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Preview

#Preview {
    PeopleView(room: .mochi)
        .background(Color(hex: "0D0D0E"))
        .preferredColorScheme(.dark)
}
