//
//  LostAndFoundView.swift
//  PetHub
//

import Foundation
import Supabase
import SwiftUI

// MARK: - Model

enum LostPetStatus: String, Codable {
    case active
    case reunited
    case resolved
    case deleted
}

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
    let reunitedAt: Date?
    let createdAt: Date

    var petStatus: LostPetStatus {
        LostPetStatus(rawValue: status) ?? .active
    }

    var isActive: Bool {
        petStatus == .active
    }

    var isReunited: Bool {
        petStatus == .reunited || petStatus == .resolved
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case reportType = "type"
        case animalType = "animal_type"
        case description
        case location
        case imageUrl = "image_url"
        case status
        case reunitedAt = "reunited_at"
        case contactPhone = "contact_phone"
        case createdAt = "created_at"
    }
}

// MARK: - Match Alert Model

struct LostFoundMatchAlert: Identifiable {
    let id = UUID()
    let lostPost: LostFoundPost
    let post: LostFoundPost // This is the matched FOUND post opened when the card is tapped
    let score: Int
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
    @State private var currentUserId: UUID? = nil
    @State private var selectedMatchPost: LostFoundPost? = nil

    let filters = ["all", "lost", "found"]

    private var possibleMatches: [LostFoundMatchAlert] {
        guard subscriptionManager.isPro, let currentUserId else {
            return []
        }

        let myActiveLostPosts = posts.filter { post in
            post.reportType == "lost"
            && post.isActive
            && post.userId == currentUserId
        }

        let activeFoundPostsFromOthers = posts.filter { post in
            post.reportType == "found"
            && post.isActive
            && post.userId != currentUserId
        }

        return myActiveLostPosts
            .flatMap { lostPost in
                activeFoundPostsFromOthers.compactMap { foundPost in
                    let score = matchScore(lostPost: lostPost, foundPost: foundPost)

                    guard score >= 40 else { return nil }

                    return LostFoundMatchAlert(
                        lostPost: lostPost,
                        post: foundPost,
                        score: score
                    )
                }
            }
            .sorted { $0.score > $1.score }
    }

