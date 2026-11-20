import 'package:flutter/material.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/models/models.dart';
import 'package:hyposense/services/auth_service.dart';
import 'package:hyposense/services/database_service.dart';

/// Beranda admin: atur peran pengguna dan hubungkan perawat <-> pasien.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _dbService = DatabaseService();
  final _authService = AuthService();

  List<UserProfile> _profiles = [];
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
      final profiles = await _dbService.getAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _roleText(String role) {
    switch (role) {
      case 'caregiver':
        return t.roleCaregiver;
      case 'admin':
        return t.roleAdmin;
      default:
        return t.rolePatient;
    }
  }

  Future<void> _changeRole(UserProfile p, String newRole) async {
    try {
      await _dbService.updateUserRole(p.id, newRole);
      _showSnackBar(t.roleUpdated);
      await _load();
    } catch (e) {
      _showSnackBar(t.actionFailed('$e'), isError: true);
    }
  }

  void _openManageLinks(UserProfile caregiver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ManageLinksSheet(
        caregiver: caregiver,
        allProfiles: _profiles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = _authService.currentUser?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(t.adminTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(t.adminSubtitle,
                style: const TextStyle(fontSize: 13, color: _textGray)),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _profiles.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _userCard(_profiles[i], isSelf: _profiles[i].id == myId),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userCard(UserProfile p, {required bool isSelf}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _primaryBlue,
                child: Text(
                  (p.fullName.isNotEmpty ? p.fullName[0] : 'U').toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
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
                              fontSize: 11, color: _textGray)),
                  ],
                ),
              ),
              // Admin tidak bisa menurunkan perannya sendiri dari sini
              // (mencegah terkunci tanpa admin sama sekali).
              if (isSelf)
                Text(_roleText(p.role),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryBlue))
              else
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: p.role,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface),
                    items: [
                      DropdownMenuItem(
                          value: 'patient', child: Text(t.rolePatient)),
                      DropdownMenuItem(
                          value: 'caregiver',
                          child: Text(t.roleCaregiver)),
                      DropdownMenuItem(
                          value: 'admin', child: Text(t.roleAdmin)),
                    ],
                    onChanged: (v) {
                      if (v != null && v != p.role) _changeRole(p, v);
                    },
                  ),
                ),
            ],
          ),
          if (p.role == 'caregiver') ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openManageLinks(p),
                icon: const Icon(Icons.link, size: 16),
                label: Text(t.managePatientsBtn,
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet: kelola pasien yang terhubung dengan seorang perawat.
class _ManageLinksSheet extends StatefulWidget {
  final UserProfile caregiver;
  final List<UserProfile> allProfiles;

  const _ManageLinksSheet({
    required this.caregiver,
    required this.allProfiles,
  });

  @override
  State<_ManageLinksSheet> createState() => _ManageLinksSheetState();
}

class _ManageLinksSheetState extends State<_ManageLinksSheet> {
  final _dbService = DatabaseService();

  List<CareLink> _links = [];
  String? _selectedPatientId;
  bool _isLoading = true;
  bool _isWorking = false;

  static const _textGray = Color(0xFF9AA0A6);

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final links = await _dbService.getCareLinks(widget.caregiver.id);
      if (mounted) {
        setState(() {
          _links = links;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  UserProfile? _profileById(String id) {
    for (final p in widget.allProfiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<UserProfile> get _availablePatients {
    final linkedIds = _links.map((l) => l.patientId).toSet();
    return widget.allProfiles
        .where((p) => p.role == 'patient' && !linkedIds.contains(p.id))
        .toList();
  }

  Future<void> _addLink() async {
    final patientId = _selectedPatientId;
    if (patientId == null || _isWorking) return;
    setState(() => _isWorking = true);
    try {
      await _dbService.addCareLink(widget.caregiver.id, patientId);
      _selectedPatientId = null;
      await _load();
    } catch (_) {
      // biarkan; user bisa coba lagi
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _removeLink(CareLink link) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await _dbService.removeCareLink(link.id);
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _availablePatients;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.managePatientsBtn} — ${widget.caregiver.fullName}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(t.linkedPatients,
                    style: const TextStyle(fontSize: 12, color: _textGray)),
                const SizedBox(height: 6),
                if (_links.isEmpty)
                  const Text('—',
                      style: TextStyle(fontSize: 13, color: _textGray))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final link in _links)
                        Chip(
                          label: Text(
                            _profileById(link.patientId)?.fullName ??
                                link.patientId,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted:
                              _isWorking ? null : () => _removeLink(link),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(t.addPatient,
                    style: const TextStyle(fontSize: 12, color: _textGray)),
                const SizedBox(height: 6),
                if (available.isEmpty)
                  Text(t.noAvailablePatients,
                      style:
                          const TextStyle(fontSize: 13, color: _textGray))
                else
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPatientId,
                              isExpanded: true,
                              hint: Text(t.addPatient,
                                  style: const TextStyle(fontSize: 13)),
                              items: [
                                for (final p in available)
                                  DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.fullName,
                                        style:
                                            const TextStyle(fontSize: 13)),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedPatientId = v),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: (_selectedPatientId == null || _isWorking)
                            ? null
                            : _addLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B6CFF),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(t.add),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
