// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

@pragma('vm:entry-point')
Future<void> _onBackgroundMessageReceived(Map<String, dynamic> message) async {
  print('onBackgrounMessage: $message');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('main');
  AzureNotificationHub.instance
      .registerBackgroundMessageHandler(_onBackgroundMessageReceived);
  await AzureNotificationHub.instance.start();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _tagController = TextEditingController();
  late StreamSubscription<Map<String, Object?>> _messageSubscription;
  late StreamSubscription<Map<String, Object?>> _messageOpenedAppSubscription;
  late Future<List<String>> _tagsFuture;
  late Future<String> _installationIdFuture;
  late Future<String> _pushChannelFuture;
  bool _isSettingTemplateIn = false;
  bool _isRemovingTemplateIn = false;

  @override
  void initState() {
    super.initState();
    _messageSubscription =
        AzureNotificationHub.instance.onMessage.listen((message) {
      print('onMessage: $message');
    });
    _messageOpenedAppSubscription =
        AzureNotificationHub.instance.onMessageOpenedApp.listen((message) {
      print('Opened App: $message');
    });

    _tagsFuture = AzureNotificationHub.instance.getTags();
    _installationIdFuture = AzureNotificationHub.instance.getInstallationId();
    _pushChannelFuture = AzureNotificationHub.instance.getPushChannel();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _messageOpenedAppSubscription.cancel();
    _tagController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('AZ Notification Hub'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                "Installation ID",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              FutureBuilder(
                future: _installationIdFuture,
                builder: (context, snapshot) {
                  return switch (snapshot) {
                    (AsyncSnapshot<String> s) when s.hasData => SelectableText(s.data!),
                    (AsyncSnapshot<String> s) when s.hasError => Text('${s.error}'),
                    _ => const Text('?'),
                  };
                },
              ),
              const SizedBox(height: 16),
              Text(
                "Push Channel",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              FutureBuilder(
                future: _pushChannelFuture,
                builder: (context, snapshot) {
                  return switch (snapshot) {
                    (AsyncSnapshot<String> s) when s.hasData => SelectableText(s.data!),
                    (AsyncSnapshot<String> s) when s.hasError => Text('${s.error}'),
                    _ => const Text('?'),
                  };
                },
              ),
              Text("Tags", style: Theme.of(context).textTheme.headlineLarge),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'New Tag'),
                      controller: _tagController,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await AzureNotificationHub.instance
                            .addTags([_tagController.text]);
                        setState(() {
                          _tagsFuture = AzureNotificationHub.instance.getTags();
                          _tagController.clear();
                        });
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: const Text('Add'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await AzureNotificationHub.instance.clearTags();
                        setState(() {
                          _tagsFuture = AzureNotificationHub.instance.getTags();
                          _tagController.clear();
                        });
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: const Text('Clear Tags'),
                  ),
                ],
              ),
              FutureBuilder(
                future: _tagsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  final tags = snapshot.data as List<String>;

                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: tags.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(tags[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await AzureNotificationHub.instance
                                .removeTags([tags[index]]);
                            setState(() {
                              _tagsFuture =
                                  AzureNotificationHub.instance.getTags();
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Text("Template",
                  style: Theme.of(context).textTheme.headlineLarge),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        setState(() {
                          _isSettingTemplateIn = true;
                        });
                        await AzureNotificationHub.instance.setTemplate(
                            json.encode(_platformTemplates[
                                defaultTargetPlatform.name]));
                      } catch (e) {
                        print(e);
                      } finally {
                        setState(() {
                          _isSettingTemplateIn = false;
                        });
                      }
                    },
                    child: _isSettingTemplateIn
                        ? const CircularProgressIndicator()
                        : const Text('Set Template'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        setState(() {
                          _isRemovingTemplateIn = true;
                        });
                        await AzureNotificationHub.instance.removeTemplate();
                      } catch (e) {
                        print(e);
                      } finally {
                        setState(() {
                          _isRemovingTemplateIn = false;
                        });
                      }
                    },
                    child: _isRemovingTemplateIn
                        ? const CircularProgressIndicator()
                        : const Text('Remove Template'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
