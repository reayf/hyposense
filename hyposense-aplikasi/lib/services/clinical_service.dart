import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Layanan data UJI KLINIK: subjek (kode pasien/gender/umur) + pengukuran
/// (data sensor + glukosa referensi). Terpisah dari [DatabaseService] agar
/// alur data pasien reguler tidak tersentuh. Membutuhkan tabel dari
/// `clinical_trial_setup.sql`.
class ClinicalService {
  final _supabase = Supabase.instance.client;

  // ─── SUBJEK ──────────────────────────────────────────────────
  Future<List<ClinicalSubject>> getSubjects() async {
    final data = await _supabase
        .from('clinical_subjects')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => ClinicalSubject.fromJson(e)).toList();
  }

  Future<ClinicalSubject> addSubject({
    required String patientCode,
    String? gender,
    int? age,
  }) async {
    final data = await _supabase
        .from('clinical_subjects')
        .insert({
          'patient_code': patientCode,
          if (gender != null) 'gender': gender,
          if (age != null) 'age': age,
        })
        .select()
        .single();
    return ClinicalSubject.fromJson(data);
  }

  Future<void> deleteSubject(String id) async {
    await _supabase.from('clinical_subjects').delete().eq('id', id);
  }

  // ─── PENGUKURAN ──────────────────────────────────────────────
  Future<List<ClinicalMeasurement>> getMeasurements(String subjectId) async {
    final data = await _supabase
        .from('clinical_measurements')
        .select()
        .eq('subject_id', subjectId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ClinicalMeasurement.fromJson(e))
        .toList();
  }

  Future<void> addMeasurement({
    required String subjectId,
    String? jenis,
    int? heartRate,
    double? prv,
    double? vocAcetone,
    double? vocRel,
    double? temperature,
    double? humidity,
    double? glucoseRef,
    String? ibiRaw,
    String? note,
    String? deviceId,
  }) async {
    await _supabase.from('clinical_measurements').insert({
      'subject_id': subjectId,
      if (jenis != null) 'jenis': jenis,
      if (heartRate != null) 'heart_rate': heartRate,
      if (prv != null) 'prv': prv,
      if (vocAcetone != null) 'voc_acetone': vocAcetone,
      if (vocRel != null) 'voc_rel': vocRel,
      if (temperature != null) 'temperature': temperature,
      if (humidity != null) 'humidity': humidity,
      if (glucoseRef != null) 'glucose_ref': glucoseRef,
      if (ibiRaw != null && ibiRaw.isNotEmpty) 'ibi_raw': ibiRaw,
      if (note != null && note.isNotEmpty) 'note': note,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    });
  }

  // ─── REKAMAN DETAK 5 MENIT ───────────────────────────────────
  Future<List<ClinicalRecording>> getRecordings(String subjectId) async {
    // Deret IBI dan cuplikan sengaja tidak dimuat: ukurannya besar dan hanya
    // dibutuhkan saat analisis (ekspor CSV dari Supabase).
    final data = await _supabase
        .from('clinical_recordings')
        .select('id, started_at, duration_s, lengkap, n_beats, lost_beats, '
            'gap_s, oximeter, glucose_ref, note')
        .eq('subject_id', subjectId)
        .order('started_at', ascending: false);
    return (data as List).map((e) => ClinicalRecording.fromJson(e)).toList();
  }

  static const _tabelSesi = {'clinical_measurements', 'clinical_recordings'};

  /// Menyimpan satu baris hasil sesi uji klinik apa adanya.
  ///
  /// Bentuknya umum karena dipakai juga untuk mengunggah ulang data yang
  /// tertunda, yang disimpan di HP sebagai pasangan nama tabel dan baris.
  /// Nama tabel dibatasi pada tabel uji klinik agar antrean yang rusak tidak
  /// dapat menulis ke tabel lain.
  Future<void> simpanBaris(String tabel, Map<String, dynamic> baris) async {
    if (!_tabelSesi.contains(tabel)) {
      throw ArgumentError('Tabel tidak dikenal: $tabel');
    }
    await _supabase.from(tabel).insert(baris);
  }
}
