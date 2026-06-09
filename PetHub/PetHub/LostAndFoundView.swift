//
//  LostAndFoundView.swift
//  PetHub
//

import Foundation
import Supabase
import SwiftUI

// MARK: - Model

struct LostFoundPost: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let contactPhone: String?
    let reportType: String
    let animalType: String
    let description: String?
    let location: String?
    let imageUrl: String?
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case reportType = "type"
        case animalType = "animal_type"
        case description
        case location
        case imageUrl = "image_url"
        case status
        case contactPhone = "contact_phone"
        case createdAt = "created_at"
    }
}

// MARK: - LostAndFoundView

struct LostAndFoundView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var store: RoomStore
    @Environment(\.dismiss) private var dismiss

    @State private var posts: [LostFoundPost] = []
    @State private var isLoading = true
    @State private var showAddPost = false
    @State private var showUpgrade = false
    @State private var selectedFilter = "all"
    @State private var selectedTab = "posts"

    let filters = ["all", "lost", "found"]

    private var filteredPosts: [LostFoundPost] {
        guard selectedFilter != "all" else { return posts }
        return posts.filter { $0.reportType == selectedFilter }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("AppSurface"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color("AppText"))
                        }
                    }
                    Spacer()
                    Text("Lost & Found")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color("AppText"))
                    Spacer()
                    Button {
                        if subscriptionManager.canPostLostPet {
                            showAddPost = true
                        } else {
                            showUpgrade = true
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "E25718").opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(hex: "E25718"))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Filter pills
                HStack(spacing: 10) {
                    ForEach(filters, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(
                                    selectedFilter == filter
                                        ? Color("AppAccentText")
                                        : Color("AppSubtext")
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        selectedFilter == filter
                                            ? Color(hex: "E25718")
                                            : Color("AppSurface")
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Posts / Messages tab switcher
                HStack(spacing: 0) {
                    ForEach(["posts", "messages"], id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    selectedTab == tab
                                        ? Color("AppText")
                                        : Color("AppSubtext")
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    selectedTab == tab
                                        ? Color("AppSurface")
                                        : Color.clear
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color("AppSurface2"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Content
                if selectedTab == "posts" {
                    postsContent
                } else {
                    LostFoundMessagesView()
                }
            }
        }.sheet(isPresented: $showUpgrade) { UpgradeView() }
            .sheet(isPresented: $showAddPost) {
                AddLostFoundView { Task { await fetchPosts() } }
            }
            .task { await fetchPosts() }
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var postsContent: some View {
        if isLoading {
            Spacer()
            ProgressView().tint(Color(hex: "E25718"))
            Spacer()
        } else if filteredPosts.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "E25718").opacity(0.4))
                Text("No reports yet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color("AppWhiteText"))
                Text("Tap + to report a lost or found animal")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AppPlaceholder"))
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredPosts) { post in
                        NavigationLink(
                            destination: LostFoundDetailView(post: post)
                                .environmentObject(subscriptionManager)
                                .environmentObject(store)
                        ) {
                            LostFoundCard(post: post)
                                .environmentObject(subscriptionManager)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }

    private func fetchPosts() async {
        isLoading = true
        do {
            let fetched: [LostFoundPost] =
                try await supabase
                .from("lost_found")
                .select()
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .execute()
                .value
            await MainActor.run {
                posts = fetched
                isLoading = false
            }
        } catch {
            print("Fetch lost found error: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Lost Found Card (display only)

struct LostFoundCard: View {
    let post: LostFoundPost
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private var isLost: Bool { post.reportType == "lost" }
    private var accentColor: Color {
        isLost ? Color(hex: "E25718") : Color(hex: "06D6A0")
    }

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)
                if let imageUrl = post.imageUrl, let url = URL(string: imageUrl)
                {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } placeholder: {
                        ProgressView().tint(accentColor)
                    }
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(isLost ? "LOST" : "FOUND")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                    Text(post.animalType)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("AppText"))
                }

                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppSubtext"))
                        .lineLimit(2)
                }

                if let location = post.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundStyle(Color("AppPlaceholder"))
                        Text(location)
                            .font(.system(size: 11))
                            .foregroundStyle(Color("AppPlaceholder"))
                    }
                }

                Text(post.createdAt.relativeString())
                    .font(.system(size: 10))
                    .foregroundStyle(Color("AppPlaceholder"))

                // Contact preview
                if let phone = post.contactPhone, !phone.isEmpty {
                    if subscriptionManager.isSemiPro
                        || subscriptionManager.isPro
                    {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color("AppPlaceholder"))
                            Text(phone)
                                .font(.system(size: 11))
                                .foregroundStyle(Color("AppPlaceholder"))
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color("AppPlaceholder"))
                            Text("Upgrade to see contact")
                                .font(.system(size: 11))
                                .foregroundStyle(Color("AppPlaceholder"))
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color("AppPlaceholder"))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Lost Found Detail View
struct LostFoundDetailView: View {
    let post: LostFoundPost
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var store: RoomStore
    @Environment(\.dismiss) private var dismiss

    @State private var showFoundConfirm = false
    @State private var showChat = false
    @State private var showUpgrade = false
    @State private var ownerMember: Member? = nil
    @State private var currentUserId: UUID? = nil

    private var isLost: Bool { post.reportType == "lost" }

    private var accentColor: Color {
        isLost ? Color(hex: "E25718") : Color(hex: "06D6A0")
    }

    private var canSeeContact: Bool {
        subscriptionManager.isSemiPro || subscriptionManager.isPro
    }

    private var isOwner: Bool {
        post.userId == currentUserId
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()
            VStack(spacing: 0) {

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("AppSurface"))
                                .frame(width: 36, height: 36)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .medium))
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
                .padding(.top, 20)
                .padding(.bottom, 20)
                ScrollView {

                    ZStack(alignment: .bottomLeading) {
                        if let imageUrl = post.imageUrl,
                            let url = URL(string: imageUrl)
                        {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 280)
                                    .clipped()
                            } placeholder: {
                                ZStack {
                                    Color("AppSurface")
                                    ProgressView().tint(accentColor)
                                }
                                .frame(height: 280)
                            }
                        } else {
                            ZStack {
                                Color("AppSurface")

                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(accentColor.opacity(0.3))
                            }
                            .frame(height: 280)
                        }

                        Text(isLost ? "LOST" : "FOUND")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(accentColor))
                            .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                    VStack(spacing: 0) {
                        LFDetailRow(
                            icon: "pawprint.fill",
                            label: "Animal",
                            value: post.animalType,
                            accentColor: accentColor
                        )

                        if let location = post.location, !location.isEmpty {
                            Divider()
                                .background(Color("AppDivider"))
                                .padding(.leading, 52)

                            LFDetailRow(
                                icon: "mappin",
                                label: "Location",
                                value: location,
                                accentColor: accentColor
                            )
                        }

                        Divider()
                            .background(Color("AppDivider"))
                            .padding(.leading, 52)

                        LFDetailRow(
                            icon: "clock",
                            label: "Reported",
                            value: post.createdAt.relativeString(),
                            accentColor: accentColor
                        )

                        if let phone = post.contactPhone, !phone.isEmpty {
                            Divider()
                                .background(Color("AppDivider"))
                                .padding(.leading, 52)

                            if canSeeContact {
                                LFDetailRow(
                                    icon: "phone.fill",
                                    label: "Contact",
                                    value: phone,
                                    accentColor: accentColor
                                )
                            } else {
                                Button {
                                    showUpgrade = true
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(accentColor.opacity(0.12))
                                                .frame(width: 36, height: 36)

                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 13))
                                                .foregroundStyle(accentColor)
                                        }

                                        VStack(alignment: .leading, spacing: 2)
                                        {
                                            Text("Contact")
                                                .font(
                                                    .system(
                                                        size: 11,
                                                        weight: .medium
                                                    )
                                                )
                                                .foregroundStyle(
                                                    Color("AppSubtext")
                                                )

                                            Text(
                                                "Upgrade to Semi-Pro to see contact info"
                                            )
                                            .font(.system(size: 13))
                                            .foregroundStyle(
                                                Color("AppPlaceholder")
                                            )
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11))
                                            .foregroundStyle(
                                                Color("AppPlaceholder")
                                            )
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)
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
                    .padding(.bottom, 16)

                    if let description = post.description, !description.isEmpty
                    {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DESCRIPTION")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(Color("AppSubtext"))

                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(Color("AppText"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("AppSurface2"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            Color("AppDivider"),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    if !isOwner {
                        if canSeeContact {
                            Button {
                                showFoundConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(
                                        systemName: isLost
                                            ? "hand.raised.fill"
                                            : "pawprint.fill"
                                    )
                                    .font(.system(size: 15))

                                    Text(
                                        isLost
                                            ? "I found this animal"
                                            : "This is my pet"
                                    )
                                    .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(Color("AppAccentText"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            isLost
                                                ? Color(hex: "06D6A0")
                                                : Color(hex: "AA9DFF")
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        } else {
                            Button {
                                showUpgrade = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 15))

                                    Text("Upgrade to respond to this post")
                                        .font(
                                            .system(size: 15, weight: .semibold)
                                        )
                                }
                                .foregroundStyle(Color("AppPlaceholder"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color("AppSurface"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    accentColor.opacity(0.4),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            store.isInRoom = true
        }
        .confirmationDialog(
            isLost ? "Did you find this animal?" : "Is this your pet?",
            isPresented: $showFoundConfirm
        ) {
            Button(isLost ? "Yes, I found it!" : "Yes, this is my pet!") {
                Task { await fetchOwnerAndOpenChat() }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will open a chat with the \(isLost ? "owner" : "finder")."
            )
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

    private func fetchOwnerAndOpenChat() async {
        do {
            let profiles: [UserProfile] =
                try await supabase
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
            print("Fetch owner error: \(error)")
        }
    }
}

// MARK: - Detail Row

private struct LFDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color("AppSubtext"))
                Text(value)
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AppText"))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Add Lost Found View

struct AddLostFoundView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var type = "lost"
    @State private var contactPhone = ""
    @State private var animalType = ""
    @State private var description = ""
    @State private var location = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Nav
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("AppSurface"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color("AppText"))
                        }
                    }
                    Spacer()
                    Button {
                        Task { await submitPost() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(Color("AppAccentText"))
                            } else {
                                Text("Post")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color("AppAccentText"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color(hex: "E25718")))
                    }
                    .buttonStyle(.plain)
                    .disabled(animalType.isEmpty || isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Type picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TYPE")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(Color("AppSubtext"))
                            HStack(spacing: 12) {
                                ForEach(["lost", "found"], id: \.self) { t in
                                    Button {
                                        type = t
                                    } label: {
                                        Text(t.capitalized)
                                            .font(
                                                .system(
                                                    size: 14,
                                                    weight: .medium
                                                )
                                            )
                                            .foregroundStyle(
                                                type == t
                                                    ? Color("AppAccentText")
                                                    : Color("AppSubtext")
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(
                                                    cornerRadius: 12
                                                )
                                                .fill(
                                                    type == t
                                                        ? Color(hex: "E25718")
                                                        : Color("AppSurface")
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Photo picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PHOTO")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(Color("AppSubtext"))
                            Button {
                                showImagePicker = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color("AppSurface"))
                                        .frame(height: 140)
                                    if let img = selectedImage {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(height: 140)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 16
                                                )
                                            )
                                    } else {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 28))
                                                .foregroundStyle(
                                                    Color("AppPlaceholder")
                                                )
                                            Text("Add a photo")
                                                .font(.system(size: 13))
                                                .foregroundStyle(
                                                    Color("AppPlaceholder")
                                                )
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)

                        // Fields
                        VStack(spacing: 16) {
                            ProfileInputField(
                                title: "Animal Type",
                                placeholder: "e.g. Golden Retriever",
                                text: $animalType
                            )
                            ProfileInputField(
                                title: "Location",
                                placeholder: "e.g. Orchard Road, Singapore",
                                text: $location
                            )
                            ProfileInputField(
                                title: "Phone Number",
                                placeholder: "e.g. +65 9123 4567",
                                text: $contactPhone
                            )

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Description")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color("AppSubtext"))
                                ZStack(alignment: .topLeading) {
                                    if description.isEmpty {
                                        Text(
                                            "Describe the animal, any identifying marks…"
                                        )
                                        .font(.system(size: 14))
                                        .foregroundStyle(
                                            Color("AppPlaceholder")
                                        )
                                        .padding(.top, 14)
                                        .padding(.leading, 16)
                                    }
                                    TextEditor(text: $description)
                                        .scrollContentBackground(.hidden)
                                        .foregroundStyle(Color("AppText"))
                                        .frame(height: 100)
                                        .padding(12)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color("AppSurface2"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(
                                                    Color("AppDivider"),
                                                    lineWidth: 0.5
                                                )
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PHPickerView { image in selectedImage = image }
        }
    }

    private func submitPost() async {
        isLoading = true
        do {
            let user = try await supabase.auth.session.user
            var imageUrl: String? = nil

            if let image = selectedImage,
                let data = image.jpegData(compressionQuality: 0.7)
            {
                let path = "lost_found/\(UUID().uuidString).jpg"
                try await supabase.storage
                    .from("photos")
                    .upload(
                        path,
                        data: data,
                        options: .init(contentType: "image/jpeg")
                    )
                let url = try supabase.storage.from("photos").getPublicURL(
                    path: path
                )
                imageUrl = url.absoluteString
            }

            var insert: [String: String] = [
                "user_id": user.id.uuidString,
                "type": type,
                "animal_type": animalType,
                "description": description,
                "location": location,
                "contact_phone": contactPhone,
                "status": "active",
            ]
            if let imageUrl { insert["image_url"] = imageUrl }

            try await supabase.from("lost_found").insert(insert).execute()

            onComplete()
            dismiss()
        } catch {
            print("Submit lost found error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Lost Found Messages View

struct LostFoundMessagesView: View {
    @State private var conversations: [LFConversation] = []
    @State private var isLoading = true
    @State private var selectedConversation: LFConversation? = nil

    struct LFConversation: Identifiable {
        let id: UUID
        let postId: UUID
        let otherUserId: UUID
        let otherUserName: String
        let otherUserAccent: String
        let animalType: String
        let lastMessage: String
        let createdAt: Date
    }

    var body: some View {
        Group {
            if isLoading {
                Spacer()
                ProgressView().tint(Color(hex: "E25718"))
                Spacer()
            } else if conversations.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "E25718").opacity(0.4))
                    Text("No messages yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color("AppWhiteText"))
                    Text("Messages from Lost & Found will appear here")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppPlaceholder"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(conversations) { conv in
                            NavigationLink(
                                destination: ChatView(
                                    title: conv.otherUserName,
                                    subtitle: "Re: \(conv.animalType)",
                                    accentHex: conv.otherUserAccent,
                                    roomId: conv.postId.uuidString,
                                    recipientId: conv.otherUserId.uuidString,
                                    isLostFound: true,
                                    messages: [],
                                    isGroup: false,
                                    members: [
                                        Member(
                                            id: conv.otherUserId,
                                            name: conv.otherUserName,
                                            initials: String(
                                                conv.otherUserName.prefix(1)
                                            ),
                                            accentHex: conv.otherUserAccent,
                                            isOnline: false,
                                            isOwner: false
                                        )
                                    ]
                                )
                            ) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                Color(hex: conv.otherUserAccent)
                                                    .opacity(0.2)
                                            )
                                            .frame(width: 44, height: 44)
                                        Text(
                                            String(conv.otherUserName.prefix(1))
                                                .uppercased()
                                        )
                                        .font(
                                            .system(size: 16, weight: .semibold)
                                        )
                                        .foregroundStyle(
                                            Color(hex: conv.otherUserAccent)
                                        )
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(conv.otherUserName)
                                            .font(
                                                .system(
                                                    size: 14,
                                                    weight: .semibold
                                                )
                                            )
                                            .foregroundStyle(Color("AppText"))
                                        Text("Re: \(conv.animalType)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(
                                                Color("AppPlaceholder")
                                            )
                                        Text(conv.lastMessage)
                                            .font(.system(size: 12))
                                            .foregroundStyle(
                                                Color("AppSubtext")
                                            )
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(conv.createdAt.relativeString())
                                        .font(.system(size: 10))
                                        .foregroundStyle(
                                            Color("AppPlaceholder")
                                        )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color("AppDivider"))
                                .padding(.leading, 72)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20).fill(
                            Color("AppSurface2")
                        )
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await fetchConversations() }
    }

    private func fetchConversations() async {
        isLoading = true
        do {
            let user = try await supabase.auth.session.user

            struct LFMsg: Codable {
                let id: UUID
                let postId: UUID
                let senderId: UUID
                let recipientId: UUID
                let body: String?
                let createdAt: Date
                enum CodingKeys: String, CodingKey {
                    case id
                    case postId = "post_id"
                    case senderId = "sender_id"
                    case recipientId = "recipient_id"
                    case body
                    case createdAt = "created_at"
                }
            }

            let messages: [LFMsg] =
                try await supabase
                .from("lost_found_messages")
                .select()
                .or(
                    "sender_id.eq.\(user.id.uuidString),recipient_id.eq.\(user.id.uuidString)"
                )
                .order("created_at", ascending: false)
                .execute()
                .value

            var seen = Set<String>()
            var convs: [LFConversation] = []

            for msg in messages {
                let otherUserId =
                    msg.senderId == user.id ? msg.recipientId : msg.senderId
                let key = "\(msg.postId.uuidString)-\(otherUserId.uuidString)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                let profiles: [UserProfile] =
                    try await supabase
                    .from("profiles").select()
                    .eq("id", value: otherUserId.uuidString)
                    .execute().value

                let posts: [LostFoundPost] =
                    try await supabase
                    .from("lost_found").select()
                    .eq("id", value: msg.postId.uuidString)
                    .execute().value

                convs.append(
                    LFConversation(
                        id: msg.id,
                        postId: msg.postId,
                        otherUserId: otherUserId,
                        otherUserName: profiles.first?.name ?? "Unknown",
                        otherUserAccent: profiles.first?.avatarAccentHex
                            ?? "AA9DFF",
                        animalType: posts.first?.animalType ?? "Animal",
                        lastMessage: msg.body ?? "📷 Photo",
                        createdAt: msg.createdAt
                    )
                )
            }

            await MainActor.run {
                conversations = convs
                isLoading = false
            }
        } catch {
            print("Fetch LF conversations error: \(error)")
            isLoading = false
        }
    }
}

#Preview {
    LostAndFoundView()
        .environmentObject(SubscriptionManager())
        .environmentObject(RoomStore())
}
