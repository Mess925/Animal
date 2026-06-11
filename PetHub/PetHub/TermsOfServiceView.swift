//
//  TermsOfServiceView.swift
//  PetHub
//
//  Created by Han Min Thant on 11/6/26.
//

import Foundation
import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Terms of Service")
                        .font(.title.bold())

                    Text(
                        """
                        Welcome to PetHub.

                        By using PetHub, you agree to:

                        • Provide accurate information.
                        • Use PetHub lawfully and respectfully.
                        • Not post misleading lost or found pet reports.
                        • Not harass, abuse, or impersonate others.
                        • Be responsible for content you upload.

                        Subscriptions are managed through Apple and may be cancelled through your Apple account settings.

                        PetHub provides tools to help connect pet owners and community members, but cannot guarantee successful pet recovery.

                        Accounts may be deleted at any time through the Delete Account feature.

                        These terms may be updated from time to time.
                        """
                    )
                }
                .padding()
            }
            .navigationTitle("Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
