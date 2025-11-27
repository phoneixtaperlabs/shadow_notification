import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'shadow_notification_platform_interface.dart';

/// An implementation of [ShadowNotificationPlatform] that uses method channels.
class MethodChannelShadowNotification extends ShadowNotificationPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('shadow_notification');

  @override
  Future<void> showEnabledNotification() async {
    await methodChannel.invokeMethod('showEnabledNotification');
  }

  @override
  Future<void> showAskNotification() async {
    await methodChannel.invokeMethod('showAskNotification');
  }

  @override
  Future<void> showAutoWindowFailedNotification() async {
    await methodChannel.invokeMethod('showAutoWindowFailedNotification');
  }

  @override
  Future<void> showMeetingWindowNotFoundNotification() async {
    await methodChannel.invokeMethod('showMeetingWindowNotFoundNotification');
  }

  // 새로 추가: Swift에서 오는 호출을 받기 위한 메서드
  @override
  void setNativeCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    methodChannel.setMethodCallHandler(handler);
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