    private var filteredPosts: [LostFoundPost] {
        let visiblePosts = posts.filter { $0.petStatus != .deleted }

        let filtered = selectedFilter == "all"
            ? visiblePosts
            : visiblePosts.filter { $0.reportType == selectedFilter }

        return filtered.sorted { a, b in
            let aIsOwn = a.userId == currentUserId
            let bIsOwn = b.userId == currentUserId

            if aIsOwn != bIsOwn { return aIsOwn }
            if a.isReunited && !b.isReunited { return false }
            if !a.isReunited && b.isReunited { return true }

            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filtersView
                tabSwitcher

                if selectedTab == "posts" {
                    postsContent
                } else {
                    LostFoundMessagesView()
                }
            }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .sheet(isPresented: $showAddPost) {
            AddLostFoundView {
                Task { await fetchPosts() }
            }
        }
        .navigationDestination(item: $selectedMatchPost) { post in
            LostFoundDetailView(
                post: post,
                onPostUpdated: {
                    Task { await fetchPosts() }
                }
            )
            .environmentObject(subscriptionManager)
            .environmentObject(store)
        }
        .task {
            await fetchPosts()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                store.isInRoom = false
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
                // Free users can still post FOUND pets.
                // LOST pet posting is checked inside AddLostFoundView.
                if subscriptionManager.canPostFoundPet || subscriptionManager.canPostLostPet {
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
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Filters

    private var filtersView: some View {
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
    }

    // MARK: - Tabs

    private var tabSwitcher: some View {
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
    }

    // MARK: - Posts Content

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
                    if let firstMatch = possibleMatches.first {
                        MatchAlertCard(match: firstMatch)
                            .environmentObject(subscriptionManager)
                            .onTapGesture {
                                if subscriptionManager.isPro {
                                    selectedMatchPost = firstMatch.post
                                } else {
                                    showUpgrade = true
                                }
                            }
                            .padding(.bottom, 4)
                    }

                    ForEach(filteredPosts) { post in
                        NavigationLink(
                            destination: LostFoundDetailView(
                                post: post,
                                onPostUpdated: {
                                    Task { await fetchPosts() }
                                }
                            )
                            .environmentObject(subscriptionManager)
                            .environmentObject(store)
                        ) {
                            LostFoundCard(
                                post: post,
                                isOwnPost: post.userId == currentUserId,
                                isPossibleMatch: possibleMatches.contains(where: { $0.post.id == post.id })
                            )
                            .environmentObject(subscriptionManager)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if post.userId == currentUserId {
                                Button(role: .destructive) {
                                    Task { await deletePost(post) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Fetch

    private func fetchPosts() async {
        isLoading = true

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
                posts = results
                isLoading = false
            }

            await createPossibleMatchActivities(
                posts: results,
                currentUserId: session.user.id
            )
        } catch {

            await MainActor.run {
                isLoading = false
            }
        }
    }

    // MARK: - Delete

    private func deletePost(_ post: LostFoundPost) async {
        do {
            try await supabase
                .from("lost_found")
                .update(["status": "deleted"])
                .eq("id", value: post.id.uuidString)
                .execute()

            await fetchPosts()
        } catch {
        }
    }

    // MARK: - Activity V1

    private func createPossibleMatchActivities(posts: [LostFoundPost], currentUserId: UUID) async {
        guard subscriptionManager.isPro else { return }

        let myActiveLostPosts = posts.filter { post in
            post.reportType == "lost"
            && post.isActive
            && post.userId == currentUserId
        }

        let activeFoundPostsFromOthers = posts.filter { post in
            post.reportType == "found"
            && post.isActive
            && post.userId != currentUserId
        }

        for lostPost in myActiveLostPosts {
            for foundPost in activeFoundPostsFromOthers {
                let score = matchScore(lostPost: lostPost, foundPost: foundPost)
                guard score >= 40 else { continue }

                let dedupeBody = "Possible match found for \(lostPost.animalType.capitalized) · lost:\(lostPost.id.uuidString) · found:\(foundPost.id.uuidString)"

                do {
                    let existing: [SupabaseActivityLite] =
                        try await supabase
                        .from("activities")
                        .select("id")
                        .eq("type", value: "possible_match")
                        .eq("recipient_id", value: currentUserId.uuidString)
                        .eq("body", value: dedupeBody)
                        .limit(1)
                        .execute()
                        .value

                    guard existing.isEmpty else { continue }

                    try await supabase
                        .from("activities")
                        .insert([
                            "type": "possible_match",
                            "actor_id": currentUserId.uuidString,
                            "recipient_id": currentUserId.uuidString,
                            "body": dedupeBody
                        ])
                        .execute()
                } catch {
                }
            }
        }
    }

    private struct SupabaseActivityLite: Codable {
        let id: UUID
    }

    // MARK: - Matching

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchScore(lostPost: LostFoundPost, foundPost: LostFoundPost) -> Int {
        let lostAnimal = normalize(lostPost.animalType)
        let foundAnimal = normalize(foundPost.animalType)
        let lostDescription = normalize(lostPost.description ?? "")
        let foundDescription = normalize(foundPost.description ?? "")
        let lostLocation = normalize(lostPost.location ?? "")
        let foundLocation = normalize(foundPost.location ?? "")

        let lostText = "\(lostAnimal) \(lostDescription)"
        let foundText = "\(foundAnimal) \(foundDescription)"

        var score = 0

        if !lostAnimal.isEmpty && lostAnimal == foundAnimal {
            score += 45
        } else if !lostAnimal.isEmpty && foundText.contains(lostAnimal) {
            score += 30
        }

        let importantWords = lostText
            .split(separator: " ")
            .map(String.init)
            .filter { word in
                word.count >= 4
                && !["lost", "found", "animal", "please", "near", "with"].contains(word)
            }

        for word in importantWords {
            if foundText.contains(word) {
                score += 15
            }
        }

        if !lostLocation.isEmpty && !foundLocation.isEmpty {
            if lostLocation == foundLocation {
                score += 30
            } else {
                let lostLocationWords = lostLocation.split(separator: " ").map(String.init)
                for word in lostLocationWords where word.count >= 4 {
                    if foundLocation.contains(word) {
                        score += 15
                    }
                }
            }
        }

        return min(score, 100)
    }
}

// MARK: - Match Alert Card

struct MatchAlertCard: View {
    let match: LostFoundMatchAlert
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "AA9DFF").opacity(0.16))
                    .frame(width: 46, height: 46)

                Image(systemName: subscriptionManager.isPro ? "pawprint.fill" : "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "AA9DFF"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Possible match found")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppText"))

                if subscriptionManager.isPro {
                    Text("Found \(match.post.animalType) may match your lost \(match.lostPost.animalType)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppSubtext"))
                        .lineLimit(2)
                } else {
                    Text("Upgrade to Pro to view the matching report")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppSubtext"))
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(subscriptionManager.isPro ? "\(match.score)%" : "PRO")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "AA9DFF"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color(hex: "AA9DFF").opacity(0.14))
                )
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "AA9DFF").opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Lost Found Card

struct LostFoundCard: View {
    let post: LostFoundPost
    let isOwnPost: Bool
    let isPossibleMatch: Bool

    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private var isLost: Bool { post.reportType == "lost" }
    private var isReunited: Bool { post.isReunited }

    private var accentColor: Color {
        if isReunited { return Color(hex: "06D6A0") }
        return isLost ? Color(hex: "E25718") : Color(hex: "06D6A0")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)

                if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .scaledToFill()
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
                HStack(spacing: 6) {
                    Text(isReunited ? "REUNITED" : (isLost ? "LOST" : "FOUND"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor.opacity(0.12)))

                    Text(post.animalType)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("AppText"))
                }

                HStack(spacing: 6) {
                    if isOwnPost {
                        BadgeText(
                            title: "YOUR POST",
                            color: Color(hex: "AA9DFF")
                        )
                    }

                    if isReunited {
                        BadgeText(
                            title: "REUNITED",
                            color: Color(hex: "06D6A0")
                        )
                    }

                    if isPossibleMatch && subscriptionManager.isPro && !isReunited {
                        BadgeText(
                            title: "POSSIBLE MATCH",
                            color: Color(hex: "AA9DFF")
                        )
                    }
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

                if let phone = post.contactPhone, !phone.isEmpty {
                    if subscriptionManager.isSemiPro || subscriptionManager.isPro {
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
        .opacity(isReunited ? 0.82 : 1)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isOwnPost
                            ? Color(hex: "AA9DFF").opacity(0.7)
                            : accentColor.opacity(0.2),
                            lineWidth: isOwnPost ? 1.2 : 0.5
                        )
                )
        )
    }
}

