//
//  LostAndFoundView.swift
//  PetHub
//
//  Created by Han Min Thant on 7/6/26.
//

import Foundation
import Supabase
import SwiftUI

// MARK: - Lost Found Post Model

struct LostFoundPost: Codable, Identifiable {
    let id: UUID
    let userId: UUID
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
        case createdAt = "created_at"
    }
}

// MARK: - LostAndFoundView

struct LostAndFoundView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showUpgrade = false
    @Environment(\.dismiss) private var dismiss
    @State private var posts: [LostFoundPost] = []
    @State private var isLoading = true
    @State private var showAddPost = false
    @State private var selectedFilter = "all"

    let filters = ["all", "lost", "found"]

    private var filteredPosts: [LostFoundPost] {
        if selectedFilter == "all" {
            return posts
        }
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
                            Image(systemName: "xmark")
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
                        if subscriptionManager.canAccessLostFound {
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
                                    Capsule()
                                        .fill(
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
                        VStack(spacing: 12) {
                            ForEach(filteredPosts) { post in
                                LostFoundCard(post: post)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showUpgrade) { UpgradeView() }
        .task {
            await fetchPosts()
        }
        .sheet(isPresented: $showAddPost) {
            AddLostFoundView {
                Task { await fetchPosts() }
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

// MARK: - Lost Found Card

struct LostFoundCard: View {
    let post: LostFoundPost

    private var isLost: Bool { post.reportType == "lost" }
    private var accentColor: Color {
        isLost ? Color(hex: "E25718") : Color(hex: "06D6A0")
    }

    var body: some View {
        HStack(spacing: 14) {
            // Image or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)

                if let imageUrl = post.imageUrl, let url = URL(string: imageUrl)
                {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
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
            }

            Spacer()
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
                            Image(systemName: "xmark")
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

                        // Photo
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
            PHPickerView { image in
                selectedImage = image
            }
        }
    }

    private func submitPost() async {
        isLoading = true
        do {
            let user = try await supabase.auth.session.user
            var imageUrl: String? = nil

            // Upload image if selected
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

            try await supabase
                .from("lost_found")
                .insert(insert)
                .execute()

            onComplete()
            dismiss()
        } catch {
            print("Submit lost found error: \(error)")
        }
        isLoading = false
    }
}
