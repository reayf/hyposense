/// Sinyal alarm & util native (Android).
///
/// Menggantikan versi web (yang memanggil `window.hypoAlert` di
/// web/index.html). Memakai hanya API bawaan Flutter agar tahap 0
/// tetap ringan tanpa plugin. Fungsi yang butuh plugin native
/// (telepon, pilih foto) di-stub dulu — dipasang di tahap terkait:
///   - openTel      -> url_launcher (tahap alarm native)  ✅ DONE
///   - openSms      -> url_launcher (tahap alarm native)  ✅ DONE
///   - pickImageBytes -> image_picker (tahap halaman akun)
///
/// Nama file & signature dipertahankan sama persis dengan versi web
/// supaya pemanggil (alert_service.dart, account_page.dart) tak berubah.
library;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bunyi penanda risiko. Alarm suara penuh (audioplayers) menyusul di
/// tahap alarm native; untuk sekarang pakai bunyi sistem + getaran kuat.
void playBeep() {
  SystemSound.play(SystemSoundType.alert);
  HapticFeedback.heavyImpact();
}

void playVibrate() {
  HapticFeedback.vibrate();
}

/// Buka dialer dengan nomor yang sudah terisi — user tetap menekan tombol
/// panggil sendiri (sesuai standar keamanan Android/iOS).
void openTel(String number) {
  final uri = Uri(scheme: 'tel', path: number);
  launchUrl(uri).catchError((_) => false);
}

/// Buka app SMS dengan nomor & isi pesan sudah terisi — user tinggal kirim.
/// [body] adalah teks pesan darurat otomatis.
void openSms(String number, String body) {
  // Android pakai query param 'body', iOS pakai 'body' juga.
  final uri = Uri(
    scheme: 'sms',
    path: number,
    queryParameters: {'body': body},
  );
  launchUrl(uri).catchError((_) => false);
}

/// Pilih foto dari galeri lalu kembalikan JPEG ter-resize.
/// TODO(tahap halaman akun): implementasi via image_picker + resize.
Future<Uint8List?> pickImageBytes({int maxSize = 512}) async {
  return null;
}