// MARK: - Badge

struct BadgeText: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
    }
}

// MARK: - Detail Row

struct LFDetailRow: View {
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
    private let lockedType: String?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var type: String
    @State private var contactPhone = ""
    @State private var animalType: String
    @State private var description: String
    @State private var location = ""

    init(
        initialType: String = "found",
        lockedType: String? = nil,
        initialAnimalType: String = "",
        initialDescription: String = "",
        onComplete: @escaping () -> Void
    ) {
        self.lockedType = lockedType
        self.onComplete = onComplete
        _type = State(initialValue: initialType)
        _animalType = State(initialValue: initialAnimalType)
        _description = State(initialValue: initialDescription)
    }
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var showUpgrade = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TYPE")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(Color("AppSubtext"))

                            HStack(spacing: 12) {
                                ForEach(["lost", "found"], id: \.self) { t in
                                    Button {
                                        guard lockedType == nil else { return }

                                        if t == "lost" && !subscriptionManager.canPostLostPet {
                                            showUpgrade = true
                                        } else {
                                            type = t
                                        }
                                    } label: {
                                        Text(t.capitalized)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(
                                                type == t
                                                ? Color("AppAccentText")
                                                : Color("AppSubtext")
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(
                                                        type == t
                                                        ? Color(hex: "E25718")
                                                        : Color("AppSurface")
                                                    )
                                            )
                                            .overlay(alignment: .topTrailing) {
                                                if t == "lost" && !subscriptionManager.canPostLostPet {
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundStyle(Color("AppSubtext"))
                                                        .padding(8)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(lockedType != nil)
                                }
                            }
                        }
                        .padding(.horizontal, 24)

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
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    } else {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 28))
                                                .foregroundStyle(Color("AppPlaceholder"))

