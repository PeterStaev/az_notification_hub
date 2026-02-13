import Flutter
import UIKit
import WindowsAzureMessaging
import Foundation

let DEFAULT_TEMPLATE_NAME = "FANH DEFAULT TEMPLATE"

public class AzureNotificationHubPlugin: NSObject, FlutterPlugin, MSNotificationHubDelegate {
    private var channel: FlutterMethodChannel?
    private var notificationResponseCompletionHandler: (() -> Void)?
    private var notificationPresentationCompletionHandler: ((UNNotificationPresentationOptions) -> Void)?
    
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
        case "AzNotificationHub.startWithHubInfo":
            startHubConnectionWithHubInfo(connectionString: (call.arguments as! [String:Any?])["connectionString"] as! String, hubName: (call.arguments as! [String:Any?])["hubName"] as! String, result: result)
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
        case "AzNotificationHub.setUserId":
            setUserId(userId: (call.arguments as! [String:Any?])["userId"] as! String, result: result)
        case "AzNotificationHub.getUserId":
            getUserId(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        notificationPresentationCompletionHandler = completionHandler
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        notificationResponseCompletionHandler = completionHandler
    }
    
    public func notificationHub(_ notificationHub: MSNotificationHub, didReceivePushNotification message: MSNotificationHubMessage) {
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
        } else if (notificationPresentationCompletionHandler != nil) { // This is needed as when "content-available" is 1, we get the message 2 times
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

    private func startHubConnectionWithHubInfo(connectionString: String, hubName: String, result: @escaping FlutterResult) {
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
    
    private func setUserId(userId: String, result: @escaping FlutterResult) {
        // Note: iOS SDK's setUserId() returns void, unlike Android which returns boolean.
        // Therefore, we always return true to indicate the method was called successfully.
        MSNotificationHub.setUserId(userId)
        result(true)
    }
    
    private func getUserId(result: @escaping FlutterResult) {
        let userId = MSNotificationHub.getUserId()
        result(userId ?? "")
    }
    
}
