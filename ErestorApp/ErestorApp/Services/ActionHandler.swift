import Foundation
import AppKit
import UserNotifications
import os

private let logger = Logger(subsystem: "org.integros.erestor", category: "ActionHandler")

@MainActor
class ActionHandler: ObservableObject {
    static let shared = ActionHandler()

    private init() {
        requestNotificationPermission()
    }

    // MARK: - Execute actions from Claude response

    private func showFeedback(_ text: String) {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        BubbleWindowController.shared.chatWebVC?.webView?.evaluateJavaScript(
            "showActionFeedback(\"\(escaped)\")"
        )
    }

    private static let actionLabels: [String: String] = [
        "reminder": "lembrete agendado",
        "open_project": "projeto aberto",
        "open_url": "url aberta",
        "open_app": "app aberto",
        "open_finder": "finder aberto",
        "clipboard": "copiado",
        "shell": "comando executado",
        "timer_start": "timer iniciado",
        "timer_stop": "timer parado",
        "gcal_create": "evento criado",
        "create_task": "tarefa criada",
        "complete_task": "tarefa concluída",
        "web_search": "busca aberta",
    ]

    func execute(_ actions: [ChatAction]) {
        for action in actions {
            if let label = Self.actionLabels[action.type] {
                let detail = action.desc ?? action.title ?? action.text ?? action.name ?? ""
                let msg = detail.isEmpty ? "✓ \(label)" : "✓ \(label): \(detail)"
                showFeedback(msg)
            }
            switch action.type {
            case "reminder":
                scheduleReminder(text: action.text ?? "Lembrete do Erestor", at: action.at)
            case "open_project":
                openProject(path: action.path ?? "")
            case "open_url":
                openURL(urlString: action.url ?? "")
            case "open_app":
                openApp(name: action.name ?? "")
            case "open_finder":
                openFinder(path: action.path ?? "")
            case "clipboard":
                copyToClipboard(text: action.text ?? "")
            case "shell":
                runShell(cmd: action.cmd ?? "")
            case "timer_start":
                startTimer(timerType: action.timerType ?? "work", desc: action.desc ?? "")
            case "timer_stop":
                stopTimer(timerType: action.timerType ?? "work")
            case "gcal_create":
                createCalendarEvent(
                    title: action.title ?? "",
                    calendar: action.calendar ?? "trabalho",
                    date: action.date ?? "",
                    start: action.start ?? "",
                    end: action.end ?? ""
                )
            case "create_task":
                createTask(
                    title: action.title ?? "",
                    priority: action.priority ?? "P2",
                    due: action.date ?? "",
                    category: action.category ?? "trabalho"
                )
            case "complete_task":
                completeTask(title: action.title ?? "")
            case "web_search":
                webSearch(query: action.text ?? "")
            default:
                logger.warning("Unknown action type: \(action.type)")
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            } else {
                logger.info("Notification permission granted: \(granted)")
            }
        }
    }

    func scheduleReminder(text: String, at timeString: String?) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Erestor"
        content.body = text
        content.sound = .default

        let trigger: UNNotificationTrigger?

        if let timeString, let (hour, minute) = parseTime(timeString) {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.timeZone = TimeZone(identifier: "America/Sao_Paulo")
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            logger.info("Scheduling reminder at \(timeString): \(text)")
        } else {
            // No time specified — deliver in 5 seconds
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            logger.info("Scheduling immediate reminder: \(text)")
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                logger.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Open project in terminal with Claude Code

    func openProject(path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            logger.warning("Project path does not exist: \(expanded)")
            // Still try to open — might be valid later
            openTerminalAt(expanded)
            return
        }
        openTerminalAt(expanded)
    }

    private func openTerminalAt(_ path: String) {
        let script = """
        tell application "iTerm"
            activate
            create window with default profile command "cd '\(path)' && claude"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                logger.error("AppleScript error: \(error)")
            }
        }
    }

    // MARK: - Open URL

    func openURL(urlString: String) {
        guard let url = URL(string: urlString) else {
            logger.warning("Invalid URL: \(urlString)")
            return
        }
        NSWorkspace.shared.open(url)
        logger.info("Opened URL: \(urlString)")
    }

    // MARK: - Open App

    func openApp(name: String) {
        guard !name.isEmpty else {
            logger.warning("open_app called with empty name")
            return
        }
        NSWorkspace.shared.launchApplication(name)
        logger.info("Opened app: \(name)")
    }

    // MARK: - Open Finder

    func openFinder(path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expanded)
        logger.info("Opened Finder at: \(expanded)")
    }

    // MARK: - Clipboard

    func copyToClipboard(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.info("Copied to clipboard (\(text.count) chars)")
    }

    // MARK: - Shell

    func runShell(cmd: String) {
        guard !cmd.isEmpty else {
            logger.warning("shell called with empty cmd")
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", cmd]
        do {
            try task.run()
            logger.info("Shell command launched: \(cmd.prefix(80))")
        } catch {
            logger.error("Shell command failed to launch: \(error.localizedDescription)")
        }
    }

    // MARK: - Timer

    func startTimer(timerType: String, desc: String) {
        callBackendEndpoint("/timer/start", body: ["type": timerType, "desc": desc])
    }

    func stopTimer(timerType: String) {
        callBackendEndpoint("/timer/stop", body: ["type": timerType])
    }

    // MARK: - Google Calendar

    func createCalendarEvent(title: String, calendar: String, date: String, start: String, end: String) {
        callBackendEndpoint("/gcal/create", body: [
            "title": title, "calendar": calendar, "date": date, "start": start, "end": end
        ])
    }

    // MARK: - Tasks

    func createTask(title: String, priority: String, due: String, category: String) {
        callBackendEndpoint("/task/create", body: [
            "title": title, "priority": priority, "due": due, "category": category
        ])
    }

    func completeTask(title: String) {
        callBackendEndpoint("/task/complete", body: ["title": title])
    }

    // MARK: - Web Search

    func webSearch(query: String) {
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.google.com/search?q=\(encoded)")
        else {
            logger.warning("web_search called with empty query")
            return
        }
        NSWorkspace.shared.open(url)
        logger.info("Web search: \(query)")
    }

    // MARK: - Backend Helper

    private func callBackendEndpoint(_ path: String, body: [String: String]) {
        let baseURL = "http://127.0.0.1:8766"
        guard let url = URL(string: "\(baseURL)\(path)") else {
            logger.error("Invalid backend URL for path: \(path)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        URLSession.shared.dataTask(with: request) { [path] data, response, error in
            if let error {
                logger.error("Backend call \(path) failed: \(error.localizedDescription)")
            } else {
                logger.info("Backend call \(path) succeeded")
            }
        }.resume()
    }

    // MARK: - Helpers

    private func parseTime(_ str: String) -> (Int, Int)? {
        let parts = str.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else { return nil }
        return (hour, minute)
    }
}
