//
//  Button.swift
//  PetHub
//
//  Shared app buttons. Updated to use the PetHub adaptive design system.
//

import SwiftUI

// MARK: - Button Style Enum

enum AppButtonStyle {
    case primary
    case secondary
}

// MARK: - Reusable App Button (Action)

struct AppButton: View {
    let title: String
    let style: AppButtonStyle
    let icon: String?
    let action: () -> Void

    init(_ title: String, style: AppButtonStyle = .primary, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
    }

    private var label: some View {
        HStack(spacing: 9) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .foregroundStyle(foregroundColor)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 0.7)
        )
        .shadow(color: shadowColor, radius: style == .primary ? 9 : 0, x: 0, y: 5)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LinearGradient(colors: [PHTheme.accent, PHTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .secondary:
            PHTheme.surface
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return PHTheme.text
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return .clear
        case .secondary: return PHTheme.border
        }
    }

    private var shadowColor: Color {
        style == .primary ? PHTheme.accent.opacity(0.12) : .clear
    }
}

// MARK: - Reusable Navigation Button (Push to View)

struct AppNavButton<Destination: View>: View {
    let title: String
    let style: AppButtonStyle
    let icon: String?
    let destination: Destination

    init(_ title: String, style: AppButtonStyle = .secondary, icon: String? = nil, destination: Destination) {
        self.title = title
        self.style = style
        self.icon = icon
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 9) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(style == .primary ? .white : PHTheme.text)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(style == .primary ? .clear : PHTheme.border, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LinearGradient(colors: [PHTheme.accent, PHTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .secondary:
            PHTheme.surface
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
            PHTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {

                // Primary action button
                AppButton("Sign In", style: .primary, icon: "arrow.right") {
                }

                // Secondary action button
                AppButton("Sign In with Apple", style: .secondary, icon: "apple.logo") {
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
