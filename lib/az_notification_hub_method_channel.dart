import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'az_notification_hub_platform_interface.dart';

@pragma('vm:entry-point')
void _messagingCallbackDispatcher() {
  // Initialize state necessary for MethodChannels.
  WidgetsFlutterBinding.ensureInitialized();

  const MethodChannel bgChannel =
      MethodChannel('plugins.flutter.io/azure_notification_hub_background');

  // This is where we handle background events from the native portion of the plugin.
  bgChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'AzRemoteMessageBackgroundWorker.onMessage') {
      final CallbackHandle handle =
          CallbackHandle.fromRawHandle(call.arguments['userCallbackHandle']);

      // PluginUtilities.getCallbackFromHandle performs a lookup based on the
      // callback handle and returns a tear-off of the original callback.
      final closure = PluginUtilities.getCallbackFromHandle(handle)!
          as BackgroundMessageHandler;

      try {
        await closure(Map<String, dynamic>.from(call.arguments['message']));
      } catch (e) {
        // ignore: avoid_print
        print('FANH: An error occurred in your background messaging handler:');
        // ignore: avoid_print
        print(e);
      }
    } else {
      throw UnimplementedError('${call.method} has not been implemented');
    }
  });

  // Once we've finished initializing, let the native portion of the plugin
  // know that it can start scheduling alarms.
  bgChannel.invokeMethod<void>('AzRemoteMessageBackgroundWorker.initialized');
}

/// An implementation of [AzureNotificationHubPlatform] that uses method channels.
class MethodChannelAzureNotificationHub extends AzureNotificationHubPlatform {
  static bool _bgHandlerInitialized = false;

  BackgroundMessageHandler? _onBackgroundMessage;

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel =
      const MethodChannel('plugins.flutter.io/azure_notification_hub');

  /// Creates an instance of [AzureNotificationHubPlatform] that uses method channels.
  MethodChannelAzureNotificationHub() {
    methodChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'AzNotificationHub.onMessage':
          AzureNotificationHubPlatform.onMessage
              .add(Map<String, dynamic>.from(call.arguments));
          break;
        case 'AzNotificationHub.onMessageOpenedApp':
          AzureNotificationHubPlatform.onMessageOpenedApp
              .add(Map<String, dynamic>.from(call.arguments));
          break;
        case 'AzNotificationHub.onBackgroundMessage':
          // iOS only! Android uses an isolate.
          _onBackgroundMessage?.call(Map<String, dynamic>.from(call.arguments));
          break;
        default:
          throw UnimplementedError('${call.method} has not been implemented');
      }
    });
  }

  @override
  Future<void> registerBackgroundMessageHandler(
      BackgroundMessageHandler handler) async {
    _onBackgroundMessage = handler;

    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!_bgHandlerInitialized) {
      _bgHandlerInitialized = true;
      final CallbackHandle bgHandle =
          PluginUtilities.getCallbackHandle(_messagingCallbackDispatcher)!;
      final CallbackHandle userHandle =
          PluginUtilities.getCallbackHandle(handler)!;
      await methodChannel.invokeMethod(
        'AzNotificationHub.startBackgroundIsolate',
        {
          'pluginCallbackHandle': bgHandle.toRawHandle(),
          'userCallbackHandle': userHandle.toRawHandle(),
        },
      );
    }
  }

  @override
  Future<void> start() {
    return methodChannel.invokeMethod<void>('AzNotificationHub.start');
  }

  @override
  Future<bool> addTags(List<String> tags) async {
    final success = await methodChannel
        .invokeMethod<bool>('AzNotificationHub.addTags', {'tags': tags});
    return success ?? false;
  }

  @override
  Future<List<String>> getTags() async {
    final tags = await methodChannel
        .invokeListMethod<String>('AzNotificationHub.getTags');
    return tags ?? [];
  }

  @override
  Future<bool> removeTags(List<String> tags) async {
    final success = await methodChannel
        .invokeMethod<bool>('AzNotificationHub.removeTags', {'tags': tags});
    return success ?? false;
  }

  @override
  Future<void> clearTags() {
    return methodChannel.invokeMethod<bool>('AzNotificationHub.clearTags');
  }

  @override
  Future<bool> setTemplate(String body) async {
    final success = await methodChannel
        .invokeMethod<bool>('AzNotificationHub.setTemplate', {'body': body});
    return success ?? false;
  }

  @override
  Future<bool> removeTemplate() async {
    final success = await methodChannel
        .invokeMethod<bool>('AzNotificationHub.removeTemplate');
    return success ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getInitialMessage() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Future.value(null);
    }

    final result =
        await methodChannel.invokeMethod('AzNotificationHub.getInitialMessage');
    return result == null ? result : Map<String, dynamic>.from(result);
  }

  @override
  Future<String> getInstallationId() async {
    final result = await methodChannel.invokeMethod<String>(
      'AzNotificationHub.getInstallationId',
    );
    return result ?? '';
  }

  @override
  Future<String> getPushChannel() async {
    final result = await methodChannel.invokeMethod<String>(
      'AzNotificationHub.getPushChannel',
    );
    return result ?? '';
  }
}
