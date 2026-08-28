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

        print("APNs Token:", token)

        Task {
            await saveToken(token)
        }
    }

    private func saveToken(_ token: String) async {
        do {
            let user = try await supabase.auth.user()

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
