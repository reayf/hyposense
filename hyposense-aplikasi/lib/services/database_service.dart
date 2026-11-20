import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ─── PROFILE ───────────────────────────────────────────────

  Future<UserProfile?> getProfile() async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _supabase
        .from('profiles')
        .update(profile.toJson())
        .eq('id', _userId);
  }

  /// Unggah foto profil (JPEG) ke bucket `avatars` lalu simpan URL-nya.
  /// Mengembalikan URL publik dengan cache-buster.
  Future<String> uploadAvatar(List<int> jpegBytes) async {
    final path = '$_userId/avatar.jpg';
    await _supabase.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(jpegBytes),
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final url = '${_supabase.storage.from('avatars').getPublicUrl(path)}'
        '?v=${DateTime.now().millisecondsSinceEpoch}';
    await _supabase
        .from('profiles')
        .update({'avatar_url': url}).eq('id', _userId);
    return url;
  }

  // ─── DEVICE DATA ────────────────────────────────────────────

  Future<DeviceData?> getLatestDeviceData() async {
    final data = await _supabase
        .from('device_data')
        .select()
        .eq('user_id', _userId)
        .order('last_update', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return DeviceData.fromJson(data);
  }

  Future<void> upsertDeviceData({
    required int batteryLevel,
    required String connectionStrength,
    required bool vocSensorActive,
  }) async {
    await _supabase.from('device_data').upsert({
      'user_id': _userId,
      'battery_level': batteryLevel,
      'connection_strength': connectionStrength,
      'last_update': DateTime.now().toIso8601String(),
      'voc_sensor_active': vocSensorActive,
    });
  }

  // Penautan perangkat lewat pengetikan device_id DIHAPUS: peninggalan
  // rancangan lama ketika gelang mengirim data langsung ke Supabase melalui
  // WiFi sehingga perlu dikaitkan ke akun secara manual. Sejak beralih ke
  // BLE, gelang dikenali langsung saat tersambung dan device_id diambil dari
  // nama perangkat BLE (lihat cloud_relay_service.dart). Tidak ada kebijakan
  // RLS yang bergantung pada tabel `devices`.

  /// Stream reading terbaru MILIK seorang pasien (untuk perawat/admin;
  /// RLS menegakkan izin akses + toggle berbagi data).
  Stream<Reading?> patientReadingStream(String patientId) {
    return _supabase
        .from('readings')
        .stream(primaryKey: ['id'])
        .eq('user_id', patientId)
        .order('created_at', ascending: false)
        .limit(1)
        .map((rows) => rows.isEmpty ? null : Reading.fromJson(rows.first));
  }

  // ─── PERAN & RELASI PERAWAT-PASIEN (Tahap 3) ───────────────

  /// Daftar pasien yang terhubung dengan perawat yang sedang login.
  Future<List<UserProfile>> getMyPatients() async {
    final links = await _supabase
        .from('care_links')
        .select('patient_id')
        .eq('caregiver_id', _userId);
    final ids =
        (links as List).map((e) => e['patient_id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await _supabase
        .from('profiles')
        .select()
        .inFilter('id', ids)
        .order('full_name', ascending: true);
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  /// Riwayat risiko seorang pasien (RLS menegakkan: hanya perawat
  /// terhubung + pasien mengizinkan berbagi data).
  Future<List<RiskLog>> getPatientRiskLogs(String patientId,
      {int limit = 200}) async {
    final data = await _supabase
        .from('risk_logs')
        .select()
        .eq('user_id', patientId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => RiskLog.fromJson(e)).toList();
  }

  // ─── ADMIN ──────────────────────────────────────────────────

  Future<List<UserProfile>> getAllProfiles() async {
    final data = await _supabase
        .from('profiles')
        .select()
        .order('full_name', ascending: true);
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _supabase.from('profiles').update({'role': role}).eq('id', userId);
  }

  Future<List<CareLink>> getCareLinks(String caregiverId) async {
    final data = await _supabase
        .from('care_links')
        .select()
        .eq('caregiver_id', caregiverId);
    return (data as List).map((e) => CareLink.fromJson(e)).toList();
  }

  Future<void> addCareLink(String caregiverId, String patientId) async {
    await _supabase.from('care_links').insert({
      'caregiver_id': caregiverId,
      'patient_id': patientId,
    });
  }

  Future<void> removeCareLink(String linkId) async {
    await _supabase.from('care_links').delete().eq('id', linkId);
  }

  // ─── ESP32 READINGS (realtime) ──────────────────────────────

  /// Stream reading terbaru dari tabel `readings` (data ESP32).
  /// Emit pertama berisi data yang sudah ada, lalu update otomatis
  /// setiap ESP32 mengirim baris baru (Supabase Realtime).
  Stream<Reading?> latestReadingStream() {
    return _supabase
        .from('readings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .map((rows) => rows.isEmpty ? null : Reading.fromJson(rows.first));
  }

  /// Insert satu reading ke cloud (dipakai relay BLE→Supabase, Tahap 3).
  /// user_id di-set ke pasien yang login supaya perawat bisa membacanya (RLS).
  Future<void> insertReading(Map<String, dynamic> row) async {
    await _supabase.from('readings').insert({
      'user_id': _userId,
      ...row,
    });
  }

  /// Riwayat reading ESP32 terbaru (untuk grafik/riwayat nanti).
  Future<List<Reading>> getReadingHistory({int limit = 50}) async {
    final data = await _supabase
        .from('readings')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Reading.fromJson(e)).toList();
  }

  // ─── SENSOR READINGS ────────────────────────────────────────

  Future<SensorReading?> getLatestSensorReading() async {
    final data = await _supabase
        .from('sensor_readings')
        .select()
        .eq('user_id', _userId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return SensorReading.fromJson(data);
  }

  Future<List<SensorReading>> getSensorHistory({int limit = 20}) async {
    final data = await _supabase
        .from('sensor_readings')
        .select()
        .eq('user_id', _userId)
        .order('recorded_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => SensorReading.fromJson(e)).toList();
  }

  // ─── RISK LOGS ──────────────────────────────────────────────

  Future<RiskLog?> getLatestRiskLog() async {
    final data = await _supabase
        .from('risk_logs')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return RiskLog.fromJson(data);
  }

  Future<void> addRiskLog({
    required String riskStatus,
    required String message,
  }) async {
    await _supabase.from('risk_logs').insert({
      'user_id': _userId,
      'risk_status': riskStatus,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── USER SETTINGS ──────────────────────────────────────────

  Future<UserSettings?> getSettings() async {
    final data = await _supabase
        .from('user_settings')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    if (data == null) return null;
    return UserSettings.fromJson(data);
  }

  Future<void> saveSettings(UserSettings settings) async {
    await _supabase
        .from('user_settings')
        .upsert(settings.toJson());
  }
}
