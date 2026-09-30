import SwiftUI

struct StaffCodeEntryView: View {
    @Bindable var session: SessionStore
    var onAuthenticated: () -> Void

    @State private var code = ""
    @State private var error: String?
    @FocusState private var codeFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                Text(AppCopy.staffCodePrompt)
                    .font(.title2.bold())
                    .foregroundStyle(DSColor.ink)
                    .multilineTextAlignment(.center)

                NumericCodeField(text: $code)
                    .focused($codeFocused)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(DSColor.accent)
                }
            }
            .padding(DSSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DSColor.bg)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                PrimaryButton(title: AppCopy.staffContinue, enabled: StaffCodePolicy.isValid(code)) {
                    codeFocused = false
                    if session.signIn(empID: code) {
                        onAuthenticated()
                    } else {
                        error = "Enter a \(StaffCodePolicy.minLength)–\(StaffCodePolicy.maxLength) digit code"
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { codeFocused = false }
            }
        }
        .onAppear { codeFocused = true }
    }
}
