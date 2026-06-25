import Supabase
import SwiftUI
import UserNotifications
import RevenueCat

@main
struct PetHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("needsUserOnboarding") private var needsUserOnboarding = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("isSigningUpWithApple") private var isSigningUpWithApple = false
    @AppStorage("isResettingPassword") private var isResettingPassword = false

    @StateObject private var themeManager = ThemeManager()
    @StateObject private var subscriptionManager: SubscriptionManager
    @StateObject private var networkMonitor = NetworkMonitor.shared

    @State private var isStartingApp = true

    init() {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared

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
            ZStack(alignment: .top) {
                if isStartingApp {
                    AppLoadingView()
                } else {
                    rootView
                }

                if !networkMonitor.isConnected {
                    OfflineBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: networkMonitor.isConnected)
            .tint(PHTheme.accent)
            .preferredColorScheme(themeManager.theme.colorScheme)
            .environmentObject(themeManager)
            .environmentObject(subscriptionManager)
            .environmentObject(networkMonitor)
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
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                isStartingApp = false
            }
        }

        if !hasSeenOnboarding {
            do {
                try await supabase.auth.signOut()
            } catch {
            #if DEBUG
            print("PetHubApp.swift:87 error:", error)
            #endif
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

        Task {
            for await state in supabase.auth.authStateChanges {
                if let session = state.session {
                    guard !isResettingPassword else { continue }
                    guard !isSigningUpWithApple else { continue }
                    isLoggedIn = true
                    await checkOnboarding(userId: session.user.id.uuidString)
                    await NotificationManager.shared.requestPermission()
                } else {
                    isResettingPassword = false
                    isSigningUpWithApple = false
                    isLoggedIn = false
                    needsUserOnboarding = true
                }
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

struct AppLoadingView: View {
    var body: some View {
        ZStack {
            PHTheme.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(PHTheme.accent.opacity(0.14))
                        .frame(width: 82, height: 82)

                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(PHTheme.accent)
                }

                Text("PetHub")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(PHTheme.text)

                ProgressView()
                    .tint(PHTheme.accent)
                    .padding(.top, 4)
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        KeyboardDismissManager.shared.start()
        return true
    }

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


// MARK: - Global Keyboard Dismiss

final class KeyboardDismissManager: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissManager()

    private var installedWindowIDs = Set<ObjectIdentifier>()

    func start() {
        installTapRecognizers()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowBecameKey),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc private func windowBecameKey() {
        installTapRecognizers()
    }

    private func installTapRecognizers() {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap { $0.windows }

            for window in windows {
                let id = ObjectIdentifier(window)
                guard !self.installedWindowIDs.contains(id) else { continue }

                let tap = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
                tap.cancelsTouchesInView = false
                tap.delegate = self
                window.addGestureRecognizer(tap)

                self.installedWindowIDs.insert(id)
            }
        }
    }

    @objc private func dismissKeyboard(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view

        while let current = view {
            if current is UITextField || current is UITextView {
                return false
            }
            view = current.superview
        }

        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
