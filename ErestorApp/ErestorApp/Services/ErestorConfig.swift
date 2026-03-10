import Foundation

/// Centralized configuration for the Erestor API connection.
/// All networking code reads from here — single place to change.
enum ErestorConfig {
    static let apiBaseURL = "https://erestor-api.kevineger.com.br"
    static let apiToken = "gzC3a3cvg15-IgU3lAu0YuJeHCxc87EOTZJ4sikSuMU"

    // MARK: - v1 API Paths

    static let eventsStreamPath = "/api/events/stream"
    static let chatStreamPath = "/api/chat/stream"
    static let pollsPath = "/api/polls"
    static let synthesisPath = "/api/synthesis"
    static let statusPath = "/api/status"
    static let contextPath = "/api/context"
    static let chatPath = "/api/chat"
    static let historyPath = "/api/history"
    static let timerStopPath = "/api/timer/stop"
    static let deviceRegisterPath = "/api/device/register"

    /// Apply auth header to a URLRequest
    static func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
    }

    /// Build a full URL for an API endpoint path
    static func url(for path: String) -> URL? {
        URL(string: "\(apiBaseURL)\(path)")
    }
}
