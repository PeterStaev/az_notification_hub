import 'package:permission_handler/permission_handler.dart';

import 'az_notification_hub_platform_interface.dart';

/// The entry point for [AzureNotificationHub].
///
/// Use [AzureNotificationHub.instance] to access the methods and events of the plugin.
class AzureNotificationHub {
  static final _instance = AzureNotificationHub();

  /// The default instance of [AzureNotificationHub] to use.
  static AzureNotificationHub get instance => _instance;

  /// [Stream] for messages received while the app is in the foreground.
  Stream<Map<String, dynamic>> get onMessage =>
      AzureNotificationHubPlatform.onMessage.stream;

  /// [Stream] for message that caused the app to open.
  Stream<Map<String, dynamic>> get onMessageOpenedApp =>
      AzureNotificationHubPlatform.onMessageOpenedApp.stream;

  /// Registers a callback to handle background messages.
  Future<void> registerBackgroundMessageHandler(
      BackgroundMessageHandler handler) {
    return AzureNotificationHubPlatform.instance
        .registerBackgroundMessageHandler(handler);
  }

  /// Intializes the plugin and requests notification permissions.
  Future<void> start() async {
    await Permission.notification.request();

    return await AzureNotificationHubPlatform.instance.start();
  }

  /// Add tags for the device. If one of the tags already exists, it will be ignored.
  Future<bool> addTags(List<String> tags) {
    return AzureNotificationHubPlatform.instance.addTags(tags);
  }

  /// Get the tags that are currently set for the device.
  Future<List<String>> getTags() {
    return AzureNotificationHubPlatform.instance.getTags();
  }

  /// Remove specific tags from the device.
  Future<bool> removeTags(List<String> tags) {
    return AzureNotificationHubPlatform.instance.removeTags(tags);
  }

  /// Clear all tags from the device.
  Future<void> clearTags() {
    return AzureNotificationHubPlatform.instance.clearTags();
  }

  /// Set a notification template to be used for this device.
  Future<bool> setTemplate(String body) {
    return AzureNotificationHubPlatform.instance.setTemplate(body);
  }

  /// Remove the notification template from this device.
  Future<bool> removeTemplate() {
    return AzureNotificationHubPlatform.instance.removeTemplate();
  }

  /// Get the installation ID for the device.
  Future<String> getInstallationId() {
    return AzureNotificationHubPlatform.instance.getInstallationId();
  }

  /// Get the push channel for the device.
  Future<String> getPushChannel() {
    return AzureNotificationHubPlatform.instance.getPushChannel();
  }
}
