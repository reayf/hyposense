import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'alert_service.dart';
import 'ble_service.dart';
import 'clinical_service.dart';

/// Tahap satu kali pengambilan sampel napas, mengikuti urutan di gelang:
/// pemanasan 60 dtk → aba-aba 6,5 dtk → pengambilan 2 dtk → hasil.
enum TahapNapas { siap, memanaskan, embuskan, menganalisis }

/// Satu sesi uji klinik untuk satu subjek.
///
/// Memusatkan tiga pekerjaan yang dulu bergantung pada ketepatan waktu
/// petugas:
///
///  1. **Memulai sesi** — patokan personal gelang direset dan gelang masuk
///     mode uji klinik, sehingga hasil napas tidak menjadi vonis maupun alarm.
///  2. **Merekam detak 5 menit** — setiap paket selama lima menit disimpan,
///     dan selang antar-denyut disambung tanpa dobel memakai penghitung denyut
///     dari gelang.
///  3. **Sampel napas** — hasilnya disimpan OTOMATIS begitu gelang selesai
///     mengukur. Dulu petugas harus menekan simpan dalam jendela ±4 detik,
///     sebelum paket berikutnya menimpa nilai napas dengan bacaan sensor yang
///     pemanasnya sudah dimatikan.
///
/// Data yang gagal diunggah disimpan di HP dan dapat diunggah ulang, sebab
/// satu sesi yang hilang berarti satu kesempatan pasien yang hilang.
class ClinicalSession extends ChangeNotifier {
  ClinicalSession({required this.subjectId}) {
    _tersambungSebelum = _ble.isConnected;
    _ble.addListener(_onBle);
    _subEvent = _ble.eventStream.listen(_terimaEvent);
    unawaited(_hitungTertunda());
  }

  final String subjectId;
  final _service = ClinicalService();
  final _ble = BleService.instance;

  static const durasiRekam = Duration(minutes: 5);
  static const targetNapas = 5;
  static const _pemanasanDetik = 60;
  static const _jendelaNapasDetik = 9; // aba-aba 6,5 dtk + pengambilan 2 dtk
  static const _batasTungguDetik = 120;
  static const _kunciTertunda = 'hyposense_uji_klinik_tertunda';

  final _pesan = StreamController<String>.broadcast();

  /// Kabar singkat untuk ditampilkan halaman (tersimpan, gagal, dsb.).
  Stream<String> get pesan => _pesan.stream;

  /// Diisi halaman dari kolom masukan; ikut tersimpan pada setiap data sesi.
  double? glukosa;
  String catatan = '';

  /// Dipanggil setelah data tersimpan, agar halaman memuat ulang riwayat.
  VoidCallback? onTersimpan;

  bool _dibuang = false;
  bool _tersambungSebelum = false;

  // ── Sesi ────────────────────────────────────────────────────────────
  DateTime? sesiDimulai;
  bool get sesiAktif => sesiDimulai != null;
  bool get sibuk => merekam || tahapNapas != TahapNapas.siap;

  // ── Rekam detak ─────────────────────────────────────────────────────
  bool merekam = false;
  DateTime? _mulaiRekam;
  Timer? _detikRekam;
  StreamSubscription<Map<String, dynamic>>? _subLive;
  final List<int> _ibi = [];
  final List<Map<String, dynamic>> _cuplikan = [];
  final List<Map<String, dynamic>> _oksimeter = [];
  int? _nSebelum;
  DateTime? _paketSebelum;
  int detikRekam = 0;
  int celahDetik = 0;
  int denyutHilang = 0;
  bool firmwareLama = false;

  int get jumlahDenyut => _ibi.length;
  int get jumlahOksimeter => _oksimeter.length;
  int get sisaDetik => durasiRekam.inSeconds - detikRekam;

  // ── Sampel napas ────────────────────────────────────────────────────
  TahapNapas tahapNapas = TahapNapas.siap;
  DateTime? _mulaiNapas;
  Timer? _detikNapas;
  StreamSubscription<Map<String, dynamic>>? _subEvent;
  int sampelNapas = 0;
  int sisaPemanasan = 0;

  // ── Unggahan tertunda ───────────────────────────────────────────────
  int tertunda = 0;

  String? get _namaGelang {
    final n = _ble.device?.platformName;
    return (n == null || n.isEmpty) ? null : n;
  }

