//
//  AppRouter.swift
//  PetHub
//
//  Central place for "go to X" requests, fed either by a tapped push
//  notification (via NotificationManager) or an in-app activity row
//  (via ActivityView). MainTabView observes AppRouter.shared and resolves
//  the destination into an actual screen.
//

import Combine
import Foundation

enum PendingChatTarget: Equatable {
    case group
    case dm(otherUserId: UUID)
}

enum AppDestination: Equatable {
    case roomChat(roomId: UUID)
    case dmChat(roomId: UUID, otherUserId: UUID)
    case roomPhotos(roomId: UUID)
    case photoDetail(roomId: UUID, photoId: UUID)
    case roomHome(roomId: UUID)
    case lostFoundChat(postId: UUID, otherUserId: UUID)
    case lostFoundPost(postId: UUID)
    case activityTab
}

extension AppDestination {
    /// Parses the destination out of a push notification's userInfo payload.
    /// Expects a `type` key plus whichever id keys that type needs
    /// (see supabase/notifications_setup.sql for what each trigger sends).
    init?(userInfo: [AnyHashable: Any]) {
        func uuid(_ key: String) -> UUID? {
            (userInfo[key] as? String).flatMap(UUID.init)
        }

        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "room_message":
            guard let roomId = uuid("room_id") else { return nil }
            self = .roomChat(roomId: roomId)

        case "dm_message":
            guard let roomId = uuid("room_id"), let senderId = uuid("sender_id")
            else { return nil }
            self = .dmChat(roomId: roomId, otherUserId: senderId)

        case "lost_found_message":
            guard let postId = uuid("post_id"), let senderId = uuid("sender_id")
            else { return nil }
            self = .lostFoundChat(postId: postId, otherUserId: senderId)

        case "photo_added":
            guard let roomId = uuid("room_id") else { return nil }
            self = .roomPhotos(roomId: roomId)

        case "like", "comment":
            guard let roomId = uuid("room_id"), let photoId = uuid("photo_id")
            else { return nil }
            self = .photoDetail(roomId: roomId, photoId: photoId)

        case "room_joined", "room_left":
            guard let roomId = uuid("room_id") else { return nil }
            self = .roomHome(roomId: roomId)

        case "possible_match", "pet_found":
            guard let postId = uuid("post_id") else { return nil }
            self = .lostFoundPost(postId: postId)

        case "room_invite":
            self = .activityTab

        default:
            return nil
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var pendingDestination: AppDestination? = nil

    private init() {}

    func route(to destination: AppDestination) {
        pendingDestination = destination
    }

    func route(userInfo: [AnyHashable: Any]) {
        guard let destination = AppDestination(userInfo: userInfo) else { return }
        pendingDestination = destination
    }
}
