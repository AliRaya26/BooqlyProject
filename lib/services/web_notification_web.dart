// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation using the browser Notification API.
class WebNotificationService {
  WebNotificationService._();

  static Future<bool> requestPermission() async {
    // ignore: deprecated_member_use
    if (html.Notification.supported != true) return false;
    // ignore: deprecated_member_use
    if (html.Notification.permission == 'granted') return true;
    // ignore: deprecated_member_use
    final result = await html.Notification.requestPermission();
    return result == 'granted';
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    // ignore: deprecated_member_use
    if (html.Notification.supported != true) return;
    // ignore: deprecated_member_use
    if (html.Notification.permission != 'granted') {
      // ignore: deprecated_member_use
      final result = await html.Notification.requestPermission();
      if (result != 'granted') return;
    }
    // ignore: deprecated_member_use
    html.Notification(
      title,
      body: body,
      icon: '/icons/Icon-192.png',
    );
  }
}
