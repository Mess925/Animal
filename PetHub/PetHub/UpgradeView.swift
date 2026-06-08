//
//  UpgradeView.swift
//  PetHub
//
//  Created by Han Min Thant on 7/6/26.
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

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // MARK: Hero
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(hex: "1E1A3A"))
                                .frame(width: 64, height: 64)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color(hex: "AA9DFF"))
                        }
                        VStack(spacing: 4) {
                            HStack(spacing: 0) {
                                Text("Unlock ")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Color("AppText"))
                                Text("PetHub")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Color(hex: "AA9DFF"))
                            }
                            Text("More rooms. More memories. More impact.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color("AppSubtext"))
                        }
                    }
                    .padding(.top, 36)

                    // MARK: Billing Toggle
                    HStack(spacing: 0) {
                        BillingToggleButton(title: "Monthly", isSelected: !isYearly) {
                            withAnimation(.easeInOut(duration: 0.2)) { isYearly = false }
                        }
                        BillingToggleButton(title: "Yearly", badge: "−33%", isSelected: isYearly) {
                            withAnimation(.easeInOut(duration: 0.2)) { isYearly = true }
                        }
                    }
                    .background(Color(hex: "161618"), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)

                    // MARK: Tier Cards
                    if isLoading {
                        ProgressView()
                            .tint(Color(hex: "AA9DFF"))
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 12) {
                            TierCard(
                                name: "Semi-Pro",
                                badgeText: "Semi-Pro",
                                badgeColor: Color(hex: "5DCAA5"),
                                badgeBg: Color(hex: "0D2820"),
                                accentColor: Color(hex: "5DCAA5"),
                                monthlyPrice: "$1.99",
                                yearlyPrice: "$15.99",
                                yearlySaving: "Save $7.89/yr",
                                buttonLabel: isPurchasing ? "Processing..." : "Get Semi-Pro",
                                buttonBg: Color(hex: "1D9E75"),
                                buttonFg: .white,
                                isFeatured: false,
                                isYearly: isYearly,
                                features: [
                                    ("house.fill", "5 pet rooms", true),
                                    ("photo.fill", "100 photos per room", true),
                                    ("mappin.circle.fill", "Stray Watch", true),
                                    ("eye.fill", "View Lost & Found", true),
                                    ("checkmark.circle.fill", "Post found pets", true),
                                    ("exclamationmark.circle.fill", "Post lost pets", true),
                                ]
                            ) {
                                Task {
                                    let id = isYearly ? "$rc_annual" : "$rc_monthly"
                                    if let package = currentOffering?.package(identifier: id) {
                                        await purchase(package)
                                    }
                                }
                            }

                            TierCard(
                                name: "Pro",
                                badgeText: "Most Popular",
                                badgeColor: Color(hex: "1A1050"),
                                badgeBg: Color(hex: "AA9DFF"),
                                accentColor: Color(hex: "AA9DFF"),
                                monthlyPrice: "$3.99",
                                yearlyPrice: "$35.99",
                                yearlySaving: "Save $11.89/yr",
                                buttonLabel: isPurchasing ? "Processing..." : "Get Pro",
                                buttonBg: Color(hex: "AA9DFF"),
                                buttonFg: Color(hex: "1A1050"),
                                isFeatured: true,
                                isYearly: isYearly,
                                features: [
                                    ("house.fill", "Unlimited rooms", true),
                                    ("photo.fill", "Unlimited photos", true),
                                    ("mappin.circle.fill", "Stray Watch", true),
                                    ("eye.fill", "View Lost & Found", true),
                                    ("checkmark.circle.fill", "Post found pets", true),
                                    ("exclamationmark.circle.fill", "Post lost pets", true),
                                ]
                            ) {
                                Task {
                                    let id = isYearly ? "pethub_pro_yearly" : "pethub_pro_monthly"
                                    if let package = currentOffering?.package(identifier: id) {
                                        await purchase(package)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // MARK: Free Tier
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Free plan includes")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "444444"))
                            Spacer()
                            Text("$0 forever")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "333333"))
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            FreeFeat(icon: "checkmark", text: "3 rooms", included: true)
                            FreeFeat(icon: "checkmark", text: "50 photos/room", included: true)
                            FreeFeat(icon: "checkmark", text: "View Lost & Found", included: true)
                            FreeFeat(icon: "checkmark", text: "Post found pets", included: true)
                            FreeFeat(icon: "xmark", text: "Post lost pets", included: false)
                            FreeFeat(icon: "checkmark", text: "Stray Watch", included: true)
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "0D0D10"), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "161618"), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // MARK: Footer
                    VStack(spacing: 12) {
                        Button("Restore purchases") {
                            Task { await restore() }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "3A3A44"))

                        Button("Maybe later") { dismiss() }
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppSubtext"))
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .task { await loadOfferings() }
    }

    // MARK: - Functions
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
        isPurchasing = true
        errorMessage = nil
        do {
            try await subscriptionManager.purchase(package)
            dismiss()
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await subscriptionManager.restorePurchases()
            dismiss()
        } catch {
            errorMessage = "Restore failed. Please try again."
        }
        isPurchasing = false
    }
}

// MARK: - Billing Toggle Button
struct BillingToggleButton: View {
    let title: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color("AppText") : Color("AppSubtext"))
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "5DCAA5"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "1D3828"), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                isSelected ? Color(hex: "252235") : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tier Card
struct TierCard: View {
    let name: String
    let badgeText: String
    let badgeColor: Color
    let badgeBg: Color
    let accentColor: Color
    let monthlyPrice: String
    let yearlyPrice: String
    let yearlySaving: String
    let buttonLabel: String
    let buttonBg: Color
    let buttonFg: Color
    let isFeatured: Bool
    let isYearly: Bool
    let features: [(String, String, Bool)]
    let onSubscribe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(badgeBg, in: Capsule())
                    Text(name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color("AppText"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(alignment: .top, spacing: 1) {
                        Text("$")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("AppText"))
                            .padding(.top, 4)
                        Text(isYearly ? String(yearlyPrice.dropFirst()) : String(monthlyPrice.dropFirst()))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color("AppText"))
                    }
                    Text(isYearly ? "per year" : "per month")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AppSubtext"))
                    if isYearly {
                        Text(yearlySaving)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "5DCAA5"))
                    }
                }
            }
            .padding(.bottom, 16)

            Divider()
                .background(isFeatured ? Color(hex: "2A2248") : Color(hex: "1E1E22"))
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(features, id: \.1) { icon, label, _ in
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(accentColor)
                            .frame(width: 18)
                        Text(label)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "B0AABF"))
                    }
                }
            }
            .padding(.bottom, 18)

            Button(buttonLabel) { onSubscribe() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(buttonFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(buttonBg, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(20)
        .background(
            isFeatured ? Color(hex: "0F0D1E") : Color(hex: "111114"),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isFeatured ? Color(hex: "3A2E6A") : Color(hex: "1E1E22"),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Free Feature Row
struct FreeFeat: View {
    let icon: String
    let text: String
    let included: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(included ? Color(hex: "444444") : Color(hex: "2E2E36"))
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(included ? Color(hex: "444444") : Color(hex: "2E2E36"))
        }
    }
}

#Preview {
    UpgradeView()
        .environmentObject(SubscriptionManager())
}
