import 'package:flutter/material.dart';

import '../models/models.dart';
import 'database_service.dart';

/// State global pengaturan aplikasi (tema, bahasa, preferensi alarm,
/// profil). Dimuat setelah login; perubahan langsung diterapkan ke
/// seluruh UI lewat ListenableBuilder di MyApp.
class SettingsController extends ChangeNotifier {
  SettingsController._();
  static final SettingsController instance = SettingsController._();

  UserSettings? settings;
  UserProfile? profile;

  /// true setelah percobaan load pertama selesai (berhasil ataupun tidak) —
  /// dipakai MainNavigation untuk menentukan halaman sesuai peran.
  bool loaded = false;

  /// Peran user saat ini: 'patient' | 'caregiver' | 'admin'.
  String get role => (profile?.role ?? 'patient').toLowerCase();

  /// Izin menyimpan data gelang ke cloud. Default true (mengikuti nilai
  /// bawaan tabel) supaya perilaku lama tak berubah bagi yang belum
  /// mengatur apa pun.
  bool get saveToCloud => settings?.saveToCloud ?? true;

  ThemeMode get themeMode =>
      settings?.theme == 'dark' ? ThemeMode.dark : ThemeMode.light;

  /// null = ikuti bahasa perangkat (sebelum settings termuat / belum login)
  Locale? get locale {
    switch (settings?.language) {
      case 'Bahasa Indonesia':
        return const Locale('id');
      case 'English':
        return const Locale('en');
      default:
        return null;
    }
  }

  Future<void> load() async {
    try {
      final db = DatabaseService();
      settings = await db.getSettings();
      profile = await db.getProfile();
    } catch (_) {
      // Biarkan default; halaman tetap berfungsi dengan nilai fallback.
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  /// Terapkan pengaturan ke UI seketika (dipanggil halaman Settings,
  /// baik untuk preview saat memilih maupun setelah tersimpan).
  void apply(UserSettings newSettings) {
    settings = newSettings;
    notifyListeners();
  }

  void applyProfile(UserProfile newProfile) {
    profile = newProfile;
    notifyListeners();
  }

  /// Reset saat logout.
  void clear() {
    settings = null;
    profile = null;
    loaded = false;
    notifyListeners();
  }
}
