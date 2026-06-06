//
//  RoomView.swift
//  PetHub
//

import SwiftUI

// MARK: - Room Tab

enum RoomTab { case gallery, people, settings }

// MARK: - RoomView

struct RoomView: View {
    let room: PetRoom
    var initialTab: RoomTab = .gallery
    @State private var selectedTab: RoomTab
    @State private var dragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    init(room: PetRoom, initialTab: RoomTab = .gallery) {
        self.room = room
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
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

                    // Member avatar stack
                    MemberAvatarStack(members: room.members)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)

                // Tab bar
                RoomTabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                Divider()
                    .background(Color("AppDivider").opacity(0.6))

                // Content
                ZStack {
                    switch selectedTab {
                    case .gallery:
                        GalleryView(room: room)
                    case .people:
                        PeopleView(room: room)
                    case .settings:
                        RoomSettingsView(room: room)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
}

// MARK: - Room Tab Bar

struct RoomTabBar: View {
    @Binding var selected: RoomTab

    var body: some View {
        HStack(spacing: 2) {
            RoomTabItem(label: "Gallery", tab: .gallery, selected: $selected)
            RoomTabItem(label: "People", tab: .people, selected: $selected)
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
