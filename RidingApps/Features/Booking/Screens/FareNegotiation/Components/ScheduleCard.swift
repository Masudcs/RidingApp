import SwiftUI

/// "Schedule for later" toggle with a date picker once on.
public struct ScheduleCard: View {
    private let scheduledFor: Date?
    private let onToggle: (Bool) -> Void
    private let onChangeDate: (Date) -> Void

    public init(scheduledFor: Date?, onToggle: @escaping (Bool) -> Void, onChangeDate: @escaping (Date) -> Void) {
        self.scheduledFor = scheduledFor
        self.onToggle = onToggle
        self.onChangeDate = onChangeDate
    }

    public var body: some View {
        SectionCard {
            Toggle("Schedule for later", isOn: Binding(
                get: { scheduledFor != nil },
                set: { onToggle($0) }
            ))
            if let scheduledFor {
                DatePicker(
                    "Pickup time",
                    selection: Binding(
                        get: { scheduledFor },
                        set: { onChangeDate($0) }
                    ),
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
    }
}

#if DEBUG

#Preview("Off") {
    ScheduleCard(scheduledFor: nil, onToggle: { _ in }, onChangeDate: { _ in })
        .padding()
}

#Preview("On") {
    ScheduleCard(scheduledFor: Date().addingTimeInterval(24 * 3600), onToggle: { _ in }, onChangeDate: { _ in })
        .padding()
}

#endif
