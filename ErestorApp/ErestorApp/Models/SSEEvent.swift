import Foundation

/// All event types that can arrive via the /v1/events/stream SSE connection
enum SSEEventType: String, Codable {
    case contextUpdate = "context_update"
    case pollEnergy = "poll_energy"
    case pollQuality = "poll_quality"
    case gateAlert = "gate_alert"
    case pollExpired = "poll_expired"
    case pollReminder = "poll_reminder"
    case heartbeat = "heartbeat"
}

/// Raw SSE event envelope — type is decoded first, then data is parsed per type
struct SSEEvent {
    let type: SSEEventType
    let rawData: [String: Any]

    /// Parse from a JSON string (the "data: " line content)
    static func parse(from jsonString: String) -> SSEEvent? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeStr = json["type"] as? String,
              let eventType = SSEEventType(rawValue: typeStr) else {
            return nil
        }
        return SSEEvent(type: eventType, rawData: json)
    }

    /// Extract typed data payload (everything except "type" key)
    var dataPayload: [String: Any] {
        rawData.filter { $0.key != "type" }
    }
}

/// Poll event delivered via SSE (energy or block quality)
struct PollSSEEvent: Codable, Identifiable {
    let pollId: String
    let pollType: String
    let question: String
    let options: [String]
    let expiresAt: Double?
    let context: String?

    var id: String { pollId }

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case pollType = "poll_type"
        case question, options
        case expiresAt = "expires_at"
        case context
    }
}

/// Gate alert event delivered via SSE
struct GateSSEEvent: Codable, Identifiable {
    let id = UUID()
    let text: String
    let severity: String  // "amber" or "red"
    let tasks: [String]?

    enum CodingKeys: String, CodingKey {
        case text, severity, tasks
    }
}
