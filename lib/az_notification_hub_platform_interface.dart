import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'az_notification_hub_method_channel.dart';

/// The method signature for the background message handler.
typedef BackgroundMessageHandler = Future<void> Function(
    Map<String, dynamic> message);

/// Base class for the AzureNotificationHub platform interface.
abstract class AzureNotificationHubPlatform extends PlatformInterface {
  /// Constructs a AzureNotificationHubPlatform.
  AzureNotificationHubPlatform() : super(token: _token);

  static final Object _token = Object();

  static AzureNotificationHubPlatform _instance =
      MethodChannelAzureNotificationHub();

  /// The default instance of [AzureNotificationHubPlatform] to use.
  ///
  /// Defaults to [MethodChannelAzureNotificationHub].
  static AzureNotificationHubPlatform get instance => _instance;

  /// [StreamController] for adding messages received while the app is in the foreground.
  static final StreamController<Map<String, dynamic>> onMessage =
      StreamController<Map<String, dynamic>>.broadcast();

  /// [StreamController] for adding message that caused the app to open.
  static final StreamController<Map<String, dynamic>> onMessageOpenedApp =
      StreamController<Map<String, dynamic>>.broadcast(
    onListen: () async {
      final initialMessage = await instance.getInitialMessage();
      if (initialMessage != null) {
        onMessageOpenedApp.add(initialMessage);
      }
    },
  );

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AzureNotificationHubPlatform] when
  /// they register themselves.
  static set instance(AzureNotificationHubPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Registers a callback to handle background messages.
  ///
  /// For Android this uses isolates and requires a top level function.
  Future<void> registerBackgroundMessageHandler(
      BackgroundMessageHandler handler) {
    throw UnimplementedError(
        'registerBackgroundMessageHandler() has not been implemented.');
  }

  /// Intializes the plugin and requests notification permissions.
  Future<void> start() {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Add tags for the device. If one of the tags already exists, it will be ignored.
  Future<bool> addTags(List<String> tags) {
    throw UnimplementedError('addTags() has not been implemented.');
  }

  /// Get the tags that are currently set for the device.
  Future<List<String>> getTags() {
    throw UnimplementedError('getTags() has not been implemented.');
  }

  /// Remove specific tags from the device.
  Future<bool> removeTags(List<String> tags) {
    throw UnimplementedError('removeTags() has not been implemented.');
  }

  /// Clear all tags from the device.
  Future<void> clearTags() {
    throw UnimplementedError('clearTags() has not been implemented.');
  }

  /// Set a notification template to be used for this device.
  Future<bool> setTemplate(String body) {
    throw UnimplementedError('setTemplate() has not been implemented.');
  }

  /// Remove the notification template from this device.
  Future<bool> removeTemplate() {
    throw UnimplementedError('removeTemplate() has not been implemented.');
  }

  /// Get the initial message that caused the app to open.
  ///
  /// Usable only for Android  and will have a value only if the app was terminated and the user clicked on a notification.
  Future<Map<String, dynamic>?> getInitialMessage() {
    throw UnimplementedError('getInitialMessage() has not been implemented.');
  }

  /// Get the installation ID for the device.
  Future<String> getInstallationId() {
    throw UnimplementedError('getInstallationId() has not been implemented.');
  }

  /// Get the push channel for the device.
  Future<String> getPushChannel() {
    throw UnimplementedError('getPushChannel() has not been implemented.');
  }
}
