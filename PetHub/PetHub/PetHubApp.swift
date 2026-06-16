import Supabase
import SwiftUI
import UserNotifications
import RevenueCat

@main
struct PetHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

        Purchases.configure(withAPIKey: "appl_evhbaETZHncfnVUSItJpgNhcoqJ")

        _subscriptionManager = StateObject(
            wrappedValue: SubscriptionManager()
        )
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .tint(PHTheme.accent)
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
            }

            isLoggedIn = false
            needsUserOnboarding = true
            return
        }

        isLoggedIn = supabase.auth.currentSession != nil

        if isLoggedIn {
            await NotificationManager.shared.requestPermission()
        }

        if let session = supabase.auth.currentSession {
            await checkOnboarding(userId: session.user.id.uuidString)
        }

        for await state in supabase.auth.authStateChanges {
            if let session = state.session {
                guard !isResettingPassword else { continue }

                isLoggedIn = true
                await checkOnboarding(userId: session.user.id.uuidString)
                await NotificationManager.shared.requestPermission()
            } else {
                isResettingPassword = false
                isLoggedIn = false
                needsUserOnboarding = true
            }
        }
    }

    @MainActor
    private func checkOnboarding(userId: String) async {
        needsUserOnboarding = false

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
            #if DEBUG
            print("Check onboarding error:", error)
            #endif
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationManager.shared.didRegisterForRemoteNotifications(
            deviceToken: deviceToken
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed:", error)
    }
}
