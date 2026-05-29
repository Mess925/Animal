//
//  WelcomeView.swift
//  personal
//
//  Created by Han Min Thant on 23/5/26.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Base background
                Color(hex: "0D0D0E").ignoresSafeArea()
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {

                    Spacer()
                    VStack(spacing: 10) {
                        AppNavButton(
                            "Sign In",
                            style: .primary,
                            destination: SignInView()
                        )
                        AppNavButton(
                            "Create an Account",
                            style: .primary,
                            destination: SignUpView()
                        )
                    }
                    .padding(.bottom, 28)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    WelcomeView()
}
