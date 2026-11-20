import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'alert_js.dart' as alert_js;
import 'ble_service.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'settings_controller.dart';

/// Memicu alarm risiko hipoglikemia di HP pasien (Tahap 5a) dan eskalasi
/// ke perawat (Tahap 5b).
///
/// Sumber sinyal risiko:
///  - **event BLE** dari gelang (utama; langsung, jalan offline)
///  - **cloud readings** (fallback + memudahkan pengujian via SQL)
///
/// Preferensi user dihormati: enable_alarm (master), risk_alert_level
/// ('high' = bunyi berulang), alert_method.
/// Tingkatan alarm.
///  - [napas]  : gelang menemukan anomali detak dan SEDANG memanaskan sensor
///               gas (~60 dtk). Tugas alarm ini MEMBANGUNKAN pengguna supaya
///               siap menghembuskan napas — karena itu selalu berulang.
///  - [bahaya] : hasil akhir menunjukkan risiko.
enum AlarmKind { none, napas, bahaya }

class AlertService extends ChangeNotifier {
  AlertService._();
  static final AlertService instance = AlertService._();

  static const Duration _escalateAfter = Duration(minutes: 5);
  static const Duration _dismissCooldown = Duration(minutes: 3);
  /// Pengaman: bila vonis napas tak kunjung datang (mis. BLE putus di tengah
  /// pemanasan), alarm pengingat napas berhenti sendiri agar tak berbunyi
  /// selamanya. Pemanasan 60 dtk + prompt + ukur ~90 dtk, jadi 3 menit cukup.
  static const Duration _napasTimeout = Duration(minutes: 3);

  StreamSubscription<Reading?>? _cloudSub;
  Timer? _repeat;
  Timer? _escalateTimer;
  Timer? _napasTimer;

  AlarmKind alarmKind = AlarmKind.none;
  bool get alarmActive => alarmKind != AlarmKind.none;
  bool get isBreathPrompt => alarmKind == AlarmKind.napas;

  DateTime? _lastBleEventAt;
  DateTime? _dismissedUntil;

  /// Selama sesi uji klinik, event dari gelang TIDAK membunyikan alarm.
  ///
  /// Pengaman lapis kedua: gelang dengan firmware terbaru sudah berhenti
  /// mengirim vonis dalam mode uji, tetapi gelang yang belum diperbarui masih
  /// mengirim "risiko" setiap kali petugas meminta cek napas. Tanpa pengaman
  /// ini, alarm layar penuh berbunyi berulang di depan pasien.
  bool _modeUjiKlinik = false;

  void setModeUjiKlinik(bool aktif) {
    _modeUjiKlinik = aktif;
    if (aktif && alarmActive) _silence();
  }

  void start() {
    BleService.instance.addListener(_onBle);
    _cloudSub ??= DatabaseService()
        .latestReadingStream()
        .listen(_onCloud, onError: (_) {});
  }

  Future<void> stop() async {
    BleService.instance.removeListener(_onBle);
    await _cloudSub?.cancel();
    _cloudSub = null;
    _silence();
  }

  // ── Sumber sinyal ────────────────────────────────────────────
  void _onBle() {
    final ble = BleService.instance;
    final at = ble.eventAt;
    if (at == null || at == _lastBleEventAt) return; // hanya event BARU
    _lastBleEventAt = at;
    if (_modeUjiKlinik) return;
    switch (ble.lastEvent?['risk']?.toString()) {
      case 'risiko':   // anomali detak — gelang mulai memanaskan sensor gas
        _evaluate(AlarmKind.napas);
        break;
      case 'positif':  // vonis akhir: berisiko
        _evaluate(AlarmKind.bahaya);
        break;
      case 'negatif':  // vonis akhir: aman -> cukup hentikan pengingat napas
        if (alarmKind == AlarmKind.napas) _silence();
        break;
    }
  }

  void _onCloud(Reading? r) {
    if (r != null && r.isPositif) _evaluate(AlarmKind.bahaya);
  }

