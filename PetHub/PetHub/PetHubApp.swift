import Supabase
import SwiftUI
import RevenueCat

@main
struct PetHubApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("needsUserOnboarding") private var needsUserOnboarding = true
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("isResettingPassword") private var isResettingPassword = false

    @StateObject private var themeManager = ThemeManager()
    @StateObject private var subscriptionManager: SubscriptionManager

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: "test_SawIEyfctZaetbkOBaLgIHHwOBZ")

        _subscriptionManager = StateObject(
            wrappedValue: SubscriptionManager()
        )
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(themeManager.theme.colorScheme)
                .environmentObject(themeManager)
                .environmentObject(subscriptionManager)
                .task {
                    await startApp()
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if !hasSeenOnboarding {
            OnboardingView()
        } else if !isLoggedIn {
            NavigationStack {
                WelcomeView()
            }
        } else if needsUserOnboarding {
            UserOnboardingView()
        } else {
            MainTabView(subscriptionManager: subscriptionManager)
        }
    }

    private func startApp() async {
        if !hasSeenOnboarding {
            do {
                try await supabase.auth.signOut()
            } catch {
                print("[Auth] signOut failed: \(error)")
            }

            isLoggedIn = false
            needsUserOnboarding = true
            return
        }

        isLoggedIn = supabase.auth.currentSession != nil

        if let session = supabase.auth.currentSession {
            await checkOnboarding(userId: session.user.id.uuidString)
        }

        for await state in supabase.auth.authStateChanges {
            if let session = state.session {
                guard !isResettingPassword else { continue }

                isLoggedIn = true
                await checkOnboarding(userId: session.user.id.uuidString)
            } else {
                isResettingPassword = false
                isLoggedIn = false
                needsUserOnboarding = true
            }
        }
    }

    @MainActor
    private func checkOnboarding(userId: String) async {
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            needsUserOnboarding = !(profile.isOnboarded ?? false)

            subscriptionManager.fetchCustomerInfo()
        } catch {
            print("[Onboarding] Failed to fetch profile: \(error)")
        }
    }
}
