import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var text: String
    let timestamp: String
    var isStreaming: Bool = false

    enum Role {
        case user
        case assistant
    }

    /// Convenience init for a streaming assistant message (starts with empty text)
    static func streaming(timestamp: String) -> ChatMessage {
        ChatMessage(role: .assistant, text: "", timestamp: timestamp, isStreaming: true)
    }
}

/// Matches the actual /api/context response from the DO server
struct ContextSummary: Codable {
    let now: String?
    let dayPhase: String?          // pre_day, morning, afternoon, evening, night
    let hora: Int?
    let activity: String?          // free_window, working, resting, etc.
    let timerType: String?
    let timerDesc: String?
    let timerElapsedMins: Int?
    let currentEvent: GCalEvent?
    let isRestEvent: Bool?
    let nextEvent: GCalEvent?
    let minsToNext: Int?
    let minsSinceLastEnd: Int?
    let todayEvents: [GCalEvent]?
    let activeP1s: [TaskItem]?
    let activeP2s: [TaskItem]?
    let energyLevel: Int?

    enum CodingKeys: String, CodingKey {
        case now
        case dayPhase = "day_phase"
        case hora, activity
        case timerType = "timer_type"
        case timerDesc = "timer_desc"
        case timerElapsedMins = "timer_elapsed_mins"
        case currentEvent = "current_event"
        case isRestEvent = "is_rest_event"
        case nextEvent = "next_event"
        case minsToNext = "mins_to_next"
        case minsSinceLastEnd = "mins_since_last_end"
        case todayEvents = "today_events"
        case activeP1s = "active_p1s"
        case activeP2s = "active_p2s"
        case energyLevel = "energy_level"
    }

    // MARK: - Computed helpers for views

    var timer: TimerInfo? {
        guard let type = timerType, let desc = timerDesc else { return nil }
        return TimerInfo(type: type, desc: desc, minutes: timerElapsedMins ?? 0)
    }

    var p1Tasks: [String] {
        activeP1s?.map { $0.title } ?? []
    }

    var p2Tasks: [String] {
        activeP2s?.map { $0.title } ?? []
    }

    struct TimerInfo {
        let type: String
        let desc: String
        let minutes: Int
    }
}

/// Google Calendar event (matches GCal API response)
struct GCalEvent: Codable {
    let summary: String?
    let start: GCalDateTime?
    let end: GCalDateTime?
    let organizer: GCalOrganizer?

    struct GCalDateTime: Codable {
        let dateTime: String?
        let timeZone: String?
    }

    struct GCalOrganizer: Codable {
        let displayName: String?
    }

    // Helpers
    var title: String { summary ?? "Sem título" }

    var startTime: String {
        guard let dt = start?.dateTime else { return "" }
        return extractTime(from: dt)
    }

    var endTime: String {
        guard let dt = end?.dateTime else { return "" }
        return extractTime(from: dt)
    }

    var calendarName: String {
        organizer?.displayName ?? ""
    }

    private func extractTime(from iso: String) -> String {
        // "2026-03-09T21:30:00-03:00" → "21:30"
        guard let tIndex = iso.firstIndex(of: "T") else { return "" }
        let afterT = iso[iso.index(after: tIndex)...]
        return String(afterT.prefix(5))
    }
}

/// Notion task item
struct TaskItem: Codable {
    let title: String
}

struct PushEvent: Codable {
    let type: String        // message, action, context_update, poll_energy, poll_quality, gate_inform, reminder
    let text: String?
    let actions: [ChatAction]?
    let context: ContextSummary?
    let options: [String]?  // poll choices (poll_energy: 5 options, poll_quality: 4 options)
    let severity: String?   // gate_inform severity: "amber" | "red"
}

struct ChatAction: Codable, Identifiable {
    let id = UUID()
    let type: String
    let text: String?
    let at: String?
    let path: String?
    let url: String?
    let name: String?
    let cmd: String?
    let desc: String?
    let title: String?
    let calendar: String?
    let date: String?
    let start: String?
    let end: String?
    let priority: String?
    let category: String?
    let timerType: String?
    let startedAt: String?

    enum CodingKeys: String, CodingKey {
        case type, text, at, path, url
        case name, cmd, desc, title, calendar, date, start, end
        case priority, category
        case timerType = "timer_type"
        case startedAt = "started_at"
    }
}
