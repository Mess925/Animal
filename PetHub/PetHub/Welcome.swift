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
                    Spacer(minLength: 24)

                    hero
                        .padding(.bottom, 28)

                    VStack(spacing: 14) {
                        Text("One home for every pet moment.")
                            .font(.system(size: 33, weight: .bold, design: .rounded))
                            .foregroundStyle(PHTheme.text)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                        Text("Rooms, photos, care notes, chat, and lost & found alerts — redesigned to feel clean, warm, and modern.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PHTheme.subtext)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        NavigationLink(destination: SignInView()) {
                            HStack(spacing: 10) {
                                Text("Sign In")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(PHTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: PHTheme.accent.opacity(0.12), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: SignUpView()) {
                            Text("Create an Account")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(PHTheme.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(PHTheme.elevated)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PHTheme.border.opacity(0.95), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, PHTheme.pagePadding)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(PHTheme.surface)
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(-5))
                .overlay(RoundedRectangle(cornerRadius: 42).stroke(PHTheme.border, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.045), radius: 16, x: 0, y: 8)

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(PHTheme.accent.opacity(0.10))
                .frame(width: 178, height: 178)
                .overlay(RoundedRectangle(cornerRadius: 38).stroke(PHTheme.accent.opacity(0.18), lineWidth: 1))

            VStack(spacing: 8) {
                Text("🐾")
                    .font(.system(size: 72))
                Text("PetHub")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(PHTheme.text)
            }

            floatingEmoji("🐶", x: 106, y: 83, color: PHTheme.accent3)
            floatingEmoji("🐱", x: -103, y: -82, color: PHTheme.accent2)
            floatingEmoji("🐦", x: 98, y: -72, color: PHTheme.warning)
            floatingEmoji("🐰", x: -94, y: 80, color: PHTheme.accent)
        }
        .frame(height: 285)
    }

    private func floatingEmoji(_ emoji: String, x: CGFloat, y: CGFloat, color: Color) -> some View {
        Text(emoji)
            .font(.system(size: 28))
            .frame(width: 56, height: 56)
            .background(PHTheme.elevated)
            .clipShape(Circle())
            .overlay(Circle().stroke(color.opacity(0.22), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            .offset(x: x, y: y)
    }
}

#Preview { WelcomeView() }
