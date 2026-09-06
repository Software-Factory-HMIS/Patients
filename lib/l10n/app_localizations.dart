import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('ur'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'My Health Record'**
  String get appTitle;

  /// No description provided for @appNameShort.
  ///
  /// In en, this message translates to:
  /// **'My Health Record'**
  String get appNameShort;

  /// No description provided for @governmentOfPunjab.
  ///
  /// In en, this message translates to:
  /// **'Government of Punjab'**
  String get governmentOfPunjab;

  /// No description provided for @patientApp.
  ///
  /// In en, this message translates to:
  /// **'My Health Record'**
  String get patientApp;

  /// No description provided for @healthDepartment.
  ///
  /// In en, this message translates to:
  /// **'Health Department'**
  String get healthDepartment;

  /// No description provided for @governmentOfThePunjab.
  ///
  /// In en, this message translates to:
  /// **'Government of the Punjab'**
  String get governmentOfThePunjab;

  /// No description provided for @tabBookVisit.
  ///
  /// In en, this message translates to:
  /// **'Book Visit'**
  String get tabBookVisit;

  /// No description provided for @tabMyVisits.
  ///
  /// In en, this message translates to:
  /// **'My Visits'**
  String get tabMyVisits;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get tabHealth;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose light or dark theme for the app.'**
  String get appearanceDescription;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language for the app.'**
  String get languageDescription;

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

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUrdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get languageUrdu;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get uploadPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @stable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stable;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @onFile.
  ///
  /// In en, this message translates to:
  /// **'On file'**
  String get onFile;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get pending;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'critical'**
  String get critical;

  /// No description provided for @finalReports.
  ///
  /// In en, this message translates to:
  /// **'final'**
  String get finalReports;

  /// No description provided for @months12.
  ///
  /// In en, this message translates to:
  /// **'12 mo'**
  String get months12;

  /// No description provided for @myHealth.
  ///
  /// In en, this message translates to:
  /// **'My Health'**
  String get myHealth;

  /// No description provided for @couldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile.'**
  String get couldNotLoadProfile;

  /// No description provided for @bookVisit.
  ///
  /// In en, this message translates to:
  /// **'Book Visit'**
  String get bookVisit;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book an Appointment'**
  String get bookAppointment;

  /// No description provided for @myVisitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your hospital visits and medical records.'**
  String get myVisitsSubtitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your profile and personal details.'**
  String get profileSubtitle;

  /// No description provided for @healthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health Records'**
  String get healthRecords;

  /// No description provided for @upcomingVisit.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Visit'**
  String get upcomingVisit;

  /// No description provided for @healthAtAGlance.
  ///
  /// In en, this message translates to:
  /// **'Health at a Glance'**
  String get healthAtAGlance;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @activeMeds.
  ///
  /// In en, this message translates to:
  /// **'Active Meds'**
  String get activeMeds;

  /// No description provided for @labs.
  ///
  /// In en, this message translates to:
  /// **'Labs'**
  String get labs;

  /// No description provided for @radiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get radiology;

  /// No description provided for @noUpcomingVisit.
  ///
  /// In en, this message translates to:
  /// **'No upcoming visit'**
  String get noUpcomingVisit;

  /// No description provided for @noUpcomingVisitMessage.
  ///
  /// In en, this message translates to:
  /// **'Book a visit to get your queue token and see it here.'**
  String get noUpcomingVisitMessage;

  /// No description provided for @joinQueue.
  ///
  /// In en, this message translates to:
  /// **'Join Queue'**
  String get joinQueue;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get token;

  /// No description provided for @tokenNumber.
  ///
  /// In en, this message translates to:
  /// **'Token Number'**
  String get tokenNumber;

  /// No description provided for @liveQueue.
  ///
  /// In en, this message translates to:
  /// **'LIVE QUEUE'**
  String get liveQueue;

  /// No description provided for @reportToRoom.
  ///
  /// In en, this message translates to:
  /// **'Report to {room} on arrival.'**
  String reportToRoom(String room);

  /// No description provided for @reportToReception.
  ///
  /// In en, this message translates to:
  /// **'Report to the reception desk on arrival.'**
  String get reportToReception;

  /// No description provided for @hospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get hospital;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get department;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @infoHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get infoHelpTitle;

  /// No description provided for @infoHelpMessage.
  ///
  /// In en, this message translates to:
  /// **'Use Book Visit to get a token at your hospital. Your visits, lab results, and prescriptions are available under Health.'**
  String get infoHelpMessage;

  /// No description provided for @last12MonthsSummary.
  ///
  /// In en, this message translates to:
  /// **'Last 12 Months Summary'**
  String get last12MonthsSummary;

  /// No description provided for @rolling.
  ///
  /// In en, this message translates to:
  /// **'Rolling'**
  String get rolling;

  /// No description provided for @emergencyHotline.
  ///
  /// In en, this message translates to:
  /// **'Contact 1033 for emergency services across Punjab.'**
  String get emergencyHotline;

  /// No description provided for @healthHub.
  ///
  /// In en, this message translates to:
  /// **'Health Hub'**
  String get healthHub;

  /// No description provided for @healthHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Centralized medical records and active treatments.'**
  String get healthHubSubtitle;

  /// No description provided for @prescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get prescriptions;

  /// No description provided for @prescriptionsBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View active medicines and full prescription history.'**
  String get prescriptionsBannerSubtitle;

  /// No description provided for @labResults.
  ///
  /// In en, this message translates to:
  /// **'Lab Results'**
  String get labResults;

  /// No description provided for @radiologyReports.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get radiologyReports;

  /// No description provided for @activePrescription.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PRESCRIPTION'**
  String get activePrescription;

  /// No description provided for @activePrescriptions.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PRESCRIPTIONS'**
  String get activePrescriptions;

  /// No description provided for @noActivePrescriptions.
  ///
  /// In en, this message translates to:
  /// **'No active prescriptions'**
  String get noActivePrescriptions;

  /// No description provided for @noActivePrescriptionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your current medicines will appear here when prescribed.'**
  String get noActivePrescriptionsMessage;

  /// No description provided for @viewHistory.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get viewHistory;

  /// No description provided for @refillHistory.
  ///
  /// In en, this message translates to:
  /// **'Refill History'**
  String get refillHistory;

  /// No description provided for @noActivePrescriptionsOnFile.
  ///
  /// In en, this message translates to:
  /// **'No active prescriptions on file.'**
  String get noActivePrescriptionsOnFile;

  /// No description provided for @trustedGovernmentApp.
  ///
  /// In en, this message translates to:
  /// **'Trusted Government App'**
  String get trustedGovernmentApp;

  /// No description provided for @trustedGovernmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure & Private · Building a healthier Punjab together'**
  String get trustedGovernmentSubtitle;

  /// No description provided for @helpDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Book Visit — get a hospital token.\nMy Visits — see your medical records.\nHealth — labs, radiology, prescriptions.'**
  String get helpDialogContent;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start: {date}'**
  String startDate(String date);

  /// No description provided for @prescriptionHistory.
  ///
  /// In en, this message translates to:
  /// **'Prescription History'**
  String get prescriptionHistory;

  /// No description provided for @tabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tabActive;

  /// No description provided for @tabDiscontinued.
  ///
  /// In en, this message translates to:
  /// **'Discontinued'**
  String get tabDiscontinued;

  /// No description provided for @noActivePrescriptionsHistory.
  ///
  /// In en, this message translates to:
  /// **'No active prescriptions'**
  String get noActivePrescriptionsHistory;

  /// No description provided for @noActivePrescriptionsHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Medicines currently prescribed to you will appear here.'**
  String get noActivePrescriptionsHistoryMessage;

  /// No description provided for @noDiscontinuedPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'No discontinued prescriptions'**
  String get noDiscontinuedPrescriptions;

  /// No description provided for @noDiscontinuedPrescriptionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Previously stopped or completed medicines will appear here.'**
  String get noDiscontinuedPrescriptionsMessage;

  /// No description provided for @activeStatus.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeStatus;

  /// No description provided for @discontinuedStatus.
  ///
  /// In en, this message translates to:
  /// **'Discontinued'**
  String get discontinuedStatus;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @settingsMenu.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsMenu;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @helpDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'For patient record or medical record issues, contact your hospital reception or Punjab Health support.'**
  String get helpDialogMessage;

  /// No description provided for @trustedByPunjabHealth.
  ///
  /// In en, this message translates to:
  /// **'Trusted by Punjab Health'**
  String get trustedByPunjabHealth;

  /// No description provided for @bookVisitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your hospital and department to get your queue token.'**
  String get bookVisitSubtitle;

  /// No description provided for @selectHospital.
  ///
  /// In en, this message translates to:
  /// **'Select Hospital'**
  String get selectHospital;

  /// No description provided for @selectHospitalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search and select the hospital where you want to visit.'**
  String get selectHospitalSubtitle;

  /// No description provided for @selectDepartment.
  ///
  /// In en, this message translates to:
  /// **'Select Department'**
  String get selectDepartment;

  /// No description provided for @selectDepartmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the clinic or department you need.'**
  String get selectDepartmentSubtitle;

  /// No description provided for @searchAndSelectHospital.
  ///
  /// In en, this message translates to:
  /// **'Search and select a hospital...'**
  String get searchAndSelectHospital;

  /// No description provided for @selectDepartmentHint.
  ///
  /// In en, this message translates to:
  /// **'Select department'**
  String get selectDepartmentHint;

  /// No description provided for @readyToBook.
  ///
  /// In en, this message translates to:
  /// **'Ready to book'**
  String get readyToBook;

  /// No description provided for @searchHospitalByName.
  ///
  /// In en, this message translates to:
  /// **'Search hospital by name'**
  String get searchHospitalByName;

  /// No description provided for @chooseHospital.
  ///
  /// In en, this message translates to:
  /// **'Choose hospital'**
  String get chooseHospital;

  /// No description provided for @chooseHospitalHelper.
  ///
  /// In en, this message translates to:
  /// **'Tap the box and type the hospital name.'**
  String get chooseHospitalHelper;

  /// No description provided for @chooseDepartment.
  ///
  /// In en, this message translates to:
  /// **'Choose department'**
  String get chooseDepartment;

  /// No description provided for @chooseDepartmentHelper.
  ///
  /// In en, this message translates to:
  /// **'Select the clinic or department you need.'**
  String get chooseDepartmentHelper;

  /// No description provided for @pickHospitalFirst.
  ///
  /// In en, this message translates to:
  /// **'First pick a hospital above.'**
  String get pickHospitalFirst;

  /// No description provided for @pickHospitalFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a hospital first'**
  String get pickHospitalFirstHint;

  /// No description provided for @tapChooseDepartment.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose department'**
  String get tapChooseDepartment;

  /// No description provided for @couldNotBookVisit.
  ///
  /// In en, this message translates to:
  /// **'Could not book visit'**
  String get couldNotBookVisit;

  /// No description provided for @bookMyVisit.
  ///
  /// In en, this message translates to:
  /// **'Book My Visit'**
  String get bookMyVisit;

  /// No description provided for @recentVisits.
  ///
  /// In en, this message translates to:
  /// **'Recent Visits'**
  String get recentVisits;

  /// No description provided for @stepHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get stepHospital;

  /// No description provided for @stepDepartment.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get stepDepartment;

  /// No description provided for @stepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get stepConfirm;

  /// No description provided for @patientComplaint.
  ///
  /// In en, this message translates to:
  /// **'Patient Complaint'**
  String get patientComplaint;

  /// No description provided for @patientComplaintHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your main problem or symptoms for the doctor.'**
  String get patientComplaintHint;

  /// No description provided for @patientHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get patientHistory;

  /// No description provided for @patientHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Any relevant past illness, medicines, or notes for hospital staff.'**
  String get patientHistoryHint;

  /// No description provided for @cnicNumber.
  ///
  /// In en, this message translates to:
  /// **'CNIC Number'**
  String get cnicNumber;

  /// No description provided for @authorizedAccessOnly.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZED\nACCESS ONLY'**
  String get authorizedAccessOnly;

  /// No description provided for @signInInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your CNIC to securely access hospital records. If your record is not found, contact hospital reception.'**
  String get signInInfoMessage;

  /// No description provided for @enterCnic.
  ///
  /// In en, this message translates to:
  /// **'Please enter your CNIC number'**
  String get enterCnic;

  /// No description provided for @enterCnicRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your CNIC'**
  String get enterCnicRequired;

  /// No description provided for @cnicMustBe13Digits.
  ///
  /// In en, this message translates to:
  /// **'CNIC must be exactly 13 digits'**
  String get cnicMustBe13Digits;

  /// No description provided for @cnicHint.
  ///
  /// In en, this message translates to:
  /// **'XXXXX-XXXXXXX-X'**
  String get cnicHint;

  /// No description provided for @scanCnic.
  ///
  /// In en, this message translates to:
  /// **'Scan CNIC'**
  String get scanCnic;

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Patient not found'**
  String get accountNotFound;

  /// No description provided for @accountNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not find a patient with CNIC {cnic}.\n\nPlease visit hospital reception for assistance.'**
  String accountNotFoundMessage(String cnic);

  /// No description provided for @phoneMissing.
  ///
  /// In en, this message translates to:
  /// **'Phone number missing'**
  String get phoneMissing;

  /// No description provided for @phoneMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello {name},\n\nYour patient record does not have a phone number. Please visit hospital reception to update your contact details.'**
  String phoneMissingMessage(String name);

  /// No description provided for @cnicPhotoCaptured.
  ///
  /// In en, this message translates to:
  /// **'CNIC photo captured. Enter the number if scan is not automatic yet.'**
  String get cnicPhotoCaptured;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @there.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get there;

  /// No description provided for @needHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get needHelp;

  /// No description provided for @contactReception.
  ///
  /// In en, this message translates to:
  /// **'Contact hospital reception'**
  String get contactReception;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @havingTroubleSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Having trouble signing in?'**
  String get havingTroubleSigningIn;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @faqs.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get faqs;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Need Help? Contact Support'**
  String get contactSupport;

  /// No description provided for @healthcarePortalFooter.
  ///
  /// In en, this message translates to:
  /// **'MY HEALTH RECORD  |  PUNJAB GOVERNMENT'**
  String get healthcarePortalFooter;

  /// No description provided for @copyrightPitb.
  ///
  /// In en, this message translates to:
  /// **'© 2024 Health and Population Department'**
  String get copyrightPitb;

  /// No description provided for @visitNearestHospitalSupport.
  ///
  /// In en, this message translates to:
  /// **'Visit the nearest hospital for support'**
  String get visitNearestHospitalSupport;

  /// No description provided for @hospitalSupport.
  ///
  /// In en, this message translates to:
  /// **'Hospital Support'**
  String get hospitalSupport;

  /// No description provided for @nearestHospital.
  ///
  /// In en, this message translates to:
  /// **'Nearest Hospital'**
  String get nearestHospital;

  /// No description provided for @nearestHospitals.
  ///
  /// In en, this message translates to:
  /// **'Nearest hospitals'**
  String get nearestHospitals;

  /// No description provided for @typeToSearchMoreHospitals.
  ///
  /// In en, this message translates to:
  /// **'Type to search more hospitals...'**
  String get typeToSearchMoreHospitals;

  /// No description provided for @distanceAwayKm.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String distanceAwayKm(String distance);

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to find the nearest hospital.'**
  String get locationPermissionRequired;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to find the nearest hospital.'**
  String get locationServicesDisabled;

  /// No description provided for @findingNearestHospital.
  ///
  /// In en, this message translates to:
  /// **'Finding nearest hospital...'**
  String get findingNearestHospital;

  /// No description provided for @noHospitalFoundNearby.
  ///
  /// In en, this message translates to:
  /// **'No hospital could be matched near your location.'**
  String get noHospitalFoundNearby;

  /// No description provided for @approximateHospitalDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance is approximate based on district location.'**
  String get approximateHospitalDistance;

  /// No description provided for @noEncountersFound.
  ///
  /// In en, this message translates to:
  /// **'No encounters found'**
  String get noEncountersFound;

  /// No description provided for @fetchingPatientData.
  ///
  /// In en, this message translates to:
  /// **'Fetching patient data...'**
  String get fetchingPatientData;

  /// No description provided for @appointmentBooked.
  ///
  /// In en, this message translates to:
  /// **'Visit booked successfully'**
  String get appointmentBooked;

  /// No description provided for @yourToken.
  ///
  /// In en, this message translates to:
  /// **'Your token'**
  String get yourToken;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goHome;

  /// No description provided for @bookAnother.
  ///
  /// In en, this message translates to:
  /// **'Book another visit'**
  String get bookAnother;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'{count} yrs'**
  String years(int count);

  /// No description provided for @mrnLabel.
  ///
  /// In en, this message translates to:
  /// **'MRN {mrn}'**
  String mrnLabel(String mrn);

  /// No description provided for @cnicLabel.
  ///
  /// In en, this message translates to:
  /// **'CNIC {cnic}'**
  String cnicLabel(String cnic);

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @verifyYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Phone'**
  String get verifyYourPhone;

  /// No description provided for @step2Of3.
  ///
  /// In en, this message translates to:
  /// **'STEP 2 OF 3'**
  String get step2Of3;

  /// No description provided for @step3Of3.
  ///
  /// In en, this message translates to:
  /// **'STEP 3 OF 3'**
  String get step3Of3;

  /// No description provided for @helloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String helloName(String name);

  /// No description provided for @phoneVerifyInfo.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code to the phone number on your patient record. Visit reception if this number is wrong.'**
  String get phoneVerifyInfo;

  /// No description provided for @howToSendCode.
  ///
  /// In en, this message translates to:
  /// **'How should we send the code?'**
  String get howToSendCode;

  /// No description provided for @channelSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get channelSms;

  /// No description provided for @channelWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get channelWhatsApp;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @otpSentToPhone.
  ///
  /// In en, this message translates to:
  /// **'We have sent a 6-digit code to {phone}'**
  String otpSentToPhone(String phone);

  /// No description provided for @otpSentToPhoneGeneric.
  ///
  /// In en, this message translates to:
  /// **'We have sent a 6-digit code to your phone'**
  String get otpSentToPhoneGeneric;

  /// No description provided for @enter6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get enter6DigitCode;

  /// No description provided for @otpMustBe6Digits.
  ///
  /// In en, this message translates to:
  /// **'OTP must be 6 digits'**
  String get otpMustBe6Digits;

  /// No description provided for @otpExpiresIn5Min.
  ///
  /// In en, this message translates to:
  /// **'This code will expire in 5 minutes'**
  String get otpExpiresIn5Min;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @registeredNumber.
  ///
  /// In en, this message translates to:
  /// **'your phone number'**
  String get registeredNumber;

  /// No description provided for @otpSentVia.
  ///
  /// In en, this message translates to:
  /// **'OTP sent via {channel} to {phone}'**
  String otpSentVia(String channel, String phone);

  /// No description provided for @failedSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP: {message}'**
  String failedSendOtp(String message);

  /// No description provided for @apiFailedInitClient.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize API client'**
  String get apiFailedInitClient;

  /// No description provided for @apiFailedRequestOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to request OTP'**
  String get apiFailedRequestOtp;

  /// No description provided for @apiFailedVerifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify OTP'**
  String get apiFailedVerifyOtp;

  /// No description provided for @apiFailedLookupPatient.
  ///
  /// In en, this message translates to:
  /// **'Failed to lookup patient'**
  String get apiFailedLookupPatient;

  /// No description provided for @apiInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP code. Please try again.'**
  String get apiInvalidOtp;

  /// No description provided for @apiPatientNotFound.
  ///
  /// In en, this message translates to:
  /// **'Patient not found'**
  String get apiPatientNotFound;

  /// No description provided for @apiCooldown.
  ///
  /// In en, this message translates to:
  /// **'Please wait {seconds} seconds before requesting another OTP'**
  String apiCooldown(int seconds);

  /// No description provided for @apiOtpSentSms.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully via SMS.'**
  String get apiOtpSentSms;

  /// No description provided for @apiOtpSentWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully via WhatsApp.'**
  String get apiOtpSentWhatsapp;

  /// No description provided for @apiOtpVerified.
  ///
  /// In en, this message translates to:
  /// **'OTP verified successfully.'**
  String get apiOtpVerified;

  /// No description provided for @apiAccountFoundOtp.
  ///
  /// In en, this message translates to:
  /// **'We found your patient record. OTP will be sent to {phone}.'**
  String apiAccountFoundOtp(String phone);

  /// No description provided for @apiNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get apiNetworkError;

  /// No description provided for @apiUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get apiUnknownError;

  /// No description provided for @visitFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get visitFrom;

  /// No description provided for @visitTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get visitTo;

  /// No description provided for @refreshRecords.
  ///
  /// In en, this message translates to:
  /// **'Refresh records'**
  String get refreshRecords;

  /// No description provided for @showRecords.
  ///
  /// In en, this message translates to:
  /// **'Show records'**
  String get showRecords;

  /// No description provided for @sectionVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get sectionVitals;

  /// No description provided for @sectionComplaints.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get sectionComplaints;

  /// No description provided for @sectionSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get sectionSymptoms;

  /// No description provided for @sectionDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get sectionDiagnosis;

  /// No description provided for @sectionMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get sectionMedicines;

  /// No description provided for @sectionLabTests.
  ///
  /// In en, this message translates to:
  /// **'Lab tests'**
  String get sectionLabTests;

  /// No description provided for @sectionClinicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Clinical notes'**
  String get sectionClinicalNotes;

  /// No description provided for @sectionProcedureNote.
  ///
  /// In en, this message translates to:
  /// **'Procedure note'**
  String get sectionProcedureNote;

  /// No description provided for @sectionComplications.
  ///
  /// In en, this message translates to:
  /// **'Complications'**
  String get sectionComplications;

  /// No description provided for @checkupTitle.
  ///
  /// In en, this message translates to:
  /// **'{type} checkup'**
  String checkupTitle(String type);

  /// No description provided for @checkupGeneric.
  ///
  /// In en, this message translates to:
  /// **'Checkup'**
  String get checkupGeneric;

  /// No description provided for @statusCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get statusCheckedIn;

  /// No description provided for @statusCheckedOut.
  ///
  /// In en, this message translates to:
  /// **'Checked out'**
  String get statusCheckedOut;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get statusStopped;

  /// No description provided for @factAnesthesia.
  ///
  /// In en, this message translates to:
  /// **'Anesthesia'**
  String get factAnesthesia;

  /// No description provided for @factAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get factAssistant;

  /// No description provided for @factOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get factOutcome;

  /// No description provided for @medQty.
  ///
  /// In en, this message translates to:
  /// **'Qty {qty}'**
  String medQty(String qty);

  /// No description provided for @medDurationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String medDurationDays(int count);

  /// No description provided for @medDurationWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String medDurationWeeks(int count);

  /// No description provided for @medDurationMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String medDurationMonths(int count);

  /// No description provided for @medImmediatelyFor.
  ///
  /// In en, this message translates to:
  /// **'Immediately for {duration}'**
  String medImmediatelyFor(String duration);

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String untilDate(String date);

  /// No description provided for @encounterViewOnly.
  ///
  /// In en, this message translates to:
  /// **'Encounter #{id} — view only'**
  String encounterViewOnly(String id);

  /// No description provided for @vitalBp.
  ///
  /// In en, this message translates to:
  /// **'BP'**
  String get vitalBp;

  /// No description provided for @vitalHr.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get vitalHr;

  /// No description provided for @vitalTemp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get vitalTemp;

  /// No description provided for @vitalSpo2.
  ///
  /// In en, this message translates to:
  /// **'SpO₂'**
  String get vitalSpo2;

  /// No description provided for @vitalRr.
  ///
  /// In en, this message translates to:
  /// **'RR'**
  String get vitalRr;

  /// No description provided for @vitalWt.
  ///
  /// In en, this message translates to:
  /// **'Wt'**
  String get vitalWt;

  /// No description provided for @vitalHt.
  ///
  /// In en, this message translates to:
  /// **'Ht'**
  String get vitalHt;

  /// No description provided for @vitalBmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get vitalBmi;

  /// No description provided for @vitalBsr.
  ///
  /// In en, this message translates to:
  /// **'BSR'**
  String get vitalBsr;
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
