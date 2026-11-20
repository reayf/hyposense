import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'HypoSense'**
  String get appTitle;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Monitor your health, stay safe'**
  String get loginTagline;

  /// No description provided for @loginWithEmailDivider.
  ///
  /// In en, this message translates to:
  /// **'or sign in with email'**
  String get loginWithEmailDivider;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleSignIn;

  /// No description provided for @errEmailPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Email and password must not be empty'**
  String get errEmailPasswordEmpty;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String errGeneric(Object error);

  /// No description provided for @errGoogleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {error}'**
  String errGoogleSignIn(Object error);

  /// No description provided for @enterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email first'**
  String get enterEmailFirst;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to {email}'**
  String resetLinkSent(Object email);

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @registerHeadline.
  ///
  /// In en, this message translates to:
  /// **'Join HypoSense'**
  String get registerHeadline;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordHint;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get registerSubmit;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @errAllFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'All fields are required'**
  String get errAllFieldsRequired;

  /// No description provided for @errPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errPasswordMismatch;

  /// No description provided for @errPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get errPasswordTooShort;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully!'**
  String get accountCreated;

  /// No description provided for @accountCreatedVerify.
  ///
  /// In en, this message translates to:
  /// **'Account created! Check your email to verify before logging in.'**
  String get accountCreatedVerify;

  /// No description provided for @authErrInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authErrInvalidCredentials;

  /// No description provided for @authErrEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email not verified yet. Check your inbox/spam folder, or ask an admin to confirm your account.'**
  String get authErrEmailNotConfirmed;

  /// No description provided for @authErrUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found. Please register first.'**
  String get authErrUserNotFound;

  /// No description provided for @authErrEmailExists.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Please log in.'**
  String get authErrEmailExists;

  /// No description provided for @authErrWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak — at least 6 characters.'**
  String get authErrWeakPassword;

  /// No description provided for @authErrEmailRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many email requests. Wait a few minutes and try again.'**
  String get authErrEmailRateLimit;

  /// No description provided for @authErrRequestRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get authErrRequestRateLimit;

  /// No description provided for @authErrInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get authErrInvalidEmail;

  /// No description provided for @navFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get navFaq;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name} 👋'**
  String greeting(Object name);

  /// No description provided for @wearableConnected.
  ///
  /// In en, this message translates to:
  /// **'Wearable: Connected'**
  String get wearableConnected;

  /// No description provided for @wearableNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Wearable: Not connected'**
  String get wearableNotConnected;

  /// No description provided for @deviceInformation.
  ///
  /// In en, this message translates to:
  /// **'Device Information'**
  String get deviceInformation;

  /// No description provided for @batteryLevel.
  ///
  /// In en, this message translates to:
  /// **'Battery Level: {level}%'**
  String batteryLevel(Object level);

  /// No description provided for @connectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection: {strength}'**
  String connectionLabel(Object strength);

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last Update: {time}'**
  String lastUpdate(Object time);

  /// No description provided for @vocSensorLabel.
  ///
  /// In en, this message translates to:
  /// **'VOC Sensor: {status}'**
  String vocSensorLabel(Object status);

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} mins ago'**
  String minutesAgo(Object minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours ago'**
  String hoursAgo(Object hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(Object days);

  /// No description provided for @hypoglycemiaRisk.
  ///
  /// In en, this message translates to:
  /// **'Hypoglycemia Risk'**
  String get hypoglycemiaRisk;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabel(Object status);

  /// No description provided for @statusSafe.
  ///
  /// In en, this message translates to:
  /// **'SAFE'**
  String get statusSafe;

  /// No description provided for @statusDanger.
  ///
  /// In en, this message translates to:
  /// **'DANGER'**
  String get statusDanger;

  /// No description provided for @statusWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get statusWarning;

  /// No description provided for @allParamsSafe.
  ///
  /// In en, this message translates to:
  /// **'All parameters are within safe limits'**
  String get allParamsSafe;

  /// No description provided for @riskDetectedMsg.
  ///
  /// In en, this message translates to:
  /// **'Hypoglycemia risk detected — check your blood glucose now!'**
  String get riskDetectedMsg;

  /// No description provided for @liveSensorData.
  ///
  /// In en, this message translates to:
  /// **'Live Sensor Data'**
  String get liveSensorData;

  /// No description provided for @waitingForDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device...'**
  String get waitingForDevice;

  /// No description provided for @heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRate;

  /// No description provided for @vocLabel.
  ///
  /// In en, this message translates to:
  /// **'VOC (MQ-138)'**
  String get vocLabel;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String roleLabel(Object role);

  /// No description provided for @sectionDataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get sectionDataPrivacy;

  /// No description provided for @saveDataToCloud.
  ///
  /// In en, this message translates to:
  /// **'Save data to cloud'**
  String get saveDataToCloud;

  /// No description provided for @saveDataToCloudNote.
  ///
  /// In en, this message translates to:
  /// **'Enforced on the wristband once device linking is set up'**
  String get saveDataToCloudNote;

  /// No description provided for @shareWithCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Share data with caregiver'**
  String get shareWithCaregiver;

  /// No description provided for @shareWithCaregiverNote.
  ///
  /// In en, this message translates to:
  /// **'Takes effect when caregiver accounts are introduced'**
  String get shareWithCaregiverNote;

  /// No description provided for @sectionAlertsSafety.
  ///
  /// In en, this message translates to:
  /// **'Alerts & Safety'**
  String get sectionAlertsSafety;

  /// No description provided for @alertsScopeNote.
  ///
  /// In en, this message translates to:
  /// **'These alerts apply to this app on your phone — the wristband shows warnings on its own screen.'**
  String get alertsScopeNote;

  /// No description provided for @enableAlarm.
  ///
  /// In en, this message translates to:
  /// **'Enable alarm'**
  String get enableAlarm;

  /// No description provided for @riskAlertLevel.
  ///
  /// In en, this message translates to:
  /// **'Risk alert level:'**
  String get riskAlertLevel;

  /// No description provided for @levelModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get levelModerate;

  /// No description provided for @levelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get levelHigh;

  /// No description provided for @riskAlertLevelNote.
  ///
  /// In en, this message translates to:
  /// **'Moderate: alarm sounds once per event. High: alarm repeats until dismissed.'**
  String get riskAlertLevelNote;

  /// No description provided for @alertMethod.
  ///
  /// In en, this message translates to:
  /// **'Alert method:'**
  String get alertMethod;

  /// No description provided for @methodSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get methodSound;

  /// No description provided for @methodVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get methodVibration;

  /// No description provided for @methodNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get methodNotification;

  /// No description provided for @methodNotificationNote.
  ///
  /// In en, this message translates to:
  /// **'Push notifications while the app is closed arrive in a later stage — for now this shows an in-app banner only.'**
  String get methodNotificationNote;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact:'**
  String get emergencyContact;

  /// No description provided for @emergencyContactHint.
  ///
  /// In en, this message translates to:
  /// **'Enter contact number'**
  String get emergencyContactHint;

  /// No description provided for @sectionAppSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get sectionAppSettings;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language:'**
  String get languageLabel;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme:'**
  String get themeLabel;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version: {version}'**
  String appVersion(Object version);

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully!'**
  String get settingsSaved;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String settingsSaveFailed(Object error);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqTitle;

  /// No description provided for @faqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faqSubtitle;

  /// No description provided for @faqCatAbout.
  ///
  /// In en, this message translates to:
  /// **'About HypoSense'**
  String get faqCatAbout;

  /// No description provided for @faqQWhat.
  ///
  /// In en, this message translates to:
  /// **'What is HypoSense?'**
  String get faqQWhat;

  /// No description provided for @faqAWhat.
  ///
  /// In en, this message translates to:
  /// **'HypoSense is a wearable device that monitors breath-based biomarkers and heart rate to detect early signs of nocturnal hypoglycemia while you sleep.'**
  String get faqAWhat;

  /// No description provided for @faqQHow.
  ///
  /// In en, this message translates to:
  /// **'How does HypoSense work?'**
  String get faqQHow;

  /// No description provided for @faqAHow.
  ///
  /// In en, this message translates to:
  /// **'The device tracks your heart rate continuously. When a pattern consistent with hypoglycemia is detected, it confirms the reading using a breath VOC sensor before triggering an alert.'**
  String get faqAHow;

  /// No description provided for @faqCatWearable.
  ///
  /// In en, this message translates to:
  /// **'Wearable & Monitoring'**
  String get faqCatWearable;

  /// No description provided for @faqQWear.
  ///
  /// In en, this message translates to:
  /// **'How do I wear the device correctly?'**
  String get faqQWear;

  /// No description provided for @faqAWear.
  ///
  /// In en, this message translates to:
  /// **'Wear the bracelet snugly on your wrist with the sensor panel facing your skin. For breath readings, bring the sensor close to your mouth and exhale gently when prompted.'**
  String get faqAWear;

  /// No description provided for @faqQMulti.
  ///
  /// In en, this message translates to:
  /// **'Can one account monitor multiple users?'**
  String get faqQMulti;

  /// No description provided for @faqAMulti.
  ///
  /// In en, this message translates to:
  /// **'Currently one account is linked to one wearable device. Multi-user monitoring for caregivers is planned for a future update.'**
  String get faqAMulti;

  /// No description provided for @faqCatAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts & Safety'**
  String get faqCatAlerts;

  /// No description provided for @faqQAlarm.
  ///
  /// In en, this message translates to:
  /// **'What should I do if the alarm sounds?'**
  String get faqQAlarm;

  /// No description provided for @faqAAlarm.
  ///
  /// In en, this message translates to:
  /// **'Check your blood glucose with a standard glucometer if possible, consume fast-acting carbohydrates if levels are low, and contact your emergency contact if symptoms persist.'**
  String get faqAAlarm;

  /// No description provided for @faqCatPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get faqCatPrivacy;

  /// No description provided for @faqQSecure.
  ///
  /// In en, this message translates to:
  /// **'Is my data secure?'**
  String get faqQSecure;

  /// No description provided for @faqASecure.
  ///
  /// In en, this message translates to:
  /// **'All data is encrypted in transit and at rest. You can control whether data is synced to the cloud or shared with a caregiver from the Settings page.'**
  String get faqASecure;

  /// No description provided for @faqQExport.
  ///
  /// In en, this message translates to:
  /// **'Can I export my data?'**
  String get faqQExport;

  /// No description provided for @faqAExport.
  ///
  /// In en, this message translates to:
  /// **'Yes, go to Settings > Data & Privacy and tap \"Export data\" to download your readings as a file.'**
  String get faqAExport;

  /// No description provided for @faqDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'HypoSense is an early warning support system and does not replace professional medical care.'**
  String get faqDisclaimer;

  /// No description provided for @alertBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'HYPOGLYCEMIA RISK!'**
  String get alertBannerTitle;

  /// No description provided for @alertBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Check blood glucose immediately and consume fast-acting carbohydrates if low.'**
  String get alertBannerBody;

  /// No description provided for @alertCallEmergency.
  ///
  /// In en, this message translates to:
  /// **'Call emergency contact'**
  String get alertCallEmergency;

  /// No description provided for @alertDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get alertDismiss;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rolePatient;

  /// No description provided for @roleCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get roleCaregiver;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @caregiverTitle.
  ///
  /// In en, this message translates to:
  /// **'My Patients'**
  String get caregiverTitle;

  /// No description provided for @caregiverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Patients linked to your account'**
  String get caregiverSubtitle;

  /// No description provided for @noPatientsYet.
  ///
  /// In en, this message translates to:
  /// **'No patients linked yet. Ask an admin to link patients to your account.'**
  String get noPatientsYet;

  /// No description provided for @patientMaybeHidden.
  ///
  /// In en, this message translates to:
  /// **'If a patient is missing, they may have turned off data sharing.'**
  String get patientMaybeHidden;

  /// No description provided for @riskHistory.
  ///
  /// In en, this message translates to:
  /// **'Risk History'**
  String get riskHistory;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No risk events recorded yet.'**
  String get noHistoryYet;

  /// No description provided for @liveDataComingP5.
  ///
  /// In en, this message translates to:
  /// **'Live sensor data per patient will appear once device linking is available.'**
  String get liveDataComingP5;

  /// No description provided for @emergencyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get emergencyContactTitle;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get adminTitle;

  /// No description provided for @adminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assign roles and link caregivers to patients'**
  String get adminSubtitle;

  /// No description provided for @managePatientsBtn.
  ///
  /// In en, this message translates to:
  /// **'Manage patients'**
  String get managePatientsBtn;

  /// No description provided for @linkedPatients.
  ///
  /// In en, this message translates to:
  /// **'Linked patients'**
  String get linkedPatients;

  /// No description provided for @addPatient.
  ///
  /// In en, this message translates to:
  /// **'Link a patient'**
  String get addPatient;

  /// No description provided for @noAvailablePatients.
  ///
  /// In en, this message translates to:
  /// **'No more patients available to link.'**
  String get noAvailablePatients;

  /// No description provided for @roleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Role updated.'**
  String get roleUpdated;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String actionFailed(Object error);

  /// No description provided for @linkAdded.
  ///
  /// In en, this message translates to:
  /// **'Patient linked.'**
  String get linkAdded;

  /// No description provided for @linkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Link removed.'**
  String get linkRemoved;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated.'**
  String get photoUpdated;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @emailReadonlyNote.
  ///
  /// In en, this message translates to:
  /// **'Email cannot be changed from here.'**
  String get emailReadonlyNote;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @newPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordHint;

  /// No description provided for @confirmNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordHint;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChanged;

  /// No description provided for @sectionDevice.
  ///
  /// In en, this message translates to:
  /// **'Wearable Device'**
  String get sectionDevice;

  /// No description provided for @deviceNote.
  ///
  /// In en, this message translates to:
  /// **'Enter the Device ID configured in your wristband\'s firmware (e.g. gelang_001). Once linked, its data belongs to your account.'**
  String get deviceNote;

  /// No description provided for @deviceIdHint.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdHint;

  /// No description provided for @linkDevice.
  ///
  /// In en, this message translates to:
  /// **'Link device'**
  String get linkDevice;

  /// No description provided for @unlinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlinkDevice;

  /// No description provided for @deviceLinked.
  ///
  /// In en, this message translates to:
  /// **'Device linked.'**
  String get deviceLinked;

  /// No description provided for @deviceUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Device unlinked.'**
  String get deviceUnlinked;

  /// No description provided for @deviceTaken.
  ///
  /// In en, this message translates to:
  /// **'This device is already linked to another account.'**
  String get deviceTaken;

  /// No description provided for @noDeviceLinked.
  ///
  /// In en, this message translates to:
  /// **'No device linked yet.'**
  String get noDeviceLinked;

  /// No description provided for @linkedSince.
  ///
  /// In en, this message translates to:
  /// **'Linked since {date}'**
  String linkedSince(Object date);

  /// No description provided for @alertSendSms.
  ///
  /// In en, this message translates to:
  /// **'Send emergency message'**
  String get alertSendSms;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
