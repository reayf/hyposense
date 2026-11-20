import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/models.dart';
import '../config/supabase_config.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  /// Terjemahkan error Supabase Auth menjadi pesan yang jelas bagi pengguna
  /// (bedakan "password salah" vs "email belum diverifikasi" vs lainnya),
  /// mengikuti bahasa aplikasi.
  static String friendlyAuthMessage(AuthException e, AppLocalizations t) {
    switch (e.code) {
      case 'invalid_credentials':
        return t.authErrInvalidCredentials;
      case 'email_not_confirmed':
        return t.authErrEmailNotConfirmed;
      case 'user_not_found':
        return t.authErrUserNotFound;
      case 'user_already_exists':
      case 'email_exists':
        return t.authErrEmailExists;
      case 'weak_password':
        return t.authErrWeakPassword;
      case 'over_email_send_rate_limit':
        return t.authErrEmailRateLimit;
      case 'over_request_rate_limit':
        return t.authErrRequestRateLimit;
      case 'validation_failed':
        return t.authErrInvalidEmail;
    }
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return t.authErrInvalidCredentials;
    }
    if (msg.contains('email not confirmed')) {
      return t.authErrEmailNotConfirmed;
    }
    return e.message;
  }

  /// Mendapatkan user yang sedang login
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream perubahan status auth
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Login dengan email & password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Register akun baru
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    // Hanya buat profil jika sudah ada session (tanpa session, insert
    // berjalan sebagai anon dan ditolak RLS — misal saat konfirmasi email
    // masih aktif). Kasus itu ditangani ensureProfileAndSettings() setelah
    // user login pertama kali.
    if (response.session != null) {
      await ensureProfileAndSettings();
    }

    return response;
  }

  /// Pastikan baris profiles & user_settings ada untuk user yang login.
  /// Dipanggil setelah login — mencakup user Google OAuth dan user yang
  /// mendaftar saat konfirmasi email aktif (yang tidak sempat dibuatkan
  /// profil saat signUp).
  Future<void> ensureProfileAndSettings() async {
    final user = currentUser;
    if (user == null) return;

    final profile = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) {
      final fullName = user.userMetadata?['full_name'] as String? ??
          user.email?.split('@').first ??
          'User';
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'role': 'patient',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    final settings = await _supabase
        .from('user_settings')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (settings == null) {
      await _supabase.from('user_settings').upsert({
        'user_id': user.id,
        'save_to_cloud': true,
        'share_with_caregiver': true,
        'enable_alarm': true,
        'risk_alert_level': 'moderate',
        'alert_method': 'sound',
        'theme': 'light',
        'language': 'English',
      });
    }
  }

  /// Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Login dengan Google OAuth
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.redirectUrl,
    );
  }

  /// Reset password via email
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Ambil profil user saat ini
  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }
}
