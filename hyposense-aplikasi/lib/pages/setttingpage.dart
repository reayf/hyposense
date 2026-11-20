import 'package:flutter/material.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/models/models.dart';
import 'package:hyposense/services/alert_service.dart';
import 'package:hyposense/services/auth_service.dart';
import 'package:hyposense/services/database_service.dart';
import 'package:hyposense/services/settings_controller.dart';

enum RiskAlertLevel { moderate, high }
enum AlertMethod { sound, vibration, notification }
enum AppTheme { light, dark }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _authService = AuthService();
  final _dbService = DatabaseService();
  final _emergencyContactController = TextEditingController();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  bool _saveDataToCloud = true;
  bool _shareDataWithCaregiver = true;
  bool _enableAlarm = true;
  RiskAlertLevel _riskAlertLevel = RiskAlertLevel.moderate;
  AlertMethod _alertMethod = AlertMethod.sound;
  AppTheme _theme = AppTheme.light;
  String _language = 'English';

  static const _primaryBlue = Color(0xFF3B6CFF);
  static const _textGray = Color(0xFF9AA0A6);
  static const _appVersion = '1.2.5';

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _dbService.getProfile();
      final settings = await _dbService.getSettings();

      if (mounted) {
        setState(() {
          _profile = profile;

          if (settings != null) {
            _saveDataToCloud = settings.saveToCloud;
            _shareDataWithCaregiver = settings.shareWithCaregiver;
            _enableAlarm = settings.enableAlarm;
            _riskAlertLevel = settings.riskAlertLevel == 'high'
                ? RiskAlertLevel.high
                : RiskAlertLevel.moderate;
            _alertMethod = AlertMethod.values.firstWhere(
              (e) => e.name == settings.alertMethod,
              orElse: () => AlertMethod.sound,
            );
            _theme = settings.theme == 'dark' ? AppTheme.dark : AppTheme.light;
            _language = settings.language;
          }

          if (profile?.emergencyContact != null) {
            _emergencyContactController.text = profile!.emergencyContact!;
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  UserSettings? _currentSettings() {
    final userId = _authService.currentUser?.id;
    if (userId == null) return null;
    return UserSettings(
      userId: userId,
      saveToCloud: _saveDataToCloud,
      shareWithCaregiver: _shareDataWithCaregiver,
      enableAlarm: _enableAlarm,
      riskAlertLevel: _riskAlertLevel.name,
      alertMethod: _alertMethod.name,
      theme: _theme.name,
      language: _language,
    );
  }

  /// Terapkan pilihan ke seluruh aplikasi SEKETIKA (tema & bahasa
  /// berubah langsung; tersimpan permanen saat tombol Simpan ditekan).
  void _previewApply() {
    final s = _currentSettings();
    if (s != null) SettingsController.instance.apply(s);
  }

  Future<void> _saveSettings() async {
    final newSettings = _currentSettings();
    if (newSettings == null) return;
    setState(() => _isSaving = true);
    try {
      await _dbService.saveSettings(newSettings);
      SettingsController.instance.apply(newSettings);

      // Update emergency contact di profile
      if (_profile != null) {
        final updatedProfile = UserProfile(
          id: _profile!.id,
          fullName: _profile!.fullName,
          role: _profile!.role,
          emergencyContact: _emergencyContactController.text.trim(),
          createdAt: _profile!.createdAt,
        );
        await _dbService.updateProfile(updatedProfile);
        SettingsController.instance.applyProfile(updatedProfile);
        _profile = updatedProfile;
      }

      _showSnackBar(t.settingsSaved);
    } catch (e) {
      _showSnackBar(t.settingsSaveFailed('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logout),
        content: Text(t.logoutConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.logout,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await AlertService.instance.stop();
      SettingsController.instance.clear();
      await _authService.signOut();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(
          child: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 16),
                    if (SettingsController.instance.role == 'patient') ...[
                      const SizedBox(height: 16),
                    ],
                    _buildDataPrivacyCard(),
                    const SizedBox(height: 16),
                    _buildAlertsSafetyCard(),
                    const SizedBox(height: 16),
                    _buildAppSettingsCard(),
                    const SizedBox(height: 16),
                    _primaryButton(
                      _isSaving ? t.saving : t.saveSettings,
                      _isSaving ? () {} : _saveSettings,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _onLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(t.logout,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleText(String role) {
    switch (role.toLowerCase()) {
      case 'caregiver':
        return t.roleCaregiver;
      case 'admin':
        return t.roleAdmin;
      default:
        return t.rolePatient;
    }
  }

  Widget _buildProfileCard() {
    final name = _profile?.fullName ?? 'User';
    final role = _roleText(_profile?.role ?? 'patient');
    final email = _authService.currentUser?.email ?? '';

    final avatarUrl = _profile?.avatarUrl;
    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _primaryBlue,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(email,
                    style: const TextStyle(fontSize: 12, color: _textGray)),
                Text(t.roleLabel(role),
                    style: const TextStyle(fontSize: 12, color: _textGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPrivacyCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(t.sectionDataPrivacy),
          const SizedBox(height: 12),
          _switchRow(
            label: t.saveDataToCloud,
            value: _saveDataToCloud,
            onChanged: (v) {
              setState(() => _saveDataToCloud = v);
              _previewApply();
            },
          ),
          _note(t.saveDataToCloudNote),
          const SizedBox(height: 10),
          _switchRow(
            label: t.shareWithCaregiver,
            value: _shareDataWithCaregiver,
            onChanged: (v) {
              setState(() => _shareDataWithCaregiver = v);
              _previewApply();
            },
          ),
          _note(t.shareWithCaregiverNote),
        ],
      ),
    );
  }

  Widget _buildAlertsSafetyCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(t.sectionAlertsSafety),
          const SizedBox(height: 4),
          _note(t.alertsScopeNote),
          const SizedBox(height: 12),
          _switchRow(
            label: t.enableAlarm,
            value: _enableAlarm,
            onChanged: (v) {
              setState(() => _enableAlarm = v);
              _previewApply();
            },
          ),
          const SizedBox(height: 14),
          _label(t.riskAlertLevel),
          const SizedBox(height: 4),
          _radioGroup<RiskAlertLevel>(
            groupValue: _riskAlertLevel,
            onChanged: (v) {
              setState(() => _riskAlertLevel = v ?? _riskAlertLevel);
              _previewApply();
            },
            options: {
              t.levelModerate: RiskAlertLevel.moderate,
              t.levelHigh: RiskAlertLevel.high,
            },
          ),
          _note(t.riskAlertLevelNote),
          const SizedBox(height: 10),
          _label(t.alertMethod),
          const SizedBox(height: 4),
          _radioGroup<AlertMethod>(
            groupValue: _alertMethod,
            onChanged: (v) {
              setState(() => _alertMethod = v ?? _alertMethod);
              _previewApply();
            },
            wrap: true,
            options: {
              t.methodSound: AlertMethod.sound,
              t.methodVibration: AlertMethod.vibration,
              t.methodNotification: AlertMethod.notification,
            },
          ),
          if (_alertMethod == AlertMethod.notification)
            _note(t.methodNotificationNote),
          const SizedBox(height: 14),
          _label(t.emergencyContact),
          const SizedBox(height: 6),
          TextField(
            controller: _emergencyContactController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: t.emergencyContactHint,
              hintStyle: const TextStyle(fontSize: 13, color: _textGray),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: _fieldBorder(),
              enabledBorder: _fieldBorder(),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      );

  Widget _buildAppSettingsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(t.sectionAppSettings),
          const SizedBox(height: 12),
          _label(t.languageLabel),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'English', child: Text('English')),
                  DropdownMenuItem(
                      value: 'Bahasa Indonesia',
                      child: Text('Bahasa Indonesia')),
                ],
                onChanged: (v) {
                  setState(() => _language = v ?? _language);
                  _previewApply();
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label(t.themeLabel),
          const SizedBox(height: 4),
          _radioGroup<AppTheme>(
            groupValue: _theme,
            onChanged: (v) {
              setState(() => _theme = v ?? _theme);
              _previewApply();
            },
            options: {
              t.themeLight: AppTheme.light,
              t.themeDark: AppTheme.dark,
            },
          ),
          const SizedBox(height: 12),
          Text(t.appVersion(_appVersion),
              style: const TextStyle(fontSize: 12, color: _textGray)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 13));

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: _textGray, height: 1.35)),
      );

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13))),
        Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _primaryBlue),
      ],
    );
  }

  Widget _radioGroup<T>({
    required T groupValue,
    required ValueChanged<T?> onChanged,
    required Map<String, T> options,
    bool wrap = false,
  }) {
    final items = [
      for (final entry in options.entries)
        GestureDetector(
          onTap: () => onChanged(entry.value),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<T>(
                value: entry.value,
                activeColor: _primaryBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Text(entry.key, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
    ];

    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: wrap
          ? Wrap(spacing: 12, children: items)
          : Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  items[i],
                ],
              ],
            ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _card({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
