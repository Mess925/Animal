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
    var id: UUID?
    var name: String
    var username: String
    var bio: String
    var avatarEmoji: String
    var avatarAccentHex: String?
    var isOnboarded: Bool?
    var subscriptionTier: String?

    var accent: Color { Color(hex: avatarAccentHex ?? "AA9DFF") }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
        case bio
        case avatarEmoji = "avatar_emoji"
        case avatarAccentHex = "avatar_accent_hex"
        case isOnboarded = "is_onboarded"
        case subscriptionTier = "subscription_tier"
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
    @State private var showDeleteAccount = false
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showUpgradeSheet = false
    @State private var showTermsOfService = false

    var body: some View {
        PHPage {
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
                                iconColor: PHTheme.accent,
                                label: "Edit Profile"
                            ) {
                                showEditProfile = true
                            }

                            ProfileDivider()

                            ProfileActionRow(
                                icon: "lock.fill",
                                iconColor: PHTheme.accent2,
                                label: "Change Password"
                            ) {
                                showChangePassword = true
                            }

                            ProfileDivider()

                            AppearanceSelector(theme: $themeManager.theme)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 32)

                    // MARK: Subscription
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionLabel(title: "Subscription")
                            .padding(.horizontal, 4)

                        ProfileCard {
                            SubscriptionStatusRow(
                                planName: currentPlanName,
                                planDescription: currentPlanDescription,
                                accentColor: currentPlanColor
                            )

                            ProfileDivider()

                            ProfileActionRow(
                                icon: subscriptionManager.isFree
                                    ? "sparkles" : "creditcard.fill",
                                iconColor: subscriptionManager.isFree
                                    ? PHTheme.accent
                                    : PHTheme.accent2,
                                label: subscriptionManager.isFree
                                    ? "Upgrade Plan" : "Manage Subscription"
                            ) {
                                if subscriptionManager.isFree {
                                    showUpgradeSheet = true
                                } else {
                                    openAppleSubscriptionSettings()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                    // MARK: Legal

                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionLabel(title: "Legal")
                            .padding(.horizontal, 4)

                        ProfileCard {

                            ProfileActionRow(
                                icon: "doc.text.fill",
                                iconColor: PHTheme.accent2,
                                label: "Privacy Policy"
                            ) {
                                if let url = URL(
                                    string:
                                        "https://gist.githubusercontent.com/Mess925/8f03559c3b2ea299b29f37fbd580bd50/raw/537d1fd4b460bb08072630df554eb27133f8f650/pethub-privacy-policy.md"
                                ) {
                                    UIApplication.shared.open(url)
                                }
                            }

                            ProfileDivider()

                            ProfileActionRow(
                                icon: "doc.plaintext.fill",
                                iconColor: PHTheme.accent,
                                label: "Terms of Service"
                            ) {
                                showTermsOfService = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    // MARK: Danger
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionLabel(title: "Danger zone")
                            .padding(.horizontal, 4)

                        ProfileCard {
                            ProfileActionRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                iconColor: PHTheme.danger,
                                label: "Log Out",
                                labelColor: PHTheme.danger
                            ) {
                                showLogoutAlert = true
                            }

                            ProfileDivider()

                            ProfileActionRow(
                                icon: "trash.fill",
                                iconColor: PHTheme.danger,
                                label: "Delete Account",
                                labelColor: PHTheme.danger
                            ) {
                                showDeleteAccount = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                    // Version tag
                    Text("PetHub v1.0.0")
                        .font(.system(size: 11))
                        .foregroundStyle(PHTheme.divider)
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
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
                .environmentObject(subscriptionManager)
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
                        .fill(PHTheme.background)
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
                    .foregroundStyle(PHTheme.text)

                Text(profile.username)
                    .font(.system(size: 13))
                    .foregroundStyle(profile.accent.opacity(0.8))

                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.system(size: 13))
                        .foregroundStyle(PHTheme.text)
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
            RoundedRectangle(cornerRadius: 28)
                .fill(PHTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(PHTheme.divider, lineWidth: 0.5)
                )
        )
    }

    private var totalPhotos: Int {
        store.rooms.reduce(0) { $0 + $1.photos.count }
    }

    private var currentPlanName: String {
        switch subscriptionManager.tier {
        case .free:
            return "Free"
        case .semiPro:
            return "Semi-Pro"
        case .pro:
            return "Pro"
        }
    }

    private var currentPlanDescription: String {
        switch subscriptionManager.tier {
        case .free:
            return "Browse Lost & Found, join rooms, and post found pets."
        case .semiPro:
            return "Lost posting and contact details are unlocked."
        case .pro:
            return "Possible Matches and premium recovery tools are unlocked."
        }
    }

    private var currentPlanColor: Color {
        switch subscriptionManager.tier {
        case .free:
            return PHTheme.accent
        case .semiPro:
            return PHTheme.accent2
        case .pro:
            return PHTheme.warning
        }
    }

    private func openAppleSubscriptionSettings() {
        guard
            let url = URL(
                string: "https://apps.apple.com/account/subscriptions"
            )
        else { return }
        UIApplication.shared.open(url)
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
            profile = fetched
        } catch {
            #if DEBUG
            print("Profile.swift:391 error:", error)
            #endif
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
                .foregroundStyle(PHTheme.text)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(PHTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(PHTheme.divider)
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
                    .foregroundStyle(PHTheme.text)
                Text(room.breed)
                    .font(.system(size: 10))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(PHTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(PHTheme.divider, lineWidth: 0.5)
                )
        )
    }
}


// MARK: - Appearance Selector

struct AppearanceSelector: View {
    @Binding var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(PHTheme.warning.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PHTheme.warning)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Appearance")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PHTheme.text)
                    Text("Choose how PetHub looks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PHTheme.subtext)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                AppearancePreviewCard(title: "System", icon: "circle.lefthalf.filled", isSelected: theme == .system) { theme = .system }
                AppearancePreviewCard(title: "Light", icon: "sun.max.fill", isSelected: theme == .light) { theme = .light }
                AppearancePreviewCard(title: "Dark", icon: "moon.fill", isSelected: theme == .dark) { theme = .dark }
            }
        }
    }
}

