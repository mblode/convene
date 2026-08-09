import Foundation
import UserNotifications

/// Routes user-notification actions back into the app via NotificationCenter so we don't have
/// to wire SwiftUI environment objects to a UN delegate.
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    private override init() { super.init() }

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        switch response.actionIdentifier {
        case "ConveneStart", UNNotificationDefaultActionIdentifier:
            // Tapping the body or the Start button both start only when idle.
            NotificationCenter.default.post(name: NSNotification.Name("ConveneStartRecordingIfIdle"), object: nil)
        default:
            break
        }
    }
}
