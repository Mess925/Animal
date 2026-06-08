import Supabase
import SwiftUI
import Combine
import RevenueCat

@main
struct PetHubApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @State private var isLoggedIn = false
    @State private var isOnboarded = false
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

    init() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_SawIEyfctZaetbkOBaLgIHHwOBZ")
    }

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
                    MainTabView(subscriptionManager: subscriptionManager)
                }
            }
            .preferredColorScheme(themeManager.theme.colorScheme)
            .environmentObject(themeManager)
            .environmentObject(subscriptionManager)
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
            await MainActor.run {
                subscriptionManager.update(from: profile)
            }
        } catch {
            isOnboarded = false
        }
    }
}
