// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

String get webNotifPermission => html.Notification.permission ?? 'default';

Future<String> requestWebNotifPermission() async {
  try {
    if (html.Notification.permission == 'granted') return 'granted';
    return await html.Notification.requestPermission();
  } catch (_) {
    return 'denied';
  }
}
bool showWebNotif({required String title, required String body, String? tag}) {
  try {
    if (html.Notification.permission != 'granted') return false;
    html.Notification(title, body: body, tag: tag);
    return true;
  } catch (_) {
    return false;
  }
}
