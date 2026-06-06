//
//  ThemeManager.swift
//  PetHub
//
//  Created by Han Min Thant on 4/6/26.
//

import Foundation
import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? "System"
        self.theme = AppTheme(rawValue: saved) ?? .system
    }
}