                                            Text("Add a photo")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color("AppPlaceholder"))
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)

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
                                        Text("Describe the animal, any identifying marks…")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color("AppPlaceholder"))
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
                                                .stroke(Color("AppDivider"), lineWidth: 0.5)
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
            PHPickerView { image in
                selectedImage = image
            }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .onAppear {
            if let lockedType {
                type = lockedType
            }

            if type == "lost" && !subscriptionManager.canPostLostPet {
                showUpgrade = true
                type = lockedType == "lost" ? "lost" : "found"
            }
        }
    }

    private func submitPost() async {
        guard type != "lost" || subscriptionManager.canPostLostPet else {
            showUpgrade = true
            return
        }

        isLoading = true

        do {
            let user = try await supabase.auth.session.user
            var imageUrl: String? = nil

            if let image = selectedImage,
               let data = image.jpegData(compressionQuality: 0.7) {
                let path = "lost_found/\(UUID().uuidString).jpg"

                try await supabase.storage
                    .from("photos")
                    .upload(
                        path,
                        data: data,
                        options: .init(contentType: "image/jpeg")
                    )

                let url = try supabase.storage
                    .from("photos")
                    .getPublicURL(path: path)

                imageUrl = url.absoluteString
            }

            var insert: [String: String] = [
                "user_id": user.id.uuidString,
                "type": type,
                "animal_type": animalType,
                "description": description,
                "location": location,
                "contact_phone": contactPhone,
                "status": "active"
            ]

            if let imageUrl {
                insert["image_url"] = imageUrl
            }

            try await supabase
                .from("lost_found")
                .insert(insert)
                .execute()

            onComplete()
            dismiss()
        } catch {
        }

        isLoading = false
    }
}

// MARK: - Lost Found Messages View

struct LostFoundMessagesView: View {
    @State private var conversations: [LFConversation] = []
    @State private var isLoading = true

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
                                            initials: String(conv.otherUserName.prefix(1)),
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
                                            .fill(Color(hex: conv.otherUserAccent).opacity(0.2))
                                            .frame(width: 44, height: 44)

                                        Text(String(conv.otherUserName.prefix(1)).uppercased())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color(hex: conv.otherUserAccent))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(conv.otherUserName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color("AppText"))

                                        Text("Re: \(conv.animalType)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color("AppPlaceholder"))

                                        Text(conv.lastMessage)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color("AppSubtext"))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(conv.createdAt.relativeString())
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color("AppPlaceholder"))
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
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("AppSurface2"))
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await fetchConversations()
        }
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

            let messages: [LFMsg] = try await supabase
                .from("lost_found_messages")
                .select()
                .or("sender_id.eq.\(user.id.uuidString),recipient_id.eq.\(user.id.uuidString)")
                .order("created_at", ascending: false)
                .execute()
                .value

            var seen = Set<String>()
            var convs: [LFConversation] = []

            for msg in messages {
                let otherUserId = msg.senderId == user.id ? msg.recipientId : msg.senderId
                let key = "\(msg.postId.uuidString)-\(otherUserId.uuidString)"

                guard !seen.contains(key) else { continue }
                seen.insert(key)

                let profiles: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: otherUserId.uuidString)
                    .execute()
                    .value

                let posts: [LostFoundPost] = try await supabase
                    .from("lost_found")
                    .select()
                    .eq("id", value: msg.postId.uuidString)
                    .execute()
                    .value

                convs.append(
                    LFConversation(
                        id: msg.id,
                        postId: msg.postId,
                        otherUserId: otherUserId,
                        otherUserName: profiles.first?.name ?? "Unknown",
                        otherUserAccent: profiles.first?.avatarAccentHex ?? "AA9DFF",
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

            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    LostAndFoundView()
        .environmentObject(SubscriptionManager())
        .environmentObject(RoomStore())
}
