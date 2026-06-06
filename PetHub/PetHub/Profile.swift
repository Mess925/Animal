import Combine
import Foundation
//
//  Profile.swift
//  PetHub
//
//  Created by Han Min Thant on 31/5/26.
//
import Supabase
import SwiftUI

// MARK: - User Profile Model

struct UserProfile: Codable {
    var name: String
    var username: String
    var bio: String
    var avatarEmoji: String
    var avatarAccentHex: String?
    var isOnboarded: Bool?

    var accent: Color { Color(hex: avatarAccentHex ?? "AA9DFF") }

    enum CodingKeys: String, CodingKey {
        case name
        case username
        case bio
        case avatarEmoji = "avatar_emoji"
        case avatarAccentHex = "avatar_accent_hex"
        case isOnboarded = "is_onboarded"
    }
}

extension UserProfile {
    static let me = UserProfile(
        name: "",
        username: "",
        bio: "",
        avatarEmoji: "🧑",
        avatarAccentHex: "AA9DFF",
        isOnboarded: false
    )
}

// MARK: - ProfileView

struct ProfileView: View {
    @State private var profile = UserProfile.me
    @State private var isLoading = true
    @EnvironmentObject private var store: RoomStore
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var showLogoutAlert = false
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // MARK: Header
                    profileHeader

                    // MARK: Stats row
                    statsRow
                        .padding(.top, 24)
                        .padding(.horizontal, 16)

                    // MARK: My Pets
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionLabel(title: "My Pets")
                            .padding(.horizontal, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.rooms) { room in
                                    PetChip(room: room)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 32)

                    // MARK: Account settings
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionLabel(title: "Account")
                            .padding(.horizontal, 4)

                        ProfileCard {
                            ProfileActionRow(
                                icon: "person.fill",
                                iconColor: Color(hex: "AA9DFF"),
                                label: "Edit Profile"
                            ) {
                                showEditProfile = true
                            }

                            ProfileDivider()

                            ProfileActionRow(
                                icon: "lock.fill",
                                iconColor: Color(hex: "7EC8C8"),
                                label: "Change Password"
                            ) {
                                showChangePassword = true
                            }

                            ProfileDivider()

                            // Theme picker
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            Color(hex: "F4A84A").opacity(0.12)
                                        )
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "circle.lefthalf.filled")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: "F4A84A"))
                                }
                                Text("Appearance")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color("AppText"))
                                Spacer()
                                Picker("", selection: $themeManager.theme) {
                                    ForEach(AppTheme.allCases, id: \.self) {
                                        theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 160)

                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 32)

                    // MARK: Danger
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionLabel(title: "Danger zone")
                            .padding(.horizontal, 4)

                        ProfileCard {
                            ProfileActionRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                iconColor: Color(hex: "E25718"),
                                label: "Log Out",
                                labelColor: Color(hex: "E25718")
                            ) {
                                showLogoutAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                    // Version tag
                    Text("PetHub v1.0.0")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("AppDivider"))
                        .padding(.top, 28)

                    Spacer().frame(height: 110)
                }
            }.task {
                await fetchProfile()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(profile: $profile)
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
        .alert("Log Out?", isPresented: $showLogoutAlert) {
            Button("Log Out", role: .destructive) {
                Task {
                    try? await supabase.auth.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your rooms.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 0) {
            // Banner
            ZStack(alignment: .bottom) {

                // Avatar
                ZStack {
                    Circle()
                        .fill(Color("AppBackground"))
                        .frame(width: 88, height: 88)

                    Circle()
                        .fill(profile.accent.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Text(profile.avatarEmoji)
                        .font(.system(size: 38))
                }
                .offset(y: 40)
            }

            // Name + username + bio
            VStack(spacing: 6) {
                Text(profile.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("AppText"))

                Text(profile.username)
                    .font(.system(size: 13))
                    .foregroundStyle(profile.accent.opacity(0.8))

                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppText"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 32)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 52)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(store.rooms.count)", label: "Rooms")
            StatDivider()
            StatCell(value: "\(totalPhotos)", label: "Photos")
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("AppDivider"), lineWidth: 0.5)
                )
        )
    }

    private var totalPhotos: Int {
        store.rooms.reduce(0) { $0 + $1.photos.count }
    }

    private func fetchProfile() async {
        do {
            let user = try await supabase.auth.session.user
            let fetched: UserProfile =
                try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value
            print("Fetched profile: \(fetched.name), \(fetched.username)")
            profile = fetched
        } catch {
            print("Fetch profile error: \(error)")
        }
    }
}

// MARK: - Stat Cell

struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color("AppText"))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color("AppWhiteText"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("AppDivider"))
            .frame(width: 0.5)
            .padding(.vertical, 12)
    }
}

