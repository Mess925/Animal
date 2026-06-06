//
//  WelcomeView.swift
//  PetHub
//
//  Created by Han Min Thant on 23/5/26.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color("AppBackground").ignoresSafeArea()

                // Slide content — same as OnboardingSlide
                VStack(spacing: 0) {
                    Spacer()

                    // Illustration
                    ZStack {
                        Circle()
                            .fill(Color(hex: "AA9DFF").opacity(0.08))
                            .frame(width: 200, height: 200)

                        RoundedRectangle(cornerRadius: 40)
                            .fill(Color(hex: "AA9DFF").opacity(0.1))
                            .frame(width: 160, height: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 40)
                                    .stroke(
                                        Color(hex: "AA9DFF").opacity(0.2),
                                        lineWidth: 1
                                    )
                            )

                        Text("🐾")
                            .font(.system(size: 72))

                        // Floating badges
                        Text("🐶")
                            .font(.system(size: 26))
                            .frame(width: 46, height: 46)
                            .background(Color("AppSurface2"))
                            .offset(x: 86, y: 86)

                        Text("🐱")
                            .font(.system(size: 26))
                            .frame(width: 46, height: 46)
                            .background(
                                Circle()
                                    .fill(Color("AppSurface"))
                                    .overlay(
                                        Circle().stroke(
                                            Color("AppBorder"),
                                            lineWidth: 0.5
                                        )
                                    )
                            )
                            .offset(x: -86, y: -86)

                        Text("🐦")
                            .font(.system(size: 26))
                            .frame(width: 46, height: 46)
                            .background(
                                Circle()
                                    .fill(Color("AppSurface"))
                                    .overlay(
                                        Circle().stroke(
                                            Color("AppBorder"),
                                            lineWidth: 0.5
                                        )
                                    )
                            )
                            .offset(x: 86, y: -52)
                    }
                    .frame(height: 240)
                    .padding(.bottom, 44)

                    // Title
                    Text("Let's get started")
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color("AppText"))
                        .lineSpacing(2)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 14)

                    // Body
                    Text(
                        "Sign in to your account or create a new one to start building rooms for the animals in your life."
                    )
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("AppSubtext"))
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)

                    Spacer()
                    Spacer().frame(height: 160)
                }

                // Bottom — same structure as onboarding CTA
                VStack(spacing: 0) {
                    NavigationLink(destination: SignInView()) {
                        Text("Sign In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("AppAccentText"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "AA9DFF"))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    NavigationLink(destination: SignUpView()) {
                        Text("Create an Account")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppSubtext"))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .padding(.bottom, 44)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color("AppBackground").opacity(0),
                            Color("AppBackground"),
                        ],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.25)
                    )
                    .ignoresSafeArea()
                )
            }
        }
    }
}

#Preview {
    WelcomeView()
}
