//
//  UserOnboardingView.swift
//  PetHub
//
//  Created by Han Min Thant on 4/6/26.
//

import Foundation
import Supabase
import SwiftUI

struct UserOnboardingView: View {
    @State private var step = 1
    @State private var username = ""
    @State private var bio = ""
    @State private var avatarEmoji = ""

    var body: some View {
        ZStack {
            PHTheme.background.ignoresSafeArea()

            switch step {
            case 1:
                StepUsernameView(username: $username, onNext: { step = 2 })
            case 2:
                StepProfileView(
                    bio: $bio,
                    avatarEmoji: $avatarEmoji,
                    onNext: { step = 3 }
                )
            case 3:
                StepCreateRoomView(onFinish: { step = 4 })
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut, value: step)
    }
}