// MARK: - Pet Chip

struct PetChip: View {
    let room: PetRoom

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(room.accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: room.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(room.accent)
            }
            VStack(spacing: 2) {
                Text(room.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
                Text(room.breed)
                    .font(.system(size: 10))
                    .foregroundStyle(Color("AppWhiteText"))
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
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

// MARK: - Helpers

struct ProfileSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.3)
            .foregroundStyle(Color("AppSubtext"))
    }
}

struct ProfileCard<Content: View>: View {
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

struct ProfileDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("AppDivider"))
            .frame(height: 0.5)
            .padding(.leading, 62)
    }
}

struct ProfileActionRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    var labelColor: Color = Color("AppText")
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)
                }
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(labelColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppDivider"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileView: View {
    @Binding var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var username: String
    @State private var bio: String

    init(profile: Binding<UserProfile>) {
        _profile = profile
        _name = State(initialValue: profile.wrappedValue.name)
        _username = State(initialValue: profile.wrappedValue.username)
        _bio = State(initialValue: profile.wrappedValue.bio)
    }

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
                                .fill(Color("AppDivider"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    Color("AppAdaptiveWhite").opacity(0.8)
                                )
                        }
                    }
                    Spacer()
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("AppAccentText"))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color(hex: "AA9DFF")))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                Text("Edit Profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                // Avatar picker (emoji for now)
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(hex: "AA9DFF").opacity(0.15))
                            .frame(width: 80, height: 80)
                        Text(profile.avatarEmoji)
                            .font(.system(size: 36))
                        // Camera badge
                        ZStack {
                            Circle()
                                .fill(Color(hex: "AA9DFF"))
                                .frame(width: 26, height: 26)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color("AppAccentText"))
                        }
                        .offset(x: 26, y: 26)
                    }
                    Spacer()
                }
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    ProfileInputField(
                        title: "Name",
                        placeholder: "Your name",
                        text: $name
                    )
                    ProfileInputField(
                        title: "Username",
                        placeholder: "@username",
                        text: $username
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bio")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color("AppSubtext"))

                        ZStack(alignment: .topLeading) {
                            if bio.isEmpty {
                                Text("Tell people about yourself…")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color("AppPlaceholder"))
                                    .padding(.top, 14)
                                    .padding(.leading, 16)
                            }
                            TextEditor(text: $bio)
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
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func saveProfile() async {
        do {
            let user = try await supabase.auth.session.user
            try await supabase
                .from("profiles")
                .update([
                    "name": name,
                    "username": username,
                    "bio": bio,
                ])
                .eq("id", value: user.id.uuidString)
                .execute()
            profile.name = name
            profile.username = username
            profile.bio = bio
            dismiss()
        } catch {
            print("Save profile error: \(error)")
        }
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var newPass = ""
    @State private var confirm = ""

    private var canSave: Bool {
        !current.isEmpty && newPass.count >= 8 && newPass == confirm
    }

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
                                .fill(Color("AppDivider"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    Button {
                        Task { await changePassword() }
                    } label: {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                canSave
                                    ? Color.black.opacity(0.8)
                                    : Color.white.opacity(0.2)
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(
                                        canSave
                                            ? Color(hex: "AA9DFF")
                                            : Color.white.opacity(0.06)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)

                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                Text("Change\nPassword")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
                    .lineSpacing(2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                VStack(spacing: 16) {
                    ProfileInputField(
                        title: "Current Password",
                        placeholder: "••••••••",
                        text: $current,
                        isSecure: true
                    )
                    ProfileInputField(
                        title: "New Password",
                        placeholder: "Min 8 characters",
                        text: $newPass,
                        isSecure: true
                    )
                    ProfileInputField(
                        title: "Confirm New Password",
                        placeholder: "••••••••",
                        text: $confirm,
                        isSecure: true
                    )

                    if !newPass.isEmpty && newPass.count < 8 {
                        Text("Password must be at least 8 characters")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "E25718"))
                            .padding(.horizontal, 4)
                    }

                    if !confirm.isEmpty && newPass != confirm {
                        Text("Passwords don't match")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "E25718"))
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
    
    private func changePassword() async {
        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPass)
            )
            dismiss()
        } catch {
            print("Change password error: \(error)")
        }
    }
}

// MARK: - Shared Input Field

struct ProfileInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color("AppSubtext"))

            Group {
                if isSecure {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(
                            Color("AppPlaceholder")
                        )
                    )
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(
                            Color("AppPlaceholder")
                        )
                    )
                }
            }
            .foregroundStyle(Color("AppText"))
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .frame(height: 52)
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
}

// MARK: - Preview

#Preview {
    ProfileView()
}
