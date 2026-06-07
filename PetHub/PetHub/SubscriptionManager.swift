//
//  SubscriptionManager.swift
//  PetHub
//
//  Created by Han Min Thant on 7/6/26.
//

import Foundation
import SwiftUI
import Combine

class SubscriptionManager: ObservableObject {
    @Published var tier: String = "free"

    var isFree: Bool { tier == "free" }
    var isSemiPro: Bool { tier == "semi_pro" }
    var isPro: Bool { tier == "pro" }

    var maxRooms: Int {
        switch tier {
        case "semi_pro": return 5
        case "pro": return Int.max
        default: return 3
        }
    }

    var maxPhotos: Int {
        switch tier {
        case "free": return 100
        default: return Int.max
        }
    }

    var canAccessLostFound: Bool { isPro }

    func update(from profile: UserProfile) {
        tier = profile.subscriptionTier ?? "free"
    }
}
