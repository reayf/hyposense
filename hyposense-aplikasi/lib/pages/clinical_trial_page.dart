import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:hyposense/models/models.dart';
import 'package:hyposense/services/ble_service.dart';
import 'package:hyposense/services/clinical_service.dart';
import 'package:hyposense/services/clinical_session.dart';

const _primaryBlue = Color(0xFF3B6CFF);

/// Mode Uji Klinik — daftar subjek untuk pengumpulan data multi-pasien
/// dengan satu alat. Suster mendaftarkan pasien (kode/gender/umur), lalu
/// merekam data sensor + glukosa referensi per pasien.
class ClinicalTrialPage extends StatefulWidget {
  const ClinicalTrialPage({super.key});

  @override
  State<ClinicalTrialPage> createState() => _ClinicalTrialPageState();
}

class _ClinicalTrialPageState extends State<ClinicalTrialPage> {
  final _service = ClinicalService();
  late Future<List<ClinicalSubject>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getSubjects();
  }

  Future<void> _reload() async {
    final f = _service.getSubjects();
    setState(() => _future = f);
    await f;
  }

  Future<void> _addSubject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddSubjectDialog(),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Uji Klinik',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubject,
        backgroundColor: _primaryBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah Pasien',
            style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<ClinicalSubject>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorBox(message: '${snap.error}', onRetry: _reload);
            }
            final subjects = snap.data ?? [];
            if (subjects.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text('Belum ada pasien.\nTekan "Tambah Pasien".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: subjects.length,
              itemBuilder: (context, i) {
                final s = subjects[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _primaryBlue.withValues(alpha: 0.12),
                      child: const Icon(Icons.person, color: _primaryBlue),
                    ),
                    title: Text(s.patientCode,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_subtitle(s)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ClinicalSubjectDetailPage(subject: s),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _subtitle(ClinicalSubject s) {
    final parts = <String>[
      if (s.gender != null && s.gender!.isNotEmpty) s.gender!,
      if (s.age != null) '${s.age} th',
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

// ── Dialog tambah subjek ────────────────────────────────────────────
class _AddSubjectDialog extends StatefulWidget {
  const _AddSubjectDialog();

  @override
  State<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<_AddSubjectDialog> {
  final _code = TextEditingController();
  final _age = TextEditingController();
  String? _gender;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Kode pasien wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ClinicalService().addSubject(
        patientCode: code,
        gender: _gender,
        age: int.tryParse(_age.text.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      // 23505 = pelanggaran batasan unik. Basis data menolak kode pasien yang
      // sudah terpakai, supaya satu orang tidak terpecah menjadi dua subjek.
      setState(() {
        _saving = false;
        _error = e.code == '23505'
            ? 'Kode "$code" sudah terdaftar. Tutup dialog ini, lalu pilih '
                'pasien tersebut dari daftar.'
            : e.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Pasien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Kode Pasien *',
              hintText: 'mis. P001',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Gender',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['Laki-laki', 'Perempuan']
                .map((g) => ChoiceChip(
                      label: Text(g),
                      selected: _gender == g,
                      onSelected: (_) => setState(() => _gender = g),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Umur (tahun)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ── Detail subjek: sesi uji klinik + riwayat ────────────────────────
///
/// Urutan kerja petugas dibuat tampak sebagai langkah bernomor:
///   1. Mulai sesi   — patokan direset, gelang masuk mode uji klinik
///   2. Rekam detak  — 5 menit, pasien diam
///   3. Sampel napas — tersimpan otomatis tiap embusan
/// Tombol langkah berikutnya tidak dapat ditekan sebelum langkah
/// sebelumnya terpenuhi, dan tak ada dua pengukuran yang berjalan bersamaan.
class ClinicalSubjectDetailPage extends StatefulWidget {
  final ClinicalSubject subject;
  const ClinicalSubjectDetailPage({super.key, required this.subject});

  @override
  State<ClinicalSubjectDetailPage> createState() =>
      _ClinicalSubjectDetailPageState();
}

class _ClinicalSubjectDetailPageState
    extends State<ClinicalSubjectDetailPage> {
  final _service = ClinicalService();
  final _glucose = TextEditingController();
  final _note = TextEditingController();
  late final ClinicalSession _sesi;
  late Future<List<ClinicalMeasurement>> _future;
  late Future<List<ClinicalRecording>> _futureRekaman;
  StreamSubscription<String>? _subPesan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sesi = ClinicalSession(subjectId: widget.subject.id);
    _sesi.onTersimpan = () {
      if (mounted) _reload();
    };
    _subPesan = _sesi.pesan.listen((teks) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(teks)));
    });
    // Glukosa dan catatan berlaku untuk SELURUH data sesi ini, sehingga
    // diteruskan ke sesi setiap kali berubah — bukan hanya saat tombol ditekan.
    _glucose.addListener(() {
      _sesi.glukosa =
          double.tryParse(_glucose.text.trim().replaceAll(',', '.'));
    });
    _note.addListener(() => _sesi.catatan = _note.text);
    _future = _service.getMeasurements(widget.subject.id);
    _futureRekaman = _service.getRecordings(widget.subject.id);
  }

  @override
  void dispose() {
    _subPesan?.cancel();
    _sesi.dispose();
    _glucose.dispose();
    _note.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.getMeasurements(widget.subject.id);
      _futureRekaman = _service.getRecordings(widget.subject.id);
    });
  }

  /// Ambil nilai sensor dari data live BLE terakhir.
  ({
    int? hr,
    double? prv,
    double? voc,
    double? temp,
    double? hum,
    String? ibi
  }) _liveSnapshot() {
    final m = BleService.instance.lastLive;
    double? toD(dynamic v) => (v as num?)?.toDouble();
    // IBI mentah dikirim gelang sebagai array angka; disimpan apa adanya
    // (teks) supaya PRV dapat dihitung ulang saat analisis.
    final rawIbi = m?['ibi'];
    final ibi = (rawIbi is List && rawIbi.isNotEmpty) ? jsonEncode(rawIbi) : null;
    return (
      hr: (m?['hr'] as num?)?.toInt(),
      prv: toD(m?['prv']),
      voc: toD(m?['voc']),
      temp: toD(m?['temp']),
      hum: toD(m?['hum']),
      ibi: ibi,
    );
  }

  /// Snapshot manual — dipertahankan sebagai cadangan. Alur utama uji klinik
  /// memakai rekaman 5 menit dan sampel napas otomatis.
  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final ble = BleService.instance;
    if (!ble.isConnected) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Alat belum terhubung — sambungkan gelang dulu (ikon Bluetooth).')));
      return;
    }
    final snap = _liveSnapshot();
    if (snap.hr == null && snap.prv == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Belum ada data sensor masuk. Tunggu beberapa detik lalu coba lagi.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.addMeasurement(
        subjectId: widget.subject.id,
        jenis: 'manual',
        heartRate: snap.hr,
        prv: snap.prv,
        vocAcetone: snap.voc,
        temperature: snap.temp,
        humidity: snap.hum,
        glucoseRef: _sesi.glukosa,
        ibiRaw: snap.ibi,
        note: _note.text.trim(),
        deviceId: ble.device?.platformName,
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Snapshot tersimpan.')));
      if (mounted) _reload();
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Gagal simpan: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    final info = <String>[
      if (s.gender != null && s.gender!.isNotEmpty) s.gender!,
      if (s.age != null) '${s.age} th',
    ];
    return ListenableBuilder(
      listenable: _sesi,
      builder: (context, _) => PopScope(
        // Keluar di tengah pengukuran membuang data yang belum tersimpan,
        // jadi petugas diminta menegaskan lebih dulu.
        canPop: !_sesi.sibuk,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final keluar = await _konfirmasiKeluar();
          if (keluar && context.mounted) {
            _sesi.batalRekam();
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(s.patientCode,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (info.isNotEmpty)
                Text(info.join(' · '),
                    style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              if (_sesi.tertunda > 0) ...[
                _kartuTertunda(),
                const SizedBox(height: 12),
              ],
              _kartuSesi(),
              const SizedBox(height: 12),
              _kartuIsian(),
              const SizedBox(height: 12),
              _kartuRekam(),
              const SizedBox(height: 12),
              _kartuNapas(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_saving || !BleService.instance.isConnected)
                      ? null
                      : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving
                      ? 'Menyimpan...'
                      : 'Simpan Snapshot Manual (cadangan)'),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Rekaman Detak',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              _daftarRekaman(),
              const SizedBox(height: 20),
              const Text('Riwayat Pengukuran',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              _historyList(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1 · Sesi ────────────────────────────────────────────────────────
  Widget _kartuSesi() {
    final ble = BleService.instance;
    final snap = _liveSnapshot();
    return _kartu(
      judul: '1 · Sesi Pasien',
      children: [
        if (!ble.isConnected)
          _peringatan(
              Icons.bluetooth_disabled,
              Colors.orange,
              'Gelang belum tersambung. Buka menu "Perangkat Gelang (BLE)", '
              'tekan "Cari Gelang", lalu "Sambung".')
        else ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('HR', snap.hr?.toString() ?? '—', 'bpm'),
              _metric('PRV', snap.prv?.toStringAsFixed(1) ?? '—', 'ms'),
              _metric('Suhu', snap.temp?.toStringAsFixed(1) ?? '—', '°C'),
              _metric('Lembap', snap.hum?.toStringAsFixed(0) ?? '—', '%'),
            ],
          ),
          const SizedBox(height: 12),
          if (!_sesi.sesiAktif) ...[
            const Text(
              'Tekan sebelum pengukuran pertama pasien ini. Patokan personal '
              'gelang direset, dan gelang masuk mode uji klinik: hasil napas '
              'tidak ditampilkan sebagai risiko dan tidak membunyikan alarm.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sesi.mulaiSesi,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Mulai Sesi Pasien Ini'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else
            _peringatan(
                Icons.check_circle,
                Colors.green,
                'Sesi aktif sejak ${_jam(_sesi.sesiDimulai!)} · mode uji '
                'klinik menyala, alarm nonaktif'),
        ],
      ],
    );
  }

  Widget _kartuIsian() {
    return _kartu(
      judul: 'Data Rujukan',
      children: [
        TextField(
          controller: _glucose,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Glukosa referensi (glukometer)',
            suffixText: 'mg/dL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Catatan (obat beta-blocker, makan terakhir, dll.)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Berlaku untuk seluruh rekaman dan sampel napas pada sesi ini.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // ── 2 · Rekam detak ─────────────────────────────────────────────────
  Widget _kartuRekam() {
    const judul = '2 · Rekam Detak 5 Menit';
    final tersambung = BleService.instance.isConnected;

    if (!_sesi.merekam) {
      return _kartu(
        judul: judul,
        children: [
          const Text(
            'Pasien duduk tenang dan tidak bergerak. Jangan ambil sampel '
            'napas selama perekaman — gelang berhenti mengirim data detak '
            'saat memanaskan sensor gas.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_sesi.sesiAktif && tersambung && !_sesi.sibuk)
                  ? _sesi.mulaiRekam
                  : null,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Mulai Rekam 5 Menit'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (!_sesi.sesiAktif)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Mulai sesi terlebih dahulu.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
      );
    }

    final total = ClinicalSession.durasiRekam.inSeconds;
    return _kartu(
      judul: judul,
      children: [
        Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
            const SizedBox(width: 6),
            const Text('MEREKAM',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_mmss(_sesi.sisaDetik.clamp(0, total)),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _sesi.detikRekam / total),
        const SizedBox(height: 10),
        _baris('Denyut terkumpul', '${_sesi.jumlahDenyut}'),
        _baris('Sinyal hilang (perkiraan)', '${_sesi.celahDetik} dtk'),
        _baris('Catatan oksimeter', '${_sesi.jumlahOksimeter}'),
        if (_sesi.celahDetik >= 30)
          _peringatan(
              Icons.warning_amber_rounded,
              Colors.orange,
              'Sinyal sering hilang. Periksa posisi gelang; pertimbangkan '
              'mengulang rekaman.'),
        if (_sesi.firmwareLama)
          _peringatan(
              Icons.system_update_alt,
              Colors.orange,
              'Firmware gelang versi lama: selang antar-denyut belum dapat '
              'disambung. Perbarui firmware sebelum uji klinik.'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _catatOksimeter,
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('Catat Oksimeter'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _konfirmasiBatal,
                child: const Text('Batalkan',
                    style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 3 · Sampel napas ────────────────────────────────────────────────
  Widget _kartuNapas() {
    final bisa = _sesi.sesiAktif &&
        BleService.instance.isConnected &&
        !_sesi.sibuk;
    final judul =
        '3 · Sampel Napas (${_sesi.sampelNapas}/${ClinicalSession.targetNapas})';

    switch (_sesi.tahapNapas) {
      case TahapNapas.siap:
        return _kartu(
          judul: judul,
          children: [
            const Text(
              'Setiap sampel: sensor dipanaskan 60 detik, lalu pasien membuka '
              'katup geser dan mengembuskan napas panjang ke kabin sensor. '
              'Hasil tersimpan otomatis.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: bisa ? _sesi.ambilNapas : null,
                icon: const Icon(Icons.air),
                label: Text(_sesi.sampelNapas == 0
                    ? 'Ambil Sampel Napas'
                    : 'Ambil Sampel Napas Berikutnya'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_sesi.merekam)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Tunggu rekaman detak selesai.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        );
      case TahapNapas.memanaskan:
        return _kartu(judul: judul, children: [
          _statusNapas(
              Icons.local_fire_department_outlined,
              Colors.orange,
              'Sensor dipanaskan — ${_sesi.sisaPemanasan} dtk',
              'Minta pasien bersiap. Jangan embuskan napas dulu.'),
        ]);
      case TahapNapas.embuskan:
        return _kartu(judul: judul, children: [
          _statusNapas(
              Icons.air,
              _primaryBlue,
              'BUKA KATUP & EMBUSKAN SEKARANG',
              'Napas panjang dan perlahan ke kabin sensor, ±8 detik.',
              menonjol: true),
        ]);
      case TahapNapas.menganalisis:
        return _kartu(judul: judul, children: [
          _statusNapas(Icons.hourglass_top, Colors.grey,
              'Menganalisis sampel…', 'Hasil tersimpan otomatis.'),
        ]);
    }
  }

  Widget _kartuTertunda() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${_sesi.tertunda} data belum terunggah',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: _sesi.unggahUlang,
              child: const Text('Unggah ulang')),
        ],
      ),
    );
  }

  // ── Dialog ──────────────────────────────────────────────────────────
  Future<bool> _konfirmasiKeluar() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Pengukuran sedang berjalan'),
        content: const Text(
            'Keluar sekarang akan membatalkan rekaman detak atau sampel napas '
            'yang belum tersimpan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Tetap di sini')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child:
                  const Text('Keluar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ya == true;
  }

  Future<void> _konfirmasiBatal() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Batalkan rekaman?'),
        content: const Text('Data rekaman ini tidak akan disimpan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Lanjutkan merekam')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Batalkan',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ya == true) _sesi.batalRekam();
  }

  Future<void> _catatOksimeter() async {
    final c = TextEditingController();
    final bpm = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Catat Oksimeter'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Detak jantung pada oksimeter',
            suffixText: 'bpm',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(d, int.tryParse(c.text.trim())),
              child: const Text('Catat')),
        ],
      ),
    );
    if (bpm != null && bpm > 20 && bpm < 250) _sesi.catatOksimeter(bpm);
  }

  // ── Riwayat ─────────────────────────────────────────────────────────
  Widget _daftarRekaman() {
    return FutureBuilder<List<ClinicalRecording>>(
      future: _futureRekaman,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text(
              'Gagal memuat rekaman: ${snap.error}\n'
              'Sudah jalankan clinical_trial_setup.sql terbaru?',
              style: const TextStyle(fontSize: 12, color: Colors.grey));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada rekaman detak.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: items
              .map((r) => Card(
                    child: ListTile(
                      title: Text(_fmtTime(r.startedAt),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text([
                        _mmss(r.durationS),
                        '${r.nBeats} denyut',
                        if (r.gapS > 0) 'celah ${r.gapS} dtk',
                        if (r.jumlahOksimeter > 0)
                          '${r.jumlahOksimeter} oksimeter',
                        if (!r.lengkap) 'tidak lengkap',
                      ].join(' · ')),
                      trailing: r.glucoseRef != null
                          ? _nilaiGlukosa(r.glucoseRef!)
                          : null,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _historyList() {
    return FutureBuilder<List<ClinicalMeasurement>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _ErrorBox(message: '${snap.error}', onRetry: _reload);
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: Text('Belum ada pengukuran.',
                    style: TextStyle(color: Colors.grey))),
          );
        }
        return Column(
          children: items
              .map((m) => Card(
                    child: ListTile(
                      title: Text(_fmtTime(m.createdAt),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(_measSummary(m)),
                      trailing: m.glucoseRef != null
                          ? _nilaiGlukosa(m.glucoseRef!)
                          : null,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  String _measSummary(ClinicalMeasurement m) {
    return <String>[
      if (m.jenis == 'napas') 'Napas',
      if (m.jenis == 'manual') 'Manual',
      if (m.heartRate != null) 'HR ${m.heartRate}',
      if (m.prv != null) 'PRV ${m.prv!.toStringAsFixed(1)}',
      if (m.vocAcetone != null) 'Ace ${m.vocAcetone!.toStringAsFixed(0)}',
      if (m.vocRel != null)
        '${m.vocRel! >= 0 ? '+' : ''}${m.vocRel!.toStringAsFixed(1)}%',
      if (m.temperature != null) '${m.temperature!.toStringAsFixed(1)}°C',
    ].join(' · ');
  }

  // ── Komponen kecil ──────────────────────────────────────────────────
  Widget _kartu({required String judul, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _peringatan(IconData ikon, Color warna, String teks) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: warna, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(teks, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _statusNapas(IconData ikon, Color warna, String judul,
      String keterangan,
      {bool menonjol = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: menonjol ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: menonjol ? Border.all(color: warna, width: 2) : null,
      ),
      child: Column(
        children: [
          Icon(ikon, color: warna, size: menonjol ? 40 : 28),
          const SizedBox(height: 8),
          Text(judul,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: menonjol ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  color: warna)),
          const SizedBox(height: 4),
          Text(keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _baris(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Text(nilai,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 3),
              Text(unit,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nilaiGlukosa(double g) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(g.toStringAsFixed(0),
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _primaryBlue)),
        const Text('mg/dL',
            style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  String _mmss(int detik) =>
      '${detik ~/ 60}:${(detik % 60).toString().padLeft(2, '0')}';

  String _jam(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  String _fmtTime(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }
}

// ── Kotak error ────────────────────────────────────────────────────
class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text(
                'Sudah jalankan clinical_trial_setup.sql di Supabase?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
