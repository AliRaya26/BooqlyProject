/// Stub for non-web platforms. All methods are no-ops.
class WebNotificationService {
  WebNotificationService._();

  static Future<bool> requestPermission() async => false;

  static Future<void> show({
    required String title,
    required String body,
  }) async {}
}
