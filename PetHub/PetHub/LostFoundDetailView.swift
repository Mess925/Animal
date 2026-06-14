//
//  LostFoundDetailView.swift
//  PetHub
//

import Foundation
import SwiftUI
import Supabase

struct LostFoundDetailView: View {
    let post: LostFoundPost
    var onPostUpdated: (() -> Void)? = nil

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showFoundConfirm = false
    @State private var showChat = false
    @State private var showUpgrade = false
    @State private var ownerMember: Member? = nil
    @State private var currentUserId: UUID? = nil

    private var isLost: Bool { post.reportType == "lost" }
    private var isReunited: Bool { post.isReunited }
    private var accent: Color {
        isReunited ? Color(hex: "06D6A0") : (isLost ? Color(hex: "E25718") : Color(hex: "06D6A0"))
    }

    private var isSemiPro: Bool { subscriptionManager.isSemiPro }
    private var isPro: Bool { subscriptionManager.isPro }
    private var canSeeContact: Bool { isSemiPro || isPro }
    private var canSeeDetails: Bool { isSemiPro || isPro }
    private var canRespond: Bool { isPro && !isReunited }
    private var isOwner: Bool { post.userId == currentUserId }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroPhoto

                        if isReunited {
                            reunitedBanner
                        }

                        if canSeeDetails {
                            detailsCard
                            descriptionCard
                        } else {
                            lockedDetailsCard
                        }

                        if isOwner {
                            ownerControls
                        } else if canRespond {
                            respondButton
                        } else if !isReunited {
                            upgradeRespondButton
                        }

                        Spacer().frame(height: 50)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .confirmationDialog(
            isLost ? "Did you find this animal?" : "Is this your pet?",
            isPresented: $showFoundConfirm
        ) {
            Button(isLost ? "Yes, I found it!" : "Yes, this is my pet!") {
                Task { await fetchOwnerAndOpenChat() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will open a chat with the \(isLost ? "owner" : "finder").")
        }
        .sheet(isPresented: $showChat) {
            if let owner = ownerMember {
                ChatView(
                    title: owner.name,
                    subtitle: "About your lost pet",
                    accentHex: owner.accentHex,
                    roomId: post.id.uuidString,
                    recipientId: owner.id.uuidString,
                    isLostFound: true,
                    messages: [],
                    isGroup: false,
                    members: [owner]
                )
            }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .task {
            if let session = try? await supabase.auth.session {
                currentUserId = session.user.id
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color("AppSurface"))
                        .frame(width: 36, height: 36)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("AppText"))
                }
            }

            Spacer()

            Text(isLost ? "Lost Animal" : "Found Animal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color("AppText"))

            Spacer()

            Circle()
                .fill(Color.clear)
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var heroPhoto: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipped()
                    } else {
                        heroBg
                    }
                }
            } else {
                heroBg
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                Text(isReunited ? "REUNITED" : (isLost ? "LOST" : "FOUND"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private var reunitedBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "06D6A0").opacity(0.15))
                    .frame(width: 42, height: 42)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "06D6A0"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Reunited Successfully")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppText"))

                Text("This pet has been reunited with its family.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppSubtext"))
            }

            Spacer()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: "06D6A0").opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            LFDetailRow(
                icon: "pawprint.fill",
                label: "Animal",
                value: post.animalType,
                accentColor: accent
            )

            if let location = post.location, !location.isEmpty {
                LFDivider()
                LFDetailRow(
                    icon: "mappin.circle.fill",
                    label: "Location",
                    value: location,
                    accentColor: accent
                )
            }

            LFDivider()
            LFDetailRow(
                icon: "clock.fill",
                label: "Reported",
                value: post.createdAt.relativeString(),
                accentColor: accent
            )

            if let phone = post.contactPhone, !phone.isEmpty {
                LFDivider()

                if canSeeContact {
                    LFDetailRow(
                        icon: "phone.fill",
                        label: "Contact",
                        value: phone,
                        accentColor: accent
                    )
                } else {
                    lockedContactRow
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
        .padding(.bottom, 14)
    }

    private var lockedContactRow: some View {
        Button {
            showUpgrade = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color("AppSurface"))
                        .frame(width: 36, height: 36)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppPlaceholder"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Contact info locked")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("AppText"))

                    Text("Upgrade to Pro to unlock")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("AppPlaceholder"))
                }

                Spacer()

                Text("Upgrade")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "AA9DFF"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "AA9DFF").opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var descriptionCard: some View {
        if let description = post.description, !description.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("DESCRIPTION")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.3)
                    .foregroundStyle(Color("AppSubtext"))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("AppText"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("AppSurface2"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color("AppDivider"), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private var lockedDetailsCard: some View {
        Button {
            showUpgrade = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Details locked")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("AppText"))

                    Text("Upgrade to Semi-Pro to see location, description and more")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppPlaceholder"))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppBorder"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("AppSurface2"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(accent.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var ownerControls: some View {
        VStack(spacing: 12) {
            if isLost && !isReunited {
                Button {
                    Task { await markReunited() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Reunited")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "06D6A0"))
                    )
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                Task { await deletePost() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("Delete Post")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var respondButton: some View {
        Button {
            showFoundConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isLost ? "hand.raised.fill" : "pawprint.fill")
                    .font(.system(size: 15))

                Text(isLost ? "I found this animal" : "This is my pet")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLost ? Color(hex: "06D6A0") : Color(hex: "AA9DFF"))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var upgradeRespondButton: some View {
        Button {
            showUpgrade = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))

                Text("Upgrade to Pro to respond")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color("AppSubtext"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("AppSurface"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var heroBg: some View {
        ZStack {
            Color("AppSurface")

            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundStyle(accent.opacity(0.15))
        }
        .frame(height: 300)
    }

    private func markReunited() async {
        do {
            try await supabase
                .from("lost_found")
                .update(["status": "resolved"])
                .eq("id", value: post.id.uuidString)
                .execute()

            await MainActor.run {
                onPostUpdated?()
                dismiss()
            }
        } catch {
        }
    }

    private func deletePost() async {
        do {
            try await supabase
                .from("lost_found")
                .update(["status": "deleted"])
                .eq("id", value: post.id.uuidString)
                .execute()

            await MainActor.run {
                onPostUpdated?()
                dismiss()
            }
        } catch {
        }
    }

    private func fetchOwnerAndOpenChat() async {
        do {
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: post.userId.uuidString)
                .execute()
                .value

            if let owner = profiles.first {
                await MainActor.run {
                    ownerMember = Member(
                        id: post.userId,
                        name: owner.name,
                        initials: String(owner.name.prefix(1)),
                        accentHex: owner.avatarAccentHex ?? "AA9DFF",
                        isOnline: false,
                        isOwner: false
                    )
                    showChat = true
                }
            }
        } catch {
        }
    }
}

private struct LFDivider: View {
    var body: some View {
        Divider()
            .background(Color("AppDivider"))
            .padding(.leading, 68)
    }
}
