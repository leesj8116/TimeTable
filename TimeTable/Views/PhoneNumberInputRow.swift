import SwiftUI
import UIKit

struct PhoneNumberInputRow: View {
    @Binding var phoneNumber: String

    @State private var middle = ""
    @State private var last = ""
    @State private var focus = PhoneFocusCoordinator()

    var body: some View {
        HStack(spacing: 4) {
            Text("010")

            Text("-").foregroundStyle(.secondary)

            BackspaceDetectingTextField(
                text: $middle,
                placeholder: "0000",
                maxLength: 4,
                onRegister: { focus.middleField = $0 },
                onBackspaceWhenEmpty: {},
                onFilled: { focus.focusLast() }
            )
            .frame(maxWidth: .infinity)

            Text("-").foregroundStyle(.secondary)

            BackspaceDetectingTextField(
                text: $last,
                placeholder: "0000",
                maxLength: 4,
                onRegister: { focus.lastField = $0 },
                onBackspaceWhenEmpty: { focus.focusMiddle() },
                onFilled: { focus.dismiss() }
            )
            .frame(maxWidth: .infinity)
        }
        .onTapGesture { focus.focusMiddle() }
        .onAppear { parsePhoneNumber() }
        .onChange(of: middle) { _ in syncPhoneNumber() }
        .onChange(of: last) { _ in syncPhoneNumber() }
    }

    private func parsePhoneNumber() {
        let digits = String(phoneNumber.filter { $0.isNumber })
        guard digits.count > 3 else { return }
        let rest = digits.dropFirst(3)
        middle = String(rest.prefix(4))
        last = String(rest.dropFirst(4).prefix(4))
    }

    private func syncPhoneNumber() {
        phoneNumber = (middle.isEmpty && last.isEmpty) ? "" : "010-\(middle)-\(last)"
    }
}

private class PhoneFocusCoordinator {
    weak var middleField: UITextField?
    weak var lastField: UITextField?

    func focusMiddle() { middleField?.becomeFirstResponder() }
    func focusLast() { lastField?.becomeFirstResponder() }
    func dismiss() {
        middleField?.resignFirstResponder()
        lastField?.resignFirstResponder()
    }
}