  // ════════════════════════════════════════════════════════════════════
  // Sesi
  // ════════════════════════════════════════════════════════════════════
  Future<void> mulaiSesi() async {
    if (!_ble.isConnected) {
      _kabari('Gelang belum tersambung.');
      return;
    }
    if (sibuk) return;
    await _ble.sendCommand('RESETBASE');
    await _ble.sendCommand('MODEUJI:1');
    AlertService.instance.setModeUjiKlinik(true);
    sesiDimulai = DateTime.now();
    sampelNapas = 0;
    _kabari('Sesi dimulai: patokan direset, alarm nonaktif selama sesi.');
    notifyListeners();
  }

  void _onBle() {
    final tersambung = _ble.isConnected;
    if (tersambung != _tersambungSebelum) {
      if (tersambung && sesiAktif) {
        // Gelang melepas mode uji setiap kali terputus, jadi harus dinyalakan
        // lagi begitu tersambung kembali.
        unawaited(_ble.sendCommand('MODEUJI:1'));
      }
      if (!tersambung) {
        if (merekam) {
          unawaited(_selesaiRekam(lengkap: false, alasan: 'gelang terputus'));
        }
        if (tahapNapas != TahapNapas.siap) {
          _hentikanNapas();
          _kabari('Gelang terputus saat pemeriksaan napas. '
              'Sambungkan lalu ulangi.');
        }
      }
      _tersambungSebelum = tersambung;
    }
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════════
  // Rekam detak 5 menit
  // ════════════════════════════════════════════════════════════════════
  void mulaiRekam() {
    if (!sesiAktif || sibuk || !_ble.isConnected) return;
    merekam = true;
    _mulaiRekam = DateTime.now();
    detikRekam = 0;
    celahDetik = 0;
    denyutHilang = 0;
    firmwareLama = false;
    _ibi.clear();
    _cuplikan.clear();
    _oksimeter.clear();
    _nSebelum = null;
    _paketSebelum = null;
    _subLive = _ble.liveStream.listen(_terimaLive);
    _detikRekam = Timer.periodic(const Duration(seconds: 1), (_) {
      detikRekam = DateTime.now().difference(_mulaiRekam!).inSeconds;
      if (detikRekam >= durasiRekam.inSeconds) {
        unawaited(_selesaiRekam(lengkap: true));
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void batalRekam() {
    if (!merekam) return;
    _hentikanRekam();
    _kabari('Rekaman dibatalkan dan tidak disimpan.');
    notifyListeners();
  }

  void catatOksimeter(int bpm) {
    if (!merekam) return;
    _oksimeter.add({
      'detik': DateTime.now().difference(_mulaiRekam!).inSeconds,
      'hr_oksimeter': bpm,
      'hr_gelang': (_ble.lastLive?['hr'] as num?)?.toInt(),
    });
    _kabari('Oksimeter $bpm bpm dicatat.');
    notifyListeners();
  }

  void _hentikanRekam() {
    merekam = false;
    _detikRekam?.cancel();
    _detikRekam = null;
    unawaited(_subLive?.cancel());
    _subLive = null;
  }

  void _terimaLive(Map<String, dynamic> m) {
    if (!merekam) return;
    // Paket tertunda berasal dari masa gelang terputus, bukan dari rekaman ini.
    if (m['buf'] == 1) return;

    final kini = DateTime.now();
    final jeda = _paketSebelum == null
        ? 5.0
        : kini.difference(_paketSebelum!).inMilliseconds / 1000.0;
    _paketSebelum = kini;

    // Perkiraan waktu tanpa data layak: paket tanpa denyut terkunci, atau
    // paket yang datang terlambat (gelang mengirim tiap 5 detik).
    final hr = (m['hr'] as num?)?.toInt() ?? 0;
    if (hr <= 0) {
      celahDetik += jeda.round();
    } else if (jeda > 8) {
      celahDetik += (jeda - 5).round();
    }

    final ibi = (m['ibi'] is List)
        ? (m['ibi'] as List).map((e) => (e as num).toInt()).toList()
        : <int>[];
    final n = (m['n'] as num?)?.toInt();
    List<int>? ibiPaket;

    if (n == null) {
      // Firmware lama tanpa penghitung denyut: selang antar-denyut tidak dapat
      // disambung tanpa dobel, jadi disimpan apa adanya per cuplikan.
      firmwareLama = true;
      ibiPaket = ibi;
    } else if (_nSebelum == null) {
      // Paket pertama: denyut di dalamnya terjadi SEBELUM rekaman dimulai.
    } else if (n >= _nSebelum!) {
      final baru = n - _nSebelum!;
      final ambil = baru > ibi.length ? ibi.length : baru;
      if (ambil > 0) _ibi.addAll(ibi.sublist(ibi.length - ambil));
      // Lebih dari 16 denyut di antara dua paket berarti ada yang tak terkirim.
      if (baru > ibi.length) denyutHilang += baru - ibi.length;
    } else {
      // Penghitung turun: riwayat denyut di gelang dikosongkan karena sinyal
      // hilang lebih dari 2,5 detik. Seluruh denyut dalam paket ini baru.
      final ambil = n > ibi.length ? ibi.length : n;
      if (ambil > 0) _ibi.addAll(ibi.sublist(ibi.length - ambil));
      if (n > ibi.length) denyutHilang += n - ibi.length;
    }
    if (n != null) _nSebelum = n;

    _cuplikan.add({
      'detik': (kini.difference(_mulaiRekam!).inMilliseconds / 1000).round(),
      'hr': hr,
      'prv': m['prv'],
      'voc': m['voc'],
      'temp': m['temp'],
      'hum': m['hum'],
      'ibi': ?ibiPaket,
    });
    notifyListeners();
  }

  Future<void> _selesaiRekam({required bool lengkap, String? alasan}) async {
    if (!merekam) return;
    final mulai = _mulaiRekam!;
    final durasi = DateTime.now().difference(mulai).inSeconds;
    _hentikanRekam();

    final nDenyut = _ibi.length;
    final nCuplikan = _cuplikan.length;
    final gabungCatatan = [
      if (catatan.trim().isNotEmpty) catatan.trim(),
      ?alasan,
      if (firmwareLama) 'firmware lama: IBI per cuplikan, belum disambung',
    ].join(' · ');

    final baris = <String, dynamic>{
      'subject_id': subjectId,
      'started_at': mulai.toUtc().toIso8601String(),
      'duration_s': durasi,
      'lengkap': lengkap,
      'n_beats': nDenyut,
      'lost_beats': denyutHilang,
      'gap_s': celahDetik,
      'ibi_raw': _ibi.isEmpty ? null : jsonEncode(_ibi),
      'samples': List<Map<String, dynamic>>.from(_cuplikan),
      'oximeter': List<Map<String, dynamic>>.from(_oksimeter),
      'glucose_ref': ?glukosa,
      if (gabungCatatan.isNotEmpty) 'note': gabungCatatan,
      'device_id': ?_namaGelang,
    };
    notifyListeners();
    await _unggah('clinical_recordings', baris,
        berhasil: 'Rekaman tersimpan: $nDenyut denyut · $nCuplikan cuplikan'
            '${lengkap ? '' : ' (tidak lengkap)'}');
  }

  // ════════════════════════════════════════════════════════════════════
  // Sampel napas
  // ════════════════════════════════════════════════════════════════════
  Future<void> ambilNapas() async {
    if (!sesiAktif || sibuk || !_ble.isConnected) return;
    tahapNapas = TahapNapas.memanaskan;
    sisaPemanasan = _pemanasanDetik;
    _mulaiNapas = DateTime.now();
    _detikNapas?.cancel();
    _detikNapas =
        Timer.periodic(const Duration(seconds: 1), (_) => _perbaruiNapas());
    notifyListeners();
    await _ble.sendCommand('VOC');
  }

  void _perbaruiNapas() {
    final s = DateTime.now().difference(_mulaiNapas!).inSeconds;
    if (s < _pemanasanDetik) {
      tahapNapas = TahapNapas.memanaskan;
      sisaPemanasan = _pemanasanDetik - s;
    } else if (s < _pemanasanDetik + _jendelaNapasDetik) {
      tahapNapas = TahapNapas.embuskan;
    } else if (s < _batasTungguDetik) {
      tahapNapas = TahapNapas.menganalisis;
    } else {
      _hentikanNapas();
      _kabari('Hasil napas tidak diterima dari gelang. Ulangi pengambilan.');
    }
    notifyListeners();
  }

  void _hentikanNapas() {
    _detikNapas?.cancel();
    _detikNapas = null;
    tahapNapas = TahapNapas.siap;
  }

  void _terimaEvent(Map<String, dynamic> m) {
    // Hanya hasil dari permintaan sesi ini yang disimpan.
    if (tahapNapas == TahapNapas.siap) return;
    final risk = m['risk']?.toString();
    if (risk == 'napas' || risk == 'risiko') {
      // Gelang baru mulai memanaskan: selaraskan hitung mundur dengan gelang.
      _mulaiNapas = DateTime.now();
      return;
    }
    if (risk == 'sampel' || risk == 'positif' || risk == 'negatif') {
      _hentikanNapas();
      sampelNapas++;
      notifyListeners();
      unawaited(_simpanNapas(m, sampelNapas));
    }
  }

  Future<void> _simpanNapas(Map<String, dynamic> m, int nomor) async {
    var suhu = (m['temp'] as num?)?.toDouble();
    var lembap = (m['hum'] as num?)?.toDouble();
    var rel = (m['rel'] as num?)?.toDouble();
    if (suhu == null) {
      // Firmware lama tidak menyertakan suhu dan simpangan pada event hasil;
      // keduanya diambil dari paket live yang dikirim tepat sesudahnya.
      await Future.delayed(const Duration(milliseconds: 800));
      final l = _ble.lastLive;
      if (l != null && l['voc'] == m['voc']) {
        suhu = (l['temp'] as num?)?.toDouble();
        lembap = (l['hum'] as num?)?.toDouble();
        rel = (l['voc_rel'] as num?)?.toDouble();
      }
    }
    final baris = <String, dynamic>{
      'subject_id': subjectId,
      'jenis': 'napas',
      'heart_rate': ?(m['hr'] as num?)?.toInt(),
      'voc_acetone': ?(m['voc'] as num?)?.toDouble(),
      'voc_rel': ?rel,
      'temperature': ?suhu,
      'humidity': ?lembap,
      'glucose_ref': ?glukosa,
      'note': [
        'Napas #$nomor',
        if (catatan.trim().isNotEmpty) catatan.trim(),
      ].join(' · '),
      'device_id': ?_namaGelang,
    };
    await _unggah('clinical_measurements', baris,
        berhasil: 'Sampel napas #$nomor tersimpan.');
  }

  // ════════════════════════════════════════════════════════════════════
  // Unggah & antrean tertunda
  // ════════════════════════════════════════════════════════════════════
  Future<void> _unggah(String tabel, Map<String, dynamic> baris,
      {required String berhasil}) async {
    try {
      await _service.simpanBaris(tabel, baris);
      _kabari(berhasil);
      onTersimpan?.call();
    } catch (_) {
      await _simpanTertunda(tabel, baris);
      _kabari('Gagal mengunggah — data disimpan di HP. '
          'Tekan "Unggah ulang" saat internet tersedia.');
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _bacaTertunda() async {
    try {
      final teks =
          await FlutterForegroundTask.getData<String>(key: _kunciTertunda);
      if (teks == null || teks.isEmpty) return [];
      return (jsonDecode(teks) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _tulisTertunda(List<Map<String, dynamic>> daftar) async {
    if (daftar.isEmpty) {
      await FlutterForegroundTask.removeData(key: _kunciTertunda);
    } else {
      await FlutterForegroundTask.saveData(
          key: _kunciTertunda, value: jsonEncode(daftar));
    }
    tertunda = daftar.length;
  }

  Future<void> _simpanTertunda(String tabel, Map<String, dynamic> baris) async {
    final daftar = await _bacaTertunda();
    daftar.add({'tabel': tabel, 'baris': baris});
    await _tulisTertunda(daftar);
  }

  Future<void> _hitungTertunda() async {
    tertunda = (await _bacaTertunda()).length;
    notifyListeners();
  }

  Future<void> unggahUlang() async {
    final daftar = await _bacaTertunda();
    final gagal = <Map<String, dynamic>>[];
    for (final item in daftar) {
      try {
        await _service.simpanBaris(item['tabel'] as String,
            Map<String, dynamic>.from(item['baris'] as Map));
      } catch (_) {
        gagal.add(item);
      }
    }
    await _tulisTertunda(gagal);
    _kabari(gagal.isEmpty
        ? 'Semua data tertunda berhasil diunggah.'
        : '${gagal.length} data masih gagal diunggah.');
    if (gagal.length < daftar.length) onTersimpan?.call();
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════════
  void _kabari(String teks) {
    if (!_pesan.isClosed) _pesan.add(teks);
  }

  @override
  void notifyListeners() {
    if (!_dibuang) super.notifyListeners();
  }

  @override
  void dispose() {
    _dibuang = true;
    _hentikanRekam();
    _hentikanNapas();
    unawaited(_subEvent?.cancel());
    _ble.removeListener(_onBle);
    if (sesiAktif && _ble.isConnected) {
      unawaited(_ble.sendCommand('MODEUJI:0'));
    }
    AlertService.instance.setModeUjiKlinik(false);
    unawaited(_pesan.close());
    super.dispose();
  }
}
