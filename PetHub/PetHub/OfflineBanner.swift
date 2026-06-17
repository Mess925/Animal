//
//  OfflineBanner.swift
//  PetHub
//
//  Created by Han Min Thant on 17/6/26.
//

import Foundation
import SwiftUI

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))

            Text("No internet connection")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(PHTheme.danger)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        )
        .padding(.top, 8)
    }
}
