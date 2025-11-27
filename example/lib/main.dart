import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shadow_notification/shadow_notification.dart';

void main() {
  runApp(const MyApp());
}

// ### [Swift --> Flutter MethodChannel]
enum NativeMethod { startListen, dismissListen }

enum ListenAction { startListen, dismissListen }

enum ActionTrigger { userAction, timeout }

class ListenStatePayload {
  final ListenAction action;
  final ActionTrigger trigger;

  ListenStatePayload({required this.action, required this.trigger});

  // Map을 DTO 객체로 변환하는 핵심 로직
  factory ListenStatePayload.fromJson(Map<String, dynamic> json) {
    // 필수 키가 없는 경우를 대비한 예외 처리
    if (json['action'] == null || json['trigger'] == null) {
      throw FormatException("Missing required keys: action or trigger");
    }

    try {
      // String 값을 해당하는 Enum 값으로 변환
      final action = ListenAction.values.byName(json['action']);
      final trigger = ActionTrigger.values.byName(json['trigger']);

      return ListenStatePayload(action: action, trigger: trigger);
    } catch (e) {
      // Swift에서 보낸 문자열이 Enum에 정의되지 않은 경우 예외 발생
      throw FormatException("Invalid enum value provided: $e");
    }
  }
}

// 1. 문자열을 Enum으로 변환하는 헬퍼 확장(extension) 추가
extension NativeMethodParser on String {
  NativeMethod? toNativeMethod() {
    // Enum의 모든 값을 순회하며 이름이 일치하는 것을 찾아 반환
    for (var method in NativeMethod.values) {
      if (method.name == this) {
        return method;
      }
    }
    return null; // 일치하는 Enum 값이 없으면 null 반환
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _shadowNotificationPlugin = ShadowNotification();

  @override
  void initState() {
    super.initState();
    _shadowNotificationPlugin.setNativeCallHandler(_handleNativeCall);
    initPlatformState();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    print("Swift에서 호출됨: ${call.method}, arguments: ${call.arguments}, type: ${call.arguments.runtimeType}");

    final method = call.method.toNativeMethod();
    if (method == null) {
      print("Unknown method received: ${call.method}");
      return;
    }

    if (call.arguments is! Map) {
      print("Invalid arguments type: ${call.arguments.runtimeType}");
      return;
    }

    final ListenStatePayload payload;
    try {
      final Map<String, dynamic> eventMap = Map<String, dynamic>.from(call.arguments);
      print("Parsed eventMap: $eventMap, type: ${eventMap.runtimeType}");
      payload = ListenStatePayload.fromJson(eventMap);
      print("Action: ${payload.action}, Trigger: ${payload.trigger}");
    } catch (e) {
      print("네이티브 이벤트 처리 중 에러 발생: $e");
      return;
    }

    switch (method) {
      case NativeMethod.startListen:
        setState(() {
          _platformVersion = 'Native Event: ${payload.action}, ${payload.trigger}';
        });
        break;
      case NativeMethod.dismissListen:
        setState(() {
          _platformVersion = 'Native Event: ${payload.action}, ${payload.trigger}';
        });
        break;
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _shadowNotificationPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Running on: $_platformVersion\n',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _shadowNotificationPlugin.showAskNotification();
                      print('Ask notification shown');
                    } catch (e) {
                      print('Error showing ask notification: $e');
                    }
                  },
                  child: const Text('Test Ask Notification'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _shadowNotificationPlugin.showEnabledNotification();
                      print('Enabled notification shown');
                    } catch (e) {
                      print('Error showing enabled notification: $e');
                    }
                  },
                  child: const Text('Test Enabled Notification'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _shadowNotificationPlugin.showAutoWindowFailedNotification();
                      print('Auto window failed notification shown');
                    } catch (e) {
                      print('Error showing auto window failed notification: $e');
                    }
                  },
                  child: const Text('Test Auto Window Failed'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _shadowNotificationPlugin.showMeetingWindowNotFoundNotification();
                      print('Meeting window not found notification shown');
                    } catch (e) {
                      print('Error showing meeting window not found notification: $e');
                    }
                  },
                  child: const Text('Test Meeting Window Not Found'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
