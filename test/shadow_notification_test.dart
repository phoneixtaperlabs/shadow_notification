import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_notification/shadow_notification.dart';
import 'package:shadow_notification/shadow_notification_platform_interface.dart';
import 'package:shadow_notification/shadow_notification_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockShadowNotificationPlatform
    with MockPlatformInterfaceMixin
    implements ShadowNotificationPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ShadowNotificationPlatform initialPlatform = ShadowNotificationPlatform.instance;

  test('$MethodChannelShadowNotification is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelShadowNotification>());
  });

  test('getPlatformVersion', () async {
    ShadowNotification shadowNotificationPlugin = ShadowNotification();
    MockShadowNotificationPlatform fakePlatform = MockShadowNotificationPlatform();
    ShadowNotificationPlatform.instance = fakePlatform;

    expect(await shadowNotificationPlugin.getPlatformVersion(), '42');
  });
}
