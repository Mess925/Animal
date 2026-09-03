//
//  NotificationManager.swift
//  PetHub
//
//  Created by Han Min Thant on 16/6/26.
//

import Foundation
import UIKit
import UserNotifications
import Supabase
import Combine

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private(set) var lastKnownToken: String?

    /// Removes this device's token from the account that's about to sign
    /// out, so it stops receiving that account's pushes once someone else
    /// signs into the same device. Call before `supabase.auth.signOut()`.
    func clearTokenForSignOut(userId: UUID) async {
        guard let token = lastKnownToken else { return }
        do {
            try await supabase
                .from("push_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("token", value: token)
                .execute()
        } catch {
            print("Failed to clear push token on sign out:", error)
        }
    }

    func requestPermission() async {
        await waitUntilAppIsActive()
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Notification permission error:", error)
        }
    }
    
    private func waitUntilAppIsActive() async {
        let isActive = await MainActor.run { UIApplication.shared.applicationState == .active }
        if isActive { return }

        await withCheckedContinuation { continuation in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let observer { NotificationCenter.default.removeObserver(observer) }
                continuation.resume()
            }
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()

        lastKnownToken = token
        print("APNs Token:", token)

        Task {
            await saveToken(token)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            AppRouter.shared.route(userInfo: userInfo)
        }
    }

    private func saveToken(_ token: String) async {
        do {
            let user = try await supabase.auth.user()

            // A device token identifies this physical device/app install, not
            // a specific account. If a different account previously signed in
            // here, its row for this same token is now stale — leaving it
            // would notify both accounts for this device. A token should only
            // ever belong to whoever is currently signed in.
            try await supabase
                .from("push_tokens")
                .delete()
                .eq("token", value: token)
                .neq("user_id", value: user.id.uuidString)
                .execute()

            try await supabase
                .from("push_tokens")
                .upsert(
                    [
                        "user_id": user.id.uuidString,
                        "token": token
                    ],
                    onConflict: "user_id,token"
                )
                .execute()

            print("Push token saved")
        } catch {
            print("Failed to save push token:", error)
        }
    }
}
