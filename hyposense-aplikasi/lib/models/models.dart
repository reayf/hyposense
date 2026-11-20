/// Model data untuk HypoSense
library;

// ── User Profile ──────────────────────────────────────────────────
class UserProfile {
  final String id;
  final String fullName;
  final String role; // 'patient' | 'caregiver' | 'admin'
  final String? email;
  final String? avatarUrl;
  final String? emergencyContact;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.avatarUrl,
    this.emergencyContact,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'User',
      role: (json['role'] as String? ?? 'patient').toLowerCase(),
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    String? emergencyContact,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'role': role,
        'emergency_contact': emergencyContact,
        // Kondisional: kolom email/avatar_url baru ada setelah
        // roles_setup.sql / account_setup.sql dijalankan
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };
}

// Model LinkedDevice dihapus bersama fitur penautan perangkat manual —
// gelang kini dikenali langsung melalui BLE saat tersambung.

// ── Relasi Perawat <-> Pasien ─────────────────────────────────────
class CareLink {
  final String id;
  final String caregiverId;
  final String patientId;

  CareLink({
    required this.id,
    required this.caregiverId,
    required this.patientId,
  });

  factory CareLink.fromJson(Map<String, dynamic> json) {
    return CareLink(
      id: json['id'] as String,
      caregiverId: json['caregiver_id'] as String,
      patientId: json['patient_id'] as String,
    );
  }
}

// ── Pembacaan Sensor ESP32 ────────────────────────────────────────
/// Data yang dikirim ESP32 ke tabel `readings` di Supabase
class Reading {
  final int id;
  final String deviceId;
  final int heartRate;     // bpm dari MAX30102
  final double? prv;       // Pulse Rate Variability (opsional)
  final double vocAcetone; // nilai mentah MQ-138
  final double temperature;// dari SHT31 (°C)
  final double humidity;   // dari SHT31 (%)
  final String riskStatus; // 'positif' | 'negatif'
  final DateTime createdAt;

