import Flutter
import UIKit
import WindowsAzureMessaging
import Foundation

let DEFAULT_TEMPLATE_NAME = "FANH DEFAULT TEMPLATE"

public class AzureNotificationHubPlugin: NSObject, FlutterPlugin, MSNotificationHubDelegate, UNUserNotificationCenterDelegate {
    private var channel: FlutterMethodChannel?
    private var notificationResponseCompletionHandler: (() -> Void)?
    private var notificationPresentationCompletionHandler: ((UNNotificationPresentationOptions) -> Void)?

    // Store as formatted notification ready for Flutter
    private var initialNotification: [String: Any?]?
    private var hasColdStartNotification = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel =  FlutterMethodChannel(name: "plugins.flutter.io/azure_notification_hub", binaryMessenger: registrar.messenger())
        let instance = AzureNotificationHubPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "AzNotificationHub.start":
            startHubConnection(result: result)
        case "AzNotificationHub.addTags":
            addTags((call.arguments as! [String:Any?])["tags"] as! [String], result: result)
        case "AzNotificationHub.removeTags":
            removeTags((call.arguments as! [String:Any?])["tags"] as! [String], result: result)
        case "AzNotificationHub.clearTags":
            clearTags(result: result)
        case "AzNotificationHub.getTags":
            getTags(result: result)
        case "AzNotificationHub.setTemplate":
            setTemplate(body: (call.arguments as! [String:Any?])["body"] as! String, result: result)
        case "AzNotificationHub.removeTemplate":
            removeTemplate(result: result)
        case "AzNotificationHub.getInstallationId":
            getInstallationId(result: result)
        case "AzNotificationHub.getPushChannel":
            getPushChannel(result: result)
        case "AzNotificationHub.getInitialMessage":
            getInitialMessage(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        notificationPresentationCompletionHandler = completionHandler
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 userNotificationCenter didReceive - hasColdStartNotification: \(hasColdStartNotification)")

        // Only set initial notification if we haven't already captured one from cold start
        // This handles the case where the app was in background (not killed)
        if initialNotification == nil {
            let userInfo = response.notification.request.content.userInfo
            initialNotification = formatNotificationForFlutter(userInfo: userInfo, notification: response.notification)
            print("📝 Stored notification from didReceive (background state)")
        }

        notificationResponseCompletionHandler = completionHandler
    }

    public func notificationHub(_ notificationHub: MSNotificationHub, didReceivePushNotification message: MSNotificationHubMessage) {
        print("📨 notificationHub didReceivePushNotification")

        var jsonNotification: [String : Any?] = [:]
        if (message.title != nil) {
            jsonNotification["title"] = message.title
        }
        if (message.body != nil) {
            jsonNotification["body"] = message.body
        }
        jsonNotification["data"] = message.userInfo

        if (notificationResponseCompletionHandler != nil) {
            channel?.invokeMethod("AzNotificationHub.onMessageOpenedApp", arguments: jsonNotification)
        } else if (UIApplication.shared.applicationState == .background || UIApplication.shared.applicationState == .inactive) {
            channel?.invokeMethod("AzNotificationHub.onBackgroundMessage", arguments: jsonNotification)
        } else if (notificationPresentationCompletionHandler != nil) {
            channel?.invokeMethod("AzNotificationHub.onMessage", arguments: jsonNotification)
        }

        // Call & clear notification completion handlers.
        notificationResponseCompletionHandler?()
        notificationResponseCompletionHandler = nil

        notificationPresentationCompletionHandler?([])
        notificationPresentationCompletionHandler = nil
    }

    private func startHubConnection(result: @escaping FlutterResult) {
        let connectionString = Bundle.main.object(forInfoDictionaryKey: "NotificationHubConnectionString") as! String
        let hubName = Bundle.main.object(forInfoDictionaryKey: "NotificationHubName") as! String

        MSNotificationHub.setDelegate(self)
        MSNotificationHub.start(connectionString: connectionString, hubName: hubName)

        result(nil)
    }

    private func addTags(_ tags: [String], result: @escaping FlutterResult) {
        let success = MSNotificationHub.addTags(tags)
        result(success)
    }

    private func removeTags(_ tags: [String], result: @escaping FlutterResult) {
        let success = MSNotificationHub.removeTags(tags)
        result(success)
    }

    private func getTags(result: @escaping FlutterResult) {
        let tags = MSNotificationHub.getTags()
        result(tags)
    }

    private func clearTags(result: @escaping FlutterResult) {
        MSNotificationHub.clearTags()
        result(nil)
    }

    private func setTemplate(body: String, result: @escaping FlutterResult) {
        let template = MSInstallationTemplate()
        template.body = body

        let success = MSNotificationHub.setTemplate(template, forKey: DEFAULT_TEMPLATE_NAME)
        result(success)
    }

    private func removeTemplate(result: @escaping FlutterResult) {
        let success = MSNotificationHub.removeTemplate(forKey: DEFAULT_TEMPLATE_NAME)
        result(success)
    }

    private func getInstallationId(result: @escaping FlutterResult) {
        let installationId = MSNotificationHub.getInstallationId()
        result(installationId)
    }

    private func getPushChannel(result: @escaping FlutterResult) {
        let pushChannel = MSNotificationHub.getPushChannel()
        result(pushChannel)
    }

    private func getInitialMessage(result: @escaping FlutterResult) {
        print("📲 getInitialMessage called - has notification: \(initialNotification != nil)")

        if let notification = initialNotification {
            print("✅ Returning initial notification: \(notification)")
            // Clear the initial notification after returning it so it's not read twice
            initialNotification = nil
            hasColdStartNotification = false
            result(notification)
        } else {
            print("❌ No initial notification available")
            result(nil)
        }
    }

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        print("🚀 didFinishLaunchingWithOptions called")

        // Check if the app was launched from a notification tap (COLD START)
        if let remoteNotification = launchOptions[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            print("🚨 COLD START: App launched from notification")
            print("📦 Raw notification: \(remoteNotification)")

            // Format it properly for Flutter
            initialNotification = formatNotificationForFlutter(userInfo: remoteNotification, notification: nil)
            hasColdStartNotification = true

            print("✅ Stored formatted cold start notification: \(initialNotification ?? [:])")
        } else {
            print("ℹ️ Normal app launch (no notification)")
        }

        return true
    }

    // CRITICAL: Format notification to match what Flutter expects
    private func formatNotificationForFlutter(userInfo: [AnyHashable: Any], notification: UNNotification?) -> [String: Any?] {
        var jsonNotification: [String: Any?] = [:]

        // Extract title and body from APS if available
        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                jsonNotification["title"] = alert["title"] as? String
                jsonNotification["body"] = alert["body"] as? String
            } else if let alert = aps["alert"] as? String {
                jsonNotification["body"] = alert
            }
        }

        // If we have a UNNotification, we can also get content from there
        if let notif = notification {
            if jsonNotification["title"] == nil {
                jsonNotification["title"] = notif.request.content.title
            }
            if jsonNotification["body"] == nil {
                jsonNotification["body"] = notif.request.content.body
            }
        }

        // Build the data structure with customData
        var customData: [String: Any] = [:]
        for (key, value) in userInfo {
            if let stringKey = key as? String, stringKey != "aps" {
                customData[stringKey] = value
            }
        }

        jsonNotification["data"] = ["customData": customData]

        print("📤 Formatted notification for Flutter: \(jsonNotification)")
        return jsonNotification
    }
}