struct AppearancePreviewCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? PHTheme.accent.opacity(0.16) : PHTheme.surface)
                        .frame(height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? PHTheme.accent : PHTheme.subtext)
                }
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? PHTheme.accent : PHTheme.subtext)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(PHTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? PHTheme.accent : PHTheme.border, lineWidth: isSelected ? 1.2 : 0.7)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Status Row

struct SubscriptionStatusRow: View {
    let planName: String
    let planDescription: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Current Plan")
                        .font(.system(size: 12))
                        .foregroundStyle(PHTheme.subtext)

                    Text(planName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(accentColor.opacity(0.12))
                        )
                }

                Text(planDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(PHTheme.text.opacity(0.78))
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Helpers

struct ProfileSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.3)
            .foregroundStyle(PHTheme.subtext)
    }
}

struct ProfileCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) { content }
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

struct ProfileDivider: View {
    var body: some View {
        Rectangle()
            .fill(PHTheme.divider)
            .frame(height: 0.5)
            .padding(.leading, 62)
    }
}

struct ProfileActionRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    var labelColor: Color = PHTheme.text
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
                    .foregroundStyle(PHTheme.divider)
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
            PHTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Nav
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(PHTheme.divider)
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    PHTheme.textOnAccent.opacity(0.8)
                                )
                        }
                    }
                    Spacer()
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PHTheme.accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(PHTheme.accent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                Text("Edit Profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(PHTheme.text)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                // Avatar picker (emoji for now)
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(PHTheme.accent.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Text(profile.avatarEmoji)
                            .font(.system(size: 36))
                        // Camera badge
                        ZStack {
                            Circle()
                                .fill(PHTheme.accent)
                                .frame(width: 26, height: 26)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(PHTheme.accent)
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
                            .foregroundStyle(PHTheme.subtext)

                        ZStack(alignment: .topLeading) {
                            if bio.isEmpty {
                                Text("Tell people about yourself…")
                                    .font(.system(size: 14))
                                    .foregroundStyle(PHTheme.placeholder)
                                    .padding(.top, 14)
                                    .padding(.leading, 16)
                            }
                            TextEditor(text: $bio)
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(PHTheme.text)
                                .frame(height: 100)
                                .padding(12)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(PHTheme.surface2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(
                                            PHTheme.divider,
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
            #if DEBUG
            print("Profile.swift:809 error:", error)
            #endif
        }
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordView: View {
    var skipCurrentPassword: Bool = false
    var onDismissAll: (() -> Void)? = nil
    @AppStorage("isResettingPassword") var isResettingPassword = false
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var newPass = ""
    @State private var confirm = ""
    @State private var isSaving = false

    private var canSave: Bool {
        (skipCurrentPassword || !current.isEmpty) && newPass.count >= 8
            && newPass == confirm
    }

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Nav
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(PHTheme.divider)
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
                                            ? PHTheme.accent
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
                    .foregroundStyle(PHTheme.text)
                    .lineSpacing(2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                VStack(spacing: 16) {
                    if !skipCurrentPassword {
                        ProfileInputField(
                            title: "Current Password",
                            placeholder: "••••••••",
                            text: $current,
                            isSecure: true
                        )
                    }
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
                            .foregroundStyle(PHTheme.danger)
                            .padding(.horizontal, 4)
                    }

                    if !confirm.isEmpty && newPass != confirm {
                        Text("Passwords don't match")
                            .font(.system(size: 12))
                            .foregroundStyle(PHTheme.danger)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func changePassword() async {
        guard !isSaving else { return }
        isSaving = true
        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPass)
            )
            isResettingPassword = false
            dismiss()
            onDismissAll?()
            try await supabase.auth.signOut()
        } catch {
            isSaving = false
        }
    }
}

// MARK: - Delete Account Sheet

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var canDelete: Bool {
        confirmText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            == "DELETE"
    }

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(PHTheme.divider)
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    PHTheme.textOnAccent.opacity(0.8)
                                )
                        }
                    }
                    .disabled(isDeleting)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                Text("Delete Account")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(PHTheme.text)
                    .padding(.horizontal, 20)

                Text(
                    "This will permanently remove your PetHub account. Your profile, rooms, posts, messages, and lost/found records should be deleted by the Supabase delete_my_account() function."
                )
                .font(.system(size: 14))
                .foregroundStyle(PHTheme.subtext)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Type DELETE to confirm")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PHTheme.subtext)

                    TextField(
                        "DELETE",
                        text: $confirmText
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(PHTheme.text)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(PHTheme.surface2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(PHTheme.divider, lineWidth: 0.5)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(PHTheme.danger)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                Button {
                    Task { await deleteAccount() }
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                                .tint(PHTheme.accent)
                        } else {
                            Text("Permanently Delete Account")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Spacer()
                    }
                    .foregroundStyle(PHTheme.accent)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                canDelete
                                    ? PHTheme.danger : PHTheme.divider
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canDelete || isDeleting)
                .padding(.horizontal, 20)
                .padding(.top, 26)

                Spacer()
            }
        }
    }

    private func deleteAccount() async {
        guard canDelete else { return }
        isDeleting = true
        errorMessage = nil

        do {
            // Create this RPC in Supabase. It must delete the current user's related data
            // and then delete auth.users where id = auth.uid().
            try await supabase
                .rpc("delete_my_account")
                .execute()

            try? await supabase.auth.signOut()
        } catch {
            print("Delete account error:", error)
            errorMessage = String(describing: error)
        }

        isDeleting = false
    }
}

// MARK: - Shared Input Field

struct ProfileInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PHTheme.subtext)

            Group {
                if isSecure {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(
                            PHTheme.placeholder
                        )
                    )
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(
                            PHTheme.placeholder
                        )
                    )
                }
            }
            .keyboardType(keyboardType)
            .foregroundStyle(PHTheme.text)
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(PHTheme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(PHTheme.divider, lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
}
