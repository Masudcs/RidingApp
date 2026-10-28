import Observation
import Foundation

/// Loads and edits the rider's emergency contacts (the people notified on SOS or route deviation).
/// Contacts can be typed in or imported from the system Contacts picker. After every add/remove
/// the list is re-fetched so the screen shows what the backend really has.
@MainActor
@Observable
public final class EmergencyContactsViewModel {
    /// Load state of the contact list. Add/remove failures go to `actionErrorMessage` instead, so the list stays visible.
    public private(set) var state: UIState<[EmergencyContact]> = .loading
    public var newName: String = ""
    public var newPhone: String = ""
    public var isShowingContactPicker: Bool = false
    public private(set) var isSaving: Bool = false
    public private(set) var actionErrorMessage: String?

    @ObservationIgnored private let repository: ISafetyRepository
    /// Set only by the debug preview initializer; stops every method from loading or saving.
    @ObservationIgnored private var isPreview = false

    public init(
        repository: ISafetyRepository = AppEnvironment.current.usesMockServices ? MockSafetyRepository.shared : SafetyRepository()
    ) {
        self.repository = repository
    }

    public var contacts: [EmergencyContact] {
        state.data ?? []
    }

    /// Load error first, otherwise the last add/remove error.
    public var errorMessage: String? {
        if case let .error(message) = state { return message }
        return actionErrorMessage
    }

    /// Spinner only when there is nothing to show yet; with contacts on screen, saving is quiet.
    public var showsLoadingOverlay: Bool {
        let isBusy: Bool
        if case .loading = state { isBusy = true } else { isBusy = isSaving }
        return isBusy && contacts.isEmpty
    }

    public func onAppear() {
        guard !isPreview else { return }
        actionErrorMessage = nil
        if !state.hasData { state = .loading }
        Task {
            do {
                state = .data(data: try await repository.fetchEmergencyContacts())
            } catch {
                state = .error(message: error.localizedDescription)
            }
        }
    }

    /// Adds the typed contact. Inputs are trimmed; the fields are cleared only if the save succeeded.
    public func didTapAdd() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = newPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !phone.isEmpty else { return }
        guard !isSaving else { return }

        add(EmergencyContact(name: name, phoneNumber: phone)) {
            self.newName = ""
            self.newPhone = ""
        }
    }

    public func didTapImportFromContacts() {
        isShowingContactPicker = true
    }

    /// Called by the system picker. Contacts with no phone number are rejected because they could not be notified.
    public func didPickContact(givenName: String, familyName: String, phoneNumber: String?) {
        let name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !phone.isEmpty else {
            actionErrorMessage = String(localized: "That contact doesn't have a phone number, so it wasn't added.")
            return
        }
        guard !isSaving else { return }
        // A contact saved with only a number still needs a readable name in the list.
        add(EmergencyContact(name: name.isEmpty ? phone : name, phoneNumber: phone))
    }

    public func didDelete(at offsets: IndexSet) {
        let current = contacts
        let ids = offsets.compactMap { current.indices.contains($0) ? current[$0].id : nil }
        for id in ids {
            remove(id: id)
        }
    }

    /// `onSuccess` runs as soon as the save works, so a failed refresh afterwards doesn't leave the
    /// form filled and invite a duplicate add. A failed refresh shows an error and the list may be
    /// stale until the next `onAppear`.
    private func add(_ contact: EmergencyContact, onSuccess: @escaping () -> Void = {}) {
        guard !isPreview else { return }
        isSaving = true
        actionErrorMessage = nil
        Task {
            do {
                try await repository.addEmergencyContact(contact)
                onSuccess()
                state = .data(data: try await repository.fetchEmergencyContacts())
            } catch {
                actionErrorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func remove(id: String) {
        guard !isPreview else { return }
        Task {
            do {
                try await repository.removeEmergencyContact(id: id)
                state = .data(data: try await repository.fetchEmergencyContacts())
            } catch {
                actionErrorMessage = error.localizedDescription
            }
        }
    }
}

#if DEBUG

extension EmergencyContactsViewModel {
    /// Fixed fake state; never reaches a repository. `isPreview` has no default so a plain
    /// `init()` call stays unambiguous.
    convenience init(isPreview: Bool, isLoading: Bool = false, isError: Bool = false, isEmptyView: Bool = false) {
        self.init(repository: MockSafetyRepository())
        self.isPreview = isPreview
        if isLoading {
            state = .loading
        } else if isError {
            state = .error(message: String(localized: "Couldn't load your emergency contacts."))
        } else {
            state = .data(data: isEmptyView ? [] : EmergencyContact.mockList())
        }
    }
}

#endif
