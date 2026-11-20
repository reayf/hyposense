import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:hyposense/services/foreground_service.dart';

/// Layanan BLE sisi HP pasien: scan, connect, dan berlangganan
/// notifikasi dari gelang HypoSense. UUID HARUS sama persis dengan
/// firmware (hyposense_esp32_ble.ino).
///
/// Tahap 2: hanya menampilkan data di app. Meneruskan ke Supabase +
/// buffer offline = Tahap 3.
class BleService extends ChangeNotifier {
  BleService._();
  static final BleService instance = BleService._();

  static final Guid svcUuid   = Guid('b1a70001-9c2e-4f1a-8d3b-2a6f5e4c7d80');
  static final Guid liveUuid  = Guid('b1a70002-9c2e-4f1a-8d3b-2a6f5e4c7d80');
  static final Guid eventUuid = Guid('b1a70003-9c2e-4f1a-8d3b-2a6f5e4c7d80');
  static final Guid cmdUuid   = Guid('b1a70004-9c2e-4f1a-8d3b-2a6f5e4c7d80');

  // 'disconnected' | 'scanning' | 'connecting' | 'connected'
  String state = 'disconnected';
  List<ScanResult> results = [];
  BluetoothDevice? device;
  BluetoothCharacteristic? _cmdChar;

  Map<String, dynamic>? lastLive;   // JSON live terakhir
  Map<String, dynamic>? lastEvent;  // JSON event terakhir
  DateTime? liveAt;                 // waktu lastLive diperbarui (untuk relay)
  DateTime? eventAt;                // waktu lastEvent diperbarui (untuk relay)
  String? errorMessage;

  // [lastLive] dan [lastEvent] hanya menyimpan paket TERAKHIR. Perekaman yang
  // membutuhkan setiap paket — rekaman detak 5 menit dan sampel napas uji
  // klinik — berlangganan aliran ini agar tak ada paket yang terlewat.
  final _liveCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _eventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get liveStream => _liveCtrl.stream;
  Stream<Map<String, dynamic>> get eventStream => _eventCtrl.stream;

  final List<StreamSubscription> _subs = [];

  bool get isConnected => state == 'connected';
  bool get isScanning => state == 'scanning';

  String deviceName(ScanResult r) {
    final adv = r.advertisementData.advName;
    if (adv.isNotEmpty) return adv;
    final p = r.device.platformName;
    if (p.isNotEmpty) return p;
    return r.device.remoteId.str;
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // untuk Android <= 11
    ].request();
    final scan = statuses[Permission.bluetoothScan];
    final connect = statuses[Permission.bluetoothConnect];
    return (scan == null || scan.isGranted) &&
           (connect == null || connect.isGranted);
  }

  Future<void> startScan() async {
    if (state == 'scanning' || state == 'connecting') return;
    errorMessage = null;

    if (!await _ensurePermissions()) {
      errorMessage = 'Izin Bluetooth ditolak. Aktifkan di Pengaturan HP.';
      notifyListeners();
      return;
    }

    // Baca status Bluetooth SEBENARNYA lewat stream — adapterStateNow
    // (cache) bisa 'unknown' sebelum stream teremit, sehingga dulu
    // salah dikira mati padahal menyala.
    BluetoothAdapterState adapter;
    try {
      adapter = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      adapter = FlutterBluePlus.adapterStateNow;
    }
    if (adapter != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn(); // Android: minta nyalakan Bluetooth
        adapter = await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
      if (adapter != BluetoothAdapterState.on) {
        errorMessage = 'Bluetooth HP mati. Nyalakan lalu coba lagi.';
        notifyListeners();
        return;
      }
    }

    results = [];
    state = 'scanning';
    notifyListeners();

    final sub = FlutterBluePlus.onScanResults.listen((r) {
      results = r;
      notifyListeners();
    }, onError: (_) {});
    _subs.add(sub);

    try {
      await FlutterBluePlus.startScan(
        withServices: [svcUuid],
        timeout: const Duration(seconds: 15),
      );
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
    } catch (e) {
      errorMessage = 'Gagal scan: $e';
    }
    if (state == 'scanning') state = 'disconnected';
    notifyListeners();
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (state == 'scanning') state = 'disconnected';
    notifyListeners();
  }

  Future<void> connect(BluetoothDevice d) async {
    await stopScan();
    device = d;
    state = 'connecting';
    errorMessage = null;
    notifyListeners();

    final cs = d.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && device == d) {
        state = 'disconnected';
        unawaited(ForegroundServiceHelper.stop());
        notifyListeners();
      }
    });
    _subs.add(cs);

    try {
      // license: nonprofit — proyek PKM (pendidikan/nonprofit), sesuai
      // ketentuan lisensi flutter_blue_plus 2.x. connect() otomatis
      // meminta MTU besar (default 512) sehingga JSON muat.
      await d.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );

      final services = await d.discoverServices();
      for (final s in services) {
        if (s.uuid != svcUuid) continue;
        for (final c in s.characteristics) {
          if (c.uuid == liveUuid) {
            await c.setNotifyValue(true);
            _subs.add(c.onValueReceived.listen((v) => _onData(v, false)));
          } else if (c.uuid == eventUuid) {
            await c.setNotifyValue(true);
            _subs.add(c.onValueReceived.listen((v) => _onData(v, true)));
          } else if (c.uuid == cmdUuid) {
            _cmdChar = c;
          }
        }
      }
      state = 'connected';
      // Nyalakan foreground service supaya BLE + relay tetap hidup saat
      // app ditutup / layar terkunci (Tahap 4).
      unawaited(ForegroundServiceHelper.start());
      // Auto-sinkron waktu ke gelang (jam OLED) begitu tersambung. Diberi
      // jeda singkat agar penulisan karakteristik stabil setelah discovery.
      unawaited(Future.delayed(const Duration(milliseconds: 800), () {
        if (isConnected) syncTime();
      }));
    } catch (e) {
      errorMessage = 'Gagal connect: $e';
      state = 'disconnected';
    }
    notifyListeners();
  }

  void _onData(List<int> bytes, bool isEvent) {
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (isEvent) {
        lastEvent = map;
        eventAt = DateTime.now();
        _eventCtrl.add(map);
      } else {
        lastLive = map;
        liveAt = DateTime.now();
        _liveCtrl.add(map);
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Kirim perintah teks ke gelang: 'VOC', 'RESETBASE', 'SYNC:[epoch]',
  /// 'CALR0', 'CALNAPAS', 'MODEUJI:1' / 'MODEUJI:0'.
  Future<void> sendCommand(String cmd) async {
    final c = _cmdChar;
    if (c == null) return;
    try {
      await c.write(utf8.encode(cmd), withoutResponse: false);
    } catch (_) {}
  }

  /// Kirim waktu HP ke gelang (untuk jam OLED). Epoch LOKAL.
  Future<void> syncTime() async {
    final localEpoch =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        DateTime.now().timeZoneOffset.inSeconds;
    await sendCommand('SYNC:$localEpoch');
  }

  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      await device?.disconnect();
    } catch (_) {}
    device = null;
    _cmdChar = null;
    lastLive = null;
    lastEvent = null;
    state = 'disconnected';
    unawaited(ForegroundServiceHelper.stop());
    notifyListeners();
  }
}
