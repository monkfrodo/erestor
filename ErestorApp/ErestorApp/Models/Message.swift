import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: String

    enum Role {
        case user
        case assistant
    }
}

struct ContextSummary: Codable {
    let snapshot: String?
    let gcal: String?
    let timer: TimerInfo?
    let timestamp: String?
    let p1Tasks: [String]?
    let nextEvent: NextEvent?
    let currentEvent: NextEvent?
    let briefing: String?

    struct TimerInfo: Codable {
        let type: String
        let desc: String
        let minutes: Int
    }

    struct NextEvent: Codable {
        let title: String
        let start: String
        let end: String
    }

    enum CodingKeys: String, CodingKey {
        case snapshot, gcal, timer, timestamp, briefing
        case p1Tasks = "p1_tasks"
        case nextEvent = "next_event"
        case currentEvent = "current_event"
    }
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

    enum CodingKeys: String, CodingKey {
        case type, text, at, path, url
        case name, cmd, desc, title, calendar, date, start, end
        case priority, category
        case timerType = "timer_type"
    }
}
