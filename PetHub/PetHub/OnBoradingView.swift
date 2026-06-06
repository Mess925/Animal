//
//  OnBoradingView.swift
//  PetHub
//
//  Created by Han Min Thant on 31/5/26.
//

import Foundation
import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let emoji: String
    let floatingEmojis: [(emoji: String, x: CGFloat, y: CGFloat)]
    let accentHex: String
    let title: String
    let body: String
    let pills: [(label: String, hex: String)]
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        emoji: "🐾",
        floatingEmojis: [
            (emoji: "🐶", x: 1,   y: 1),
            (emoji: "🐱", x: -1,  y: -1),
            (emoji: "🐦", x: 1,   y: -0.6),
        ],
        accentHex: "AA9DFF",
        title: "A home for every animal in your life",
        body: "Create rooms for your pets, follow strays in your neighbourhood, and share moments with the people who care.",
        pills: [
            ("🐾  My Pet",      "AA9DFF"),
            ("🏘️  Stray Watch", "7EC8C8"),
            ("📍  Lost & Found","E25718"),
        ]
    ),
    OnboardingPage(
        emoji: "🏘️",
        floatingEmojis: [
            (emoji: "📸", x: 1,  y: 1),
            (emoji: "💬", x: -1, y: -1),
        ],
        accentHex: "7EC8C8",
        title: "Invite people, share the moments",
        body: "Each room is a shared space. Invite family, friends, or neighbours to post photos, updates, and memories together.",
        pills: [
            ("📸  Photos", "F4A84A"),
            ("💬  Chat",   "AA9DFF"),
            ("🤝  People", "7EC8C8"),
        ]
    ),
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showWelcome = false

    private var accent: Color { Color(hex: pages[currentPage].accentHex) }

    var body: some View {
        if showWelcome {
            WelcomeView()
        } else {
            ZStack(alignment: .bottom) {
                Color("AppBackground").ignoresSafeArea()

                // Slides
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        OnboardingSlide(page: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)

                // Bottom controls
                VStack(spacing: 0) {
                    // Dots
                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? accent : Color("AppBorder").opacity(1.8))
                                .frame(width: i == currentPage ? 20 : 6, height: 6)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .padding(.bottom, 22)

                    // CTA
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                finishOnboarding()
                            }
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ctaTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)

                    // Skip
                    Button {
                        finishOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppPlaceholder"))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .padding(.bottom, 44)
                    .opacity(currentPage < pages.count - 1 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
                .background(
                    LinearGradient(
                        colors: [Color("AppBackground").opacity(0), Color("AppBackground")],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.25)
                    )
                    .ignoresSafeArea()
                )
            }
        }
    }

    private var ctaTextColor: Color {
        switch pages[currentPage].accentHex {
        case "AA9DFF": return Color("AppAccentText")
        case "7EC8C8": return Color("AppAccentText")
        default:       return .white
        }
    }

    private func finishOnboarding() {
        hasSeenOnboarding = true
        withAnimation(.easeInOut(duration: 0.35)) {
            showWelcome = true
        }
    }
}

// MARK: - Onboarding Slide

private struct OnboardingSlide: View {
    let page: OnboardingPage
    private var accent: Color { Color(hex: page.accentHex) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                // Glow bg
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 200, height: 200)

                RoundedRectangle(cornerRadius: 40)
                    .fill(accent.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(accent.opacity(0.2), lineWidth: 1)
                    )

                Text(page.emoji)
                    .font(.system(size: 72))

                // Floating badges
                ForEach(page.floatingEmojis.indices, id: \.self) { i in
                    let f = page.floatingEmojis[i]
                    Text(f.emoji)
                        .font(.system(size: 26))
                        .frame(width: 46, height: 46)
                        .background(
                            Circle()
                                .fill(Color("AppSurface"))
                                .overlay(Circle().stroke(Color("AppBorder"), lineWidth: 0.5))
                        )
                        .offset(
                            x: f.x * 86,
                            y: f.y * 86
                        )
                }
            }
            .frame(height: 240)
            .padding(.bottom, 44)

            // Text
            Text(page.title)
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("AppText"))
                .lineSpacing(2)
                .padding(.horizontal, 32)
                .padding(.bottom, 14)

            Text(page.body)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("AppSubtext"))
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .padding(.bottom, 28)

            // Pills
            HStack(spacing: 8) {
                ForEach(page.pills, id: \.label) { pill in
                    Text(pill.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: pill.hex))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(hex: pill.hex).opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: pill.hex).opacity(0.3), lineWidth: 0.5)
                                )
                        )
                }
            }

            Spacer()
            // Bottom padding so dots/CTA don't overlap
            Spacer().frame(height: 160)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
