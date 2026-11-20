import 'package:flutter/material.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';
import 'package:hyposense/pages/account_page.dart';
import 'package:hyposense/pages/admin_home.dart';
import 'package:hyposense/pages/ble_screen.dart';
import 'package:hyposense/pages/caregiver_home.dart';
import 'package:hyposense/pages/clinical_trial_page.dart';
import 'package:hyposense/pages/faqpage.dart';
import 'package:hyposense/pages/homepage.dart';
import 'package:hyposense/pages/setttingpage.dart';
import 'package:hyposense/services/alert_service.dart';
import 'package:hyposense/services/auth_service.dart';
import 'package:hyposense/services/ble_service.dart';
import 'package:hyposense/services/cloud_relay_service.dart';
import 'package:hyposense/services/settings_controller.dart';

/// Kerangka navigasi utama (pola mobile):
///  - AppBar: hamburger (menu sekunder) + logo + avatar -> halaman Akun
///  - Bottom nav berikon: Beranda (sesuai peran) + Pengaturan
///  - Drawer: FAQ + Logout
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedTab = 0;

  static const _primaryBlue = Color(0xFF3B6CFF);

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    // Lengkapi profil untuk user yang belum punya baris profiles/user_settings
    // (Google OAuth atau register dengan konfirmasi email). Kegagalan di sini
    // tidak boleh memblokir aplikasi — halaman tetap punya nilai fallback.
    AuthService().ensureProfileAndSettings().catchError((_) {});
    // Muat preferensi (tema/bahasa/alarm/peran) lalu mulai pemantauan alarm
    // + relay data BLE ke cloud (Tahap 3).
    SettingsController.instance.load();
    AlertService.instance.start();
    CloudRelayService.instance.start();
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
  }

  void _openBle() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BleScreen()),
    );
  }

  void _openFaq() {
    Navigator.pop(context); // tutup drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(AppLocalizations.of(context).navFaq,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          body: const FaqPage(),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    Navigator.pop(context); // tutup drawer
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
              child:
                  Text(t.logout, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await AlertService.instance.stop();
      CloudRelayService.instance.stop();
      await BleService.instance.disconnect();
      SettingsController.instance.clear();
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) {
        final ctrl = SettingsController.instance;
        if (!ctrl.loaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final Widget homePage = switch (ctrl.role) {
          'caregiver' => const CaregiverHomePage(),
          'admin' => const AdminHomePage(),
          _ => const HomePage(),
        };

        return Stack(
          children: [
            Scaffold(
              appBar: _buildAppBar(),
              drawer: _buildDrawer(ctrl),
              body: IndexedStack(
                index: _selectedTab,
                children: [homePage, const SettingsPage()],
              ),
              bottomNavigationBar: _buildBottomNav(ctrl.role),
            ),
            // Overlay alarm menutupi seluruh layar (termasuk AppBar).
            ListenableBuilder(
              listenable: AlertService.instance,
              builder: (context, _) => AlertService.instance.alarmActive
                  ? const _AlarmOverlay()
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'HypoSense',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _primaryBlue),
          ),
        ],
      ),
      actions: [
        // Tombol BLE (warna hijau saat gelang tersambung) -> layar BLE
        ListenableBuilder(
          listenable: BleService.instance,
          builder: (context, _) => IconButton(
            onPressed: _openBle,
            icon: Icon(
              BleService.instance.isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth,
              color: BleService.instance.isConnected
                  ? const Color(0xFF34C77B)
                  : _primaryBlue,
            ),
          ),
        ),
        // Avatar profil -> halaman Akun (ubah nama/foto/password)
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: _openAccount,
            child: _avatar(radius: 16),
          ),
        ),
      ],
    );
  }

  Widget _avatar({required double radius}) {
    final p = SettingsController.instance.profile;
    final name = p?.fullName ?? 'U';
    final url = p?.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: _primaryBlue,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.9),
            )
          : null,
    );
  }

  Widget _buildDrawer(SettingsController ctrl) {
    final name = ctrl.profile?.fullName ?? 'User';
    final email = AuthService().currentUser?.email ?? '';
    final roleText = switch (ctrl.role) {
      'caregiver' => t.roleCaregiver,
      'admin' => t.roleAdmin,
      _ => t.rolePatient,
    };

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header profil — bisa ditekan untuk membuka halaman Akun
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _openAccount();
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _avatar(radius: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text(email,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9AA0A6))),
                          Text(roleText,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryBlue)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(t.accountTitle,
                  style: const TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _openAccount();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(t.navFaq, style: const TextStyle(fontSize: 14)),
              onTap: _openFaq,
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Mode Uji Klinik',
                  style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ClinicalTrialPage()),
                );
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(t.logout,
                  style: const TextStyle(fontSize: 14, color: Colors.red)),
              onTap: _confirmLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(String role) {
    final (midLabel, midIcon, midIconSelected) = switch (role) {
      'caregiver' => (
          t.navPatients,
          Icons.people_outline,
          Icons.people
        ),
      'admin' => (
          t.navAdmin,
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings
        ),
      _ => (t.navHome, Icons.home_outlined, Icons.home),
    };

    return NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (i) => setState(() => _selectedTab = i),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: Icon(midIcon),
          selectedIcon: Icon(midIconSelected, color: _primaryBlue),
          label: midLabel,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings, color: _primaryBlue),
          label: t.navSettings,
        ),
      ],
    );
  }
}

/// Layar peringatan penuh saat risiko hipoglikemia terdeteksi.
class _AlarmOverlay extends StatelessWidget {
  const _AlarmOverlay();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final contact =
        SettingsController.instance.profile?.emergencyContact?.trim() ?? '';

    // Dua tingkat tampilan: pengingat napas (jingga — ajakan bertindak) dan
    // bahaya (merah — vonis). Teks pengingat napas belum ada di berkas .arb,
    // jadi sementara dipilih menurut bahasa aktif; pindahkan ke .arb saat ada
    // kesempatan agar konsisten dengan teks lain.
    final napas = AlertService.instance.isBreathPrompt;
    final indo = Localizations.localeOf(context).languageCode == 'id';
    final judul = napas
        ? (indo ? 'BANGUN — CEK NAPAS' : 'WAKE UP — BREATH CHECK')
        : t.alertBannerTitle;
    final isi = napas
        ? (indo
            ? 'Detak jantung menyimpang. Gelang sedang memanaskan sensor gas '
                '(±60 detik). Buka katup geser, lalu hembuskan napas ke sensor '
                'saat diminta.'
            : 'Heart rate deviated. The band is warming up the gas sensor '
                '(~60 s). Open the slide valve, then breathe into the sensor '
                'when prompted.')
        : t.alertBannerBody;

    return Positioned.fill(
      child: Container(
        color: (napas ? const Color(0xFFE8833A) : const Color(0xFFB71C1C))
            .withValues(alpha: 0.96),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(napas ? Icons.air : Icons.warning_amber_rounded,
                color: Colors.white, size: 72),
            const SizedBox(height: 16),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isi,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            if (contact.isNotEmpty) ...[
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      AlertService.instance.callEmergency(contact),
                  icon: const Icon(Icons.call),
                  label: Text('${t.alertCallEmergency} ($contact)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB71C1C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => AlertService.instance.sendEmergencySms(
                    contact,
                    patientName:
                        SettingsController.instance.profile?.fullName ?? '',
                  ),
                  icon: const Icon(Icons.message_outlined),
                  label: Text('${t.alertSendSms} ($contact)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: AlertService.instance.dismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(t.alertDismiss),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
