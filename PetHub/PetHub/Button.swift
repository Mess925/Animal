//
//  AppButton.swift
//  personal
//
//  Created by Han Min Thant on 25/5/26.
//

import SwiftUI

// MARK: - Button Style Enum

enum AppButtonStyle {
    case primary    // Gold gradient — main CTA
    case secondary  // Glass — Apple, Email, etc.
}

// MARK: - Reusable App Button (Action)

struct AppButton: View {
    let title: String
    let style: AppButtonStyle
    let icon: String?
    let action: () -> Void

    init(
        _ title: String,
        style: AppButtonStyle = .primary,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundView)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: [Color(hex: "AA9DFF"), Color(hex: "8B7EE0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color("AppBorder"), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        case .secondary:
            Color("AppDivider").opacity(0.6)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return Color("AppBackground")
        case .secondary: return Color("AppText").opacity(0.75)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:   return Color.clear
        case .secondary: return Color("AppBorder")
        }
    }
}

// MARK: - Reusable Navigation Button (Push to View)

struct AppNavButton<Destination: View>: View {
    let title: String
    let style: AppButtonStyle
    let icon: String?
    let destination: Destination

    init(
        _ title: String,
        style: AppButtonStyle = .secondary,
        icon: String? = nil,
        destination: Destination
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundView)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: [Color(hex: "AA9DFF"), Color(hex: "8B7EE0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color("AppBorder"), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        case .secondary:
            Color("AppDivider").opacity(0.6)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return Color("AppBackground")
        case .secondary: return Color("AppText").opacity(0.75)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:   return Color.clear
        case .secondary: return Color("AppBorder")
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 12) {

                // Primary action button
                AppButton("Sign In", style: .primary, icon: "arrow.right") {
                    print("Signing in...")
                }

                // Secondary action button
                AppButton("Sign In with Apple", style: .secondary, icon: "apple.logo") {
                    print("Apple sign in...")
                }

                // Navigation button — replace Text("Destination") with your real view
                AppNavButton(
                    "Sign In with Email",
                    style: .secondary,
                    icon: "envelope",
                    destination: Text("Email Sign In View")
                )
            }
            .padding(.horizontal, 24)
        }
    }
}
