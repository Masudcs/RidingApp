import Foundation

/// Static help-center question and answer. Content is bundled in the app, not fetched.
public struct FAQItem: Identifiable, Sendable {
    public let id = UUID()
    public let question: String
    public let answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }

    public static let all: [FAQItem] = [
        FAQItem(
            question: String(localized: "How does fare negotiation work?"),
            answer: String(localized: "After you request a ride, you and a driver can go back and forth with counter-offers before agreeing on a fare — similar to InDrive. You can also just accept the suggested fare outright.")
        ),
        FAQItem(
            question: String(localized: "What happens if I cancel a ride?"),
            answer: String(localized: "Cancelling before a driver is matched, or within a couple of minutes after, is free. After that, a small cancellation fee applies since your driver is already on the way.")
        ),
        FAQItem(
            question: String(localized: "How do I add an emergency contact?"),
            answer: String(localized: "Go to Safety > Emergency Contacts to add contacts manually or import them from your phone. They're notified automatically if a route deviation or SOS is triggered.")
        ),
        FAQItem(
            question: String(localized: "How is my fare calculated?"),
            answer: String(localized: "Fare = base fare + distance rate + a small per-stop fee, multiplied by any surge in your area. You can see the full breakdown on your receipt before and after paying.")
        ),
        FAQItem(
            question: String(localized: "Can I split the fare with friends?"),
            answer: String(localized: "Yes — on the payment screen, use the Split Fare stepper to divide the total between multiple riders. You're only charged your own share.")
        )
    ]
}
