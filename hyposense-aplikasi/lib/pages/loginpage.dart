import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/services/auth_service.dart';
import 'package:hyposense/pages/registerpage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  static const _primaryBlue = Color(0xFF3B6CFF);

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(t.errEmailPasswordEmpty, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(email: email, password: password);
    } on AuthException catch (e) {
      if (mounted) {
        _showSnackBar(AuthService.friendlyAuthMessage(e, t), isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar(t.errGeneric('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) {
        _showSnackBar(AuthService.friendlyAuthMessage(e, t), isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar(t.errGoogleSignIn('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _onRegister() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar(t.enterEmailFirst, isError: true);
      return;
    }
    try {
      await _authService.resetPassword(email);
      if (mounted) _showSnackBar(t.resetLinkSent(email));
    } on AuthException catch (e) {
      if (mounted) {
        _showSnackBar(AuthService.friendlyAuthMessage(e, t), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Logo HypoSense (latar putih di-crop lingkaran agar
                // tampil rapi di tema terang maupun gelap)
                Center(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'HypoSense',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _primaryBlue),
                ),
                Text(
                  t.loginTagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 36),

                // ── Google Sign In Button ─────────────────────
                _GoogleSignInButton(
                    isLoading: _isGoogleLoading, onPressed: _onGoogleSignIn),
                const SizedBox(height: 24),

                // ── Divider ───────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: borderColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        t.loginWithEmailDivider,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    Expanded(child: Divider(color: borderColor)),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Email & Password ──────────────────────────
                _field(
                    controller: _emailController,
                    hint: t.emailHint,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _field(
                  controller: _passwordController,
                  hint: t.passwordHint,
                  obscure: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _onForgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      t.forgotPassword,
                      style: const TextStyle(
                          color: _primaryBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Login Button ──────────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(t.loginButton,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Register Button ───────────────────────────
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _onRegister,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(t.registerButton,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide:
          BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: border,
        enabledBorder: border,
        focusedBorder:
            border.copyWith(borderSide: const BorderSide(color: _primaryBlue)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Google Sign In Button
// ─────────────────────────────────────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Color(0xFF3B6CFF), strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleIcon(),
                  const SizedBox(width: 12),
                  Text(
                    t.googleSignIn,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
      ),
    );
  }
}

// Google "G" Icon menggunakan warna asli Google
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  const _GoogleIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()..style = PaintingStyle.fill;

    // Red (top-left)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.0, h * 0.2)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), -2.76, 1.57, false)
      ..close();
    canvas.drawPath(redPath, paint);

    // Blue (top-right)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), -1.18, 1.57, false)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Yellow (bottom-right)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), 0.39, 1.57, false)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green (bottom-left)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), 1.96, 1.57, false)
      ..close();
    canvas.drawPath(greenPath, paint);

    // White circle (inner cutout)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.3, paint);

    // Blue right bar (Google G horizontal bar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(w * 0.5, h * 0.38, w * 0.48, h * 0.24), paint);

    // White inner circle (final cutout)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.22, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
