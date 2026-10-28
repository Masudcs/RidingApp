import Foundation

extension String {
    /// Makes an id safe to place inside a URL path segment (escapes `/`, `?`, `#`, `%`, spaces...).
    var pathEscaped: String {
        addingPercentEncoding(withAllowedCharacters: .pathSegmentAllowed) ?? self
    }
}

private extension CharacterSet {
    /// RFC 3986 unreserved characters only, so nothing can change the path structure.
    static let pathSegmentAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
