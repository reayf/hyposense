import 'dart:convert';

import 'package:hyposense/services/ble_service.dart';
import 'package:hyposense/services/database_service.dart';
import 'package:hyposense/services/settings_controller.dart';

/// Tahap 3: meneruskan data BLE dari gelang ke Supabase, supaya perawat
/// bisa memantau + jadi riwayat.
///  - data rutin (live): throttle 1 insert / 30 dtk
///  - event risiko: dikirim segera
///  - saat internet putus: baris diantre di memori, dikirim ulang saat
///    berhasil lagi (buffer lapis HP↔internet)
/// Hanya aktif untuk akun berperan 'patient' (HP pasien yang pegang gelang).
class CloudRelayService {
  CloudRelayService._();
  static final CloudRelayService instance = CloudRelayService._();

  final _db = DatabaseService();

  // Diperpendek 30 -> 15 detik, dan angkanya mengikuti ukuran penyangga IBI di
  // firmware. Gelang menyimpan 16 selang antar-denyut terakhir; pada 60 bpm itu
  // setara ~16 detik. Dengan jeda 30 detik, separuh denyut tiap selang TIDAK
  // pernah terkirim — dan bagi analisis PRV, deret yang bolong sama saja dengan
  // deret yang hilang. Pada 15 detik cakupannya nyaris utuh.
  //
  // Biayanya masih ringan: ~4 baris/menit, sekitar 1.900 baris untuk satu malam
  // delapan jam.
  static const _routineInterval = Duration(seconds: 15);

  bool _running = false;
  bool _flushing = false;
  DateTime? _lastLiveSeen;
  DateTime? _lastEventSeen;
  DateTime? _lastRoutineInsert;
  final List<Map<String, dynamic>> _pending = [];

  int get pendingCount => _pending.length;

  void start() {
    if (_running) return;
    _running = true;
    BleService.instance.addListener(_onBle);
  }

  void stop() {
    BleService.instance.removeListener(_onBle);
    _running = false;
    _pending.clear();
    _lastLiveSeen = null;
    _lastEventSeen = null;
    _lastRoutineInsert = null;
  }

  void _onBle() {
    final ble = BleService.instance;
    if (!ble.isConnected) return;
    if (SettingsController.instance.role != 'patient') return;
    // Hormati saklar "simpan data ke cloud" di Pengaturan. Sebelumnya saklar
    // ini tersimpan tapi tak pernah diperiksa di sini, sehingga data tetap
    // terkirim walau dimatikan — termasuk saat sesi kalibrasi/uji alat yang
    // datanya belum layak masuk riwayat.
    if (!SettingsController.instance.saveToCloud) return;

    // Event risiko baru -> kirim segera
    if (ble.eventAt != null && ble.eventAt != _lastEventSeen) {
      _lastEventSeen = ble.eventAt;
      _enqueue(ble, fromEvent: true);
    }

    // Data live baru -> throttle 30 dtk
    if (ble.liveAt != null && ble.liveAt != _lastLiveSeen) {
      _lastLiveSeen = ble.liveAt;
      final now = DateTime.now();
      if (_lastRoutineInsert == null ||
          now.difference(_lastRoutineInsert!) >= _routineInterval) {
        _lastRoutineInsert = now;
        _enqueue(ble, fromEvent: false);
      }
    }
  }

  void _enqueue(BleService ble, {required bool fromEvent}) {
    final live = ble.lastLive;
    final event = ble.lastEvent;
    final name = ble.device?.platformName;
    final risk = fromEvent
        ? (event?['risk'] == 'positif' ? 'positif' : 'negatif')
        : 'negatif';

    // VOC dibaca dari paket LIVE lebih dulu, baru event. Sebelumnya hanya
    // event yang dibaca, padahal event hanya terbit saat verifikasi napas —
    // sehingga SELURUH baris rutin semalaman tersimpan dengan voc_acetone
    // kosong, walau firmware sebenarnya mengirimkannya tiap 5 detik.
    final vocLive = (live?['voc'] as num?)?.toDouble();
    final vocEvent = (event?['voc'] as num?)?.toDouble();

    // Deret IBI mentah ikut disimpan. Inilah yang membuat PRV dapat DIHITUNG
    // ULANG saat analisis: rumus PRV boleh berubah kemudian (RMSSD, SDNN,
    // pNN50) tanpa perlu merekam ulang semalaman. Tanpa kolom ini, satu-satunya
    // yang tersisa adalah satu angka PRV dari rumus yang berlaku malam itu, dan
    // data tak dapat dipakai ulang. Tabel uji klinik sudah menyimpannya; jalur
    // rutin tertinggal.
    final ibi = live?['ibi'];
    final ibiRaw = (ibi is List && ibi.isNotEmpty) ? jsonEncode(ibi) : null;

    // voc_ppm bernilai -1 dari firmware bila R0 belum dikalibrasi (CALR0);
    // disimpan sebagai null supaya tidak tertukar dengan kadar sesungguhnya.
    final ppm = (live?['voc_ppm'] as num?)?.toDouble();

    _pending.add({
      'device_id': (name == null || name.isEmpty) ? 'HypoSense' : name,
      'heart_rate': (live?['hr'] ?? event?['hr']) as num?,
      'prv': (live?['prv'] as num?)?.toDouble(),
      'voc_acetone': fromEvent ? (vocEvent ?? vocLive) : (vocLive ?? vocEvent),
      'voc_ppm': (ppm != null && ppm >= 0) ? ppm : null,
      'voc_rel': (live?['voc_rel'] as num?)?.toDouble(),
      'ibi_raw': ibiRaw,
      'temperature': (live?['temp'] as num?)?.toDouble(),
      'humidity': (live?['hum'] as num?)?.toDouble(),
      'risk_status': risk,
    });
    _flush();
  }

  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_pending.isNotEmpty) {
        try {
          await _db.insertReading(_pending.first);
          _pending.removeAt(0);
        } catch (_) {
          // Gagal (kemungkinan offline) -> hentikan, coba lagi nanti.
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
