//
//  OnboardingView.swift
//  PetHub
//

import SwiftUI

private struct OnboardingPage {
    let animal: String
    let step: String
    let title: String
    let body: String
    let accentHex: String
    let cards: [MiniPetCard]
}

private struct MiniPetCard {
    let emoji: String
    let text: String
    let color: String
    let rotation: Double
    let x: CGFloat
    let y: CGFloat
}

private let pages: [OnboardingPage] = [
    .init(
        animal: "🐶",
        step: "STEP 01",
        title: "A cozy space for every pet",
        body: "Save photos, notes, rooms, and little daily memories in one simple place.",
        accentHex: "FF8A3D",
        cards: [
            .init(emoji: "🐾", text: "Pet rooms", color: "FFE1CC", rotation: -8, x: -82, y: 12),
            .init(emoji: "📸", text: "Photos", color: "DCE7FF", rotation: 7, x: 72, y: -10),
            .init(emoji: "💬", text: "Updates", color: "E2F8E8", rotation: -4, x: 0, y: 78)
        ]
    ),
    .init(
        animal: "🐱",
        step: "STEP 02",
        title: "Share with people who care",
        body: "Invite family, friends, or neighbours so everyone stays close to your pet’s moments.",
        accentHex: "5F7CFF",
        cards: [
            .init(emoji: "👥", text: "Members", color: "DCE7FF", rotation: -7, x: -78, y: 6),
            .init(emoji: "❤️", text: "Memories", color: "FFE0EA", rotation: 9, x: 80, y: -8),
            .init(emoji: "🔔", text: "Alerts", color: "FFF0C7", rotation: -3, x: 0, y: 78)
        ]
    ),
    .init(
        animal: "🐰",
        step: "STEP 03",
        title: "Help lost pets get home",
        body: "Post lost or found pets and get possible-match alerts when someone nearby has a clue.",
        accentHex: "18A35D",
        cards: [
            .init(emoji: "📍", text: "Lost", color: "FFE1CC", rotation: -9, x: -82, y: 8),
            .init(emoji: "🔎", text: "Matches", color: "E2F8E8", rotation: 8, x: 76, y: -12),
            .init(emoji: "🏡", text: "Home", color: "DCE7FF", rotation: -3, x: 0, y: 78)
        ]
    )
]

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var currentPage = 0
    @State private var showWelcome = false

    private var page: OnboardingPage { pages[currentPage] }
    private var accent: Color { Color(hex: page.accentHex) }

    var body: some View {
        if showWelcome {
            WelcomeView()
        } else {
            ZStack {
                Color.white.ignoresSafeArea()

                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        ModernOnboardingSlide(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack {
                    Spacer()
                    bottomControls
                }
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.black : Color.black.opacity(0.14))
                        .frame(width: index == currentPage ? 22 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                }
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    } else {
                        finishOnboarding()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button {
                finishOnboarding()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .opacity(currentPage < pages.count - 1 ? 1 : 0)
        }
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [.white.opacity(0), .white, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 210)
            .ignoresSafeArea()
        )
    }

    private func finishOnboarding() {
        hasSeenOnboarding = true
        withAnimation(.easeInOut(duration: 0.25)) {
            showWelcome = true
        }
    }
}

private struct ModernOnboardingSlide: View {
    let page: OnboardingPage

    private var accent: Color { Color(hex: page.accentHex) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 70)

            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 210, height: 210)
                    .blur(radius: 2)

                ForEach(Array(page.cards.enumerated()), id: \.offset) { _, card in
                    PetFloatingCard(card: card)
                }

                Text(page.animal)
                    .font(.system(size: 104))
                    .padding(34)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 14)
            }
            .frame(height: 330)

            VStack(spacing: 14) {
                Text(page.step)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.black.opacity(0.35))

                Text(page.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-1)
                    .padding(.horizontal, 26)

                Text(page.body)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 34)
            }

            Spacer()
            Spacer().frame(height: 170)
        }
    }
}

private struct PetFloatingCard: View {
    let card: MiniPetCard

    var body: some View {
        VStack(spacing: 8) {
            Text(card.emoji)
                .font(.system(size: 26))

            Text(card.text)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.black)
        }
        .frame(width: 96, height: 94)
        .background(Color(hex: card.color))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .rotationEffect(.degrees(card.rotation))
        .offset(x: card.x, y: card.y)
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
    }
}

#Preview {
    OnboardingView()
}
