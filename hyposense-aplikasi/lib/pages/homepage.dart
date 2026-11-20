import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/models/models.dart';
import 'package:hyposense/services/auth_service.dart';
import 'package:hyposense/services/ble_service.dart';
import 'package:hyposense/services/database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  final _dbService = DatabaseService();

  UserProfile? _profile;
  DeviceData? _deviceData;
  RiskLog? _riskLog;
  Reading? _latestReading;
  StreamSubscription<Reading?>? _readingSub;
  bool _isLoading = true;

  static const _primaryBlue = Color(0xFF3B6CFF);
  static const _safeGreen = Color(0xFF34C77B);
  static const _warnOrange = Color(0xFFFF9800);
  static const _dangerRed = Color(0xFFE53935);
  static const _textGray = Color(0xFF9AA0A6);

  AppLocalizations get t => AppLocalizations.of(context);
  BleService get _ble => BleService.instance;

  /// Data live dari gelang via BLE (null jika tidak tersambung).
  Map<String, dynamic>? get _live => _ble.isConnected ? _ble.lastLive : null;
  Map<String, dynamic>? get _event => _ble.isConnected ? _ble.lastEvent : null;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeReadings();
    // Rebuild saat data BLE masuk / status koneksi berubah.
    _ble.addListener(_onBle);
  }

  @override
  void dispose() {
    _readingSub?.cancel();
    _ble.removeListener(_onBle);
    super.dispose();
  }

  void _onBle() {
    if (mounted) setState(() {});
  }

  /// Langganan realtime ke tabel `readings` (fallback cloud).
  void _subscribeReadings() {
    _readingSub = _dbService.latestReadingStream().listen(
      (reading) {
        if (mounted) setState(() => _latestReading = reading);
      },
      onError: (_) {},
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _dbService.getProfile(),
        _dbService.getLatestDeviceData(),
        _dbService.getLatestRiskLog(),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as UserProfile?;
          _deviceData = results[1] as DeviceData?;
          _riskLog = results[2] as RiskLog?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _riskColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'WARNING':
        return _warnOrange;
      case 'DANGER':
        return _dangerRed;
      default:
        return _safeGreen;
    }
  }

  Color _riskBg(String? status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (status?.toUpperCase()) {
      case 'WARNING':
        return dark ? const Color(0xFF3A2E14) : const Color(0xFFFFF3E0);
      case 'DANGER':
        return dark ? const Color(0xFF3A1A1A) : const Color(0xFFFFEBEE);
      default:
        return dark ? const Color(0xFF16233A) : const Color(0xFFEAF3FF);
    }
  }

  String _statusText(String status) {
    switch (status.toUpperCase()) {
      case 'WARNING':
        return t.statusWarning;
      case 'DANGER':
        return t.statusDanger;
      default:
        return t.statusSafe;
    }
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t.justNow;
    if (diff.inMinutes < 60) return t.minutesAgo('${diff.inMinutes}');
    if (diff.inHours < 24) return t.hoursAgo('${diff.inHours}');
    return t.daysAgo('${diff.inDays}');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _buildHeader(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDeviceInfoCard(),
                        const SizedBox(height: 16),
                        _buildHypoglycemiaCard(),
                        const SizedBox(height: 16),
                        _buildMetricsRow(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profile?.fullName ?? _authService.currentUser?.email ?? 'User';
    // Tersambung jika BLE tersambung (prioritas), atau ada reading cloud
    // segar (<2 mnt), atau info device_data lama.
    final reading = _latestReading;
    final isConnected = _ble.isConnected ||
        (reading != null
            ? DateTime.now().difference(reading.createdAt).inMinutes < 2
            : _deviceData != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.greeting(name),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: isConnected ? _safeGreen : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              isConnected ? t.wearableConnected : t.wearableNotConnected,
              style: const TextStyle(fontSize: 13, color: _textGray),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceInfoCard() {
    final d = _deviceData;
    final connection =
        _ble.isConnected ? 'BLE' : (d?.connectionStrength ?? '--');
    final lastUpd = _ble.isConnected
        ? t.justNow
        : (d?.lastUpdate != null ? _relTime(d!.lastUpdate) : t.notAvailable);
    final vocActive = _ble.isConnected
        ? (_event?['voc'] != null)
        : (d?.vocSensorActive ?? false);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.deviceInformation,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          // Baris baterai dihapus: pembagi tegangannya belum terpasang,
          // sehingga persentasenya tidak mencerminkan keadaan sebenarnya.
          _infoRow(Icons.bluetooth, t.connectionLabel(connection)),
          const SizedBox(height: 10),
          _infoRow(Icons.access_time, t.lastUpdate(lastUpd)),
          const SizedBox(height: 10),
          _infoRow(Icons.sensors,
              t.vocSensorLabel(vocActive ? t.active : t.inactive)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primaryBlue),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildHypoglycemiaCard() {
    final String status;
    final String message;

    // Prioritas: event risiko dari BLE > reading cloud > risk_logs lama.
    final bleRisk = _event?['risk']?.toString();
    if (bleRisk != null) {
      if (bleRisk == 'positif') {
        status = 'DANGER';
        message = t.riskDetectedMsg;
      } else if (bleRisk == 'risiko') {
        status = 'WARNING';
        message = t.riskDetectedMsg;
      } else {
        status = 'SAFE';
        message = t.allParamsSafe;
      }
    } else {
      final reading = _latestReading;
      if (reading != null) {
        status = reading.isPositif ? 'DANGER' : 'SAFE';
        message = reading.isPositif ? t.riskDetectedMsg : t.allParamsSafe;
      } else {
        final log = _riskLog;
        final fresh = log != null &&
            DateTime.now().difference(log.createdAt).inMinutes < 30;
        status = fresh ? log.riskStatus : 'SAFE';
        message = (fresh && log.message.isNotEmpty)
            ? log.message
            : t.allParamsSafe;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _riskBg(status),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.hypoglycemiaRisk,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  t.statusLabel(_statusText(status)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _riskColor(status),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, color: _textGray),
                ),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _riskColor(status),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status.toUpperCase() == 'SAFE'
                  ? Icons.check
                  : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    // Sumber data: BLE (live/event) saat tersambung, jika tidak fallback
    // ke reading cloud.
    final live = _live;
    final event = _event;
    final r = _latestReading;
    final connected = live != null;

    final num? hr = live?['hr'] as num? ?? r?.heartRate;
    final num? voc = event?['voc'] as num? ?? r?.vocAcetone;
    final num? temp = live?['temp'] as num? ?? r?.temperature;
    final num? hum = live?['hum'] as num? ?? r?.humidity;

    final timeLabel = connected
        ? t.justNow
        : (r != null ? _relTime(r.createdAt) : t.waitingForDevice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              t.liveSensorData,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(timeLabel,
                style: const TextStyle(fontSize: 11, color: _textGray)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.favorite_outline,
                label: t.heartRate,
                value: hr != null ? '$hr bpm' : '--',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                icon: Icons.air,
                label: t.vocLabel,
                value: voc != null ? voc.toStringAsFixed(0) : '--',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.thermostat_outlined,
                label: t.temperature,
                value: temp != null ? '${temp.toStringAsFixed(1)}°C' : '--',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                icon: Icons.water_drop_outlined,
                label: t.humidity,
                value: hum != null ? '${hum.toStringAsFixed(0)}%' : '--',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 20, color: _primaryBlue),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 11, color: _textGray)),
          const SizedBox(height: 4),
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
