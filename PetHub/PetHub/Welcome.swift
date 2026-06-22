//
//  WelcomeView.swift
//  PetHub
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            PHPage {
                VStack(spacing: 0) {
                    Spacer(minLength: 34)

                    hero
                        .padding(.bottom, 30)

                    VStack(spacing: 12) {
                        Text("PetHub")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(PHTheme.subtext)

                        Text("Everything about your pet, in one place")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(PHTheme.text)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-1)

                        Text("Create rooms, save memories, invite family, and help lost pets get home faster.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PHTheme.subtext)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        NavigationLink(destination: SignInView()) {
                            HStack(spacing: 10) {
                                Text("Sign In")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(PHTheme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(PHTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: SignUpView()) {
                            Text("Create an Account")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(PHTheme.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(PHTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PHTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, PHTheme.pagePadding)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(PHTheme.accent2.opacity(0.13))
                .frame(width: 220, height: 220)
                .blur(radius: 2)

            miniCard("🐶", "Rooms", color: "FFE1CC", rotation: -9, x: -96, y: 8)
            miniCard("📸", "Photos", color: "DCE7FF", rotation: 8, x: 96, y: -18)
            miniCard("🏡", "Home", color: "E2F8E8", rotation: -4, x: 0, y: 96)

            VStack(spacing: 8) {
                Text("🐾")
                    .font(.system(size: 78))
                Text("PetHub")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
            }
            .frame(width: 178, height: 178)
            .background(PHTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 42).stroke(PHTheme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 24, x: 0, y: 14)
        }
        .frame(height: 330)
    }

    private func miniCard(_ emoji: String, _ label: String, color: String, rotation: Double, x: CGFloat, y: CGFloat) -> some View {
        VStack(spacing: 7) {
            Text(emoji).font(.system(size: 27))
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.black)
        }
        .frame(width: 86, height: 82)
        .background(Color(hex: color))
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .rotationEffect(.degrees(rotation))
        .offset(x: x, y: y)
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 8)
    }
}

#Preview { WelcomeView() }
