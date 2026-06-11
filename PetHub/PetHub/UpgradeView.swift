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
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var currentPlanName: String {
        switch subscriptionManager.tier {
        case .free: return "Free"
        case .semiPro: return "Semi-Pro"
        case .pro: return "Pro"
        }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

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
                            .tint(Color(hex: "AA9DFF"))
                            .padding(.top, 36)
                    } else {
                        VStack(spacing: 14) {
                            freePlanCard

                            planCard(
                                tier: .semiPro,
                                name: "Semi-Pro",
                                badge: "Best starter",
                                accentColor: Color(hex: "5DCAA5"),
                                monthlyPrice: "$1.99",
                                yearlyPrice: "$15.99",
                                yearlySaving: "Save $7.89/year",
                                packageMonthlyId: "pethub_semipro_monthly",
                                packageYearlyId: "pethub_semipro_yearly",
                                features: [
                                    PlanFeature(icon: "checkmark.circle.fill", title: "Post lost pets", subtitle: "Create lost reports from your pet room", isIncluded: true),
                                    PlanFeature(icon: "phone.fill", title: "See contact details", subtitle: "Call or message owners/finders faster", isIncluded: true),
                                    PlanFeature(icon: "house.fill", title: "5 pet rooms", subtitle: "More space for your pets", isIncluded: true),
                                    PlanFeature(icon: "photo.fill", title: "100 photos per room", subtitle: "More shared memories", isIncluded: true),
                                    PlanFeature(icon: "magnifyingglass.circle.fill", title: "Possible Matches", subtitle: "Pro only", isIncluded: false)
                                ]
                            )

                            planCard(
                                tier: .pro,
                                name: "Pro",
                                badge: "Recovery tools",
                                accentColor: Color(hex: "AA9DFF"),
                                monthlyPrice: "$3.99",
                                yearlyPrice: "$35.99",
                                yearlySaving: "Save $11.89/year",
                                packageMonthlyId: "pethub_pro_monthly",
                                packageYearlyId: "pethub_pro_yearly",
                                features: [
                                    PlanFeature(icon: "magnifyingglass.circle.fill", title: "Possible Matches", subtitle: "Match your lost pet with found posts", isIncluded: true),
                                    PlanFeature(icon: "bell.badge.fill", title: "Future radius alerts", subtitle: "Notify nearby users after Apple setup", isIncluded: true),
                                    PlanFeature(icon: "house.fill", title: "Unlimited rooms", subtitle: "No room limit", isIncluded: true),
                                    PlanFeature(icon: "photo.fill", title: "Unlimited photos", subtitle: "No photo limit", isIncluded: true),
                                    PlanFeature(icon: "crown.fill", title: "Everything in Semi-Pro", subtitle: "Lost posts and contact details included", isIncluded: true)
                                ]
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "E25718"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    footer
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
            }
        }
        .task { await loadOfferings() }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color("AppSurface2"))
                        .frame(width: 38, height: 38)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("AppText"))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Plans")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color("AppText"))

            Spacer()

            Button("Restore") {
                Task { await restore() }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(hex: "AA9DFF"))
            .disabled(isPurchasing)
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(hex: "1E1A3A"))
                    .frame(width: 72, height: 72)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "AA9DFF"))
            }

            VStack(spacing: 6) {
                Text("Choose your PetHub plan")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(Color("AppText"))
                    .multilineTextAlignment(.center)

                Text("Free is for helping the community. Semi-Pro unlocks lost posting. Pro unlocks active recovery tools.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("AppSubtext"))
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
                    .fill(Color(hex: "AA9DFF").opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "AA9DFF"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Current plan")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppSubtext"))
                Text(currentPlanName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
            }

            Spacer()

            Text(subscriptionManager.tier == .free ? "Upgrade anytime" : "Active")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(subscriptionManager.tier == .free ? Color(hex: "AA9DFF") : Color(hex: "5DCAA5"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (subscriptionManager.tier == .free ? Color(hex: "AA9DFF") : Color(hex: "5DCAA5")).opacity(0.12),
                    in: Capsule()
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("AppDivider"), lineWidth: 0.5)
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
        .background(Color("AppSurface2"), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("AppDivider"), lineWidth: 0.5)
        )
    }

    // MARK: - Cards

    private var freePlanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Free")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color("AppText"))
                    Text("Community access")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppSubtext"))
                }
                Spacer()
                Text("$0")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color("AppText"))
            }

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(feature: PlanFeature(icon: "eye.fill", title: "View Lost & Found", subtitle: "Browse community reports", isIncluded: true), accentColor: Color("AppSubtext"))
                FeatureRow(feature: PlanFeature(icon: "checkmark.circle.fill", title: "Post found pets", subtitle: "Help owners find missing pets", isIncluded: true), accentColor: Color("AppSubtext"))
                FeatureRow(feature: PlanFeature(icon: "xmark.circle.fill", title: "Post lost pets", subtitle: "Upgrade to Semi-Pro", isIncluded: false), accentColor: Color("AppSubtext"))
                FeatureRow(feature: PlanFeature(icon: "xmark.circle.fill", title: "Possible Matches", subtitle: "Upgrade to Pro", isIncluded: false), accentColor: Color("AppSubtext"))
            }

            currentPlanButton(for: .free)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(subscriptionManager.tier == .free ? Color(hex: "AA9DFF") : Color("AppDivider"), lineWidth: subscriptionManager.tier == .free ? 1.2 : 0.5)
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
        let isProCard = tier == .pro
        let price = isYearly ? yearlyPrice : monthlyPrice

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color("AppText"))

                        Text(isCurrent ? "Current" : badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isCurrent ? Color(hex: "5DCAA5") : accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background((isCurrent ? Color(hex: "5DCAA5") : accentColor).opacity(0.13), in: Capsule())
                    }

                    Text(isProCard ? "Active recovery tools for lost pets" : "Lost posting and contact access")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppSubtext"))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(Color("AppText"))
                    Text(isYearly ? "per year" : "per month")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppSubtext"))
                    if isYearly {
                        Text(yearlySaving)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "5DCAA5"))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(features) { feature in
                    FeatureRow(feature: feature, accentColor: accentColor)
                }
            }

            Button {
                guard !isCurrent else { return }
                Task {
                    let id = isYearly ? packageYearlyId : packageMonthlyId
                    if let package = currentOffering?.package(identifier: id) {
                        await purchase(package)
                    } else {
                        errorMessage = "Plan is not available yet. Check RevenueCat package id: \(id)"
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    if isPurchasing && !isCurrent {
                        ProgressView()
                            .tint(isProCard ? Color(hex: "1A1050") : .white)
                    } else {
                        Text(isCurrent ? "Current Plan" : buttonTitle(for: tier))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Spacer()
                }
                .foregroundStyle(isCurrent ? Color("AppSubtext") : (isProCard ? Color(hex: "1A1050") : .white))
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isCurrent ? Color("AppDivider").opacity(0.5) : accentColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(isCurrent || isPurchasing)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(isProCard ? Color(hex: "0F0D1E") : Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(isCurrent || isProCard ? accentColor.opacity(0.65) : Color("AppDivider"), lineWidth: isCurrent || isProCard ? 1.2 : 0.5)
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
        .foregroundStyle(Color("AppSubtext"))
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("AppDivider").opacity(0.45))
        )
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
                .foregroundStyle(Color("AppSubtext"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button("Maybe later") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("AppSubtext"))
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
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load plans. Please try again."
                isLoading = false
            }
        }
    }

    private func purchase(_ package: Package) async {
        await MainActor.run {
            isPurchasing = true
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

        await MainActor.run { isPurchasing = false }
    }

    private func restore() async {
        await MainActor.run {
            isPurchasing = true
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

        await MainActor.run { isPurchasing = false }
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
                    .foregroundStyle(isSelected ? Color("AppText") : Color("AppSubtext"))

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "5DCAA5"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "5DCAA5").opacity(0.12), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color("AppBackground") : Color.clear,
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
                .foregroundStyle(feature.isIncluded ? accentColor : Color("AppSubtext").opacity(0.55))
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(feature.isIncluded ? Color("AppText") : Color("AppSubtext"))

                Text(feature.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color("AppSubtext"))
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