  void _evaluate(AlarmKind kind) {
    final enabled = SettingsController.instance.settings?.enableAlarm ?? true;
    if (!enabled) return;
    if (alarmKind == kind) return;              // sudah berbunyi di tingkat ini
    if (alarmKind == AlarmKind.bahaya) return;  // sudah di tingkat tertinggi
    if (_dismissedUntil != null &&
        DateTime.now().isBefore(_dismissedUntil!)) {
      return; // baru saja ditutup — jangan langsung berbunyi lagi
    }
    _startAlarm(kind);   // 'bahaya' boleh menimpa 'napas' (naik tingkat)
  }

  // ── Alarm ────────────────────────────────────────────────────
  void _startAlarm(AlarmKind kind) {
    alarmKind = kind;
    final s = SettingsController.instance.settings;
    _fire(s);
    _logRiskEvent(
        'DANGER',
        kind == AlarmKind.napas
            ? 'Anomali detak jantung — pengguna diminta menghembuskan napas'
            : 'Risiko hipoglikemia terdeteksi gelang');

    // Pengingat napas SELALU berulang apa pun setelan levelnya: tujuannya
    // membangunkan orang yang sedang tidur, jadi sekali bunyi tak cukup.
    final berulang = kind == AlarmKind.napas ||
        (s?.riskAlertLevel ?? 'moderate') == 'high';
    _repeat?.cancel();
    if (berulang) {
      _repeat = Timer.periodic(
          const Duration(seconds: 4), (_) => _fire(s));
    }

    _napasTimer?.cancel();
    if (kind == AlarmKind.napas) {
      _napasTimer = Timer(_napasTimeout, () {
        if (alarmKind == AlarmKind.napas) _silence();
      });
    }

    // Eskalasi ke perawat jika tak direspons dalam 5 menit.
    _escalateTimer?.cancel();
    _escalateTimer = Timer(_escalateAfter, _escalate);

    notifyListeners();
  }

  void _fire(UserSettings? s) {
    final napas = alarmKind == AlarmKind.napas;
    // Notifikasi native = bunyi + getar walau app di background/terkunci.
    NotificationService.showAlarm(
      napas ? 'Bangun — Cek Napas!' : 'Risiko Hipoglikemia!',
      napas
          ? 'Detak jantung menyimpang. Buka katup lalu hembuskan napas ke '
              'sensor saat diminta gelang.'
          : 'Segera cek gula darah & konsumsi karbohidrat cepat.',
    );
    // Umpan balik tambahan saat app di depan.
    if (s?.alertMethod != 'notification') alert_js.playVibrate();
    if ((s?.alertMethod ?? 'sound') == 'sound') alert_js.playBeep();
  }

  /// Catat kejadian ke risk_logs (riwayat yang dilihat perawat).
  /// Hanya untuk akun pasien.
  void _logRiskEvent(String status, String message) {
    if (SettingsController.instance.role != 'patient') return;
    Future(() async {
      try {
        await DatabaseService()
            .addRiskLog(riskStatus: status, message: message);
      } catch (_) {}
    });
  }

  /// Pasien tak merespons dalam 5 menit -> catat eskalasi agar perawat tahu.
  void _escalate() {
    if (!alarmActive) return;
    _logRiskEvent('DANGER',
        'ESKALASI: pasien tidak merespons alarm selama 5 menit');
  }

  /// Pasien menekan "Tutup" — hentikan alarm, beri jeda agar tidak
  /// langsung berbunyi lagi dari sinyal yang sama.
  void dismiss() {
    _dismissedUntil = DateTime.now().add(_dismissCooldown);
    _silence();
  }

  void _silence() {
    alarmKind = AlarmKind.none;
    _repeat?.cancel();
    _repeat = null;
    _escalateTimer?.cancel();
    _escalateTimer = null;
    _napasTimer?.cancel();
    _napasTimer = null;
    NotificationService.cancelAlarm();
    notifyListeners();
  }

  void callEmergency(String number) => alert_js.openTel(number);

  /// Buka app SMS dengan nomor kontak darurat dan isi pesan otomatis.
  /// [patientName] digunakan untuk personalisasi isi pesan.
  void sendEmergencySms(String number, {String patientName = ''}) {
    final name = patientName.isNotEmpty ? patientName : 'Pasien';
    final body =
        '⚠️ DARURAT: $name terdeteksi risiko hipoglikemia oleh HypoSense. '
        'Mohon segera hubungi atau kunjungi!';
    alert_js.openSms(number, body);
  }
}
