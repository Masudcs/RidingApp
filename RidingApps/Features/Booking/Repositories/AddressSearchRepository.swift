import Foundation
import Combine
import MapKit

/// One row in the address search results. Wraps the MapKit completion because it has no
/// coordinate yet; call `IAddressSearchRepository.resolve(_:)` to get the real location.
public struct AddressSuggestion: Identifiable, Equatable {
    /// Compared by `id` only, so a refreshed result list with the same rows doesn't look changed.
    public static func == (lhs: AddressSuggestion, rhs: AddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }

    public let id = UUID()
    public let title: String
    public let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion

    fileprivate init(title: String, subtitle: String, completion: MKLocalSearchCompletion) {
        self.title = title
        self.subtitle = subtitle
        self.completion = completion
    }
}

/// Address autocomplete used by `AddressSearchViewModel`. Kept as a protocol so tests can fake it.
@MainActor
public protocol IAddressSearchRepository: AnyObject {
    /// Emits the latest suggestions for the current query (empty when there is no query or on error).
    var suggestionsPublisher: AnyPublisher<[AddressSuggestion], Never> { get }
    /// Feeds the text the user is typing; results arrive later through `suggestionsPublisher`.
    func updateQuery(_ query: String)
    /// Turns a suggestion into a real location. Returns nil when the lookup fails or finds nothing.
    func resolve(_ suggestion: AddressSuggestion) async -> NamedLocation?
}

/// Wraps `MKLocalSearchCompleter` for SwiftUI use. No API key needed — this is plain MapKit, unlike
/// turn-by-turn Directions which was deferred pending real credentials. Used in every environment
/// since it never touches our backend.
@MainActor
public final class AddressSearchRepository: NSObject, IAddressSearchRepository {
    @Published public private(set) var suggestions: [AddressSuggestion] = []

    public var suggestionsPublisher: AnyPublisher<[AddressSuggestion], Never> {
        $suggestions.eraseToAnyPublisher()
    }

    private let completer = MKLocalSearchCompleter()

    public override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // Bias results toward Dhaka, matching the rest of this mock's geography.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 23.78, longitude: 90.40),
            span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
        )
    }

    /// An empty or whitespace-only query clears the results and cancels any search in flight.
    public func updateQuery(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            suggestions = []
            completer.cancel()
            return
        }
        completer.queryFragment = query
    }

    public func resolve(_ suggestion: AddressSuggestion) async -> NamedLocation? {
        // A failed or cancelled lookup is reported as nil; the caller decides what to tell the user.
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(), let item = response.mapItems.first else { return nil }
        let point = GeoPoint(coordinate: item.placemark.coordinate)
        return NamedLocation(title: suggestion.title, subtitle: suggestion.subtitle.isEmpty ? "Searched address" : suggestion.subtitle, point: point)
    }
}

extension AddressSearchRepository: MKLocalSearchCompleterDelegate {
    // MapKit calls these delegate methods off the main actor, so hop back before touching state.
    public nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results.map { AddressSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
        }
    }

    public nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.

extension AddressSuggestion {
    /// The MapKit completion is an empty placeholder; only title and subtitle are displayed.
    static func mock(title: String = "Gulshan 1 Circle", subtitle: String = "Gulshan, Dhaka") -> AddressSuggestion {
        AddressSuggestion(title: title, subtitle: subtitle, completion: MKLocalSearchCompletion())
    }

    static func mockList() -> [AddressSuggestion] {
        [
            .mock(title: "Gulshan 1 Circle", subtitle: "Gulshan, Dhaka"),
            .mock(title: "Gulshan 2 Circle", subtitle: "Gulshan, Dhaka"),
            .mock(title: "Gulshan Avenue", subtitle: "Dhaka, Bangladesh")
        ]
    }
}

/// Does no searching, so a preview never starts a MapKit query.
@MainActor
final class PreviewAddressSearchRepository: IAddressSearchRepository {
    var suggestionsPublisher: AnyPublisher<[AddressSuggestion], Never> {
        Just([]).eraseToAnyPublisher()
    }

    func updateQuery(_ query: String) {}

    func resolve(_ suggestion: AddressSuggestion) async -> NamedLocation? {
        .mockPickup()
    }
}

#endif
