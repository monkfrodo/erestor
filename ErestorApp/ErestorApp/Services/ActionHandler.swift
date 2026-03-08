import Foundation
import AppKit
import UserNotifications
import os

private let logger = Logger(subsystem: "org.integros.erestor", category: "ActionHandler")

@MainActor
class ActionHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ActionHandler()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
    }

    // Show notifications even when app is in foreground (LSUIElement)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
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
        "gcal_update": "evento atualizado",
        "create_task": "tarefa criada",
        "complete_task": "tarefa concluída",
        "web_search": "busca aberta",
        "music_toggle": "música play/pause",
        "music_next": "próxima faixa",
        "music_prev": "faixa anterior",
        "screenshot": "screenshot capturado",
    ]

    // Actions that call backend and need deferred feedback
    private static let backendActions: Set<String> = [
        "gcal_create", "gcal_update", "create_task", "complete_task",
        "timer_start", "timer_stop"
    ]

    func execute(_ actions: [ChatAction]) {
        // Execute actions sequentially to preserve ordering (e.g. timer_stop then timer_start)
        Task { @MainActor in
            for action in actions {
                // Backend actions show feedback after completion; others show immediately
                if action.type != "screenshot" && !Self.backendActions.contains(action.type),
                   let label = Self.actionLabels[action.type] {
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
                    await callBackendEndpointAsync("/timer/start", body: [
                        "type": action.timerType ?? "work",
                        "desc": action.desc ?? "",
                        "started_at": action.startedAt ?? ""
                    ].filter { !$0.value.isEmpty }, actionType: "timer_start")
                case "timer_stop":
                    await callBackendEndpointAsync("/timer/stop", body: [
                        "type": action.timerType ?? "work"
                    ], actionType: "timer_stop")
                case "gcal_create":
                    await callBackendEndpointAsync("/gcal/create", body: [
                        "title": action.title ?? "",
                        "calendar": action.calendar ?? "trabalho",
                        "date": action.date ?? "",
                        "start": action.start ?? "",
                        "end": action.end ?? ""
                    ], actionType: "gcal_create")
                case "gcal_update":
                    await callBackendEndpointAsync("/gcal/update", body: {
                        var b = ["title": action.title ?? "", "calendar": action.calendar ?? "trabalho"]
                        if let s = action.start, !s.isEmpty { b["start"] = s }
                        if let e = action.end, !e.isEmpty { b["end"] = e }
                        return b
                    }(), actionType: "gcal_update")
                case "create_task":
                    await callBackendEndpointAsync("/task/create", body: [
                        "title": action.title ?? "",
                        "priority": action.priority ?? "P2",
                        "due": action.date ?? "",
                        "category": action.category ?? "trabalho"
                    ], actionType: "create_task")
                case "complete_task":
                    await callBackendEndpointAsync("/task/complete", body: [
                        "title": action.title ?? ""
                    ], actionType: "complete_task")
                case "web_search":
                    webSearch(query: action.text ?? "")
                case "music_toggle":
                    musicControl(action: "playpause")
                case "music_next":
                    musicControl(action: "next track")
                case "music_prev":
                    musicControl(action: "previous track")
                case "screenshot":
                    captureScreenshot()
                default:
                    logger.warning("Unknown action type: \(action.type)")
                }
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
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "iTerm"
            activate
            create window with default profile command "cd '\(safePath)' && claude"
        end tell
        """

        // NSAppleScript must run on main thread for thread safety
        DispatchQueue.main.async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error {
                    logger.error("AppleScript error: \(error)")
                }
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

    // MARK: - Timer, Calendar, Tasks — now called via callBackendEndpointAsync from execute()

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

    // MARK: - Music Control

    func musicControl(action: String) {
        // Detect which music app is running (safe on main thread — just reads a list)
        let runningApps = NSWorkspace.shared.runningApplications
        let musicRunning = runningApps.contains { $0.bundleIdentifier == "com.apple.Music" }
        let spotifyRunning = runningApps.contains { $0.bundleIdentifier == "com.spotify.client" }

        let appName: String
        if spotifyRunning {
            appName = "Spotify"
        } else if musicRunning {
            appName = "Music"
        } else {
            // Default to Music — it will launch if needed
            appName = "Music"
        }

        let script = """
        tell application "\(appName)" to \(action)
        """

        // NSAppleScript must run on main thread for thread safety
        DispatchQueue.main.async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error {
                    logger.error("Music control error (\(appName)): \(error)")
                } else {
                    logger.info("Music control: \(action) on \(appName)")
                }
            }
        }
    }

    // MARK: - Screenshot

    func captureScreenshot() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "erestor-screenshot-\(timestamp).png"
        let desktopPath = ("~/Desktop" as NSString).expandingTildeInPath
        let filePath = "\(desktopPath)/\(filename)"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", filePath]
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if process.terminationStatus != 0 {
                    self?.showFeedback("✗ screenshot cancelado")
                    return
                }
                guard FileManager.default.fileExists(atPath: filePath) else {
                    self?.showFeedback("✗ screenshot cancelado")
                    logger.info("Screenshot cancelled by user")
                    return
                }
                NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
                self?.showFeedback("✓ screenshot salvo")
                logger.info("Screenshot saved and opened: \(filePath)")
            }
        }
        do {
            try task.run()
            logger.info("screencapture launched (interactive selection)")
        } catch {
            logger.error("screencapture failed to launch: \(error.localizedDescription)")
        }
    }

    // MARK: - Backend Helper (async — ensures sequential execution for ordered actions)

    private func callBackendEndpointAsync(_ path: String, body: [String: String], actionType: String? = nil) async {
        let baseURL = "http://127.0.0.1:8766"
        guard let url = URL(string: "\(baseURL)\(path)") else {
            logger.error("Invalid backend URL for path: \(path)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            let success = (200..<300).contains(httpStatus)

            if !success {
                let errorMsg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "erro desconhecido"
                logger.error("Backend call \(path) returned \(httpStatus): \(errorMsg)")
            } else {
                logger.info("Backend call \(path) succeeded")
            }

            if let actionType, let label = Self.actionLabels[actionType] {
                let detail = body["title"] ?? body["desc"] ?? body["type"] ?? ""
                if success {
                    let msg = detail.isEmpty ? "✓ \(label)" : "✓ \(label): \(detail)"
                    showFeedback(msg)
                } else {
                    showFeedback("✗ falha: \(label)")
                }
            }
        } catch {
            logger.error("Backend call \(path) failed: \(error.localizedDescription)")
            if let actionType, let label = Self.actionLabels[actionType] {
                showFeedback("✗ falha: \(label)")
            }
        }
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
