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

    // MARK: - Register device token with backend

    private func registerDeviceToken(_ token: String) {
        guard let url = ErestorConfig.url(for: "/api/device/register") else { return }
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
