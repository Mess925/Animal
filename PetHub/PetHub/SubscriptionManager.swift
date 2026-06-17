//
//  SubscriptionManager.swift
//  PetHub
//
//  Created by Han Min Thant on 7/6/26.
//

import Foundation
import SwiftUI
import Combine
import RevenueCat
import Supabase

class SubscriptionManager: ObservableObject {
    @Published var tier: SubscriptionTier = .free
    @Published var isLoading: Bool = false

    // MARK: - Convenience
    var isFree: Bool { tier == .free }
    var isSemiPro: Bool { tier == .semiPro }
    var isPro: Bool { tier == .pro }

    var maxRooms: Int {
        switch tier {
        case .free: return 3
        case .semiPro: return 5
        case .pro: return Int.max
        }
    }

    var maxPhotosTotal: Int {
        switch tier {
        case .free: return 50
        case .semiPro: return 200
        case .pro: return Int.max
        }
    }

    var hasUnlimitedPhotos: Bool { tier == .pro }

    var canPostLostPet: Bool { tier == .semiPro || tier == .pro }
    var canPostFoundPet: Bool { true }
    var canViewLostFound: Bool { true }

    // MARK: - Init
    init() {
        fetchCustomerInfo()
        Purchases.shared.delegate = PurchasesDelegateHandler.shared
        PurchasesDelegateHandler.shared.onCustomerInfoUpdated = { [weak self] customerInfo in
            self?.updateTier(from: customerInfo)
        }
    }

    // MARK: - Subscription source of truth
    // RevenueCat is the single source of truth for subscription state.
    // profiles.subscription_tier in Supabase is written back purely for
    // server-side convenience (RLS, edge functions, analytics). It must
    // never be read back to set `tier` — RevenueCat owns that.

    // MARK: - RevenueCat
    func fetchCustomerInfo() {
        isLoading = true
        Purchases.shared.getCustomerInfo { [weak self] customerInfo, _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let customerInfo {
                    self?.updateTier(from: customerInfo)
                }
            }
        }
    }

    private func updateTier(from customerInfo: CustomerInfo) {
        let newTier: SubscriptionTier
        if customerInfo.entitlements["pro"]?.isActive == true {
            newTier = .pro
        } else if customerInfo.entitlements["semi_pro"]?.isActive == true {
            newTier = .semiPro
        } else {
            newTier = .free
        }

        DispatchQueue.main.async {
            self.tier = newTier
        }

        // Write back to Supabase so server-side logic (RLS, edge functions,
        // analytics) can use it. This is fire-and-forget — a failure here
        // does not affect the in-app subscription state.
        Task { await Self.syncTierToSupabase(newTier) }
    }

    // MARK: - Supabase write-back (fire-and-forget)
    private static func syncTierToSupabase(_ tier: SubscriptionTier) async {
        guard let userId = await supabase.auth.currentUser?.id.uuidString else { return }
        let tierString = tier.supabaseValue
        do {
            try await supabase
                .from("profiles")
                .update(["subscription_tier": tierString])
                .eq("id", value: userId)
                .execute()
        } catch {
            // Non-fatal: RevenueCat remains the source of truth client-side.
        }
    }

    // MARK: - Purchase / Restore
    func purchase(_ package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        updateTier(from: result.customerInfo)
    }

    func restorePurchases() async throws {
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateTier(from: customerInfo)
    }
}

// MARK: - Tier Enum
enum SubscriptionTier {
    case free, semiPro, pro

    var supabaseValue: String {
        switch self {
        case .free: return "free"
        case .semiPro: return "semi_pro"
        case .pro: return "pro"
        }
    }
}

// MARK: - Purchases Delegate
class PurchasesDelegateHandler: NSObject, PurchasesDelegate {
    static let shared = PurchasesDelegateHandler()
    var onCustomerInfoUpdated: ((CustomerInfo) -> Void)?

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onCustomerInfoUpdated?(customerInfo)
    }
}
