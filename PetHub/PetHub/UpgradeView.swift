//
//  UpgradeView.swift
//  PetHub
//
//  Created by Han Min Thant on 7/6/26.
//

import Foundation
import SwiftUI

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "star.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color(hex: "AA9DFF"))

                Text("Upgrade PetHub")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color("AppText"))

                VStack(spacing: 16) {
                    UpgradeTierCard(
                        name: "Semi-Pro",
                        price: "$4.99/month",
                        features: ["5 rooms", "Unlimited photos"],
                        accentHex: "7EC8C8"
                    )
                    UpgradeTierCard(
                        name: "Pro",
                        price: "$9.99/month",
                        features: ["Unlimited rooms", "Unlimited photos", "Lost & Found"],
                        accentHex: "AA9DFF"
                    )
                }
                .padding(.horizontal, 20)

                Button { dismiss() } label: {
                    Text("Maybe later")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppSubtext"))
                }
            }
            .padding(.top, 40)
        }
    }
}

struct UpgradeTierCard: View {
    let name: String
    let price: String
    let features: [String]
    let accentHex: String

    var accent: Color { Color(hex: accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
                Text(price)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppText"))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)
                            .font(.system(size: 14))
                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundStyle(Color("AppText"))
                    }
                }
            }

            Button {} label: {
                Text("Subscribe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppAccentText"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("AppSurface2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
