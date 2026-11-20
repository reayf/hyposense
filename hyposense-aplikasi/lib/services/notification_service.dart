import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifikasi alarm native (Tahap 5). Berbunyi + bergetar walau app di
/// latar belakang / layar terkunci — beda dari SystemSound yang hanya
/// jalan saat app di depan.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // v2: channel Android tidak bisa diubah setelah dibuat — ID baru agar
  // setelan "volume alarm" (audioAttributesUsage) berlaku.
  static const String _alarmChannelId = 'hyposense_alarm_v2';
  static const String _alarmChannelName = 'Alarm Risiko Hipoglikemia';
  static const int _alarmId = 1001;
  static bool _inited = false;

  // Pola getar kuat & berulang (ms): jeda, getar, jeda, getar, ...
  static final Int64List _vibrate =
      Int64List.fromList([0, 600, 300, 600, 300, 600]);

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Channel importance MAX -> notifikasi heads-up + bunyi walau terkunci.
    await android?.createNotificationChannel(AndroidNotificationChannel(
      _alarmChannelId,
      _alarmChannelName,
      description: 'Peringatan saat risiko hipoglikemia terdeteksi',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrate,
      audioAttributesUsage: AudioAttributesUsage.alarm, // volume ALARM (keras)
    ));

    try {
      await android?.requestNotificationsPermission();     // Android 13+
      await android?.requestFullScreenIntentPermission();  // Android 14+
    } catch (_) {}
  }

  /// Tampilkan alarm (persisten sampai di-cancel).
  static Future<void> showAlarm(String title, String body) async {
    final details = AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true, // tampil & bangunkan di lock screen
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrate,
      audioAttributesUsage: AudioAttributesUsage.alarm, // volume ALARM (keras)
      ongoing: true,
      autoCancel: false,
    );
    await _plugin.show(
      id: _alarmId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  static Future<void> cancelAlarm() async {
    await _plugin.cancel(id: _alarmId);
  }
}
