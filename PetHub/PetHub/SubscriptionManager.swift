//
//  SubscriptionManager.swift
//  PetHub
//
//  Created by Han Min Thant on 7/6/26.
//
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

    var maxPhotosPerRoom: Int {
        switch tier {
        case .free: return 50
        case .semiPro: return 100
        case .pro: return Int.max
        }
    }

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

    // MARK: - Supabase profile sync (keep existing)
    func update(from profile: UserProfile) {
        switch profile.subscriptionTier {
        case "semi_pro": tier = .semiPro
        case "pro": tier = .pro
        default: tier = .free
        }
    }

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
        DispatchQueue.main.async {
            if customerInfo.entitlements["pro"]?.isActive == true {
                self.tier = .pro
            } else if customerInfo.entitlements["semi_pro"]?.isActive == true {
                self.tier = .semiPro
            } else {
                self.tier = .free
            }
        }
    }

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
}

// MARK: - Purchases Delegate
class PurchasesDelegateHandler: NSObject, PurchasesDelegate {
    static let shared = PurchasesDelegateHandler()
    var onCustomerInfoUpdated: ((CustomerInfo) -> Void)?

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onCustomerInfoUpdated?(customerInfo)
    }
}
