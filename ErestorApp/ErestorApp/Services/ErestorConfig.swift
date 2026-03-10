import Foundation

/// Centralized configuration for the Erestor API connection.
/// All networking code reads from here — single place to change.
enum ErestorConfig {
    static let apiBaseURL = "https://erestor-api.kevineger.com.br"
    static let apiToken = "gzC3a3cvg15-IgU3lAu0YuJeHCxc87EOTZJ4sikSuMU"

    // MARK: - v1 API Paths

    static let eventsStreamPath = "/v1/events/stream"
    static let chatStreamPath = "/v1/chat/stream"
    static let pollsPath = "/v1/polls"
    static let synthesisPath = "/v1/synthesis"
    static let statusPath = "/v1/status"
    static let contextPath = "/v1/context"
    static let chatPath = "/v1/chat"
    static let historyPath = "/v1/history"
    static let timerStopPath = "/v1/timer/stop"
    static let deviceRegisterPath = "/v1/device/register"

    /// Apply auth header to a URLRequest
    static func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
    }

    /// Build a full URL for an API endpoint path
    static func url(for path: String) -> URL? {
        URL(string: "\(apiBaseURL)\(path)")
    }
}
