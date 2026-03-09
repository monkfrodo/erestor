import Foundation

/// Centralized configuration for the Erestor API connection.
/// All networking code reads from here — single place to change.
enum ErestorConfig {
    static let apiBaseURL = "https://erestor-api.kevineger.com.br"
    static let apiToken = "gzC3a3cvg15-IgU3lAu0YuJeHCxc87EOTZJ4sikSuMU"

    /// Apply auth header to a URLRequest
    static func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
    }

    /// Build a full URL for an API endpoint path
    static func url(for path: String) -> URL? {
        URL(string: "\(apiBaseURL)\(path)")
    }
}
