import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'shadow_notification_method_channel.dart';

abstract class ShadowNotificationPlatform extends PlatformInterface {
  /// Constructs a ShadowNotificationPlatform.
  ShadowNotificationPlatform() : super(token: _token);

  static final Object _token = Object();

  static ShadowNotificationPlatform _instance = MethodChannelShadowNotification();

  /// The default instance of [ShadowNotificationPlatform] to use.
  ///
  /// Defaults to [MethodChannelShadowNotification].
  static ShadowNotificationPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ShadowNotificationPlatform] when
  /// they register themselves.
  static set instance(ShadowNotificationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> showEnabledNotification() async {
    throw UnimplementedError('showEnabledNotification() has not been implemented.');
  }

  Future<void> showAskNotification() async {
    throw UnimplementedError('showAskNotification() has not been implemented.');
  }

  Future<void> showGoogleMeetWindowFailedNotification() async {
    throw UnimplementedError('showGoogleMeetWindowFailedNotification() has not been implemented.');
  }

  Future<void> showAutoWindowFailedNotification() async {
    throw UnimplementedError('showAutoWindowFailedNotification() has not been implemented.');
  }

  Future<void> showMeetingWindowNotFoundNotification() async {
    throw UnimplementedError('showMeetingWindowNotFoundNotification() has not been implemented.');
  }

  Future<void> showUpcomingEventNoti(Map<String, dynamic>? params) async {
    throw UnimplementedError('showUpcomingEventNoti() has not been implemented.');
  }

  Future<void> showInactiveNoti(Map<String, dynamic>? params) async {
    throw UnimplementedError('showInactiveNoti() has not been implemented.');
  }

  void setNativeCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    throw UnimplementedError('setNativeCallHandler() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
