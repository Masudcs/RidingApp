import Contacts
import SwiftUI

/// Lists, adds (typed or imported) and swipe-deletes emergency contacts.
public struct EmergencyContactsScreen: View {
    @State private var viewModel: EmergencyContactsViewModel

    public init(viewModel: EmergencyContactsViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? EmergencyContactsViewModel())
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    ErrorBanner(errorMessage)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("Emergency Contacts") {
                ForEach(viewModel.contacts) { contact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(BrandTypography.headline)
                        Text(contact.phoneNumber)
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                    }
                }
                .onDelete { offsets in
                    viewModel.didDelete(at: offsets)
                }
            }

            Section("Add Contact") {
                TextField("Name", text: $viewModel.newName)
                TextField("Phone number", text: $viewModel.newPhone)
                    .keyboardType(.phonePad)
                SecondaryButton("Add", systemImage: "plus") {
                    viewModel.didTapAdd()
                }
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

                SecondaryButton("Import from Contacts", systemImage: "person.crop.circle.badge.plus") {
                    viewModel.didTapImportFromContacts()
                }
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.showsLoadingOverlay {
                ProgressView()
            }
        }
        .navigationTitle("Emergency Contacts")
        .onAppear {
            viewModel.onAppear()
        }
        .sheet(isPresented: $viewModel.isShowingContactPicker) {
            ContactPickerRepresentable { contact in
                viewModel.didPickContact(
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    phoneNumber: contact.phoneNumbers.first?.value.stringValue
                )
            }
        }
    }
}

#if DEBUG

#Preview("Loading") {
    NavigationStack {
        EmergencyContactsScreen(viewModel: EmergencyContactsViewModel(isPreview: true, isLoading: true))
    }
}

#Preview("Data") {
    NavigationStack {
        EmergencyContactsScreen(viewModel: EmergencyContactsViewModel(isPreview: true))
    }
}

#Preview("Empty") {
    NavigationStack {
        EmergencyContactsScreen(viewModel: EmergencyContactsViewModel(isPreview: true, isEmptyView: true))
    }
}

#Preview("Error") {
    NavigationStack {
        EmergencyContactsScreen(viewModel: EmergencyContactsViewModel(isPreview: true, isError: true))
    }
}

#Preview("Data - Dark") {
    NavigationStack {
        EmergencyContactsScreen(viewModel: EmergencyContactsViewModel(isPreview: true))
    }
    .preferredColorScheme(.dark)
}

#endif
