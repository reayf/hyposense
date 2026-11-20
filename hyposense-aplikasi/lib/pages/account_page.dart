import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/services/alert_js.dart' as alert_js;
import 'package:hyposense/services/auth_service.dart';
import 'package:hyposense/services/database_service.dart';
import 'package:hyposense/services/settings_controller.dart';

/// Halaman Akun — pengaturan identitas login (nama, foto, password).
/// Terpisah dari Settings aplikasi (preferensi alarm/tema/bahasa).
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _savingName = false;
  bool _savingPassword = false;
  bool _uploadingPhoto = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  static const _primaryBlue = Color(0xFF3B6CFF);
  static const _textGray = Color(0xFF9AA0A6);

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _nameController.text =
        SettingsController.instance.profile?.fullName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    final bytes = await alert_js.pickImageBytes(maxSize: 512);
    if (bytes == null) return; // dibatalkan
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _dbService.uploadAvatar(bytes);
      final profile = SettingsController.instance.profile;
      if (profile != null) {
        SettingsController.instance
            .applyProfile(profile.copyWith(avatarUrl: url));
      }
      _showSnackBar(t.photoUpdated);
    } catch (e) {
      _showSnackBar(t.actionFailed('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _savingName) return;
    setState(() => _savingName = true);
    try {
      final profile = SettingsController.instance.profile;
      if (profile != null) {
        final updated = profile.copyWith(fullName: name);
        await _dbService.updateProfile(updated);
        SettingsController.instance.applyProfile(updated);
      }
      _showSnackBar(t.profileUpdated);
    } catch (e) {
      _showSnackBar(t.actionFailed('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPass.length < 6) {
      _showSnackBar(t.errPasswordTooShort, isError: true);
      return;
    }
    if (newPass != confirm) {
      _showSnackBar(t.errPasswordMismatch, isError: true);
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPass));
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnackBar(t.passwordChanged);
    } on AuthException catch (e) {
      _showSnackBar(AuthService.friendlyAuthMessage(e, t), isError: true);
    } catch (e) {
      _showSnackBar(t.actionFailed('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t.accountTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: SettingsController.instance,
          builder: (context, _) {
            final profile = SettingsController.instance.profile;
            final name = profile?.fullName ?? 'User';
            final email = _authService.currentUser?.email ?? '';
            final avatarUrl = profile?.avatarUrl;

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Foto profil ─────────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: _primaryBlue,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  (name.isNotEmpty ? name[0] : 'U')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _changePhoto,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                    width: 2),
                              ),
                              child: _uploadingPhoto
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.photo_camera,
                                      color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _changePhoto,
                      child: Text(t.changePhoto,
                          style: const TextStyle(
                              fontSize: 12, color: _primaryBlue)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Nama ────────────────────────────────────
                  _label(t.fullNameHint),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: _fieldDecoration(),
                  ),
                  const SizedBox(height: 10),
                  _primaryButton(
                    _savingName ? t.saving : t.save,
                    _savingName ? null : _saveName,
                  ),
                  const SizedBox(height: 24),

                  // ── Email (read-only) ───────────────────────
                  _label(t.emailHint),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Text(email,
                        style: const TextStyle(
                            fontSize: 13, color: _textGray)),
                  ),
                  const SizedBox(height: 4),
                  Text(t.emailReadonlyNote,
                      style: const TextStyle(
                          fontSize: 11, color: _textGray)),
                  const SizedBox(height: 24),

                  // ── Ganti password ──────────────────────────
                  Text(t.changePassword,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: _fieldDecoration(
                      hint: t.newPasswordHint,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: _fieldDecoration(
                      hint: t.confirmNewPasswordHint,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _primaryButton(
                    _savingPassword ? t.saving : t.changePassword,
                    _savingPassword ? null : _changePassword,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 13));

  InputDecoration _fieldDecoration({String? hint, Widget? suffix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:
          BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: _textGray),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: _primaryBlue)),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}