  Reading({
    required this.id,
    required this.deviceId,
    required this.heartRate,
    this.prv,
    required this.vocAcetone,
    required this.temperature,
    required this.humidity,
    required this.riskStatus,
    required this.createdAt,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: (json['id'] as num).toInt(),
      deviceId: json['device_id'] as String? ?? 'unknown',
      heartRate: (json['heart_rate'] as num?)?.toInt() ?? 0,
      prv: (json['prv'] as num?)?.toDouble(),
      vocAcetone: (json['voc_acetone'] as num?)?.toDouble() ?? 0.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      riskStatus: json['risk_status'] as String? ?? 'negatif',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isPositif => riskStatus.toLowerCase() == 'positif';

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

// ── Device Data (info gelang) ─────────────────────────────────────
class DeviceData {
  final String id;
  final String userId;
  final int batteryLevel;
  final String connectionStrength;
  final DateTime lastUpdate;
  final bool vocSensorActive;

  DeviceData({
    required this.id,
    required this.userId,
    required this.batteryLevel,
    required this.connectionStrength,
    required this.lastUpdate,
    required this.vocSensorActive,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    return DeviceData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      batteryLevel: (json['battery_level'] as num?)?.toInt() ?? 0,
      connectionStrength: json['connection_strength'] as String? ?? 'Unknown',
      lastUpdate: DateTime.parse(json['last_update'] as String),
      vocSensorActive: json['voc_sensor_active'] as bool? ?? false,
    );
  }
}

// ── Sensor Reading (legacy — sebelum ada tabel readings) ──────────
class SensorReading {
  final String id;
  final String userId;
  final String vocTrend;
  final String sleepQuality;
  final double temperature;
  final DateTime recordedAt;

  SensorReading({
    required this.id,
    required this.userId,
    required this.vocTrend,
    required this.sleepQuality,
    required this.temperature,
    required this.recordedAt,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      vocTrend: json['voc_trend'] as String? ?? 'Stable',
      sleepQuality: json['sleep_quality'] as String? ?? 'Restful',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 36.5,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}

// ── Risk Log ──────────────────────────────────────────────────────
class RiskLog {
  final String id;
  final String userId;
  final String riskStatus;
  final String message;
  final DateTime createdAt;

  RiskLog({
    required this.id,
    required this.userId,
    required this.riskStatus,
    required this.message,
    required this.createdAt,
  });

  factory RiskLog.fromJson(Map<String, dynamic> json) {
    return RiskLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      riskStatus: json['risk_status'] as String? ?? 'SAFE',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ── User Settings ─────────────────────────────────────────────────
class UserSettings {
  final String userId;
  final bool saveToCloud;
  final bool shareWithCaregiver;
  final bool enableAlarm;
  final String riskAlertLevel;
  final String alertMethod;
  final String theme;
  final String language;

  UserSettings({
    required this.userId,
    required this.saveToCloud,
    required this.shareWithCaregiver,
    required this.enableAlarm,
    required this.riskAlertLevel,
    required this.alertMethod,
    required this.theme,
    required this.language,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['user_id'] as String,
      saveToCloud: json['save_to_cloud'] as bool? ?? true,
      shareWithCaregiver: json['share_with_caregiver'] as bool? ?? true,
      enableAlarm: json['enable_alarm'] as bool? ?? true,
      riskAlertLevel: json['risk_alert_level'] as String? ?? 'moderate',
      alertMethod: json['alert_method'] as String? ?? 'sound',
      theme: json['theme'] as String? ?? 'light',
      language: json['language'] as String? ?? 'English',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'save_to_cloud': saveToCloud,
        'share_with_caregiver': shareWithCaregiver,
        'enable_alarm': enableAlarm,
        'risk_alert_level': riskAlertLevel,
        'alert_method': alertMethod,
        'theme': theme,
        'language': language,
      };
}

// ── Uji Klinik: Subjek & Pengukuran ───────────────────────────────
/// Subjek uji klinik (BUKAN akun login). Satu alat dipakai banyak orang.
class ClinicalSubject {
  final String id;
  final String patientCode;
  final String? gender;
  final int? age;
  final DateTime createdAt;

  ClinicalSubject({
    required this.id,
    required this.patientCode,
    this.gender,
    this.age,
    required this.createdAt,
  });

  factory ClinicalSubject.fromJson(Map<String, dynamic> json) {
    return ClinicalSubject(
      id: json['id'] as String,
      patientCode: json['patient_code'] as String? ?? '-',
      gender: json['gender'] as String?,
      age: (json['age'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Satu pengukuran: snapshot sensor + glukosa referensi (glukometer).
class ClinicalMeasurement {
  final String id;
  final String subjectId;
  final String? jenis;      // 'napas' | 'manual' (null = data lama)
  final int? heartRate;
  final double? prv;
  final double? vocAcetone;
  final double? vocRel;     // simpangan terhadap embusan pertama sesi (%)
  final double? temperature;
  final double? humidity;
  final double? glucoseRef; // mg/dL dari glukometer (label)
  final String? ibiRaw;     // "[812,798,...]" — untuk hitung ulang PRV offline
  final String? note;
  final DateTime createdAt;

  ClinicalMeasurement({
    required this.id,
    required this.subjectId,
    this.jenis,
    this.heartRate,
    this.prv,
    this.vocAcetone,
    this.vocRel,
    this.temperature,
    this.humidity,
    this.glucoseRef,
    this.ibiRaw,
    this.note,
    required this.createdAt,
  });

  factory ClinicalMeasurement.fromJson(Map<String, dynamic> json) {
    return ClinicalMeasurement(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      jenis: json['jenis'] as String?,
      heartRate: (json['heart_rate'] as num?)?.toInt(),
      prv: (json['prv'] as num?)?.toDouble(),
      vocAcetone: (json['voc_acetone'] as num?)?.toDouble(),
      vocRel: (json['voc_rel'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      glucoseRef: (json['glucose_ref'] as num?)?.toDouble(),
      ibiRaw: json['ibi_raw'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Satu rekaman detak 5 menit (ringkasan untuk ditampilkan; deret IBI dan
/// cuplikannya tidak ikut dimuat karena hanya dibutuhkan saat analisis).
class ClinicalRecording {
  final String id;
  final DateTime startedAt;
  final int durationS;
  final bool lengkap;
  final int nBeats;
  final int lostBeats;
  final int gapS;
  final int jumlahOksimeter;
  final double? glucoseRef;
  final String? note;

  ClinicalRecording({
    required this.id,
    required this.startedAt,
    required this.durationS,
    required this.lengkap,
    required this.nBeats,
    required this.lostBeats,
    required this.gapS,
    required this.jumlahOksimeter,
    this.glucoseRef,
    this.note,
  });

  factory ClinicalRecording.fromJson(Map<String, dynamic> json) {
    final oksimeter = json['oximeter'];
    return ClinicalRecording(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      durationS: (json['duration_s'] as num?)?.toInt() ?? 0,
      lengkap: json['lengkap'] as bool? ?? true,
      nBeats: (json['n_beats'] as num?)?.toInt() ?? 0,
      lostBeats: (json['lost_beats'] as num?)?.toInt() ?? 0,
      gapS: (json['gap_s'] as num?)?.toInt() ?? 0,
      jumlahOksimeter: oksimeter is List ? oksimeter.length : 0,
      glucoseRef: (json['glucose_ref'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }
}
