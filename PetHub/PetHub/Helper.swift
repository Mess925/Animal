import SwiftUI

struct AuthenticationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "AA9DFF").opacity(0.7))

            HStack(spacing: 10) {
                Image(systemName: isSecure ? "lock" : "envelope")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "AA9DFF").opacity(0.5))
                    .frame(width: 16)

                Group {
                    if isSecure {
                        SecureField(
                            title,
                            text: $text,
                            prompt: Text(placeholder)
                                .foregroundStyle(Color.white.opacity(0.2))
                        )
                    } else {
                        TextField(
                            title,
                            text: $text,
                            prompt: Text(placeholder)
                                .foregroundStyle(Color.white.opacity(0.2))
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(isFocused ? Color(hex: "F0EDE6") : Color(hex: "F0EDE6").opacity(0.6))
            }
            .focused($isFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Color(hex: "AA9DFF").opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// Divider

struct OrDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
            Text("OR")
                .font(.system(size: 10, weight: .regular))
                .tracking(0.5)
                .foregroundStyle(Color.white.opacity(0.4))
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
        }
    }
}

