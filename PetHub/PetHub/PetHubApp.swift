import Supabase
import SwiftUI

@main
struct PetHubApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @State private var isLoggedIn = false
    @State private var isOnboarded = false
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else if !isLoggedIn {
                    NavigationStack {
                        WelcomeView()
                    }
                } else if !isOnboarded {
                    UserOnboardingView()
                } else {
                    MainTabView()
                }
            }
            .preferredColorScheme(themeManager.theme.colorScheme)
            .environmentObject(themeManager)
            .task {
                isLoggedIn = supabase.auth.currentSession != nil
                if let session = supabase.auth.currentSession {
                    await checkOnboarding(userId: session.user.id.uuidString)
                }
                for await state in supabase.auth.authStateChanges {
                    isLoggedIn = state.session != nil
                    if let session = state.session {
                        await checkOnboarding(userId: session.user.id.uuidString)
                    } else {
                        isOnboarded = false
                    }
                }
            }
        }
    }

    private func checkOnboarding(userId: String) async {
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            isOnboarded = profile.isOnboarded ?? false
        } catch {
            isOnboarded = false
        }
    }
}
