import 'package:flutter/services.dart';

import 'shadow_notification_platform_interface.dart';

class ShadowNotification {
  Future<String?> getPlatformVersion() {
    return ShadowNotificationPlatform.instance.getPlatformVersion();
  }

  Future<void> showEnabledNotification() async {
    await ShadowNotificationPlatform.instance.showEnabledNotification();
  }

  Future<void> showAskNotification() async {
    await ShadowNotificationPlatform.instance.showAskNotification();
  }

  Future<void> showAutoWindowFailedNotification() async {
    await ShadowNotificationPlatform.instance.showAutoWindowFailedNotification();
  }

  Future<void> showMeetingWindowNotFoundNotification() async {
    await ShadowNotificationPlatform.instance.showMeetingWindowNotFoundNotification();
  }

  void setNativeCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    ShadowNotificationPlatform.instance.setNativeCallHandler(handler);
  }
}
