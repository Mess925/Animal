//
//  SignUpView.swift
//  PetHub
//
//  Created by Han Min Thant on 29/5/26.
//

import SwiftUI

struct SignUpView: View {
    var body: some View {
        ZStack {
            Color(hex: "0D0D0E").ignoresSafeArea()
            Text("Sign Up")
                .foregroundStyle(Color(hex: "F0EDE6"))
        }
        .preferredColorScheme(.dark)
    }
}

#Preview{
    SignUpView()
}
