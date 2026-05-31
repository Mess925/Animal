//
//  PetHubApp.swift
//  PetHub
//
//  Created by Han Min Thant on 26/5/26.
//

import SwiftData
import SwiftUI

@main
struct PetHubApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            let _ = UserDefaults.standard.removeObject(
                forKey: "hasSeenOnboarding"
            )

            if hasSeenOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
