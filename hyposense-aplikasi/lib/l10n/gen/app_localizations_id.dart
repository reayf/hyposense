// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'HypoSense';

  @override
  String get loginTagline => 'Pantau kesehatanmu, tetap aman';

  @override
  String get loginWithEmailDivider => 'atau masuk dengan email';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get forgotPassword => 'Lupa Password?';

  @override
  String get loginButton => 'Masuk';

  @override
  String get registerButton => 'Daftar';

  @override
  String get googleSignIn => 'Masuk dengan Google';

  @override
  String get errEmailPasswordEmpty => 'Email dan password tidak boleh kosong';

  @override
  String errGeneric(Object error) {
    return 'Terjadi kesalahan: $error';
  }

  @override
  String errGoogleSignIn(Object error) {
    return 'Gagal masuk dengan Google: $error';
  }

  @override
  String get enterEmailFirst => 'Masukkan email kamu dulu';

  @override
  String resetLinkSent(Object email) {
    return 'Link reset password dikirim ke $email';
  }

  @override
  String get createAccountTitle => 'Buat Akun';

  @override
  String get registerHeadline => 'Daftar HypoSense';

  @override
  String get fullNameHint => 'Nama Lengkap';

  @override
  String get confirmPasswordHint => 'Konfirmasi Password';

  @override
  String get registerSubmit => 'Daftar';

  @override
  String get alreadyHaveAccount => 'Sudah punya akun? ';

  @override
  String get errAllFieldsRequired => 'Semua field harus diisi';

  @override
  String get errPasswordMismatch => 'Password tidak cocok';

  @override
  String get errPasswordTooShort => 'Password minimal 6 karakter';

  @override
  String get accountCreated => 'Akun berhasil dibuat!';

  @override
  String get accountCreatedVerify =>
      'Akun dibuat! Cek email untuk verifikasi sebelum login.';

  @override
  String get authErrInvalidCredentials => 'Email atau password salah.';

  @override
  String get authErrEmailNotConfirmed =>
      'Email belum diverifikasi. Cek inbox/folder spam, atau minta admin mengonfirmasi akunmu.';

  @override
  String get authErrUserNotFound =>
      'Akun tidak ditemukan. Silakan daftar dulu.';

  @override
  String get authErrEmailExists => 'Email ini sudah terdaftar. Silakan login.';

  @override
  String get authErrWeakPassword =>
      'Password terlalu lemah — minimal 6 karakter.';

  @override
  String get authErrEmailRateLimit =>
      'Terlalu banyak permintaan email. Tunggu beberapa menit lalu coba lagi.';

  @override
  String get authErrRequestRateLimit =>
      'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';

  @override
  String get authErrInvalidEmail => 'Format email tidak valid.';

  @override
  String get navFaq => 'FAQ';

  @override
  String get navHome => 'Beranda';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String greeting(Object name) {
    return 'Hai, $name 👋';
  }

  @override
  String get wearableConnected => 'Gelang: Terhubung';

  @override
  String get wearableNotConnected => 'Gelang: Tidak terhubung';

  @override
  String get deviceInformation => 'Informasi Perangkat';

  @override
  String batteryLevel(Object level) {
    return 'Level Baterai: $level%';
  }

  @override
  String connectionLabel(Object strength) {
    return 'Koneksi: $strength';
  }

  @override
  String lastUpdate(Object time) {
    return 'Update Terakhir: $time';
  }

  @override
  String vocSensorLabel(Object status) {
    return 'Sensor VOC: $status';
  }

  @override
  String get active => 'Aktif';

  @override
  String get inactive => 'Nonaktif';

  @override
  String get notAvailable => 'N/A';

  @override
  String get justNow => 'Baru saja';

  @override
  String minutesAgo(Object minutes) {
    return '$minutes menit lalu';
  }

  @override
  String hoursAgo(Object hours) {
    return '$hours jam lalu';
  }

  @override
  String daysAgo(Object days) {
    return '$days hari lalu';
  }

  @override
  String get hypoglycemiaRisk => 'Risiko Hipoglikemia';

  @override
  String statusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get statusSafe => 'AMAN';

  @override
  String get statusDanger => 'BAHAYA';

  @override
  String get statusWarning => 'WASPADA';

  @override
  String get allParamsSafe => 'Semua parameter dalam batas aman';

  @override
  String get riskDetectedMsg =>
      'Risiko hipoglikemia terdeteksi — segera cek gula darahmu!';

  @override
  String get liveSensorData => 'Data Sensor Langsung';

  @override
  String get waitingForDevice => 'Menunggu perangkat...';

  @override
  String get heartRate => 'Detak Jantung';

  @override
  String get vocLabel => 'VOC (MQ-138)';

  @override
  String get temperature => 'Suhu';

  @override
  String get humidity => 'Kelembapan';

  @override
  String roleLabel(Object role) {
    return 'Peran: $role';
  }

  @override
  String get sectionDataPrivacy => 'Data & Privasi';

  @override
  String get saveDataToCloud => 'Simpan data ke cloud';

  @override
  String get saveDataToCloudNote =>
      'Diberlakukan di gelang setelah penautan perangkat tersedia';

  @override
  String get shareWithCaregiver => 'Bagikan data ke perawat';

  @override
  String get shareWithCaregiverNote =>
      'Berlaku saat akun perawat sudah tersedia';

  @override
  String get sectionAlertsSafety => 'Peringatan & Keselamatan';

  @override
  String get alertsScopeNote =>
      'Peringatan di bawah berlaku untuk aplikasi di HP-mu — gelang menampilkan peringatan di layarnya sendiri.';

  @override
  String get enableAlarm => 'Aktifkan alarm';

  @override
  String get riskAlertLevel => 'Tingkat peringatan risiko:';

  @override
  String get levelModerate => 'Sedang';

  @override
  String get levelHigh => 'Tinggi';

  @override
  String get riskAlertLevelNote =>
      'Sedang: alarm berbunyi sekali per kejadian. Tinggi: alarm berulang sampai ditutup.';

  @override
  String get alertMethod => 'Metode peringatan:';

  @override
  String get methodSound => 'Suara';

  @override
  String get methodVibration => 'Getar';

  @override
  String get methodNotification => 'Notifikasi';

  @override
  String get methodNotificationNote =>
      'Push notification saat aplikasi tertutup hadir di tahap berikutnya — untuk sekarang berupa banner di dalam aplikasi.';

  @override
  String get emergencyContact => 'Kontak darurat:';

  @override
  String get emergencyContactHint => 'Masukkan nomor kontak';

  @override
  String get sectionAppSettings => 'Pengaturan Aplikasi';

  @override
  String get languageLabel => 'Bahasa:';

  @override
  String get themeLabel => 'Tema:';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String appVersion(Object version) {
    return 'Versi aplikasi: $version';
  }

  @override
  String get saveSettings => 'Simpan Pengaturan';

  @override
  String get saving => 'Menyimpan...';

  @override
  String get settingsSaved => 'Pengaturan berhasil disimpan!';

  @override
  String settingsSaveFailed(Object error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String get logout => 'Keluar';

  @override
  String get logoutConfirm => 'Apakah kamu yakin ingin keluar?';

  @override
  String get cancel => 'Batal';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqSubtitle => 'Pertanyaan yang Sering Diajukan';

  @override
  String get faqCatAbout => 'Tentang HypoSense';

  @override
  String get faqQWhat => 'Apa itu HypoSense?';

  @override
  String get faqAWhat =>
      'HypoSense adalah perangkat wearable yang memantau biomarker napas dan detak jantung untuk mendeteksi tanda awal hipoglikemia nokturnal saat kamu tidur.';

  @override
  String get faqQHow => 'Bagaimana cara kerja HypoSense?';

  @override
  String get faqAHow =>
      'Perangkat memantau detak jantungmu terus-menerus. Saat terdeteksi pola yang konsisten dengan hipoglikemia, perangkat mengonfirmasi lewat sensor VOC napas sebelum membunyikan peringatan.';

  @override
  String get faqCatWearable => 'Gelang & Pemantauan';

  @override
  String get faqQWear => 'Bagaimana cara memakai perangkat dengan benar?';

  @override
  String get faqAWear =>
      'Kenakan gelang dengan pas di pergelangan tangan dengan panel sensor menghadap kulit. Untuk pembacaan napas, dekatkan sensor ke mulut dan hembuskan napas perlahan saat diminta.';

  @override
  String get faqQMulti => 'Bisakah satu akun memantau beberapa pengguna?';

  @override
  String get faqAMulti =>
      'Saat ini satu akun terhubung ke satu perangkat. Pemantauan multi-pengguna untuk perawat direncanakan pada pembaruan berikutnya.';

  @override
  String get faqCatAlerts => 'Peringatan & Keselamatan';

  @override
  String get faqQAlarm => 'Apa yang harus dilakukan saat alarm berbunyi?';

  @override
  String get faqAAlarm =>
      'Cek gula darah dengan glukometer jika memungkinkan, konsumsi karbohidrat cepat serap jika kadarnya rendah, dan hubungi kontak daruratmu jika gejala berlanjut.';

  @override
  String get faqCatPrivacy => 'Data & Privasi';

  @override
  String get faqQSecure => 'Apakah data saya aman?';

  @override
  String get faqASecure =>
      'Semua data dienkripsi saat dikirim dan disimpan. Kamu bisa mengatur sinkronisasi cloud dan berbagi data dengan perawat dari halaman Pengaturan.';

  @override
  String get faqQExport => 'Bisakah saya mengekspor data saya?';

  @override
  String get faqAExport =>
      'Bisa, buka Pengaturan > Data & Privasi lalu pilih \"Ekspor data\" untuk mengunduh riwayatmu sebagai file.';

  @override
  String get faqDisclaimer =>
      'HypoSense adalah sistem pendukung peringatan dini dan tidak menggantikan perawatan medis profesional.';

  @override
  String get alertBannerTitle => 'RISIKO HIPOGLIKEMIA!';

  @override
  String get alertBannerBody =>
      'Segera cek gula darah dan konsumsi karbohidrat cepat serap jika rendah.';

  @override
  String get alertCallEmergency => 'Hubungi kontak darurat';

  @override
  String get alertDismiss => 'Tutup';

  @override
  String get rolePatient => 'Pasien';

  @override
  String get roleCaregiver => 'Perawat';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get navPatients => 'Pasien';

  @override
  String get navAdmin => 'Admin';

  @override
  String get caregiverTitle => 'Pasien Saya';

  @override
  String get caregiverSubtitle => 'Pasien yang terhubung dengan akunmu';

  @override
  String get noPatientsYet =>
      'Belum ada pasien terhubung. Minta admin menghubungkan pasien ke akunmu.';

  @override
  String get patientMaybeHidden =>
      'Jika ada pasien yang tidak muncul, kemungkinan ia mematikan berbagi data.';

  @override
  String get riskHistory => 'Riwayat Risiko';

  @override
  String get noHistoryYet => 'Belum ada kejadian risiko tercatat.';

  @override
  String get liveDataComingP5 =>
      'Data sensor langsung per pasien akan tampil setelah penautan perangkat tersedia.';

  @override
  String get emergencyContactTitle => 'Kontak darurat';

  @override
  String get notSet => 'Belum diisi';

  @override
  String get adminTitle => 'Kelola Pengguna';

  @override
  String get adminSubtitle => 'Atur peran dan hubungkan perawat dengan pasien';

  @override
  String get managePatientsBtn => 'Kelola pasien';

  @override
  String get linkedPatients => 'Pasien terhubung';

  @override
  String get addPatient => 'Hubungkan pasien';

  @override
  String get noAvailablePatients => 'Tidak ada pasien lain untuk dihubungkan.';

  @override
  String get roleUpdated => 'Peran diperbarui.';

  @override
  String actionFailed(Object error) {
    return 'Gagal: $error';
  }

  @override
  String get linkAdded => 'Pasien terhubung.';

  @override
  String get linkRemoved => 'Tautan dihapus.';

  @override
  String get add => 'Tambah';

  @override
  String get accountTitle => 'Akun';

  @override
  String get changePhoto => 'Ganti foto';

  @override
  String get photoUpdated => 'Foto diperbarui.';

  @override
  String get profileUpdated => 'Profil diperbarui.';

  @override
  String get save => 'Simpan';

  @override
  String get emailReadonlyNote => 'Email tidak bisa diubah dari sini.';

  @override
  String get changePassword => 'Ganti Password';

  @override
  String get newPasswordHint => 'Password baru';

  @override
  String get confirmNewPasswordHint => 'Konfirmasi password baru';

  @override
  String get passwordChanged => 'Password berhasil diganti.';

  @override
  String get sectionDevice => 'Perangkat Gelang';

  @override
  String get deviceNote =>
      'Masukkan Device ID yang dikonfigurasi di firmware gelangmu (mis. gelang_001). Setelah tertaut, datanya menjadi milik akunmu.';

  @override
  String get deviceIdHint => 'Device ID';

  @override
  String get linkDevice => 'Tautkan perangkat';

  @override
  String get unlinkDevice => 'Lepas';

  @override
  String get deviceLinked => 'Perangkat tertaut.';

  @override
  String get deviceUnlinked => 'Tautan perangkat dilepas.';

  @override
  String get deviceTaken => 'Perangkat ini sudah tertaut ke akun lain.';

  @override
  String get noDeviceLinked => 'Belum ada perangkat tertaut.';

  @override
  String linkedSince(Object date) {
    return 'Tertaut sejak $date';
  }

  @override
  String get alertSendSms => 'Kirim pesan darurat';
}
