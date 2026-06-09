import SwiftUI
import UIKit

struct BackspaceDetectingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let maxLength: Int
    let onRegister: (UITextField) -> Void
    let onBackspaceWhenEmpty: () -> Void
    let onFilled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> InternalTextField {
        let field = InternalTextField()
        field.placeholder = placeholder
        field.keyboardType = .numberPad
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.textAlignment = .center
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.onDeleteBackwardWhenEmpty = onBackspaceWhenEmpty
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        onRegister(field)
        return field
    }

    func updateUIView(_ uiView: InternalTextField, context: Context) {
        context.coordinator.parent = self
        uiView.onDeleteBackwardWhenEmpty = onBackspaceWhenEmpty
        if uiView.text != text { uiView.text = text }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BackspaceDetectingTextField

        init(_ parent: BackspaceDetectingTextField) { self.parent = parent }

        @objc func textChanged(_ sender: UITextField) {
            let filtered = String((sender.text ?? "").filter { $0.isNumber }.prefix(parent.maxLength))
            if sender.text != filtered { sender.text = filtered }
            parent.text = filtered
            if filtered.count == parent.maxLength { parent.onFilled() }
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.isEmpty { return true }
            guard string.allSatisfy({ $0.isNumber }) else { return false }
            let newLength = (textField.text?.count ?? 0) + string.count - range.length
            return newLength <= parent.maxLength
        }
    }

    class InternalTextField: UITextField {
        var onDeleteBackwardWhenEmpty: (() -> Void)?

        override func deleteBackward() {
            if (text ?? "").isEmpty { onDeleteBackwardWhenEmpty?() }
            super.deleteBackward()
        }
    }
}
