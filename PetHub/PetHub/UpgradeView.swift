//
//  UpgradeView.swift
//  PetHub
//
//  Subscription page polish
//

import SwiftUI
import RevenueCat

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var isYearly = false
    @State private var currentOffering: Offering?
    @State private var isLoading = true
    @State private var purchasingTier: SubscriptionTier? = nil
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private var isPurchasing: Bool { purchasingTier != nil }

    private var currentPlanName: String {
        switch subscriptionManager.tier {
        case .free: return "Free"
        case .semiPro: return "Semi-Pro"
        case .pro: return "Pro"
        }
    }

    var body: some View {
        PHPage {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 18)

                    hero
                        .padding(.horizontal, 20)

                    currentPlanCard
                        .padding(.horizontal, 20)

                    billingToggle
                        .padding(.horizontal, 20)

                    if isLoading {
                        ProgressView()
                            .tint(PHTheme.accent)
                            .padding(.top, 36)
                    } else {
                        VStack(spacing: 14) {
                            freePlanCard

                            planCard(
                                tier: .semiPro,
                                name: "Semi-Pro",
                                badge: "More space",
                                accentColor: PHTheme.success,
                                monthlyPrice: "$3.99",
                                yearlyPrice: "$39.99",
                                yearlySaving: "Save $7.89/year",
                                packageMonthlyId: "pethub_semipro_monthly",
                                packageYearlyId: "pethub_semipro_yearly",
                                features: [
                                    PlanFeature(icon: "location.fill", title: "35 km search radius", subtitle: "See more nearby lost and found posts", isIncluded: true),
                                    PlanFeature(icon: "house.fill", title: "5 pet rooms", subtitle: "More space for your pets", isIncluded: true),
                                    PlanFeature(icon: "photo.fill", title: "1000 photos total", subtitle: "Across your whole account", isIncluded: true),
                                    PlanFeature(icon: "checkmark.circle.fill", title: "Post found pets", subtitle: "Help owners find missing pets", isIncluded: true),
                                    PlanFeature(icon: "lock.fill", title: "Post lost pets", subtitle: "Pro only", isIncluded: false),
                                    PlanFeature(icon: "magnifyingglass.circle.fill", title: "Possible Matches", subtitle: "Pro only", isIncluded: false)
                                ]
                            )

                            planCard(
                                tier: .pro,
                                name: "Pro",
                                badge: "Recovery tools",
                                accentColor: PHTheme.accent,
                                monthlyPrice: "$5.99",
                                yearlyPrice: "$59.99",
                                yearlySaving: "Save $11.89/year",
                                packageMonthlyId: "pethub_pro_monthly",
                                packageYearlyId: "pethub_pro_yearly",
                                features: [
                                    PlanFeature(icon: "location.fill", title: "150 km search radius", subtitle: "Search across a much wider area", isIncluded: true),
                                    PlanFeature(icon: "checkmark.circle.fill", title: "Post lost pets", subtitle: "Create lost reports from your pet room", isIncluded: true),
                                    PlanFeature(icon: "phone.fill", title: "See contact details", subtitle: "Call or message owners/finders faster", isIncluded: true),
                                    PlanFeature(icon: "magnifyingglass.circle.fill", title: "Possible Matches", subtitle: "Match your lost pet with found posts", isIncluded: true),
                                    PlanFeature(icon: "bell.badge.fill", title: "Possible Match alerts", subtitle: "Get notified about possible matches", isIncluded: true),
                                    PlanFeature(icon: "house.fill", title: "Unlimited rooms", subtitle: "No room limit", isIncluded: true),
                                    PlanFeature(icon: "photo.fill", title: "Unlimited photos", subtitle: "No photo limit", isIncluded: true)
                                ]
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(PHTheme.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    footer
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
                .task { await loadOfferings() }
            }
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(PHTheme.surface2)
                        .frame(width: 38, height: 38)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PHTheme.text)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Plans")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PHTheme.text)

            Spacer()

            Button("Restore") {
                Task { await restore() }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(PHTheme.accent)
            .disabled(isPurchasing || isRestoring)
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.black)
                    .frame(width: 72, height: 72)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Choose your PetHub plan")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(PHTheme.text)
                    .multilineTextAlignment(.center)

                Text("Free is for local community access. Semi-Pro gives you more pet space and a wider search radius. Pro unlocks full lost pet recovery tools.")
                    .font(.system(size: 14))
                    .foregroundStyle(PHTheme.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.top, 8)
    }

    private var currentPlanCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(PHTheme.text.opacity(0.07))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PHTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Current plan")
                    .font(.system(size: 12))
                    .foregroundStyle(PHTheme.subtext)
                Text(currentPlanName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PHTheme.text)
            }

            Spacer()

            Text(subscriptionManager.tier == .free ? "Upgrade anytime" : "Active")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(subscriptionManager.tier == .free ? PHTheme.accent : PHTheme.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (subscriptionManager.tier == .free ? PHTheme.accent : PHTheme.success).opacity(0.12),
                    in: Capsule()
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(PHTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(PHTheme.divider, lineWidth: 0.5)
                )
        )
    }

    private var billingToggle: some View {
        HStack(spacing: 0) {
            BillingToggleButton(title: "Monthly", isSelected: !isYearly) {
                withAnimation(.easeInOut(duration: 0.2)) { isYearly = false }
            }
            BillingToggleButton(title: "Yearly", badge: "Save", isSelected: isYearly) {
                withAnimation(.easeInOut(duration: 0.2)) { isYearly = true }
            }
        }
        .padding(4)
        .background(PHTheme.surface2, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(PHTheme.divider, lineWidth: 0.5)
        )
    }

    // MARK: - Cards

    private var freePlanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Free")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(PHTheme.text)
                    Text("Local community access")
                        .font(.system(size: 13))
                        .foregroundStyle(PHTheme.subtext)
                }
                Spacer()
                Text("$0")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(PHTheme.text)
            }

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(feature: PlanFeature(icon: "location.fill", title: "10 km search radius", subtitle: "See local lost and found posts", isIncluded: true), accentColor: PHTheme.subtext)
                FeatureRow(feature: PlanFeature(icon: "house.fill", title: "3 pet rooms", subtitle: "Create up to 3 pet rooms", isIncluded: true), accentColor: PHTheme.subtext)
                FeatureRow(feature: PlanFeature(icon: "photo.fill", title: "50 photos total", subtitle: "Across your whole account", isIncluded: true), accentColor: PHTheme.subtext)
                FeatureRow(feature: PlanFeature(icon: "checkmark.circle.fill", title: "Post found pets", subtitle: "Help owners find missing pets", isIncluded: true), accentColor: PHTheme.subtext)
                FeatureRow(feature: PlanFeature(icon: "xmark.circle.fill", title: "Post lost pets", subtitle: "Upgrade to Pro", isIncluded: false), accentColor: PHTheme.subtext)
                FeatureRow(feature: PlanFeature(icon: "xmark.circle.fill", title: "Possible Matches", subtitle: "Upgrade to Pro", isIncluded: false), accentColor: PHTheme.subtext)
            }

            currentPlanButton(for: .free)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(PHTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(subscriptionManager.tier == .free ? PHTheme.accent : PHTheme.divider, lineWidth: subscriptionManager.tier == .free ? 1.2 : 0.5)
                )
        )
    }

    private func planCard(
        tier: SubscriptionTier,
        name: String,
        badge: String,
        accentColor: Color,
        monthlyPrice: String,
        yearlyPrice: String,
        yearlySaving: String,
        packageMonthlyId: String,
        packageYearlyId: String,
        features: [PlanFeature]
    ) -> some View {
        let isCurrent = subscriptionManager.tier == tier
        let isIncludedInCurrentPlan = tier == .semiPro && subscriptionManager.tier == .pro
        let isProCard = tier == .pro
        let price = isYearly ? yearlyPrice : monthlyPrice
        let isThisTierPurchasing = purchasingTier == tier

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(PHTheme.text)

                        Text(isCurrent ? "Current" : badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isCurrent ? PHTheme.success : accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background((isCurrent ? PHTheme.success : accentColor).opacity(0.13), in: Capsule())
                    }

                    Text(isProCard ? "Full recovery tools for lost pets" : "More space and wider nearby search")
                        .font(.system(size: 13))
                        .foregroundStyle(PHTheme.subtext)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(PHTheme.text)
                    Text(isYearly ? "per year" : "per month")
                        .font(.system(size: 12))
                        .foregroundStyle(PHTheme.subtext)
                    if isYearly {
                        Text(yearlySaving)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PHTheme.success)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(features) { feature in
                    FeatureRow(feature: feature, accentColor: accentColor)
                }
            }

            Button {
                guard !isCurrent && !isIncludedInCurrentPlan else { return }
                Task {
                    let id = isYearly ? packageYearlyId : packageMonthlyId
                    if let package = findPackage(id) {
                        await purchase(package, tier: tier)
                    } else {
                        errorMessage = "Plan is not available. Missing package/product id: \(id)"
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    if isThisTierPurchasing {
                        ProgressView()
                            .tint(isProCard ? PHTheme.text : .white)
                    } else {
                        Text(isCurrent ? "Current Plan" : buttonTitle(for: tier))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Spacer()
                }
                .foregroundStyle(isCurrent || isIncludedInCurrentPlan ? PHTheme.subtext : .white)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isCurrent || isIncludedInCurrentPlan ? PHTheme.divider.opacity(0.5) : accentColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(isCurrent || isIncludedInCurrentPlan || isPurchasing || isRestoring)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(isProCard ? PHTheme.surface : PHTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(isCurrent || isProCard ? accentColor.opacity(0.65) : PHTheme.divider, lineWidth: isCurrent || isProCard ? 1.2 : 0.5)
                )
        )
    }

    private func currentPlanButton(for tier: SubscriptionTier) -> some View {
        let isCurrent = subscriptionManager.tier == tier

        return HStack {
            Spacer()
            Text(isCurrent ? "Current Plan" : "Included")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(PHTheme.subtext)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PHTheme.divider.opacity(0.45))
        )
    }

    private func findPackage(_ id: String) -> Package? {
        currentOffering?.availablePackages.first {
            $0.identifier == id || $0.storeProduct.productIdentifier == id
        }
    }

    private func buttonTitle(for tier: SubscriptionTier) -> String {
        switch tier {
        case .free:
            return "Current Plan"
        case .semiPro:
            return subscriptionManager.tier == .pro ? "Included in Pro" : "Upgrade to Semi-Pro"
        case .pro:
            return "Upgrade to Pro"
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text("Subscriptions renew automatically unless cancelled. You can restore purchases anytime.")
                .font(.system(size: 11))
                .foregroundStyle(PHTheme.subtext)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button("Maybe later") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PHTheme.subtext)
                .padding(.top, 2)
        }
    }

    // MARK: - RevenueCat

    private func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()

            await MainActor.run {
                currentOffering = offerings.current
                isLoading = false
                if offerings.current == nil {
                    errorMessage = "Subscriptions are currently unavailable. Please try again later."
                }
            }
        } catch {
            await MainActor.run {
                currentOffering = nil
                isLoading = false
                errorMessage = "Unable to load subscriptions. Please try again later."
            }
        }
    }

    private func purchase(_ package: Package, tier: SubscriptionTier) async {
        await MainActor.run {
            purchasingTier = tier
            errorMessage = nil
        }

        do {
            try await subscriptionManager.purchase(package)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Purchase failed. Please try again."
            }
        }

        await MainActor.run { purchasingTier = nil }
    }

    private func restore() async {
        await MainActor.run {
            isRestoring = true
            errorMessage = nil
        }

        do {
            try await subscriptionManager.restorePurchases()
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Restore failed. Please try again."
            }
        }

        await MainActor.run { isRestoring = false }
    }
}

// MARK: - Models

struct PlanFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let isIncluded: Bool
}

// MARK: - Components

struct BillingToggleButton: View {
    let title: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? PHTheme.text : PHTheme.subtext)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PHTheme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PHTheme.success.opacity(0.12), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? PHTheme.background : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let feature: PlanFeature
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: feature.isIncluded ? feature.icon : "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(feature.isIncluded ? accentColor : PHTheme.subtext.opacity(0.55))
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(feature.isIncluded ? PHTheme.text : PHTheme.subtext)

                Text(feature.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(PHTheme.subtext)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    UpgradeView()
        .environmentObject(SubscriptionManager())
}
