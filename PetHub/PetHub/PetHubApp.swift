import Supabase
import SwiftUI
import Combine
import RevenueCat

@main
struct PetHubApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("needsUserOnboarding") var needsUserOnboarding = true
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var subscriptionManager: SubscriptionManager
    @AppStorage("isResettingPassword") var isResettingPassword = false
    
    init() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_SawIEyfctZaetbkOBaLgIHHwOBZ")
        _subscriptionManager = StateObject(wrappedValue: SubscriptionManager())
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
                } else if needsUserOnboarding {
                    UserOnboardingView()
                } else {
                    MainTabView(subscriptionManager: subscriptionManager)
                }
            }
            .preferredColorScheme(themeManager.theme.colorScheme)
            .environmentObject(themeManager)
            .environmentObject(subscriptionManager)
            .task {
                if !hasSeenOnboarding {
                    try? await supabase.auth.signOut()
                    isLoggedIn = false
                    needsUserOnboarding = true
                    return
                }

                isLoggedIn = supabase.auth.currentSession != nil
                if let session = supabase.auth.currentSession {
                    await checkOnboarding(userId: session.user.id.uuidString)
                }
                for await state in supabase.auth.authStateChanges {
                    if state.session == nil {
                        isResettingPassword = false
                        isLoggedIn = false
                        needsUserOnboarding = true
                    } else if !isResettingPassword {
                        isLoggedIn = true
                        await checkOnboarding(userId: state.session!.user.id.uuidString)
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
            await MainActor.run {
                needsUserOnboarding = !(profile.isOnboarded ?? false)
                subscriptionManager.fetchCustomerInfo()
            }
        } catch {
            // Leave needsUserOnboarding as-is if the fetch fails
        }
    }
}
