//
//  AppThemeKit.swift
//  PetHub
//
//  Modern adaptive design system for PetHub.
//  Works in both Light and Dark mode without depending on asset colors.
//

import SwiftUI
import UIKit

// MARK: - PetHub Modern Design System

enum PHTheme {
    // PetHub 2026: soft monochrome, frosted surfaces, small animal-green accent.
    // Inspired by the reference shots: clean cards, deep dark mode, high whitespace.
    static let accent = Color(light: "111111", dark: "F7F7F7")
    static let accent2 = Color(light: "FF8A3D", dark: "FFB477")
    static let accent3 = Color(light: "5F7CFF", dark: "9AAEFF")
    static let danger = Color(light: "E5484D", dark: "FF7373")
    static let success = Color(light: "21A67A", dark: "65D6B8")
    static let warning = Color(light: "D99A26", dark: "F2C46D")

    static let background = Color(light: "FFFFFF", dark: "050506")
    static let background2 = Color(light: "F7F7F5", dark: "0C0C0E")
    static let surface = Color(light: "FFFFFF", dark: "151518")
    static let surface2 = Color(light: "F1F1EF", dark: "232326")
    static let elevated = Color(light: "FFFFFF", dark: "1D1D21")
    static let text = Color(light: "111214", dark: "F8F8F8")
    static let subtext = Color(light: "777A80", dark: "A3A3AA")
    static let muted = Color(light: "A0A5AA", dark: "777A82")
    static let border = Color(light: "E8E8E4", dark: "2B2B30")
    static let divider = Color(light: "ECEDE9", dark: "28282C")
    static let placeholder = Color(light: "A8ADB3", dark: "777D86")
    static let textOnAccent = Color(light: "FFFFFF", dark: "050506")

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let fieldRadius: CGFloat = 18

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var warmGradient: LinearGradient {
        LinearGradient(colors: [accent3, accent3.opacity(0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var coolGradient: LinearGradient {
        LinearGradient(colors: [accent2, accent.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - App Background

struct PHBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PHTheme.background, PHTheme.background2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(PHTheme.accent2.opacity(scheme == .dark ? 0.10 : 0.06))
                .frame(width: 330, height: 330)
                .blur(radius: 95)
                .offset(x: -180, y: -310)
                .ignoresSafeArea()

            Circle()
                .fill(PHTheme.accent3.opacity(scheme == .dark ? 0.06 : 0.045))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 180, y: -180)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Page Container

struct PHPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack { PHBackground(); content }
            .preferredColorScheme(nil)
    }
}

// MARK: - Header

struct PHHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var trailing: AnyView? = nil

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PHTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PHTheme.accent.opacity(0.10))
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
                    .lineSpacing(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(PHTheme.subtext)
                        .lineSpacing(3)
                }
            }
            Spacer(minLength: 12)
            if let trailing { trailing }
        }
    }
}

// MARK: - Card

struct PHCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = PHTheme.cardRadius
    let content: Content

    init(padding: CGFloat = 18, radius: CGFloat = PHTheme.cardRadius, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(PHTheme.surface)
                    .shadow(color: Color.black.opacity(0.035), radius: 22, x: 0, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(PHTheme.border.opacity(0.9), lineWidth: 0.8)
            )
    }
}

struct PHGradientCard<Content: View>: View {
    var padding: CGFloat = 20
    var gradient: LinearGradient = PHTheme.brandGradient
    let content: Content

    init(padding: CGFloat = 20, gradient: LinearGradient = PHTheme.brandGradient, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.gradient = gradient
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(PHTheme.elevated)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(PHTheme.accent.opacity(0.55))
                    .frame(width: 54, height: 4)
                    .padding(.top, 10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(PHTheme.border.opacity(0.9), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 22, x: 0, y: 12)
    }
}

// MARK: - Buttons

enum PHButtonKind { case primary, secondary, danger, warm }

struct PHButton: View {
    let title: String
    var icon: String? = nil
    var kind: PHButtonKind = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    init(_ title: String, icon: String? = nil, kind: PHButtonKind = .primary, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.kind = kind; self.isLoading = isLoading; self.isDisabled = isDisabled; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(foreground) }
                else {
                    if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                    Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(border, lineWidth: 0.8))
            .shadow(color: shadow, radius: kind == .secondary ? 0 : 10, x: 0, y: 5)
            .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }

    private var foreground: Color { kind == .secondary ? PHTheme.text : (kind == .primary ? PHTheme.textOnAccent : .white) }
    @ViewBuilder private var background: some View {
        switch kind {
        case .primary: LinearGradient(colors: [PHTheme.accent, PHTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warm: LinearGradient(colors: [PHTheme.accent3, PHTheme.accent3], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .secondary: PHTheme.surface.opacity(0.92)
        case .danger: PHTheme.danger
        }
    }
    private var border: Color { kind == .secondary ? PHTheme.border : .clear }
    private var shadow: Color {
        switch kind { case .primary: return PHTheme.accent.opacity(0.14); case .warm: return PHTheme.accent3.opacity(0.12); case .danger: return PHTheme.danger.opacity(0.18); case .secondary: return .clear }
    }
}

// MARK: - Search Field

struct PHSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PHTheme.accent)

            TextField(placeholder, text: $text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PHTheme.text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(PHTheme.placeholder)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(PHTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(PHTheme.border, lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Text Field

struct PHTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(isFocused ? PHTheme.accent : PHTheme.subtext)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isFocused ? PHTheme.accent : PHTheme.muted)
                    .frame(width: 20)

                Group {
                    if isSecure { SecureField(label, text: $text, prompt: Text(placeholder).foregroundStyle(PHTheme.placeholder)) }
                    else { TextField(label, text: $text, prompt: Text(placeholder).foregroundStyle(PHTheme.placeholder)) }
                }
                .font(.system(size: 15, weight: .medium))
                .keyboardType(keyboardType)
                .foregroundStyle(PHTheme.text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            }
            .focused($isFocused)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(PHTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: PHTheme.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PHTheme.fieldRadius, style: .continuous).stroke(isFocused ? PHTheme.accent.opacity(0.8) : PHTheme.border, lineWidth: 0.9))
            .shadow(color: isFocused ? PHTheme.accent.opacity(0.07) : Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.18), value: isFocused)
        }
    }
}

// MARK: - Empty State / Helpers

struct PHEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        PHCard(padding: 24) {
            VStack(spacing: 13) {
                PHIconBubble(systemName: icon, color: PHTheme.accent, size: 58)
                Text(title).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(PHTheme.text)
                Text(message).font(.system(size: 14)).foregroundStyle(PHTheme.subtext).multilineTextAlignment(.center).lineSpacing(3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct PHIconBubble: View {
    let systemName: String
    var color: Color = PHTheme.accent
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                ZStack {
                    Circle().fill(color.opacity(0.14))
                    Circle().fill(.white.opacity(0.08)).padding(2)
                }
            )
            .overlay(Circle().stroke(color.opacity(0.20), lineWidth: 0.8))
    }
}

struct PHGlassPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(PHTheme.surface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(PHTheme.border.opacity(0.8), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
}

struct PHBackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PHTheme.text)
                .frame(width: 42, height: 42)
                .background(PHTheme.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(PHTheme.border, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func phCardStyle(radius: CGFloat = PHTheme.cardRadius) -> some View {
        self
            .background(PHTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(PHTheme.border.opacity(0.9), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 5)
    }

    func phScreenChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PHBackground())
    }
}

extension Color {
    init(light: String, dark: String) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
