import SwiftUI
import UserNotifications

#if os(iOS)
@MainActor
class AppDelegate_iOS: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }

        registerNotificationCategories()

        return true
    }

    // MARK: - APNs device token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NSLog("[Erestor-iOS] APNs device token: \(token)")
        registerDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("[Erestor-iOS] APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - Notification presentation (foreground)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Notification response handler

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        guard actionID != UNNotificationDefaultActionIdentifier,
              actionID != UNNotificationDismissActionIdentifier else {
            completionHandler()
            return
        }

        // REMIND_10: schedule local notification in 10 minutes
        if actionID == "REMIND_10" {
            if let pollId = userInfo["poll_id"] as? String,
               let pollType = userInfo["poll_type"] as? String {
                scheduleReminder(
                    pollId: pollId,
                    pollType: pollType,
                    question: response.notification.request.content.body
                )
            }
            completionHandler()
            return
        }

        // GATE_VER: bring app to foreground
        if actionID == "GATE_VER" {
            completionHandler()
            return
        }

        // GATE_DISPENSAR: just dismiss
        if actionID == "GATE_DISPENSAR" {
            completionHandler()
            return
        }

        // Poll response actions
        if let pollId = userInfo["poll_id"] as? String {
            let value = parsePollResponseValue(action: actionID)
            respondToPollBackend(pollId: pollId, value: value)
        }

        completionHandler()
    }

    // MARK: - Notification categories

    private func registerNotificationCategories() {
        // Energy poll: 4 actions (iOS 4-button limit)
        // Full 5-option UI is in the modal sheet when notification is tapped
        let energyActions = [
            UNNotificationAction(identifier: "ENERGY_12", title: "1-2 baixa", options: []),
            UNNotificationAction(identifier: "ENERGY_3", title: "3 ok", options: []),
            UNNotificationAction(identifier: "ENERGY_45", title: "4-5 alta", options: []),
            UNNotificationAction(identifier: "REMIND_10", title: "Lembrar 10min", options: []),
        ]
        let energyCategory = UNNotificationCategory(
            identifier: "POLL_ENERGY",
            actions: energyActions,
            intentIdentifiers: [],
            options: []
        )

        // Quality poll: 4 actions
        let qualityActions = [
            UNNotificationAction(identifier: "QUALITY_perdi", title: "perdi", options: []),
            UNNotificationAction(identifier: "QUALITY_meh", title: "meh", options: []),
            UNNotificationAction(identifier: "QUALITY_ok", title: "ok", options: []),
            UNNotificationAction(identifier: "QUALITY_flow", title: "flow", options: []),
        ]
        let qualityCategory = UNNotificationCategory(
            identifier: "POLL_QUALITY",
            actions: qualityActions,
            intentIdentifiers: [],
            options: []
        )

        // Gate inform: 2 actions
        let gateActions = [
            UNNotificationAction(identifier: "GATE_VER", title: "Ver", options: [.foreground]),
            UNNotificationAction(identifier: "GATE_DISPENSAR", title: "Dispensar", options: []),
        ]
        let gateCategory = UNNotificationCategory(
            identifier: "GATE_INFORM",
            actions: gateActions,
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            energyCategory, qualityCategory, gateCategory,
        ])
    }

    // MARK: - Parse poll response value from action identifier

    private func parsePollResponseValue(action: String) -> String {
        // ENERGY_12 -> "2" (midpoint), ENERGY_3 -> "3", ENERGY_45 -> "4" (midpoint)
        if action == "ENERGY_12" { return "2" }
        if action == "ENERGY_3" { return "3" }
        if action == "ENERGY_45" { return "4" }
        // QUALITY_flow -> "flow"
        if action.hasPrefix("QUALITY_") {
            return String(action.dropFirst("QUALITY_".count))
        }
        return action
    }

    // MARK: - POST poll response to backend

    private func respondToPollBackend(pollId: String, value: String) {
        guard let url = ErestorConfig.url(for: "\(ErestorConfig.pollsPath)/\(pollId)/respond") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        ErestorConfig.authorize(&request)

        let body: [String: String] = ["value": value]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                NSLog("[Erestor-iOS] Poll respond failed: \(error.localizedDescription)")
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            NSLog("[Erestor-iOS] Poll response sent (status \(status), value: \(value))")
        }.resume()
    }

    // MARK: - Schedule reminder notification

    private func scheduleReminder(pollId: String, pollType: String, question: String) {
        let content = UNMutableNotificationContent()
        content.title = "Erestor"
        content.body = question
        content.sound = .default
        content.categoryIdentifier = pollType == "energy" ? "POLL_ENERGY" : "POLL_QUALITY"
        content.userInfo = ["poll_id": pollId, "poll_type": pollType]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(pollId)_reminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[Erestor-iOS] Reminder schedule failed: \(error.localizedDescription)")
            } else {
                NSLog("[Erestor-iOS] Reminder scheduled in 10min for poll \(pollId)")
            }
        }
    }

    // MARK: - Register device token with backend

    private func registerDeviceToken(_ token: String) {
        guard let url = ErestorConfig.url(for: ErestorConfig.deviceRegisterPath) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        ErestorConfig.authorize(&request)

        let body: [String: String] = [
            "token": token,
            "platform": "ios"
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                NSLog("[Erestor-iOS] Device register failed: \(error.localizedDescription)")
            } else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                NSLog("[Erestor-iOS] Device registered (status \(status))")
            }
        }.resume()
    }
}

@main
struct ErestorIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate_iOS.self) var appDelegate
    @StateObject private var chatService = ChatService()

    var body: some Scene {
        WindowGroup {
            iOS_TabRootView(chatService: chatService)
        }
    }
}
#endif
