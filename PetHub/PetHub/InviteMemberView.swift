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
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Nav
                HStack {
                    Button { dismiss() } label: {
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
                    .foregroundStyle(Color("AppText"))

                    Text("Enter their username to invite them")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppSubtext"))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("USERNAME")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color("AppSubtext"))

                    TextField("", text: $username, prompt: Text("@username").foregroundStyle(Color("AppPlaceholder")))
                        .autocapitalization(.none)
                        .foregroundStyle(Color("AppText"))
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color("AppSurface"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color("AppBorder"), lineWidth: 0.5)
                                )
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "E25718"))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }

                if !successMessage.isEmpty {
                    Text(successMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "06D6A0"))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }

                // Invite button
                Button {
                    Task { await inviteMember() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(Color("AppAccentText"))
                        } else {
                            Text("Send Invite")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color("AppAccentText"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(username.isEmpty ? Color(hex: "AA9DFF").opacity(0.4) : Color(hex: "AA9DFF"))
                    )
                }
                .buttonStyle(.plain)
                .disabled(username.isEmpty || isLoading)
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
            let searchUsername = username.hasPrefix("@") ? username : "@\(username)"
            
            let users: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("username", value: searchUsername)
                .execute()
                .value

            guard let user = users.first, let userId = user.id else {
                errorMessage = "No user found with that username."
                isLoading = false
                return
            }

            // Check if already a member
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

            try await supabase
                .from("room_members")
                .insert([
                    "room_id": room.id.uuidString.lowercased(),
                    "user_id": userId.uuidString.lowercased(),
                    "role": "member"
                ])
                .execute()

            // Activity V1: roomJoined
            try? await supabase
                .from("activities")
                .insert([
                    "type": "room_joined",
                    "actor_id": userId.uuidString,
                    "room_id": room.id.uuidString,
                    "body": "\(user.name) joined \(room.name)'s room"
                ])
                .execute()

            successMessage = "Invited successfully! 🎉"
        } catch {
            errorMessage = "Something went wrong. Try again."
        }

        isLoading = false
    }
}
