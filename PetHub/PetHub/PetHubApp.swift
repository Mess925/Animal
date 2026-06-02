import SwiftUI
import Supabase

@main
struct PetHubApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @State private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else if isLoggedIn {
                    MainTabView()
                } else {
                    NavigationStack {
                        WelcomeView()
                    }
                }
            }
            .task {
                isLoggedIn = supabase.auth.currentSession != nil
                for await state in supabase.auth.authStateChanges {
                    isLoggedIn = state.session != nil
                }
            }
        }
    }
}
