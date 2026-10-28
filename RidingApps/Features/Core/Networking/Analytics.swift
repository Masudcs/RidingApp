import Foundation

/// There's no real analytics backend yet — every call funnels through `AppLogger` so the event
/// stream is inspectable in Console.app today, and swapping in a real SDK later only touches
/// this file.
public enum Analytics {
    private static let logger = AppLogger(category: "Analytics")

    /// Records one event. Properties are sorted so the log line is stable. Don't put personal
    /// data in `properties`; it ends up in the (public) log.
    public static func track(_ name: String, _ properties: [String: String] = [:]) {
        let propsText = properties.isEmpty ? "" : " " + properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.info("event=\(name)\(propsText)")
    }
}
