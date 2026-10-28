import Foundation

/// Screen-level load state, rendered by a screen with a single `switch`.
public enum UIState<T> {
    case loading
    case error(message: String)
    case data(data: T)

    public var hasData: Bool {
        if case .data = self { return true }
        return false
    }

    public var data: T? {
        if case let .data(data) = self { return data }
        return nil
    }
}
