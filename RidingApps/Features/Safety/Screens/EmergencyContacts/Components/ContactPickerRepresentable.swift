import Contacts
import ContactsUI
import SwiftUI

/// Wraps the system contact picker, showing phone numbers only. It runs in a separate process, so
/// no Contacts permission prompt is needed. `onPick` gets the contact the user tapped.
struct ContactPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    /// Receives the picker callback and forwards the chosen contact to `onPick`.
    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onPick: (CNContact) -> Void

        init(onPick: @escaping (CNContact) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(contact)
        }
    }
}

#if DEBUG

#Preview("Contact picker") {
    ContactPickerRepresentable { _ in }
}

#endif
