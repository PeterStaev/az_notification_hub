# Azure Notification Hubs Plugin for Flutter

A Flutter plugin to use Azure Notification Hubs

[![Pub Version](https://img.shields.io/pub/v/az_notification_hub)](https://pub.dev/packages/az_notification_hub)

Microsoft Azure Notification Hubs is a scalable push notification engine for quickly sending millions of messages to any mobile platform. You can visit the [developer center](https://learn.microsoft.com/en-us/azure/notification-hubs/) to learn more.

## Getting Started

Before you can integrate Microsoft Azure Notification Hubs in your Flutter project, you need to already have one created in the Azure portal. If you haven't already done this, you can follow the [quick start](https://learn.microsoft.com/en-us/azure/notification-hubs/create-notification-hub-portal) guide provided in the developer center. Also make sure you configure on the Azure portal any platforms to which you intend to send notifications by following the respective guides.

### Android Setup

> [!NOTE]  
> Although you are using Azure Notification Hubs to send your messages, behind the sceenes that uses Firebase Cloud Messaging to deliver the messages to devices. That's why you need to have a configured app in your Firebase console as well.

1. Open the Firebase console and create a project for your Flutter app.
2. Add an Android app and provide all the details the Firebase console asks for the app
3. Download the `google-services.json` file and place it in the `android/app` folder of your Flutter app.

   If you already have an Android app registered with Firebase, then you can download the `google-services.json` by going to the settings of the app on the Firebase console

4. Add the Google Services plugin to the `android/settings.graddle` file of your Flutter app and

```groovy
//....
plugins {
    //....
    id "com.google.gms.google-services" version "4.3.15" apply false
}

include ":app"
```

5. Apply the Google Services plugin to the `android/app/build.gradle` file of your Flutter app

```groovy
plugins {
    //.....
    id "com.google.gms.google-services"
}
```

6. Add the notification hub name and connection string to the `android/app/src/main/AndroidManifest.xml` file of your Flutter app (you can obtain the values from the Azure portal)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="...."
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            ....>
            <!-- ... -->
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
        <meta-data
            android:name="NotificationHubName"
            android:value="....." />
        <meta-data
            android:name="NotificationHubConnectionString"
            android:value="Endpoint=sb://...." />
    </application>
    <!-- ... -->
</manifest>
```

> [!NOTE]  
> This step is not needed if you are using the `startWithHubInfo` method and passing the connection string and hub name to it.

### iOS Setup

1. Add the following code to the `application` method in your Flutter app's `ios/Runner/AppDelegate.swift` or `ios/Runner/AppDelegate.m` file

```swift
// Swift
if #available(iOS 10.0, *) {
    UNUserNotificationCenter.current().delegate = self
}

```

```objc
// Objective-C
if (@available(iOS 10.0, *)) {
  [UNUserNotificationCenter currentNotificationCenter].delegate = self;
}
```

2. In the `ios/Info.plist` file of your Flutter app add values for the notification hub name and connection string

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- .... -->
	<key>NotificationHubConnectionString</key>
	<string>Endpoint=sb://....</string>
	<key>NotificationHubName</key>
	<string>....</string>
    <!-- .... -->
</dict>
</plist>
```

> [!NOTE]  
> This step is not needed if you are using the `startWithHubInfo` method and passing the connection string and hub name to it.

3. Open your Flutter app in XCode and for the `Runner` project, under `Signing & Capabilities` add the `Push Notifications` capability.

   If you also want to handle push notifications while your app is in the background, also add the `Background Modes` capability and tick the `Remote notifications` mode.

## Usage

### Initialization

In order to register the device with the Azure Notification Hub and start receiving messages you need to call the `start()` method. This has to be done as early as possible (preferably in the `main()` method of your Flutter app after Flutter's bindings are initialized) and needs to be awaited before trying to call any other plugin methods. This will also ask for user permission to receive push notifications.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AzureNotificationHub.instance.start();

  runApp(const MyApp());
}
```

If you do not want to put your connection string and hub name in the `AndroidManifest.xml` and `Info.plist` you can use the `startWithHubInfo()` method and pass your connection info there. `

### Handling notifications in the foreground

The plugin exposes an `onMessage` stream on which you can listen. You can have more than one listener in different places of your app, just remember to cancel the subscription once your widget is disposed.

You will receive the push notification as a `Map<String, dynamic>` that has `title` & `body` properties of the notification as well as `data` which is another `Map<String, dynamic>` of all custom properties sent with the notification.

> [!NOTE]  
> On both platforms foreground notifications are silent and are not shown to the user.

### Handling notifications in the background

Unlike foreground, notifications in the background are handled by a callback since on Android it needs to be executed in an isolate. Because of this you also can not update any UI/widget state in this callback, but you should have access to save the data in files/settings/etc.

The callback needs to be globally available and decorated with `@pragma('vm:entry-point')` to prevent Dart's tree shacking from removing it. The adding of the callback needs to happen even before calling start.

```dart
@pragma('vm:entry-point')
Future<void> _onBackgroundMessageReceived(Map<String, dynamic> message) async {
  print('onBackgrounMessage: $message');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AzureNotificationHub.instance.registerBackgroundMessageHandler(_onBackgroundMessageReceived);
  await AzureNotificationHub.instance.start();

  runApp(const MyApp());
}
```

For iOS in order background notifications to work, you need to have enabled the Background Mode for the app with the Remote notification ticked. Also you need to have `"content-available": 1` set in your `aps` JSON payload for the notification:

```json
{
  "aps": {
    "content-available": 1
  },
  "acme1": "bar",
  "acme2": 42
}
```

For more details you can check the [official Apple documentation](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CreatingtheNotificationPayload.html) for notification's payload.

### Getting the notification that caused the app to open

The plugin exposes an `onMessageOpenedApp` stream on which you can listen to get the tapped notification which caused your app to open. Similar to foreground messages you can have multiple listeners. And you will receive a similar object as for a foreground message.

> [!IMPORTANT]  
> The way Android notifications work, when the user taps on the message the `title` and `body` properties are not sent to the native code. If you need to access those properties when the user taps the message, you can also send them in the `data` payload of the notification.

### Managing tags

You can easily manage tags by calling the plugin's `getTags()`, `addTags(...)`, `removeTags(...)` and `clearTags()` methods.

### Managing templates

The plugin currently supports setting a single template with the name hardcoded in the plugin as `FANH DEFAULT TEMPLATE`.

To easily receive cross platform notifications without worrying in your backend about the platform specific payload, it is best you define the template body based on the platform you are currently running on. Then Azure Notification Hubs will handle sending the correct payload for each platform. For example:

```dart
import 'package:flutter/foundation.dart';
import 'package:az_notification_hub/az_notification_hub.dart';

final _platformTemplates = {
  TargetPlatform.android.name: {
    'message': {
      'notification': {
        'title': '\$(title)',
        'body': '\$(body)',
      },
      'data': {
        'title': '\$(title)',
        'body': '\$(body)',
        'extra': '\$(extra)',
      },
    },
  },
  TargetPlatform.iOS.name: {
    'aps': {
      'alert': {
        'title': '\$(title)',
        'body': '\$(body)',
      },
      "sound": "default",
      "content-available": 1,
    },
    'title': '\$(title)',
    'body': '\$(body)',
    'extra': '\$(extra)',
  },
};

Future<bool> _setTemplate() {
    return AzureNotificationHub.instance.setTemplate(
        json.encode(_platformTemplates[defaultTargetPlatform.name]),
    );
}
```

And the JSON payload that needs to be submitted to Azure Notification Hub is:

```json
{
  "title": "Great News1",
  "body": "Notifications actually work",
  "extra": "123"
}
```

For more info about template expressions you check the [official Microsoft documentation](https://learn.microsoft.com/en-us/azure/notification-hubs/notification-hubs-templates-cross-platform-push-messages#template-expression-language).
