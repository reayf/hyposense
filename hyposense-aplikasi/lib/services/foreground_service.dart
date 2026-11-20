import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Callback foreground service (berjalan di isolate terpisah).
/// Kerja BLE + relay tetap di isolate UTAMA — yang tetap hidup selama
/// foreground service menjaga proses app tidak dimatikan Android.
/// TaskHandler ini sengaja minimal (cuma menjaga service tetap ada).
@pragma('vm:entry-point')
void hypoForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_HypoTaskHandler());
}

class _HypoTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Pembungkus foreground service HypoSense (Tahap 4).
/// Menjaga koneksi BLE + relay tetap jalan saat app ditutup/layar terkunci.
class ForegroundServiceHelper {
  static bool _inited = false;

  static void _initOptions() {
    if (_inited) return;
    _inited = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hyposense_monitor',
        channelName: 'HypoSense Monitoring',
        channelDescription: 'Menjaga koneksi gelang tetap aktif',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Minta izin notifikasi (wajib untuk notif service di Android 13+) dan
  /// pengecualian optimasi baterai (agar sistem tidak mematikan app saat tidur).
  static Future<void> requestPermissions() async {
    final noti = await FlutterForegroundTask.checkNotificationPermission();
    if (noti != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> start() async {
    _initOptions();
    await requestPermissions();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: [ForegroundServiceTypes.connectedDevice],
      notificationTitle: 'HypoSense aktif',
      notificationText: 'Memantau gelang di latar belakang',
      callback: hypoForegroundCallback,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
