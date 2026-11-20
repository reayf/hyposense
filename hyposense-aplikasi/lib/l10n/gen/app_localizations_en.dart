// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HypoSense';

  @override
  String get loginTagline => 'Monitor your health, stay safe';

  @override
  String get loginWithEmailDivider => 'or sign in with email';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get loginButton => 'Login';

  @override
  String get registerButton => 'Register';

  @override
  String get googleSignIn => 'Sign in with Google';

  @override
  String get errEmailPasswordEmpty => 'Email and password must not be empty';

  @override
  String errGeneric(Object error) {
    return 'Something went wrong: $error';
  }

  @override
  String errGoogleSignIn(Object error) {
    return 'Google sign-in failed: $error';
  }

  @override
  String get enterEmailFirst => 'Enter your email first';

  @override
  String resetLinkSent(Object email) {
    return 'Password reset link sent to $email';
  }

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get registerHeadline => 'Join HypoSense';

  @override
  String get fullNameHint => 'Full Name';

  @override
  String get confirmPasswordHint => 'Confirm Password';

  @override
  String get registerSubmit => 'Sign Up';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get errAllFieldsRequired => 'All fields are required';

  @override
  String get errPasswordMismatch => 'Passwords do not match';

  @override
  String get errPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get accountCreated => 'Account created successfully!';

  @override
  String get accountCreatedVerify =>
      'Account created! Check your email to verify before logging in.';

  @override
  String get authErrInvalidCredentials => 'Wrong email or password.';

  @override
  String get authErrEmailNotConfirmed =>
      'Email not verified yet. Check your inbox/spam folder, or ask an admin to confirm your account.';

  @override
  String get authErrUserNotFound => 'Account not found. Please register first.';

  @override
  String get authErrEmailExists =>
      'This email is already registered. Please log in.';

  @override
  String get authErrWeakPassword =>
      'Password is too weak — at least 6 characters.';

  @override
  String get authErrEmailRateLimit =>
      'Too many email requests. Wait a few minutes and try again.';

  @override
  String get authErrRequestRateLimit =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get authErrInvalidEmail => 'Invalid email format.';

  @override
  String get navFaq => 'FAQ';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Settings';

  @override
  String greeting(Object name) {
    return 'Hi, $name 👋';
  }

  @override
  String get wearableConnected => 'Wearable: Connected';

  @override
  String get wearableNotConnected => 'Wearable: Not connected';

  @override
  String get deviceInformation => 'Device Information';

  @override
  String batteryLevel(Object level) {
    return 'Battery Level: $level%';
  }

  @override
  String connectionLabel(Object strength) {
    return 'Connection: $strength';
  }

  @override
  String lastUpdate(Object time) {
    return 'Last Update: $time';
  }

  @override
  String vocSensorLabel(Object status) {
    return 'VOC Sensor: $status';
  }

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get notAvailable => 'N/A';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(Object minutes) {
    return '$minutes mins ago';
  }

  @override
  String hoursAgo(Object hours) {
    return '$hours hours ago';
  }

  @override
  String daysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String get hypoglycemiaRisk => 'Hypoglycemia Risk';

  @override
  String statusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get statusSafe => 'SAFE';

  @override
  String get statusDanger => 'DANGER';

  @override
  String get statusWarning => 'WARNING';

  @override
  String get allParamsSafe => 'All parameters are within safe limits';

  @override
  String get riskDetectedMsg =>
      'Hypoglycemia risk detected — check your blood glucose now!';

  @override
  String get liveSensorData => 'Live Sensor Data';

  @override
  String get waitingForDevice => 'Waiting for device...';

  @override
  String get heartRate => 'Heart Rate';

  @override
  String get vocLabel => 'VOC (MQ-138)';

  @override
  String get temperature => 'Temperature';

  @override
  String get humidity => 'Humidity';

  @override
  String roleLabel(Object role) {
    return 'Role: $role';
  }

  @override
  String get sectionDataPrivacy => 'Data & Privacy';

  @override
  String get saveDataToCloud => 'Save data to cloud';

  @override
  String get saveDataToCloudNote =>
      'Enforced on the wristband once device linking is set up';

  @override
  String get shareWithCaregiver => 'Share data with caregiver';

  @override
  String get shareWithCaregiverNote =>
      'Takes effect when caregiver accounts are introduced';

  @override
  String get sectionAlertsSafety => 'Alerts & Safety';

  @override
  String get alertsScopeNote =>
      'These alerts apply to this app on your phone — the wristband shows warnings on its own screen.';

  @override
  String get enableAlarm => 'Enable alarm';

  @override
  String get riskAlertLevel => 'Risk alert level:';

  @override
  String get levelModerate => 'Moderate';

  @override
  String get levelHigh => 'High';

  @override
  String get riskAlertLevelNote =>
      'Moderate: alarm sounds once per event. High: alarm repeats until dismissed.';

  @override
  String get alertMethod => 'Alert method:';

  @override
  String get methodSound => 'Sound';

  @override
  String get methodVibration => 'Vibration';

  @override
  String get methodNotification => 'Notification';

  @override
  String get methodNotificationNote =>
      'Push notifications while the app is closed arrive in a later stage — for now this shows an in-app banner only.';

  @override
  String get emergencyContact => 'Emergency contact:';

  @override
  String get emergencyContactHint => 'Enter contact number';

  @override
  String get sectionAppSettings => 'App Settings';

  @override
  String get languageLabel => 'Language:';

  @override
  String get themeLabel => 'Theme:';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String appVersion(Object version) {
    return 'App version: $version';
  }

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get saving => 'Saving...';

  @override
  String get settingsSaved => 'Settings saved successfully!';

  @override
  String settingsSaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get cancel => 'Cancel';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqSubtitle => 'Frequently Asked Questions';

  @override
  String get faqCatAbout => 'About HypoSense';

  @override
  String get faqQWhat => 'What is HypoSense?';

  @override
  String get faqAWhat =>
      'HypoSense is a wearable device that monitors breath-based biomarkers and heart rate to detect early signs of nocturnal hypoglycemia while you sleep.';

  @override
  String get faqQHow => 'How does HypoSense work?';

  @override
  String get faqAHow =>
      'The device tracks your heart rate continuously. When a pattern consistent with hypoglycemia is detected, it confirms the reading using a breath VOC sensor before triggering an alert.';

  @override
  String get faqCatWearable => 'Wearable & Monitoring';

  @override
  String get faqQWear => 'How do I wear the device correctly?';

  @override
  String get faqAWear =>
      'Wear the bracelet snugly on your wrist with the sensor panel facing your skin. For breath readings, bring the sensor close to your mouth and exhale gently when prompted.';

  @override
  String get faqQMulti => 'Can one account monitor multiple users?';

  @override
  String get faqAMulti =>
      'Currently one account is linked to one wearable device. Multi-user monitoring for caregivers is planned for a future update.';

  @override
  String get faqCatAlerts => 'Alerts & Safety';

  @override
  String get faqQAlarm => 'What should I do if the alarm sounds?';

  @override
  String get faqAAlarm =>
      'Check your blood glucose with a standard glucometer if possible, consume fast-acting carbohydrates if levels are low, and contact your emergency contact if symptoms persist.';

  @override
  String get faqCatPrivacy => 'Data & Privacy';

  @override
  String get faqQSecure => 'Is my data secure?';

  @override
  String get faqASecure =>
      'All data is encrypted in transit and at rest. You can control whether data is synced to the cloud or shared with a caregiver from the Settings page.';

  @override
  String get faqQExport => 'Can I export my data?';

  @override
  String get faqAExport =>
      'Yes, go to Settings > Data & Privacy and tap \"Export data\" to download your readings as a file.';

  @override
  String get faqDisclaimer =>
      'HypoSense is an early warning support system and does not replace professional medical care.';

  @override
  String get alertBannerTitle => 'HYPOGLYCEMIA RISK!';

  @override
  String get alertBannerBody =>
      'Check blood glucose immediately and consume fast-acting carbohydrates if low.';

  @override
  String get alertCallEmergency => 'Call emergency contact';

  @override
  String get alertDismiss => 'Dismiss';

  @override
  String get rolePatient => 'Patient';

  @override
  String get roleCaregiver => 'Caregiver';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get navPatients => 'Patients';

  @override
  String get navAdmin => 'Admin';

  @override
  String get caregiverTitle => 'My Patients';

  @override
  String get caregiverSubtitle => 'Patients linked to your account';

  @override
  String get noPatientsYet =>
      'No patients linked yet. Ask an admin to link patients to your account.';

  @override
  String get patientMaybeHidden =>
      'If a patient is missing, they may have turned off data sharing.';

  @override
  String get riskHistory => 'Risk History';

  @override
  String get noHistoryYet => 'No risk events recorded yet.';

  @override
  String get liveDataComingP5 =>
      'Live sensor data per patient will appear once device linking is available.';

  @override
  String get emergencyContactTitle => 'Emergency contact';

  @override
  String get notSet => 'Not set';

  @override
  String get adminTitle => 'User Management';

  @override
  String get adminSubtitle => 'Assign roles and link caregivers to patients';

  @override
  String get managePatientsBtn => 'Manage patients';

  @override
  String get linkedPatients => 'Linked patients';

  @override
  String get addPatient => 'Link a patient';

  @override
  String get noAvailablePatients => 'No more patients available to link.';

  @override
  String get roleUpdated => 'Role updated.';

  @override
  String actionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get linkAdded => 'Patient linked.';

  @override
  String get linkRemoved => 'Link removed.';

  @override
  String get add => 'Add';

  @override
  String get accountTitle => 'Account';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get photoUpdated => 'Photo updated.';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String get save => 'Save';

  @override
  String get emailReadonlyNote => 'Email cannot be changed from here.';

  @override
  String get changePassword => 'Change Password';

  @override
  String get newPasswordHint => 'New password';

  @override
  String get confirmNewPasswordHint => 'Confirm new password';

  @override
  String get passwordChanged => 'Password changed successfully.';

  @override
  String get sectionDevice => 'Wearable Device';

  @override
  String get deviceNote =>
      'Enter the Device ID configured in your wristband\'s firmware (e.g. gelang_001). Once linked, its data belongs to your account.';

  @override
  String get deviceIdHint => 'Device ID';

  @override
  String get linkDevice => 'Link device';

  @override
  String get unlinkDevice => 'Unlink';

  @override
  String get deviceLinked => 'Device linked.';

  @override
  String get deviceUnlinked => 'Device unlinked.';

  @override
  String get deviceTaken => 'This device is already linked to another account.';

  @override
  String get noDeviceLinked => 'No device linked yet.';

  @override
  String linkedSince(Object date) {
    return 'Linked since $date';
  }

  @override
  String get alertSendSms => 'Send emergency message';
}
