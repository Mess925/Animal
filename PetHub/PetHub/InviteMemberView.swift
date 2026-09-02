//
//  InviteMemberView.swift
//  PetHub
//
//  Created by Han Min Thant on 6/6/26.
//

import Foundation
import SwiftUI
import Supabase

struct InviteMemberView: View {
    let room: PetRoom
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Nav
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(PHTheme.surface)
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PHTheme.text)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Group {
                        Text("Invite to ") +
                        Text("\(room.name)'s room 🐾")
                            .font(.custom("Georgia-Italic", size: 28))
                            .foregroundColor(room.accent)
                    }
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(PHTheme.text)

                    Text("Enter their invite code to send a room request")
                        .font(.system(size: 12))
                        .foregroundStyle(PHTheme.subtext)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("INVITE CODE")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(PHTheme.subtext)

                    TextField("", text: $inviteCode, prompt: Text("PH-8K42Q").foregroundStyle(PHTheme.placeholder))
                        .textInputAutocapitalization(.characters)
                        .foregroundStyle(PHTheme.text)
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(PHTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(PHTheme.border, lineWidth: 0.5)
                                )
                        )
                        .onChange(of: inviteCode) { _, newValue in
                            inviteCode = formatInviteCode(newValue)
                        }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(PHTheme.danger)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }

                if !successMessage.isEmpty {
                    Text(successMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(PHTheme.success)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }

                // Invite button
                Button {
                    Task { await inviteMember() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(PHTheme.background)
                        } else {
                            Text("Send Invite")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PHTheme.background)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(inviteCode.isEmpty ? PHTheme.accent.opacity(0.4) : PHTheme.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(inviteCode.isEmpty || isLoading)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func inviteMember() async {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        do {
            let currentUser = try await supabase.auth.session.user
            let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            struct InviteLookupResult: Codable {
                let id: UUID
                let name: String
            }

            let users: [InviteLookupResult] = try await supabase
                .rpc("lookup_profile_by_invite_code", params: ["p_code": code])
                .execute()
                .value

            guard let user = users.first else {
                errorMessage = "No user found with that invite code."
                isLoading = false
                return
            }
            let userId = user.id

            if userId == currentUser.id {
                errorMessage = "You cannot invite yourself."
                isLoading = false
                return
            }

            let existing: [RoomMembership] = try await supabase
                .from("room_members")
                .select()
                .eq("room_id", value: room.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if !existing.isEmpty {
                errorMessage = "This user is already a member."
                isLoading = false
                return
            }

            let pendingInvites: [RoomInvitation] = try await supabase
                .from("room_invitations")
                .select()
                .eq("room_id", value: room.id.uuidString)
                .eq("invited_user_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .execute()
                .value

            if !pendingInvites.isEmpty {
                errorMessage = "This user already has a pending invite."
                isLoading = false
                return
            }

            try await supabase
                .from("room_invitations")
                .insert([
                    "room_id": room.id.uuidString.lowercased(),
                    "invited_user_id": userId.uuidString.lowercased(),
                    "invited_by": currentUser.id.uuidString.lowercased(),
                    "status": "pending"
                ])
                .execute()

            try? await supabase
                .from("activities")
                .insert([
                    "type": "room_invite",
                    "actor_id": currentUser.id.uuidString,
                    "recipient_id": userId.uuidString,
                    "room_id": room.id.uuidString,
                    "body": "You were invited to join \(room.name)'s room"
                ])
                .execute()

            successMessage = "Invite request sent to \(user.name)."
        } catch {print("Invite error:", error)
            errorMessage = "\(error)"
        }

        isLoading = false
    }

    private func formatInviteCode(_ value: String) -> String {
        let cleaned = value
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        if cleaned.hasPrefix("PH"), cleaned.count > 2 {
            let suffix = cleaned.dropFirst(2)
            return "PH-" + String(suffix.prefix(6))
        }

        if cleaned.count > 2 {
            return "PH-" + String(cleaned.prefix(6))
        }

        return cleaned
    }
}
