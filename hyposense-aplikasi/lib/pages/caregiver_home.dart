import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/models/models.dart';
import 'package:hyposense/services/database_service.dart';

/// Beranda perawat: daftar pasien yang terhubung (di-assign admin).
class CaregiverHomePage extends StatefulWidget {
  const CaregiverHomePage({super.key});

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  final _dbService = DatabaseService();

  List<UserProfile> _patients = [];
  bool _isLoading = true;

  static const _primaryBlue = Color(0xFF3B6CFF);
  static const _textGray = Color(0xFF9AA0A6);

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final patients = await _dbService.getMyPatients();
      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
            Text(t.caregiverTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(t.caregiverSubtitle,
                style: const TextStyle(fontSize: 13, color: _textGray)),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _patients.isEmpty
                          ? ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 60),
                                Icon(Icons.people_outline,
                                    size: 56,
                                    color: _textGray.withValues(alpha: 0.6)),
                                const SizedBox(height: 16),
                                Text(t.noPatientsYet,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 13, color: _textGray)),
                                const SizedBox(height: 8),
                                Text(t.patientMaybeHidden,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12, color: _textGray)),
                              ],
                            )
                          : ListView.separated(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              itemCount: _patients.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _patientCard(_patients[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientCard(UserProfile p) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PatientDetailPage(patient: p)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _primaryBlue,
              child: Text(
                (p.fullName.isNotEmpty ? p.fullName[0] : 'P').toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.fullName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (p.email != null)
                    Text(p.email!,
                        style: const TextStyle(
                            fontSize: 12, color: _textGray)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textGray),
          ],
        ),
      ),
    );
  }
}

/// Detail pasien untuk perawat: kontak darurat + riwayat risiko per hari.
class PatientDetailPage extends StatefulWidget {
  final UserProfile patient;

  const PatientDetailPage({super.key, required this.patient});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  final _dbService = DatabaseService();

  List<RiskLog> _logs = [];
  bool _isLoading = true;
  late final Stream<Reading?> _readingStream;

  static const _primaryBlue = Color(0xFF3B6CFF);
  static const _safeGreen = Color(0xFF34C77B);
  static const _dangerRed = Color(0xFFE53935);
  static const _textGray = Color(0xFF9AA0A6);

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    // Data sensor live milik pasien ini (RLS menegakkan izin akses).
    _readingStream = _dbService.patientReadingStream(widget.patient.id);
    _load();
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t.justNow;
    if (diff.inMinutes < 60) return t.minutesAgo('${diff.inMinutes}');
    if (diff.inHours < 24) return t.hoursAgo('${diff.inHours}');
    return t.daysAgo('${diff.inDays}');
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _dbService.getPatientRiskLogs(widget.patient.id);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kelompokkan log per tanggal (kunci terurut terbaru dulu — log
  /// sudah diurut desc dari query).
  Map<DateTime, List<RiskLog>> get _groupedByDay {
    final map = <DateTime, List<RiskLog>>{};
    for (final log in _logs) {
      final local = log.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      map.putIfAbsent(day, () => []).add(log);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final dayFormat = DateFormat.yMMMMEEEEd(locale);
    final timeFormat = DateFormat.Hm(locale);
    final grouped = _groupedByDay;
    final contact = widget.patient.emergencyContact?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.patient.fullName,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  children: [
                    _card(
                      child: Row(
                        children: [
                          const Icon(Icons.contact_phone_outlined,
                              size: 20, color: Color(0xFF3B6CFF)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.emergencyContactTitle,
                                    style: const TextStyle(
                                        fontSize: 12, color: _textGray)),
                                Text(
                                    contact.isNotEmpty
                                        ? contact
                                        : t.notSet,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLiveDataCard(),
                    const SizedBox(height: 16),
                    Text(t.riskHistory,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (grouped.isEmpty) ...[
                      const SizedBox(height: 24),
                      Text(t.noHistoryYet,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: _textGray)),
                    ] else
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Text(
                            dayFormat.format(entry.key),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        _card(
                          child: Column(
                            children: [
                              for (var i = 0; i < entry.value.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                      height: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                _logRow(entry.value[i], timeFormat),
                              ],
                            ],
                          ),
                        ),
                      ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  /// Kartu data sensor live pasien (update otomatis via realtime).
  Widget _buildLiveDataCard() {
    return StreamBuilder<Reading?>(
      stream: _readingStream,
      builder: (context, snapshot) {
        final r = snapshot.data;
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.liveSensorData,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (r != null)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: r.isPositif ? _dangerRed : _safeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    r != null
                        ? _relTime(r.createdAt)
                        : t.waitingForDevice,
                    style:
                        const TextStyle(fontSize: 11, color: _textGray),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniMetric(Icons.favorite_outline, t.heartRate,
                      r != null ? '${r.heartRate}' : '--'),
                  _miniMetric(Icons.air, 'VOC',
                      r != null ? r.vocAcetone.toStringAsFixed(0) : '--'),
                  _miniMetric(Icons.thermostat_outlined, t.temperature,
                      r != null
                          ? '${r.temperature.toStringAsFixed(1)}°'
                          : '--'),
                  _miniMetric(Icons.water_drop_outlined, t.humidity,
                      r != null
                          ? '${r.humidity.toStringAsFixed(0)}%'
                          : '--'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniMetric(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: _primaryBlue),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: _textGray)),
        ],
      ),
    );
  }

  Widget _logRow(RiskLog log, DateFormat timeFormat) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: _dangerRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            log.message.isNotEmpty ? log.message : log.riskStatus,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(
          timeFormat.format(log.createdAt.toLocal()),
          style: const TextStyle(fontSize: 12, color: _textGray),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
