import 'package:flutter/material.dart';
import 'package:hyposense/services/ble_service.dart';

/// Layar scan & sambung gelang HypoSense via BLE + tampilan data live.
/// (Tahap 2: verifikasi pipa BLE HP<-gelang. Teks belum di-i18n.)
class BleScreen extends StatelessWidget {
  const BleScreen({super.key});

  static const _blue = Color(0xFF3B6CFF);
  static const _green = Color(0xFF34C77B);
  static const _red = Color(0xFFE53935);
  static const _gray = Color(0xFF9AA0A6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Perangkat Gelang (BLE)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: BleService.instance,
          builder: (context, _) {
            final ble = BleService.instance;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  _statusRow(ble),
                  if (ble.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(ble.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: _red)),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: ble.isConnected
                        ? _connectedView(context, ble)
                        : _scanView(context, ble),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusRow(BleService ble) {
    final (label, color) = switch (ble.state) {
      'connected' => ('Tersambung', _green),
      'connecting' => ('Menyambungkan...', Colors.orange),
      'scanning' => ('Mencari perangkat...', _blue),
      _ => ('Tidak tersambung', _gray),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  // ── Tampilan scan (belum tersambung) ─────────────────────────
  Widget _scanView(BuildContext context, BleService ble) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: ble.isScanning ? ble.stopScan : ble.startScan,
            icon: Icon(ble.isScanning ? Icons.stop : Icons.bluetooth_searching),
            label: Text(ble.isScanning ? 'Hentikan' : 'Cari Gelang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (ble.results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              ble.isScanning
                  ? 'Memindai... pastikan gelang menyala.'
                  : 'Tekan "Cari Gelang" untuk memindai.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _gray),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: ble.results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = ble.results[i];
                return _card(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.watch, color: _blue),
                    title: Text(ble.deviceName(r),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Sinyal: ${r.rssi} dBm',
                        style: const TextStyle(fontSize: 12, color: _gray)),
                    trailing: TextButton(
                      onPressed: () => ble.connect(r.device),
                      child: const Text('Sambung'),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Tampilan tersambung (data live) ──────────────────────────
  Widget _connectedView(BuildContext context, BleService ble) {
    final live = ble.lastLive;
    final event = ble.lastEvent;
    final risk = event?['risk']?.toString();
    final buffered = (live?['buf'] == 1);

    return ListView(
      children: [
        _card(
          child: Row(
            children: [
              const Icon(Icons.watch, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ble.device?.platformName.isNotEmpty == true
                      ? ble.device!.platformName
                      : 'HypoSense',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (buffered)
                const Text('data tertunda',
                    style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (risk != null && risk != 'negatif')
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Status risiko: ${risk.toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _red)),
                ),
              ],
            ),
          ),
        Row(
          children: [
            _metric('Detak Jantung',
                live?['hr'] != null ? '${live!['hr']} bpm' : '--'),
            const SizedBox(width: 12),
            // Baterai dihapus: pembagi tegangannya belum terpasang.
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metric('Suhu',
                live?['temp'] != null ? '${live!['temp']}°C' : '--'),
            const SizedBox(width: 12),
            _metric('Kelembapan',
                live?['hum'] != null ? '${live!['hum']}%' : '--'),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Perintah ke gelang'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _cmdButton('Sinkron waktu', () => ble.syncTime()),
            _cmdButton('Minta cek napas', () => ble.sendCommand('VOC')),
            _cmdButton('Reset baseline', () => ble.sendCommand('RESETBASE')),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Kalibrasi sensor gas'),
        const SizedBox(height: 4),
        const Text(
          'Dua kalibrasi ini berbeda dan tidak boleh tertukar. '
          'Keduanya memanaskan sensor selama 60 detik lebih dulu.',
          style: TextStyle(fontSize: 12, color: _gray),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // R0 = resistansi sensor di udara bersih, dasar pengubahan ke ppm.
            _cmdButton('Kalibrasi udara bersih',
                () => _konfirmasi(
                      context,
                      'Kalibrasi udara bersih',
                      'Letakkan gelang di ruangan berudara bersih dan '
                          'JANGAN ditiup selama proses berlangsung.\n\n'
                          'Hasilnya dipakai mengubah bacaan sensor menjadi ppm.',
                      () => ble.sendCommand('CALR0'),
                    )),
            // Patokan napas = kadar aseton orang itu saat glukosanya NORMAL.
            // Tanpa ini, ambang 30% dari Turner tidak punya acuan yang sahih.
            _cmdButton('Rekam patokan napas',
                () => _konfirmasi(
                      context,
                      'Rekam patokan napas',
                      'Pastikan kadar gula pengguna sudah diperiksa dengan '
                          'glukometer dan hasilnya NORMAL.\n\n'
                          'Patokan ini menjadi acuan pembanding, sehingga '
                          'merekamnya saat gula tidak normal akan membuat '
                          'seluruh penilaian berikutnya keliru.',
                      () => ble.sendCommand('CALNAPAS'),
                    )),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: ble.disconnect,
            icon: const Icon(Icons.bluetooth_disabled, color: _red),
            label: const Text('Putuskan', style: TextStyle(color: _red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Data tersimpan otomatis ke cloud selama gelang tersambung.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: _gray),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: _card(
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: _gray)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _cmdButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _blue,
        side: const BorderSide(color: _blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _sectionLabel(String t) =>
      Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));

  /// Meminta penegasan sebelum menjalankan kalibrasi.
  ///
  /// Kedua kalibrasi memerlukan syarat yang tak terlihat dari layar — udara
  /// harus bersih, atau kadar gula harus sudah dipastikan normal. Menjalankan
  /// salah satunya pada keadaan yang keliru akan merusak acuan yang dipakai
  /// seluruh penilaian berikutnya, tanpa gejala apa pun. Karena itu syaratnya
  /// ditampilkan lebih dulu, bukan disembunyikan di balik satu ketukan.
  Future<void> _konfirmasi(BuildContext context, String judul, String isi,
      VoidCallback jalankan) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(judul),
        content: Text(isi),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Mulai')),
        ],
      ),
    );
    if (ya != true || !context.mounted) return;
    jalankan();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Sensor dipanaskan 60 detik — tunggu sampai selesai'),
      duration: Duration(seconds: 5),
    ));
  }

  Widget _card({required Widget child}) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: child,
      );
    });
  }
}
