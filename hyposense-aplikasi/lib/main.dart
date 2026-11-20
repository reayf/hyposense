import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hyposense/config/supabase_config.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/navigation.dart';
import 'package:hyposense/pages/loginpage.dart';
import 'package:hyposense/services/notification_service.dart';
import 'package:hyposense/services/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Port komunikasi untuk foreground service (Tahap 4).
  FlutterForegroundTask.initCommunicationPort();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabasePublishableKey,
  );

  // Notifikasi alarm native (Tahap 5).
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _seed = Color(0xFF3B6CFF);

  @override
  Widget build(BuildContext context) {
    // Rebuild seluruh app saat tema/bahasa berubah dari halaman Settings.
    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) {
        final ctrl = SettingsController.instance;
        final isDark = ctrl.themeMode == ThemeMode.dark;
        return MaterialApp(
          title: 'HypoSense',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: _seed),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _seed,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: ctrl.themeMode,
          locale: ctrl.locale, // null = ikuti bahasa perangkat
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Wrap semua halaman dalam container seukuran HP, centered di layar
          builder: (context, child) {
            return Container(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: ClipRect(
                    child: child!,
                  ),
                ),
              ),
            );
          },
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Cek apakah user sudah login atau belum
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const MainNavigation();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
