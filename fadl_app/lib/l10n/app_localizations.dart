import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @mushaf.
  ///
  /// In en, this message translates to:
  /// **'Mushaf'**
  String get mushaf;

  /// No description provided for @athkar.
  ///
  /// In en, this message translates to:
  /// **'Remembrances'**
  String get athkar;

  /// No description provided for @prayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Prayer times'**
  String get prayerTimes;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @quranReading.
  ///
  /// In en, this message translates to:
  /// **'Read the Quran'**
  String get quranReading;

  /// No description provided for @quranReadingDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the Mushaf, listen to reciters, and follow your reading plan'**
  String get quranReadingDescription;

  /// No description provided for @reciters.
  ///
  /// In en, this message translates to:
  /// **'Reciters'**
  String get reciters;

  /// No description provided for @quranCompletion.
  ///
  /// In en, this message translates to:
  /// **'Quran reading plan'**
  String get quranCompletion;

  /// No description provided for @worship.
  ///
  /// In en, this message translates to:
  /// **'Prayer and worship'**
  String get worship;

  /// No description provided for @worshipDescription.
  ///
  /// In en, this message translates to:
  /// **'Your next prayer, prayer log, and remembrances'**
  String get worshipDescription;

  /// No description provided for @dailyTools.
  ///
  /// In en, this message translates to:
  /// **'Daily tools'**
  String get dailyTools;

  /// No description provided for @dailyToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh, supplications, Ramadan, and more'**
  String get dailyToolsDescription;

  /// No description provided for @qibla.
  ///
  /// In en, this message translates to:
  /// **'Qibla'**
  String get qibla;

  /// No description provided for @tasbeeh.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh'**
  String get tasbeeh;

  /// No description provided for @parentDua.
  ///
  /// In en, this message translates to:
  /// **'Prayer for a parent'**
  String get parentDua;

  /// No description provided for @ramadan.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get ramadan;

  /// No description provided for @moreTools.
  ///
  /// In en, this message translates to:
  /// **'Hijri calendar • fasting tracker • zakat calculator in More'**
  String get moreTools;

  /// No description provided for @prayerTracker.
  ///
  /// In en, this message translates to:
  /// **'Prayer tracker'**
  String get prayerTracker;

  /// No description provided for @prayerTrackerDescription.
  ///
  /// In en, this message translates to:
  /// **'Log your prayers or open the missed-prayer record'**
  String get prayerTrackerDescription;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Quran • remembrance • supplication'**
  String get appTagline;

  /// No description provided for @dedicationPrefix.
  ///
  /// In en, this message translates to:
  /// **'An ongoing charity in memory of '**
  String get dedicationPrefix;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @dailyAyah.
  ///
  /// In en, this message translates to:
  /// **'Verse of the day'**
  String get dailyAyah;

  /// No description provided for @dailyBlessing.
  ///
  /// In en, this message translates to:
  /// **'Today\'s reflection'**
  String get dailyBlessing;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @openMushaf.
  ///
  /// In en, this message translates to:
  /// **'Open in Mushaf'**
  String get openMushaf;

  /// No description provided for @nextPrayerIn.
  ///
  /// In en, this message translates to:
  /// **'Next prayer in'**
  String get nextPrayerIn;

  /// No description provided for @allPrayerTimes.
  ///
  /// In en, this message translates to:
  /// **'All prayer times'**
  String get allPrayerTimes;

  /// No description provided for @setLocation.
  ///
  /// In en, this message translates to:
  /// **'Set your location'**
  String get setLocation;

  /// No description provided for @setLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'See prayer times, countdown, and Qibla direction'**
  String get setLocationDescription;

  /// No description provided for @dailyProgress.
  ///
  /// In en, this message translates to:
  /// **'Daily progress'**
  String get dailyProgress;

  /// No description provided for @noActivePlan.
  ///
  /// In en, this message translates to:
  /// **'No active reading plan'**
  String get noActivePlan;

  /// No description provided for @planCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reading plan completed, praise be to Allah'**
  String get planCompleted;

  /// No description provided for @startPlan.
  ///
  /// In en, this message translates to:
  /// **'Start a reading plan'**
  String get startPlan;

  /// No description provided for @hadithToday.
  ///
  /// In en, this message translates to:
  /// **'Hadith of the day'**
  String get hadithToday;

  /// No description provided for @hadithLibrary.
  ///
  /// In en, this message translates to:
  /// **'Hadith library'**
  String get hadithLibrary;

  /// No description provided for @dedicateToday.
  ///
  /// In en, this message translates to:
  /// **'Dedicate today\'s reading'**
  String get dedicateToday;

  /// No description provided for @honoringParents.
  ///
  /// In en, this message translates to:
  /// **'Honoring parents'**
  String get honoringParents;

  /// No description provided for @shareDua.
  ///
  /// In en, this message translates to:
  /// **'Share supplication'**
  String get shareDua;

  /// No description provided for @dedicatedReward.
  ///
  /// In en, this message translates to:
  /// **'Reward dedicated'**
  String get dedicatedReward;

  /// No description provided for @hijriCalendar.
  ///
  /// In en, this message translates to:
  /// **'Hijri calendar'**
  String get hijriCalendar;

  /// No description provided for @fastingTracker.
  ///
  /// In en, this message translates to:
  /// **'Fasting tracker'**
  String get fastingTracker;

  /// No description provided for @zakatCalculator.
  ///
  /// In en, this message translates to:
  /// **'Zakat calculator'**
  String get zakatCalculator;

  /// No description provided for @quranAssistant.
  ///
  /// In en, this message translates to:
  /// **'Quran assistant'**
  String get quranAssistant;

  /// No description provided for @audioLibrary.
  ///
  /// In en, this message translates to:
  /// **'Audio library'**
  String get audioLibrary;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @tasbeehElectronic.
  ///
  /// In en, this message translates to:
  /// **'Digital tasbeeh'**
  String get tasbeehElectronic;

  /// No description provided for @qiblaDirection.
  ///
  /// In en, this message translates to:
  /// **'Qibla direction'**
  String get qiblaDirection;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance and reading'**
  String get appearance;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get appTheme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @mushafFontSize.
  ///
  /// In en, this message translates to:
  /// **'Mushaf font size'**
  String get mushafFontSize;

  /// No description provided for @defaultReciter.
  ///
  /// In en, this message translates to:
  /// **'Default reciter'**
  String get defaultReciter;

  /// No description provided for @defaultTafsir.
  ///
  /// In en, this message translates to:
  /// **'Default tafsir'**
  String get defaultTafsir;

  /// No description provided for @availableOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get availableOffline;

  /// No description provided for @needsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download from Offline tafsir first'**
  String get needsDownload;

  /// No description provided for @loadsOnDemand.
  ///
  /// In en, this message translates to:
  /// **'Loaded on demand'**
  String get loadsOnDemand;

  /// No description provided for @manageLibrary.
  ///
  /// In en, this message translates to:
  /// **'Manage tafsir, tajweed, hadith, and recitations'**
  String get manageLibrary;

  /// No description provided for @coloredTajweed.
  ///
  /// In en, this message translates to:
  /// **'Color-coded Tajweed text'**
  String get coloredTajweed;

  /// No description provided for @offlineTafsir.
  ///
  /// In en, this message translates to:
  /// **'Offline tafsir'**
  String get offlineTafsir;

  /// No description provided for @optionalDownload.
  ///
  /// In en, this message translates to:
  /// **'Optional download; delete to save space'**
  String get optionalDownload;

  /// No description provided for @locationPrayer.
  ///
  /// In en, this message translates to:
  /// **'Location and prayer times'**
  String get locationPrayer;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set yet'**
  String get notSet;

  /// No description provided for @calculationMethod.
  ///
  /// In en, this message translates to:
  /// **'Calculation method'**
  String get calculationMethod;

  /// No description provided for @asrSchool.
  ///
  /// In en, this message translates to:
  /// **'Asr school'**
  String get asrSchool;

  /// No description provided for @hijriAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Hijri date adjustment'**
  String get hijriAdjustment;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get enableNotifications;

  /// No description provided for @notificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Adhan and reminders on this device'**
  String get notificationDescription;

  /// No description provided for @preAdhanAlert.
  ///
  /// In en, this message translates to:
  /// **'Before-adhan alert'**
  String get preAdhanAlert;

  /// No description provided for @perPrayerAdhan.
  ///
  /// In en, this message translates to:
  /// **'Configure each prayer\'s adhan in Prayer times'**
  String get perPrayerAdhan;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @morningAthkar.
  ///
  /// In en, this message translates to:
  /// **'Morning remembrances'**
  String get morningAthkar;

  /// No description provided for @eveningAthkar.
  ///
  /// In en, this message translates to:
  /// **'Evening remembrances'**
  String get eveningAthkar;

  /// No description provided for @sleepAthkar.
  ///
  /// In en, this message translates to:
  /// **'Bedtime remembrances'**
  String get sleepAthkar;

  /// No description provided for @qiyam.
  ///
  /// In en, this message translates to:
  /// **'Night prayer'**
  String get qiyam;

  /// No description provided for @qiyamDescription.
  ///
  /// In en, this message translates to:
  /// **'At the start of the last third of the night'**
  String get qiyamDescription;

  /// No description provided for @duha.
  ///
  /// In en, this message translates to:
  /// **'Duha prayer'**
  String get duha;

  /// No description provided for @duhaDescription.
  ///
  /// In en, this message translates to:
  /// **'Midway between sunrise and noon'**
  String get duhaDescription;

  /// No description provided for @kahf.
  ///
  /// In en, this message translates to:
  /// **'Surah Al-Kahf'**
  String get kahf;

  /// No description provided for @kahfDescription.
  ///
  /// In en, this message translates to:
  /// **'Every Friday after Fajr'**
  String get kahfDescription;

  /// No description provided for @fridayHour.
  ///
  /// In en, this message translates to:
  /// **'Friday\'s hour of supplication'**
  String get fridayHour;

  /// No description provided for @fridayHourDescription.
  ///
  /// In en, this message translates to:
  /// **'One hour before Maghrib'**
  String get fridayHourDescription;

  /// No description provided for @mondayThursday.
  ///
  /// In en, this message translates to:
  /// **'Monday and Thursday fasting'**
  String get mondayThursday;

  /// No description provided for @mondayThursdayDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminder the night before'**
  String get mondayThursdayDescription;

  /// No description provided for @whiteDays.
  ///
  /// In en, this message translates to:
  /// **'White days fasting'**
  String get whiteDays;

  /// No description provided for @whiteDaysDescription.
  ///
  /// In en, this message translates to:
  /// **'13th, 14th, and 15th of each Hijri month'**
  String get whiteDaysDescription;

  /// No description provided for @planReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reading reminder'**
  String get planReminder;

  /// No description provided for @planReminderDescription.
  ///
  /// In en, this message translates to:
  /// **'When today\'s reading has pages remaining'**
  String get planReminderDescription;

  /// No description provided for @dataAbout.
  ///
  /// In en, this message translates to:
  /// **'Data and about'**
  String get dataAbout;

  /// No description provided for @deleteMyData.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get deleteMyData;

  /// No description provided for @deleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes reading plans, counters, bookmarks, and settings'**
  String get deleteDescription;

  /// No description provided for @accountDescription.
  ///
  /// In en, this message translates to:
  /// **'Your account is anonymous; no sign-in required. Fadl is completely free.'**
  String get accountDescription;

  /// No description provided for @dedicationLabel.
  ///
  /// In en, this message translates to:
  /// **'Ongoing charity in memory of'**
  String get dedicationLabel;

  /// No description provided for @recipientName.
  ///
  /// In en, this message translates to:
  /// **'Recipient\'s name'**
  String get recipientName;

  /// No description provided for @recipientExample.
  ///
  /// In en, this message translates to:
  /// **'For example: Fadl Salim Mohammed Saleh'**
  String get recipientExample;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @nameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved'**
  String get nameSaved;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @myDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your data was deleted'**
  String get myDataDeleted;

  /// No description provided for @restartAfterDelete.
  ///
  /// In en, this message translates to:
  /// **'Your data was deleted. Restart the app to begin again.'**
  String get restartAfterDelete;

  /// No description provided for @tajweedDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Tajweed text downloaded'**
  String get tajweedDownloaded;

  /// No description provided for @tajweedRedownload.
  ///
  /// In en, this message translates to:
  /// **'You can download it again when online.'**
  String get tajweedRedownload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @notDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get notDownloaded;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloading;

  /// No description provided for @tajweedDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'The color-coded text is not bundled; download is optional when online. '**
  String get tajweedDisclaimer;

  /// No description provided for @tajweedLegal.
  ///
  /// In en, this message translates to:
  /// **'Colors are a visual aid, not a religious ruling.'**
  String get tajweedLegal;

  /// No description provided for @tafsirRedownload.
  ///
  /// In en, this message translates to:
  /// **'You can download it again anytime.'**
  String get tafsirRedownload;

  /// No description provided for @verseByVerse.
  ///
  /// In en, this message translates to:
  /// **'Verse-by-verse recitation — synchronized verses'**
  String get verseByVerse;

  /// No description provided for @fullSurah.
  ///
  /// In en, this message translates to:
  /// **'Full-surah recitations — no automatic verse sync'**
  String get fullSurah;

  /// No description provided for @searchReciter.
  ///
  /// In en, this message translates to:
  /// **'Search reciters'**
  String get searchReciter;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @murattal.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get murattal;

  /// No description provided for @mujawwad.
  ///
  /// In en, this message translates to:
  /// **'Melodic'**
  String get mujawwad;

  /// No description provided for @muallim.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get muallim;

  /// No description provided for @searchReciterBoth.
  ///
  /// In en, this message translates to:
  /// **'Search reciters in Arabic or Latin script'**
  String get searchReciterBoth;

  /// No description provided for @streamingNotice.
  ///
  /// In en, this message translates to:
  /// **'Streaming only; permission to listen does not grant redistribution rights.'**
  String get streamingNotice;

  /// No description provided for @chooseEdition.
  ///
  /// In en, this message translates to:
  /// **'Choose a reading or edition'**
  String get chooseEdition;

  /// No description provided for @searchSurah.
  ///
  /// In en, this message translates to:
  /// **'Search surahs'**
  String get searchSurah;

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get cancelDownload;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get deleteDownload;

  /// No description provided for @partiallyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Partially downloaded'**
  String get partiallyDownloaded;

  /// No description provided for @resumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get resumeDownload;

  /// No description provided for @downloadOffline.
  ///
  /// In en, this message translates to:
  /// **'Download for offline listening'**
  String get downloadOffline;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @pageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageNumber(String page);

  /// No description provided for @surahPage.
  ///
  /// In en, this message translates to:
  /// **'Surah {surah} (page {page})'**
  String surahPage(String surah, String page);

  /// No description provided for @surahVerse.
  ///
  /// In en, this message translates to:
  /// **'Surah {surah}: verse {verse}'**
  String surahVerse(String surah, String verse);

  /// No description provided for @surahName.
  ///
  /// In en, this message translates to:
  /// **'Surah {surah}'**
  String surahName(String surah);

  /// No description provided for @versesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} verses'**
  String versesCount(String count);

  /// No description provided for @nextPrayer.
  ///
  /// In en, this message translates to:
  /// **'{prayer} prayer'**
  String nextPrayer(String prayer);

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan ({title})'**
  String currentPlan(String title);

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(String percent);

  /// No description provided for @remainingPages.
  ///
  /// In en, this message translates to:
  /// **'Remaining today: {count} pages'**
  String remainingPages(String count);

  /// No description provided for @editionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} editions • {edition}'**
  String editionsCount(String count, String edition);

  /// No description provided for @dailyAt.
  ///
  /// In en, this message translates to:
  /// **'Daily at {time}'**
  String dailyAt(String time);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(String minutes);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @optionalSource.
  ///
  /// In en, this message translates to:
  /// **'Optional download • Source: {source}'**
  String optionalSource(String source);

  /// No description provided for @downloadedSize.
  ///
  /// In en, this message translates to:
  /// **'Downloaded • {size}'**
  String downloadedSize(String size);

  /// No description provided for @notDownloadedSize.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded • about {size}'**
  String notDownloadedSize(String size);

  /// No description provided for @downloadingSize.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {size}'**
  String downloadingSize(String size);

  /// No description provided for @downloadedTafsir.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {name}'**
  String downloadedTafsir(String name);

  /// No description provided for @deleteNamed.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String deleteNamed(String name);

  /// No description provided for @fullSurahLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load full-surah reciters. Check your connection: {error}'**
  String fullSurahLoadError(String error);

  /// No description provided for @prayerTrackerMore.
  ///
  /// In en, this message translates to:
  /// **'Log, make up, and review prayers'**
  String get prayerTrackerMore;

  /// No description provided for @hijriCalendarMore.
  ///
  /// In en, this message translates to:
  /// **'Dates and occasions'**
  String get hijriCalendarMore;

  /// No description provided for @fastingTrackerMore.
  ///
  /// In en, this message translates to:
  /// **'History and missed Ramadan fasts'**
  String get fastingTrackerMore;

  /// No description provided for @zakatMore.
  ///
  /// In en, this message translates to:
  /// **'Offline estimate'**
  String get zakatMore;

  /// No description provided for @hadithMore.
  ///
  /// In en, this message translates to:
  /// **'The nine books, Gardens of the Righteous, and the Forty Hadith'**
  String get hadithMore;

  /// No description provided for @assistantMore.
  ///
  /// In en, this message translates to:
  /// **'Search verses, hadith, and remembrances'**
  String get assistantMore;

  /// No description provided for @audioMore.
  ///
  /// In en, this message translates to:
  /// **'Recitations and memorization settings'**
  String get audioMore;

  /// No description provided for @libraryMore.
  ///
  /// In en, this message translates to:
  /// **'Saved content and downloadable books'**
  String get libraryMore;

  /// No description provided for @downloadsMore.
  ///
  /// In en, this message translates to:
  /// **'Surahs downloaded for offline listening'**
  String get downloadsMore;

  /// No description provided for @tasbeehMore.
  ///
  /// In en, this message translates to:
  /// **'Remembrance counter and daily goal'**
  String get tasbeehMore;

  /// No description provided for @planMore.
  ///
  /// In en, this message translates to:
  /// **'Reading plan and daily progress'**
  String get planMore;

  /// No description provided for @qiblaMore.
  ///
  /// In en, this message translates to:
  /// **'Compass and distance to Makkah'**
  String get qiblaMore;

  /// No description provided for @ramadanMore.
  ///
  /// In en, this message translates to:
  /// **'Fasting times and Ramadan practices'**
  String get ramadanMore;

  /// No description provided for @parentMore.
  ///
  /// In en, this message translates to:
  /// **'Ongoing charity and traditional supplications'**
  String get parentMore;

  /// No description provided for @settingsMore.
  ///
  /// In en, this message translates to:
  /// **'Appearance, notifications, and reciter'**
  String get settingsMore;

  /// No description provided for @deleteBackendWarning.
  ///
  /// In en, this message translates to:
  /// **'All your server data will be permanently deleted: reading plans, counters, bookmarks, supplications, and settings. This cannot be undone.'**
  String get deleteBackendWarning;

  /// No description provided for @deleteLocalWarning.
  ///
  /// In en, this message translates to:
  /// **'Data saved on this device will be permanently deleted: reading plans, counters, bookmarks, and settings. This cannot be undone.'**
  String get deleteLocalWarning;

  /// No description provided for @deleteTajweedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete color-coded Tajweed text?'**
  String get deleteTajweedQuestion;

  /// No description provided for @tafsirDownloadDescription.
  ///
  /// In en, this message translates to:
  /// **'No tafsir is bundled. Download the editions you need when online, then read them offline. Space used: {size}'**
  String tafsirDownloadDescription(String size);

  /// No description provided for @tajweedDetails.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}\n{url}\nThe color-coded text ships with the app and works offline; installing it unpacks about {approx} (safety limit {limit}). Space used: {used}. Colors are a visual aid, not a religious ruling.'**
  String tajweedDetails(
    String source,
    String url,
    String approx,
    String limit,
    String used,
  );

  /// No description provided for @mushafTitle.
  ///
  /// In en, this message translates to:
  /// **'The Noble Quran'**
  String get mushafTitle;

  /// No description provided for @surahsTab.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get surahsTab;

  /// No description provided for @juzTab.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get juzTab;

  /// No description provided for @quizShortcut.
  ///
  /// In en, this message translates to:
  /// **'Quran memorization quiz • Review pages'**
  String get quizShortcut;

  /// No description provided for @searchMushaf.
  ///
  /// In en, this message translates to:
  /// **'Search by surah name, number, or page'**
  String get searchMushaf;

  /// No description provided for @surahSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} verses • page {page}'**
  String surahSummary(String count, String page);

  /// No description provided for @meccan.
  ///
  /// In en, this message translates to:
  /// **'Meccan'**
  String get meccan;

  /// No description provided for @medinan.
  ///
  /// In en, this message translates to:
  /// **'Medinan'**
  String get medinan;

  /// No description provided for @juzName.
  ///
  /// In en, this message translates to:
  /// **'Juz {name}'**
  String juzName(String name);

  /// No description provided for @verseNumber.
  ///
  /// In en, this message translates to:
  /// **'Verse {verse}'**
  String verseNumber(String verse);

  /// No description provided for @readingPageJuz.
  ///
  /// In en, this message translates to:
  /// **'Page {page} • Juz {juz}'**
  String readingPageJuz(String page, String juz);

  /// No description provided for @quizTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran memorization quiz'**
  String get quizTitle;

  /// No description provided for @quizLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the Mushaf data'**
  String get quizLoadError;

  /// No description provided for @reviewSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your review on this device'**
  String get reviewSaveError;

  /// No description provided for @reviewsDue.
  ///
  /// In en, this message translates to:
  /// **'Reviews due: {count}'**
  String reviewsDue(String count);

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @quizPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Mushaf page (1–604)'**
  String get quizPageLabel;

  /// No description provided for @pageDue.
  ///
  /// In en, this message translates to:
  /// **'This page is due for review'**
  String get pageDue;

  /// No description provided for @nextReview.
  ///
  /// In en, this message translates to:
  /// **'Next review: {date} • in {days} days'**
  String nextReview(String date, String days);

  /// No description provided for @quizType.
  ///
  /// In en, this message translates to:
  /// **'Quiz type'**
  String get quizType;

  /// No description provided for @completeNextVerse.
  ///
  /// In en, this message translates to:
  /// **'Complete the next verse'**
  String get completeNextVerse;

  /// No description provided for @hiddenWords.
  ///
  /// In en, this message translates to:
  /// **'Hidden words'**
  String get hiddenWords;

  /// No description provided for @orderVerses.
  ///
  /// In en, this message translates to:
  /// **'Put the verses in order'**
  String get orderVerses;

  /// No description provided for @rateRecall.
  ///
  /// In en, this message translates to:
  /// **'Rate your recall (0 = not remembered, 5 = remembered well)'**
  String get rateRecall;

  /// No description provided for @reviewSaved.
  ///
  /// In en, this message translates to:
  /// **'Review saved on this device'**
  String get reviewSaved;

  /// No description provided for @newQuiz.
  ///
  /// In en, this message translates to:
  /// **'New quiz'**
  String get newQuiz;

  /// No description provided for @showAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get showAnswer;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @dragVerses.
  ///
  /// In en, this message translates to:
  /// **'Drag the verses into order'**
  String get dragVerses;

  /// No description provided for @checkOrder.
  ///
  /// In en, this message translates to:
  /// **'Check and reveal order'**
  String get checkOrder;

  /// No description provided for @correctOrder.
  ///
  /// In en, this message translates to:
  /// **'Correct order'**
  String get correctOrder;

  /// No description provided for @actualOrder.
  ///
  /// In en, this message translates to:
  /// **'Correct order:'**
  String get actualOrder;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @nightMode.
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get nightMode;

  /// No description provided for @dayMode.
  ///
  /// In en, this message translates to:
  /// **'Day mode'**
  String get dayMode;

  /// No description provided for @blackMode.
  ///
  /// In en, this message translates to:
  /// **'Pure black'**
  String get blackMode;

  /// No description provided for @increaseFont.
  ///
  /// In en, this message translates to:
  /// **'Increase font size ({size})'**
  String increaseFont(String size);

  /// No description provided for @decreaseFont.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get decreaseFont;

  /// No description provided for @tajweedColors.
  ///
  /// In en, this message translates to:
  /// **'Tajweed colors'**
  String get tajweedColors;

  /// No description provided for @tajweedScheme.
  ///
  /// In en, this message translates to:
  /// **'Tajweed colors: {scheme}'**
  String tajweedScheme(String scheme);

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @myBookmarks.
  ///
  /// In en, this message translates to:
  /// **'My bookmarks'**
  String get myBookmarks;

  /// No description provided for @dedicateReading.
  ///
  /// In en, this message translates to:
  /// **'Dedicate the reward of reading'**
  String get dedicateReading;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @togglePlayback.
  ///
  /// In en, this message translates to:
  /// **'Play or pause'**
  String get togglePlayback;

  /// No description provided for @bookmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get bookmarkPage;

  /// No description provided for @mushafIndex.
  ///
  /// In en, this message translates to:
  /// **'Mushaf index'**
  String get mushafIndex;

  /// No description provided for @goTo.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goTo;

  /// No description provided for @quickSearch.
  ///
  /// In en, this message translates to:
  /// **'Quick search'**
  String get quickSearch;

  /// No description provided for @emphasisNotMarked.
  ///
  /// In en, this message translates to:
  /// **'Emphatic letters are not marked in the source data.'**
  String get emphasisNotMarked;

  /// No description provided for @colorsIllustrative.
  ///
  /// In en, this message translates to:
  /// **'Colors are illustrative only'**
  String get colorsIllustrative;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @playFromPage.
  ///
  /// In en, this message translates to:
  /// **'Play from this page'**
  String get playFromPage;

  /// No description provided for @listenWhileReading.
  ///
  /// In en, this message translates to:
  /// **'Listen while reading'**
  String get listenWhileReading;

  /// No description provided for @repeatNow.
  ///
  /// In en, this message translates to:
  /// **'Repeat now • {count}'**
  String repeatNow(String count);

  /// No description provided for @startSelectedVerse.
  ///
  /// In en, this message translates to:
  /// **'Start from the selected verse or the first verse on this page'**
  String get startSelectedVerse;

  /// No description provided for @surahAndVerse.
  ///
  /// In en, this message translates to:
  /// **'Surah {surah} • verse {verse}'**
  String surahAndVerse(String surah, String verse);

  /// No description provided for @previousVerse.
  ///
  /// In en, this message translates to:
  /// **'Previous verse'**
  String get previousVerse;

  /// No description provided for @nextVerse.
  ///
  /// In en, this message translates to:
  /// **'Next verse'**
  String get nextVerse;

  /// No description provided for @memorizationSettings.
  ///
  /// In en, this message translates to:
  /// **'Memorization settings'**
  String get memorizationSettings;

  /// No description provided for @chooseReciter.
  ///
  /// In en, this message translates to:
  /// **'Choose reciter'**
  String get chooseReciter;

  /// No description provided for @jumpInMushaf.
  ///
  /// In en, this message translates to:
  /// **'Navigate the Mushaf'**
  String get jumpInMushaf;

  /// No description provided for @pageTab.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get pageTab;

  /// No description provided for @surahTab.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surahTab;

  /// No description provided for @juzTabSingular.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get juzTabSingular;

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get jump;

  /// No description provided for @juzHizbPage.
  ///
  /// In en, this message translates to:
  /// **'Juz {juz} • Hizb {hizb} • p. {page}'**
  String juzHizbPage(String juz, String hizb, String page);

  /// No description provided for @surahOrder.
  ///
  /// In en, this message translates to:
  /// **'No. {number}'**
  String surahOrder(String number);

  /// No description provided for @surahVerses.
  ///
  /// In en, this message translates to:
  /// **'{count} verses'**
  String surahVerses(String count);

  /// No description provided for @recitationError.
  ///
  /// In en, this message translates to:
  /// **'Could not play the recitation'**
  String get recitationError;

  /// No description provided for @bookmarkSaved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark saved'**
  String get bookmarkSaved;

  /// No description provided for @pageLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the page'**
  String get pageLoadError;

  /// No description provided for @readingPositionSaved.
  ///
  /// In en, this message translates to:
  /// **'Reading position saved'**
  String get readingPositionSaved;

  /// No description provided for @tafsirNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'This tafsir is not downloaded on this device.'**
  String get tafsirNotDownloaded;

  /// No description provided for @offlineTafsirSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings • Offline tafsir'**
  String get offlineTafsirSettings;

  /// No description provided for @tafsirUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No tafsir is available for this verse in this edition.'**
  String get tafsirUnavailable;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @saveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Save bookmark'**
  String get saveBookmark;

  /// No description provided for @markRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markRead;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks saved yet'**
  String get noBookmarks;

  /// No description provided for @deleteBookmark.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get deleteBookmark;

  /// No description provided for @sharedFromFadl.
  ///
  /// In en, this message translates to:
  /// **'From the Fadl app'**
  String get sharedFromFadl;

  /// No description provided for @listenToQuran.
  ///
  /// In en, this message translates to:
  /// **'Listen to the Quran'**
  String get listenToQuran;

  /// No description provided for @surahLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the surah'**
  String get surahLoadError;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @cancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get cancelTimer;

  /// No description provided for @timerEndsAt.
  ///
  /// In en, this message translates to:
  /// **'Stops at {time}'**
  String timerEndsAt(String time);

  /// No description provided for @dedicateListening.
  ///
  /// In en, this message translates to:
  /// **'Dedicate the reward of listening'**
  String get dedicateListening;

  /// No description provided for @previousSurah.
  ///
  /// In en, this message translates to:
  /// **'Previous surah'**
  String get previousSurah;

  /// No description provided for @nextSurah.
  ///
  /// In en, this message translates to:
  /// **'Next surah'**
  String get nextSurah;

  /// No description provided for @currentVerse.
  ///
  /// In en, this message translates to:
  /// **'Current verse ({verse} of {total})'**
  String currentVerse(String verse, String total);

  /// No description provided for @rewindTen.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get rewindTen;

  /// No description provided for @forwardTen.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get forwardTen;

  /// No description provided for @repeatEachVerse.
  ///
  /// In en, this message translates to:
  /// **'Repeat each verse'**
  String get repeatEachVerse;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @repeatSegment.
  ///
  /// In en, this message translates to:
  /// **'Repeat a passage from the surah'**
  String get repeatSegment;

  /// No description provided for @fromVerse.
  ///
  /// In en, this message translates to:
  /// **'From verse'**
  String get fromVerse;

  /// No description provided for @toVerse.
  ///
  /// In en, this message translates to:
  /// **'To verse'**
  String get toVerse;

  /// No description provided for @repeatPassage.
  ///
  /// In en, this message translates to:
  /// **'Repeat passage'**
  String get repeatPassage;

  /// No description provided for @recitationPause.
  ///
  /// In en, this message translates to:
  /// **'Pause after each verse for repetition'**
  String get recitationPause;

  /// No description provided for @verseLength.
  ///
  /// In en, this message translates to:
  /// **'Verse length'**
  String get verseLength;

  /// No description provided for @doubleVerseLength.
  ///
  /// In en, this message translates to:
  /// **'Twice the verse length'**
  String get doubleVerseLength;

  /// No description provided for @recitationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Recitation speed'**
  String get recitationSpeed;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @secondsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds'**
  String secondsCount(String count);

  /// No description provided for @speedMultiplier.
  ///
  /// In en, this message translates to:
  /// **'{speed}×'**
  String speedMultiplier(String speed);

  /// No description provided for @fullSurahHeading.
  ///
  /// In en, this message translates to:
  /// **'Surah {surah} • {edition}'**
  String fullSurahHeading(String surah, String edition);

  /// No description provided for @fullSurahOnlineNotice.
  ///
  /// In en, this message translates to:
  /// **'Online streaming only; permission to listen does not grant redistribution rights.'**
  String get fullSurahOnlineNotice;

  /// No description provided for @fullSurahPlayError.
  ///
  /// In en, this message translates to:
  /// **'Could not play this surah. Check your connection.'**
  String get fullSurahPlayError;

  /// No description provided for @fullSurahInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Playback stopped unexpectedly. Try again.'**
  String get fullSurahInterrupted;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @simpleTajweed.
  ///
  /// In en, this message translates to:
  /// **'Simple colors'**
  String get simpleTajweed;

  /// No description provided for @darAlMaarifaTajweed.
  ///
  /// In en, this message translates to:
  /// **'Dar Al-Maarifa'**
  String get darAlMaarifaTajweed;

  /// No description provided for @tajweedMadd.
  ///
  /// In en, this message translates to:
  /// **'Prolongation'**
  String get tajweedMadd;

  /// No description provided for @tajweedGhunnah.
  ///
  /// In en, this message translates to:
  /// **'Nasalization / concealment'**
  String get tajweedGhunnah;

  /// No description provided for @tajweedIdgham.
  ///
  /// In en, this message translates to:
  /// **'Assimilation / conversion'**
  String get tajweedIdgham;

  /// No description provided for @tajweedQalqalah.
  ///
  /// In en, this message translates to:
  /// **'Echoing'**
  String get tajweedQalqalah;

  /// No description provided for @tajweedWasl.
  ///
  /// In en, this message translates to:
  /// **'Joining / lam'**
  String get tajweedWasl;

  /// No description provided for @tajweedSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent letters'**
  String get tajweedSilent;

  /// No description provided for @tajweedTwoCounts.
  ///
  /// In en, this message translates to:
  /// **'Two-count prolongation'**
  String get tajweedTwoCounts;

  /// No description provided for @tajweedOptionalCounts.
  ///
  /// In en, this message translates to:
  /// **'Optional 2-, 4-, or 6-count prolongation'**
  String get tajweedOptionalCounts;

  /// No description provided for @tajweedObligatoryCounts.
  ///
  /// In en, this message translates to:
  /// **'Obligatory 4- or 5-count prolongation'**
  String get tajweedObligatoryCounts;

  /// No description provided for @tajweedNecessaryCounts.
  ///
  /// In en, this message translates to:
  /// **'Necessary 6-count prolongation'**
  String get tajweedNecessaryCounts;

  /// No description provided for @tajweedNasalization.
  ///
  /// In en, this message translates to:
  /// **'Concealment and nasalization (two counts)'**
  String get tajweedNasalization;

  /// No description provided for @tajweedUnpronounced.
  ///
  /// In en, this message translates to:
  /// **'Assimilation and unpronounced letters'**
  String get tajweedUnpronounced;

  /// No description provided for @hijriMuharram.
  ///
  /// In en, this message translates to:
  /// **'Muharram'**
  String get hijriMuharram;

  /// No description provided for @hijriSafar.
  ///
  /// In en, this message translates to:
  /// **'Safar'**
  String get hijriSafar;

  /// No description provided for @hijriRabiI.
  ///
  /// In en, this message translates to:
  /// **'Rabi\' al-Awwal'**
  String get hijriRabiI;

  /// No description provided for @hijriRabiII.
  ///
  /// In en, this message translates to:
  /// **'Rabi\' al-Thani'**
  String get hijriRabiII;

  /// No description provided for @hijriJumadaI.
  ///
  /// In en, this message translates to:
  /// **'Jumada al-Ula'**
  String get hijriJumadaI;

  /// No description provided for @hijriJumadaII.
  ///
  /// In en, this message translates to:
  /// **'Jumada al-Akhira'**
  String get hijriJumadaII;

  /// No description provided for @hijriRajab.
  ///
  /// In en, this message translates to:
  /// **'Rajab'**
  String get hijriRajab;

  /// No description provided for @hijriShaban.
  ///
  /// In en, this message translates to:
  /// **'Sha\'ban'**
  String get hijriShaban;

  /// No description provided for @hijriRamadan.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get hijriRamadan;

  /// No description provided for @hijriShawwal.
  ///
  /// In en, this message translates to:
  /// **'Shawwal'**
  String get hijriShawwal;

  /// No description provided for @hijriDhulQadah.
  ///
  /// In en, this message translates to:
  /// **'Dhu al-Qi\'dah'**
  String get hijriDhulQadah;

  /// No description provided for @hijriDhulHijjah.
  ///
  /// In en, this message translates to:
  /// **'Dhu al-Hijjah'**
  String get hijriDhulHijjah;

  /// No description provided for @hijriDate.
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year} AH'**
  String hijriDate(String day, String month, String year);

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayerSunrise;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @methodUmmAlQura.
  ///
  /// In en, this message translates to:
  /// **'Umm al-Qura University, Makkah'**
  String get methodUmmAlQura;

  /// No description provided for @methodEgyptian.
  ///
  /// In en, this message translates to:
  /// **'Egyptian General Authority of Survey'**
  String get methodEgyptian;

  /// No description provided for @methodMuslimWorldLeague.
  ///
  /// In en, this message translates to:
  /// **'Muslim World League'**
  String get methodMuslimWorldLeague;

  /// No description provided for @methodKarachi.
  ///
  /// In en, this message translates to:
  /// **'University of Islamic Sciences, Karachi'**
  String get methodKarachi;

  /// No description provided for @methodDubai.
  ///
  /// In en, this message translates to:
  /// **'Dubai'**
  String get methodDubai;

  /// No description provided for @methodKuwait.
  ///
  /// In en, this message translates to:
  /// **'Kuwait'**
  String get methodKuwait;

  /// No description provided for @methodQatar.
  ///
  /// In en, this message translates to:
  /// **'Qatar'**
  String get methodQatar;

  /// No description provided for @methodSingapore.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get methodSingapore;

  /// No description provided for @methodTurkey.
  ///
  /// In en, this message translates to:
  /// **'Turkish Presidency of Religious Affairs'**
  String get methodTurkey;

  /// No description provided for @methodTehran.
  ///
  /// In en, this message translates to:
  /// **'Institute of Geophysics, Tehran'**
  String get methodTehran;

  /// No description provided for @methodNorthAmerica.
  ///
  /// In en, this message translates to:
  /// **'Islamic Society of North America (ISNA)'**
  String get methodNorthAmerica;

  /// No description provided for @methodMoonsightingCommittee.
  ///
  /// In en, this message translates to:
  /// **'Moonsighting Committee'**
  String get methodMoonsightingCommittee;

  /// No description provided for @madhabShafi.
  ///
  /// In en, this message translates to:
  /// **'Majority (Shafi\'i, Maliki, Hanbali)'**
  String get madhabShafi;

  /// No description provided for @madhabHanafi.
  ///
  /// In en, this message translates to:
  /// **'Hanafi (later Asr)'**
  String get madhabHanafi;

  /// No description provided for @asrCalculationSchool.
  ///
  /// In en, this message translates to:
  /// **'Asr calculation school'**
  String get asrCalculationSchool;

  /// No description provided for @cityRiyadh.
  ///
  /// In en, this message translates to:
  /// **'Riyadh, Saudi Arabia'**
  String get cityRiyadh;

  /// No description provided for @cityMakkah.
  ///
  /// In en, this message translates to:
  /// **'Makkah, Saudi Arabia'**
  String get cityMakkah;

  /// No description provided for @cityMadinah.
  ///
  /// In en, this message translates to:
  /// **'Madinah, Saudi Arabia'**
  String get cityMadinah;

  /// No description provided for @cityJeddah.
  ///
  /// In en, this message translates to:
  /// **'Jeddah, Saudi Arabia'**
  String get cityJeddah;

  /// No description provided for @cityCairo.
  ///
  /// In en, this message translates to:
  /// **'Cairo, Egypt'**
  String get cityCairo;

  /// No description provided for @cityAlexandria.
  ///
  /// In en, this message translates to:
  /// **'Alexandria, Egypt'**
  String get cityAlexandria;

  /// No description provided for @cityDubai.
  ///
  /// In en, this message translates to:
  /// **'Dubai, UAE'**
  String get cityDubai;

  /// No description provided for @cityKuwait.
  ///
  /// In en, this message translates to:
  /// **'Kuwait City, Kuwait'**
  String get cityKuwait;

  /// No description provided for @cityDoha.
  ///
  /// In en, this message translates to:
  /// **'Doha, Qatar'**
  String get cityDoha;

  /// No description provided for @cityAmman.
  ///
  /// In en, this message translates to:
  /// **'Amman, Jordan'**
  String get cityAmman;

  /// No description provided for @cityCasablanca.
  ///
  /// In en, this message translates to:
  /// **'Casablanca, Morocco'**
  String get cityCasablanca;

  /// No description provided for @cityIstanbul.
  ///
  /// In en, this message translates to:
  /// **'Istanbul, Türkiye'**
  String get cityIstanbul;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'My current location'**
  String get currentLocation;

  /// No description provided for @locationUseGps.
  ///
  /// In en, this message translates to:
  /// **'Use my current location (GPS)'**
  String get locationUseGps;

  /// No description provided for @locationPurpose.
  ///
  /// In en, this message translates to:
  /// **'Used only to calculate prayer times and Qibla direction'**
  String get locationPurpose;

  /// No description provided for @locationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your location. Choose a city from the list.'**
  String get locationFailed;

  /// No description provided for @prayerLocationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Set your location to see prayer times'**
  String get prayerLocationPrompt;

  /// No description provided for @qiblaLocationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Set your location to find the Qibla'**
  String get qiblaLocationPrompt;

  /// No description provided for @ramadanLocationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Set your location to see the fasting timetable'**
  String get ramadanLocationPrompt;

  /// No description provided for @todayPrayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Today\'s prayer times'**
  String get todayPrayerTimes;

  /// No description provided for @adhanSettings.
  ///
  /// In en, this message translates to:
  /// **'Adhan settings'**
  String get adhanSettings;

  /// No description provided for @nextPrayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Next prayer'**
  String get nextPrayerLabel;

  /// No description provided for @timeUntilAdhan.
  ///
  /// In en, this message translates to:
  /// **'Time until adhan'**
  String get timeUntilAdhan;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get upcoming;

  /// No description provided for @nowLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get nowLabel;

  /// No description provided for @elapsed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get elapsed;

  /// No description provided for @moments.
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get moments;

  /// No description provided for @calculationTiming.
  ///
  /// In en, this message translates to:
  /// **'Calculation and timing settings'**
  String get calculationTiming;

  /// No description provided for @hijriCalendarAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Hijri calendar adjustment'**
  String get hijriCalendarAdjustment;

  /// No description provided for @hijriAdjustmentHint.
  ///
  /// In en, this message translates to:
  /// **'Match your local moon sighting'**
  String get hijriAdjustmentHint;

  /// No description provided for @decreaseDay.
  ///
  /// In en, this message translates to:
  /// **'Subtract one day'**
  String get decreaseDay;

  /// No description provided for @increaseDay.
  ///
  /// In en, this message translates to:
  /// **'Add one day'**
  String get increaseDay;

  /// No description provided for @modeAdhan.
  ///
  /// In en, this message translates to:
  /// **'Adhan'**
  String get modeAdhan;

  /// No description provided for @modeNotify.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get modeNotify;

  /// No description provided for @modeSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get modeSilent;

  /// No description provided for @fajrSoundFallback.
  ///
  /// In en, this message translates to:
  /// **'No Fajr adhan has been imported; you will receive a short notification.'**
  String get fajrSoundFallback;

  /// No description provided for @perPrayerAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert for each prayer'**
  String get perPrayerAlert;

  /// No description provided for @adhanSound.
  ///
  /// In en, this message translates to:
  /// **'Adhan sound'**
  String get adhanSound;

  /// No description provided for @otherPrayers.
  ///
  /// In en, this message translates to:
  /// **'Other prayers'**
  String get otherPrayers;

  /// No description provided for @adhanAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Full adhan is available on Android only; on this device, prayers set to Adhan receive a notification at prayer time.'**
  String get adhanAndroidOnly;

  /// No description provided for @adhanDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off in general settings. Enable them to hear the adhan.'**
  String get adhanDisabled;

  /// No description provided for @fajrSoundNotice.
  ///
  /// In en, this message translates to:
  /// **'The bundled adhan does not include the Fajr phrase ‘prayer is better than sleep’, so it is not used for Fajr. Import a Fajr adhan from your phone or receive a short notification.'**
  String get fajrSoundNotice;

  /// No description provided for @fajrImportHint.
  ///
  /// In en, this message translates to:
  /// **'No Fajr adhan imported yet; you will receive a short notification.'**
  String get fajrImportHint;

  /// No description provided for @adhanOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get adhanOptions;

  /// No description provided for @respectSilent.
  ///
  /// In en, this message translates to:
  /// **'Respect silent mode'**
  String get respectSilent;

  /// No description provided for @respectSilentHint.
  ///
  /// In en, this message translates to:
  /// **'When the phone is silent or vibrating: vibrate and notify instead of playing adhan'**
  String get respectSilentHint;

  /// No description provided for @testAdhan.
  ///
  /// In en, this message translates to:
  /// **'Test adhan in one minute'**
  String get testAdhan;

  /// No description provided for @testAdhanHint.
  ///
  /// In en, this message translates to:
  /// **'Schedules a real alarm; close the app or lock your screen to check'**
  String get testAdhanHint;

  /// No description provided for @batterySaving.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get batterySaving;

  /// No description provided for @batteryExempt.
  ///
  /// In en, this message translates to:
  /// **'This app is exempt from battery optimization'**
  String get batteryExempt;

  /// No description provided for @batteryWarning.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization may delay or prevent the adhan'**
  String get batteryWarning;

  /// No description provided for @batteryAdvice.
  ///
  /// In en, this message translates to:
  /// **'Some phones stop alarms from closed apps to save battery. Open settings, select All apps, then Fadl, and set it to Unrestricted or Not optimized. On some devices, also enable Autostart.'**
  String get batteryAdvice;

  /// No description provided for @openBatterySettings.
  ///
  /// In en, this message translates to:
  /// **'Open battery settings'**
  String get openBatterySettings;

  /// No description provided for @bundledAdhan.
  ///
  /// In en, this message translates to:
  /// **'Default adhan (calm)'**
  String get bundledAdhan;

  /// No description provided for @noFajrAdhan.
  ///
  /// In en, this message translates to:
  /// **'No adhan (short notification)'**
  String get noFajrAdhan;

  /// No description provided for @importFajr.
  ///
  /// In en, this message translates to:
  /// **'Import Fajr adhan from phone'**
  String get importFajr;

  /// No description provided for @importPhone.
  ///
  /// In en, this message translates to:
  /// **'Import from phone'**
  String get importPhone;

  /// No description provided for @stopPreview.
  ///
  /// In en, this message translates to:
  /// **'Stop preview'**
  String get stopPreview;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get deleteFile;

  /// No description provided for @importsReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read imported files'**
  String get importsReadError;

  /// No description provided for @previewError.
  ///
  /// In en, this message translates to:
  /// **'Could not play preview'**
  String get previewError;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Could not import file'**
  String get importError;

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get fileDeleted;

  /// No description provided for @fileDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete file'**
  String get fileDeleteError;

  /// No description provided for @testAdhanScheduled.
  ///
  /// In en, this message translates to:
  /// **'The test adhan will play in one minute; you can close the app'**
  String get testAdhanScheduled;

  /// No description provided for @testAdhanError.
  ///
  /// In en, this message translates to:
  /// **'Could not schedule the test'**
  String get testAdhanError;

  /// No description provided for @batterySettingsError.
  ///
  /// In en, this message translates to:
  /// **'Could not open settings'**
  String get batterySettingsError;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @north.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get north;

  /// No description provided for @east.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get east;

  /// No description provided for @south.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get south;

  /// No description provided for @west.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get west;

  /// No description provided for @northEast.
  ///
  /// In en, this message translates to:
  /// **'Northeast'**
  String get northEast;

  /// No description provided for @southEast.
  ///
  /// In en, this message translates to:
  /// **'Southeast'**
  String get southEast;

  /// No description provided for @southWest.
  ///
  /// In en, this message translates to:
  /// **'Southwest'**
  String get southWest;

  /// No description provided for @northWest.
  ///
  /// In en, this message translates to:
  /// **'Northwest'**
  String get northWest;

  /// No description provided for @qiblaCompass.
  ///
  /// In en, this message translates to:
  /// **'Qibla compass'**
  String get qiblaCompass;

  /// No description provided for @qiblaAngle.
  ///
  /// In en, this message translates to:
  /// **'Qibla bearing'**
  String get qiblaAngle;

  /// No description provided for @distanceToMakkah.
  ///
  /// In en, this message translates to:
  /// **'Distance to Makkah'**
  String get distanceToMakkah;

  /// No description provided for @fromTrueNorth.
  ///
  /// In en, this message translates to:
  /// **'from true north'**
  String get fromTrueNorth;

  /// No description provided for @straightToKaaba.
  ///
  /// In en, this message translates to:
  /// **'Straight line to the Kaaba'**
  String get straightToKaaba;

  /// No description provided for @noCompassSensor.
  ///
  /// In en, this message translates to:
  /// **'No compass sensor is available on this device'**
  String get noCompassSensor;

  /// No description provided for @readingCompass.
  ///
  /// In en, this message translates to:
  /// **'Reading the compass…'**
  String get readingCompass;

  /// No description provided for @holdPhoneLevel.
  ///
  /// In en, this message translates to:
  /// **'Hold the phone level and away from metal'**
  String get holdPhoneLevel;

  /// No description provided for @facingQibla.
  ///
  /// In en, this message translates to:
  /// **'You are facing the Qibla'**
  String get facingQibla;

  /// No description provided for @turnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get turnRight;

  /// No description provided for @turnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get turnLeft;

  /// No description provided for @noSensorAdvice.
  ///
  /// In en, this message translates to:
  /// **'The bearing is calculated from your location, but live direction requires a compass sensor.'**
  String get noSensorAdvice;

  /// No description provided for @calibrateCompass.
  ///
  /// In en, this message translates to:
  /// **'For better accuracy, move away from metal and magnets, and move your phone in a figure eight to calibrate the sensor.'**
  String get calibrateCompass;

  /// No description provided for @accuracyHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get accuracyHigh;

  /// No description provided for @accuracyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get accuracyMedium;

  /// No description provided for @accuracyLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get accuracyLow;

  /// No description provided for @ramadanTimetable.
  ///
  /// In en, this message translates to:
  /// **'Ramadan fasting timetable'**
  String get ramadanTimetable;

  /// No description provided for @ramadanOfflineOnly.
  ///
  /// In en, this message translates to:
  /// **'The offline fasting timetable is available only during Ramadan within the supported Hijri calendar range.'**
  String get ramadanOfflineOnly;

  /// No description provided for @imsakiyaTable.
  ///
  /// In en, this message translates to:
  /// **'Fasting timetable'**
  String get imsakiyaTable;

  /// No description provided for @imsakEstimate.
  ///
  /// In en, this message translates to:
  /// **'Imsak is an estimate: ten minutes before Fajr.'**
  String get imsakEstimate;

  /// No description provided for @oddNightHint.
  ///
  /// In en, this message translates to:
  /// **'Odd night of the last ten days (seek Laylat al-Qadr)'**
  String get oddNightHint;

  /// No description provided for @ramadanDuas.
  ///
  /// In en, this message translates to:
  /// **'Ramadan and fasting supplications'**
  String get ramadanDuas;

  /// No description provided for @ramadanDuasHint.
  ///
  /// In en, this message translates to:
  /// **'New moon, iftar, and Witr supplications…'**
  String get ramadanDuasHint;

  /// No description provided for @ramadanGreeting.
  ///
  /// In en, this message translates to:
  /// **'Ramadan Kareem'**
  String get ramadanGreeting;

  /// No description provided for @fastAccepted.
  ///
  /// In en, this message translates to:
  /// **'May Allah accept your fast'**
  String get fastAccepted;

  /// No description provided for @untilIftar.
  ///
  /// In en, this message translates to:
  /// **'Until iftar'**
  String get untilIftar;

  /// No description provided for @iftar.
  ///
  /// In en, this message translates to:
  /// **'Iftar'**
  String get iftar;

  /// No description provided for @tomorrowImsak.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s imsak'**
  String get tomorrowImsak;

  /// No description provided for @tomorrowFajr.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s Fajr'**
  String get tomorrowFajr;

  /// No description provided for @dailySunnahs.
  ///
  /// In en, this message translates to:
  /// **'Today\'s practices'**
  String get dailySunnahs;

  /// No description provided for @sunnahSuhoor.
  ///
  /// In en, this message translates to:
  /// **'Suhoor'**
  String get sunnahSuhoor;

  /// No description provided for @sunnahIftarDua.
  ///
  /// In en, this message translates to:
  /// **'Iftar supplication'**
  String get sunnahIftarDua;

  /// No description provided for @sunnahTaraweeh.
  ///
  /// In en, this message translates to:
  /// **'Taraweeh prayer'**
  String get sunnahTaraweeh;

  /// No description provided for @sunnahFeedFasting.
  ///
  /// In en, this message translates to:
  /// **'Feed a fasting person'**
  String get sunnahFeedFasting;

  /// No description provided for @periodFirst.
  ///
  /// In en, this message translates to:
  /// **'First ten days'**
  String get periodFirst;

  /// No description provided for @periodMiddle.
  ///
  /// In en, this message translates to:
  /// **'Middle ten days'**
  String get periodMiddle;

  /// No description provided for @periodLast.
  ///
  /// In en, this message translates to:
  /// **'Last ten days'**
  String get periodLast;

  /// No description provided for @periodAll.
  ///
  /// In en, this message translates to:
  /// **'Full month'**
  String get periodAll;

  /// No description provided for @imsak.
  ///
  /// In en, this message translates to:
  /// **'Imsak'**
  String get imsak;

  /// No description provided for @taraweeh.
  ///
  /// In en, this message translates to:
  /// **'Taraweeh'**
  String get taraweeh;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySun;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySat;

  /// No description provided for @prayerAfter.
  ///
  /// In en, this message translates to:
  /// **'{prayer} in {duration}'**
  String prayerAfter(String prayer, String duration);

  /// No description provided for @afterDuration.
  ///
  /// In en, this message translates to:
  /// **'In {duration}'**
  String afterDuration(String duration);

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min'**
  String hoursMinutes(String hours, String minutes);

  /// No description provided for @hoursOnly.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr'**
  String hoursOnly(String hours);

  /// No description provided for @minutesOnly.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesOnly(String minutes);

  /// No description provided for @timingMethod.
  ///
  /// In en, this message translates to:
  /// **'Method: {method}'**
  String timingMethod(String method);

  /// No description provided for @prayerAlertMode.
  ///
  /// In en, this message translates to:
  /// **'{prayer} alert: {mode}'**
  String prayerAlertMode(String prayer, String mode);

  /// No description provided for @qiblaSummary.
  ///
  /// In en, this message translates to:
  /// **'{distance} km to Makkah • {bearing}° {direction}'**
  String qiblaSummary(String distance, String bearing, String direction);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String distanceKm(String distance);

  /// No description provided for @bearingFromNorth.
  ///
  /// In en, this message translates to:
  /// **'{bearing}° from true north; use another compass'**
  String bearingFromNorth(String bearing);

  /// No description provided for @headingDeviation.
  ///
  /// In en, this message translates to:
  /// **'Heading {heading}° • deviation {deviation}°'**
  String headingDeviation(String heading, String deviation);

  /// No description provided for @sensorAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Sensor accuracy: {level} (±{degrees}°). If low, move your phone in a figure eight to calibrate it.'**
  String sensorAccuracy(String level, String degrees);

  /// No description provided for @importedSound.
  ///
  /// In en, this message translates to:
  /// **'Imported ‘{name}’ and selected it'**
  String importedSound(String name);

  /// No description provided for @confirmDeleteSound.
  ///
  /// In en, this message translates to:
  /// **'Delete ‘{name}’ from the app?'**
  String confirmDeleteSound(String name);

  /// No description provided for @ramadanDayYear.
  ///
  /// In en, this message translates to:
  /// **'{day} Ramadan {year} AH'**
  String ramadanDayYear(String day, String year);

  /// No description provided for @ramadanYear.
  ///
  /// In en, this message translates to:
  /// **'Ramadan {year} AH'**
  String ramadanYear(String year);

  /// No description provided for @daysToEid.
  ///
  /// In en, this message translates to:
  /// **'{days} days until Eid al-Fitr'**
  String daysToEid(String days);

  /// No description provided for @ramadanStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in {days} days — {date}'**
  String ramadanStartsIn(String days, String date);

  /// No description provided for @ramadanStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String ramadanStarts(String date);

  /// No description provided for @checklistProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String checklistProgress(String done, String total);

  /// No description provided for @trackerPrayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer and make-up tracker'**
  String get trackerPrayerTitle;

  /// No description provided for @trackerImportJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get trackerImportJson;

  /// No description provided for @trackerExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get trackerExportJson;

  /// No description provided for @trackerPasteBackup.
  ///
  /// In en, this message translates to:
  /// **'Paste backup here'**
  String get trackerPasteBackup;

  /// No description provided for @trackerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get trackerCancel;

  /// No description provided for @trackerImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get trackerImport;

  /// No description provided for @trackerInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON file'**
  String get trackerInvalidJson;

  /// No description provided for @trackerInvalidPrayerData.
  ///
  /// In en, this message translates to:
  /// **'Invalid prayer data'**
  String get trackerInvalidPrayerData;

  /// No description provided for @trackerUnrecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get trackerUnrecorded;

  /// No description provided for @trackerClear.
  ///
  /// In en, this message translates to:
  /// **'Clear record'**
  String get trackerClear;

  /// No description provided for @trackerQadaHelp.
  ///
  /// In en, this message translates to:
  /// **'Make-up prayers — adjust manually after completion'**
  String get trackerQadaHelp;

  /// No description provided for @trackerOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get trackerOnTime;

  /// No description provided for @trackerCongregation.
  ///
  /// In en, this message translates to:
  /// **'In congregation'**
  String get trackerCongregation;

  /// No description provided for @trackerLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get trackerLate;

  /// No description provided for @trackerMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get trackerMissed;

  /// No description provided for @trackerToday.
  ///
  /// In en, this message translates to:
  /// **'Record today\'s prayer'**
  String get trackerToday;

  /// No description provided for @trackerFastingTitle.
  ///
  /// In en, this message translates to:
  /// **'Fasting tracker'**
  String get trackerFastingTitle;

  /// No description provided for @trackerFastingType.
  ///
  /// In en, this message translates to:
  /// **'Type of fast'**
  String get trackerFastingType;

  /// No description provided for @trackerNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get trackerNotes;

  /// No description provided for @trackerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get trackerDelete;

  /// No description provided for @trackerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get trackerSave;

  /// No description provided for @trackerManualFast.
  ///
  /// In en, this message translates to:
  /// **'Record manually; no day is marked as fasted automatically.'**
  String get trackerManualFast;

  /// No description provided for @trackerNoFast.
  ///
  /// In en, this message translates to:
  /// **'No fast recorded'**
  String get trackerNoFast;

  /// No description provided for @trackerRamadanQada.
  ///
  /// In en, this message translates to:
  /// **'Ramadan make-up (separate counter)'**
  String get trackerRamadanQada;

  /// No description provided for @trackerFastingNotice.
  ///
  /// In en, this message translates to:
  /// **'Monday, Thursday and white-day reminders are managed in existing notification settings; no extra reminders are created here.'**
  String get trackerFastingNotice;

  /// No description provided for @trackerFastRamadan.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get trackerFastRamadan;

  /// No description provided for @trackerFastQada.
  ///
  /// In en, this message translates to:
  /// **'Make-up fast'**
  String get trackerFastQada;

  /// No description provided for @trackerFastMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get trackerFastMonday;

  /// No description provided for @trackerFastThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get trackerFastThursday;

  /// No description provided for @trackerFastWhiteDays.
  ///
  /// In en, this message translates to:
  /// **'White days'**
  String get trackerFastWhiteDays;

  /// No description provided for @trackerFastArafah.
  ///
  /// In en, this message translates to:
  /// **'Arafah'**
  String get trackerFastArafah;

  /// No description provided for @trackerFastAshura.
  ///
  /// In en, this message translates to:
  /// **'Ashura'**
  String get trackerFastAshura;

  /// No description provided for @trackerFastShawwal.
  ///
  /// In en, this message translates to:
  /// **'Six days of Shawwal'**
  String get trackerFastShawwal;

  /// No description provided for @trackerFastOther.
  ///
  /// In en, this message translates to:
  /// **'Voluntary'**
  String get trackerFastOther;

  /// No description provided for @trackerZakatTitle.
  ///
  /// In en, this message translates to:
  /// **'Zakat calculator'**
  String get trackerZakatTitle;

  /// No description provided for @trackerCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get trackerCash;

  /// No description provided for @trackerGoldGrams.
  ///
  /// In en, this message translates to:
  /// **'Gold (grams)'**
  String get trackerGoldGrams;

  /// No description provided for @trackerGoldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price per gram of pure (24k) gold'**
  String get trackerGoldPrice;

  /// No description provided for @trackerSilverGrams.
  ///
  /// In en, this message translates to:
  /// **'Silver (grams)'**
  String get trackerSilverGrams;

  /// No description provided for @trackerSilverPrice.
  ///
  /// In en, this message translates to:
  /// **'Silver price per gram'**
  String get trackerSilverPrice;

  /// No description provided for @trackerInventory.
  ///
  /// In en, this message translates to:
  /// **'Trade inventory'**
  String get trackerInventory;

  /// No description provided for @trackerReceivables.
  ///
  /// In en, this message translates to:
  /// **'Collectible debts'**
  String get trackerReceivables;

  /// No description provided for @trackerCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Use one currency for all amounts and prices; enter the price per gram in your currency.'**
  String get trackerCurrencyHint;

  /// No description provided for @trackerGoldNisab.
  ///
  /// In en, this message translates to:
  /// **'Gold nisab'**
  String get trackerGoldNisab;

  /// No description provided for @trackerSilverNisab.
  ///
  /// In en, this message translates to:
  /// **'Silver nisab'**
  String get trackerSilverNisab;

  /// No description provided for @trackerGoldValue.
  ///
  /// In en, this message translates to:
  /// **'Gold value'**
  String get trackerGoldValue;

  /// No description provided for @trackerSilverValue.
  ///
  /// In en, this message translates to:
  /// **'Silver value'**
  String get trackerSilverValue;

  /// No description provided for @trackerTotalAssets.
  ///
  /// In en, this message translates to:
  /// **'Total entered assets'**
  String get trackerTotalAssets;

  /// No description provided for @trackerNisab.
  ///
  /// In en, this message translates to:
  /// **'Nisab'**
  String get trackerNisab;

  /// No description provided for @trackerEstimatedZakat.
  ///
  /// In en, this message translates to:
  /// **'Estimated zakat (2.5%)'**
  String get trackerEstimatedZakat;

  /// No description provided for @trackerCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Hijri calendar and occasions'**
  String get trackerCalendarTitle;

  /// No description provided for @trackerCalendarNotice.
  ///
  /// In en, this message translates to:
  /// **'Dates are calculated using the Umm al-Qura calendar and may differ according to moon sighting in your country. Monday, Thursday and white-day reminders are in notification settings.'**
  String get trackerCalendarNotice;

  /// No description provided for @trackerSunShort.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get trackerSunShort;

  /// No description provided for @trackerMonShort.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get trackerMonShort;

  /// No description provided for @trackerTueShort.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get trackerTueShort;

  /// No description provided for @trackerWedShort.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get trackerWedShort;

  /// No description provided for @trackerThuShort.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get trackerThuShort;

  /// No description provided for @trackerFriShort.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get trackerFriShort;

  /// No description provided for @trackerSatShort.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get trackerSatShort;

  /// No description provided for @trackerGregorianShort.
  ///
  /// In en, this message translates to:
  /// **'CE'**
  String get trackerGregorianShort;

  /// No description provided for @trackerHijriShort.
  ///
  /// In en, this message translates to:
  /// **'AH'**
  String get trackerHijriShort;

  /// No description provided for @hadithLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Hadith library'**
  String get hadithLibraryTitle;

  /// No description provided for @hadithAllBooks.
  ///
  /// In en, this message translates to:
  /// **'All books'**
  String get hadithAllBooks;

  /// No description provided for @hadithSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search hadith texts...'**
  String get hadithSearchHint;

  /// No description provided for @hadithResults.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get hadithResults;

  /// No description provided for @hadithNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching hadith found'**
  String get hadithNoMatches;

  /// No description provided for @hadithLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get hadithLoadMore;

  /// No description provided for @hadithOfDay.
  ///
  /// In en, this message translates to:
  /// **'Hadith of the day'**
  String get hadithOfDay;

  /// No description provided for @hadithUnit.
  ///
  /// In en, this message translates to:
  /// **'hadith'**
  String get hadithUnit;

  /// No description provided for @hadithDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download book?'**
  String get hadithDownloadTitle;

  /// No description provided for @hadithDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get hadithDownload;

  /// No description provided for @hadithDeleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get hadithDeleteDownload;

  /// No description provided for @hadithDownloadBook.
  ///
  /// In en, this message translates to:
  /// **'Download book'**
  String get hadithDownloadBook;

  /// No description provided for @hadithNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded • requires an internet download'**
  String get hadithNotDownloaded;

  /// No description provided for @hadithMissingBook.
  ///
  /// In en, this message translates to:
  /// **'This book is not downloaded. Connect to the internet and configure API_BASE to download it.'**
  String get hadithMissingBook;

  /// No description provided for @hadithChapterSearch.
  ///
  /// In en, this message translates to:
  /// **'Search chapters...'**
  String get hadithChapterSearch;

  /// No description provided for @hadithShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all hadith in order'**
  String get hadithShowAll;

  /// No description provided for @hadithNoChapters.
  ///
  /// In en, this message translates to:
  /// **'No matching chapters'**
  String get hadithNoChapters;

  /// No description provided for @hadithNoItems.
  ///
  /// In en, this message translates to:
  /// **'No hadith'**
  String get hadithNoItems;

  /// No description provided for @hadithUnknownGrade.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get hadithUnknownGrade;

  /// No description provided for @hadithGradeNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Grade not specified by the source — verify via Dorar'**
  String get hadithGradeNotSpecified;

  /// No description provided for @hadithEnglishTranslation.
  ///
  /// In en, this message translates to:
  /// **'English translation'**
  String get hadithEnglishTranslation;

  /// No description provided for @hadithCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get hadithCopy;

  /// No description provided for @hadithShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get hadithShare;

  /// No description provided for @hadithVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify on Dorar'**
  String get hadithVerify;

  /// No description provided for @hadithViewSunnah.
  ///
  /// In en, this message translates to:
  /// **'View on sunnah.com'**
  String get hadithViewSunnah;

  /// No description provided for @hadithDedicate.
  ///
  /// In en, this message translates to:
  /// **'Dedicate the reward of reading'**
  String get hadithDedicate;

  /// No description provided for @hadithReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get hadithReadMore;

  /// No description provided for @hadithShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get hadithShowLess;

  /// No description provided for @hadithLinkError.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get hadithLinkError;

  /// No description provided for @hadithCopied.
  ///
  /// In en, this message translates to:
  /// **'Hadith copied'**
  String get hadithCopied;

  /// No description provided for @hadithMinimumQuery.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two characters'**
  String get hadithMinimumQuery;

  /// No description provided for @trackerRecordPrayer.
  ///
  /// In en, this message translates to:
  /// **'Record {prayer}'**
  String trackerRecordPrayer(String prayer);

  /// No description provided for @trackerRecordedPrayer.
  ///
  /// In en, this message translates to:
  /// **'Recorded {prayer}: {status}'**
  String trackerRecordedPrayer(String prayer, String status);

  /// No description provided for @trackerRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {count}'**
  String trackerRemaining(String count);

  /// No description provided for @trackerDecreaseQada.
  ///
  /// In en, this message translates to:
  /// **'Decrease make-up {prayer}'**
  String trackerDecreaseQada(String prayer);

  /// No description provided for @trackerIncreaseQada.
  ///
  /// In en, this message translates to:
  /// **'Increase make-up {prayer}'**
  String trackerIncreaseQada(String prayer);

  /// No description provided for @trackerMissedCount.
  ///
  /// In en, this message translates to:
  /// **'Recorded missed prayers: {count}'**
  String trackerMissedCount(String count);

  /// No description provided for @trackerThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week: {summary}'**
  String trackerThisWeek(String summary);

  /// No description provided for @trackerThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month: {summary}'**
  String trackerThisMonth(String summary);

  /// No description provided for @trackerFastingDay.
  ///
  /// In en, this message translates to:
  /// **'Fast on {date}'**
  String trackerFastingDay(String date);

  /// No description provided for @trackerYearSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary for {year} CE'**
  String trackerYearSummary(String year);

  /// No description provided for @trackerNextPrayer.
  ///
  /// In en, this message translates to:
  /// **'Next prayer: {prayer}'**
  String trackerNextPrayer(String prayer);

  /// No description provided for @trackerLocalTime.
  ///
  /// In en, this message translates to:
  /// **'Local time: {time}'**
  String trackerLocalTime(String time);

  /// No description provided for @hadithResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String hadithResultCount(String count);

  /// No description provided for @hadithCount.
  ///
  /// In en, this message translates to:
  /// **'{count} hadith'**
  String hadithCount(String count);

  /// No description provided for @hadithChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters ({count})'**
  String hadithChapters(String count);

  /// No description provided for @hadithNumber.
  ///
  /// In en, this message translates to:
  /// **'No. {number}'**
  String hadithNumber(String number);

  /// No description provided for @hadithGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade: {grade}'**
  String hadithGrade(String grade);

  /// No description provided for @hadithDownloadPrompt.
  ///
  /// In en, this message translates to:
  /// **'{book} will be saved on your device for offline reading and search. The book may be several megabytes; an internet connection is required.'**
  String hadithDownloadPrompt(String book);

  /// No description provided for @hadithDownloadError.
  ///
  /// In en, this message translates to:
  /// **'Could not download: {error}'**
  String hadithDownloadError(String error);

  /// No description provided for @hadithDownloadedSize.
  ///
  /// In en, this message translates to:
  /// **'Downloaded • {size} MB'**
  String hadithDownloadedSize(String size);

  /// No description provided for @occasionRamadanBegins.
  ///
  /// In en, this message translates to:
  /// **'Start of Ramadan'**
  String get occasionRamadanBegins;

  /// No description provided for @occasionEidAlFitr.
  ///
  /// In en, this message translates to:
  /// **'Eid al-Fitr'**
  String get occasionEidAlFitr;

  /// No description provided for @occasionArafah.
  ///
  /// In en, this message translates to:
  /// **'Day of Arafah'**
  String get occasionArafah;

  /// No description provided for @occasionEidAlAdha.
  ///
  /// In en, this message translates to:
  /// **'Eid al-Adha'**
  String get occasionEidAlAdha;

  /// No description provided for @occasionAshura.
  ///
  /// In en, this message translates to:
  /// **'Ashura'**
  String get occasionAshura;

  /// No description provided for @occasionWhiteDays.
  ///
  /// In en, this message translates to:
  /// **'White days'**
  String get occasionWhiteDays;

  /// No description provided for @occasionMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get occasionMonday;

  /// No description provided for @occasionThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get occasionThursday;

  /// No description provided for @hadithNineBooks.
  ///
  /// In en, this message translates to:
  /// **'The Nine Books'**
  String get hadithNineBooks;

  /// No description provided for @hadithForties.
  ///
  /// In en, this message translates to:
  /// **'Forty Hadith collections'**
  String get hadithForties;

  /// No description provided for @hadithOtherBooks.
  ///
  /// In en, this message translates to:
  /// **'Other books'**
  String get hadithOtherBooks;

  /// No description provided for @tasbeehResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset counter'**
  String get tasbeehResetTitle;

  /// No description provided for @tasbeehResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete today\'s counts for “{dhikr}”?'**
  String tasbeehResetConfirm(String dhikr);

  /// No description provided for @tasbeehReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get tasbeehReset;

  /// No description provided for @tasbeehAdd.
  ///
  /// In en, this message translates to:
  /// **'Add remembrance'**
  String get tasbeehAdd;

  /// No description provided for @tasbeehEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit remembrance'**
  String get tasbeehEdit;

  /// No description provided for @tasbeehText.
  ///
  /// In en, this message translates to:
  /// **'Remembrance text'**
  String get tasbeehText;

  /// No description provided for @tasbeehTargetInput.
  ///
  /// In en, this message translates to:
  /// **'Target (repetitions)'**
  String get tasbeehTargetInput;

  /// No description provided for @tasbeehEditTarget.
  ///
  /// In en, this message translates to:
  /// **'Edit remembrance and target'**
  String get tasbeehEditTarget;

  /// No description provided for @tasbeehDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete remembrance from list'**
  String get tasbeehDelete;

  /// No description provided for @tasbeehChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a remembrance'**
  String get tasbeehChoose;

  /// No description provided for @tasbeehRoundRemaining.
  ///
  /// In en, this message translates to:
  /// **'Round {round} • {remaining} remaining'**
  String tasbeehRoundRemaining(String round, String remaining);

  /// No description provided for @tasbeehCountSemantics.
  ///
  /// In en, this message translates to:
  /// **'Count a remembrance, current count {count}'**
  String tasbeehCountSemantics(String count);

  /// No description provided for @tasbeehCurrentCount.
  ///
  /// In en, this message translates to:
  /// **'Current count'**
  String get tasbeehCurrentCount;

  /// No description provided for @tasbeehTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to count'**
  String get tasbeehTap;

  /// No description provided for @tasbeehToday.
  ///
  /// In en, this message translates to:
  /// **'Today: {count}'**
  String tasbeehToday(String count);

  /// No description provided for @tasbeehVibrationOn.
  ///
  /// In en, this message translates to:
  /// **'Vibration on'**
  String get tasbeehVibrationOn;

  /// No description provided for @tasbeehVibrationOff.
  ///
  /// In en, this message translates to:
  /// **'Vibration off'**
  String get tasbeehVibrationOff;

  /// No description provided for @tasbeehSoundOn.
  ///
  /// In en, this message translates to:
  /// **'Sound on'**
  String get tasbeehSoundOn;

  /// No description provided for @tasbeehSoundOff.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get tasbeehSoundOff;

  /// No description provided for @tasbeehDhikrProgress.
  ///
  /// In en, this message translates to:
  /// **'Target: {target} times • today {count}'**
  String tasbeehDhikrProgress(String target, String count);

  /// No description provided for @tasbeehDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get tasbeehDailyGoal;

  /// No description provided for @tasbeehGoalProgress.
  ///
  /// In en, this message translates to:
  /// **'{total} of {goal} counts'**
  String tasbeehGoalProgress(String total, String goal);

  /// No description provided for @tasbeehPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String tasbeehPercent(String percent);

  /// No description provided for @tasbeehThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week\'s progress'**
  String get tasbeehThisWeek;

  /// No description provided for @tasbeehStreak.
  ///
  /// In en, this message translates to:
  /// **'🔥 {days} consecutive days'**
  String tasbeehStreak(String days);

  /// No description provided for @tasbeehMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get tasbeehMon;

  /// No description provided for @tasbeehTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tasbeehTue;

  /// No description provided for @tasbeehWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get tasbeehWed;

  /// No description provided for @tasbeehThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get tasbeehThu;

  /// No description provided for @tasbeehFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get tasbeehFri;

  /// No description provided for @tasbeehSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get tasbeehSat;

  /// No description provided for @tasbeehSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get tasbeehSun;

  /// No description provided for @tasbeehCharity.
  ///
  /// In en, this message translates to:
  /// **'Ongoing charity and supplication'**
  String get tasbeehCharity;

  /// No description provided for @tasbeehDedication.
  ///
  /// In en, this message translates to:
  /// **'Dedicate the reward of tasbeeh to a parent'**
  String get tasbeehDedication;

  /// No description provided for @tasbeehDedicateAction.
  ///
  /// In en, this message translates to:
  /// **'Dedicate the reward of tasbeeh to my parent'**
  String get tasbeehDedicateAction;

  /// No description provided for @tasbeehCountFirst.
  ///
  /// In en, this message translates to:
  /// **'Count a remembrance before dedicating its reward'**
  String get tasbeehCountFirst;

  /// No description provided for @tasbeehRoundComplete.
  ///
  /// In en, this message translates to:
  /// **'You completed a round ({target}) — بارك الله فيك'**
  String tasbeehRoundComplete(String target);

  /// No description provided for @athkarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Arabic remembrance and supplication text...'**
  String get athkarSearchHint;

  /// No description provided for @athkarNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String athkarNoResults(String query);

  /// No description provided for @athkarRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat: {count}'**
  String athkarRepeat(String count);

  /// No description provided for @athkarAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get athkarAll;

  /// No description provided for @athkarChapters.
  ///
  /// In en, this message translates to:
  /// **'Remembrance categories'**
  String get athkarChapters;

  /// No description provided for @athkarAllChapters.
  ///
  /// In en, this message translates to:
  /// **'All remembrances'**
  String get athkarAllChapters;

  /// No description provided for @athkarCategoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String athkarCategoryCount(String count);

  /// No description provided for @athkarOtherCount.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String athkarOtherCount(String count);

  /// No description provided for @athkarDailyWird.
  ///
  /// In en, this message translates to:
  /// **'Daily reading'**
  String get athkarDailyWird;

  /// No description provided for @athkarActiveWird.
  ///
  /// In en, this message translates to:
  /// **'Active daily reading'**
  String get athkarActiveWird;

  /// No description provided for @athkarDailyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed {done} of {total} remembrances today'**
  String athkarDailyCompleted(String done, String total);

  /// No description provided for @athkarStart.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get athkarStart;

  /// No description provided for @athkarContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get athkarContinue;

  /// No description provided for @athkarPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String athkarPercent(String percent);

  /// No description provided for @athkarComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get athkarComplete;

  /// No description provided for @athkarPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially complete • {done}/{total}'**
  String athkarPartial(String done, String total);

  /// No description provided for @athkarNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get athkarNotStarted;

  /// No description provided for @athkarEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} remembrances and supplications'**
  String athkarEntryCount(String count);

  /// No description provided for @athkarEmpty.
  ///
  /// In en, this message translates to:
  /// **'No remembrances in this category'**
  String get athkarEmpty;

  /// No description provided for @athkarPosition.
  ///
  /// In en, this message translates to:
  /// **'Remembrance {current} of {total}'**
  String athkarPosition(String current, String total);

  /// No description provided for @athkarFinished.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get athkarFinished;

  /// No description provided for @athkarCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'Completed {done} of {total}'**
  String athkarCompletedCount(String done, String total);

  /// No description provided for @athkarVirtue.
  ///
  /// In en, this message translates to:
  /// **'Virtue:'**
  String get athkarVirtue;

  /// No description provided for @athkarTapNext.
  ///
  /// In en, this message translates to:
  /// **'Done ✓ — Next'**
  String get athkarTapNext;

  /// No description provided for @athkarTapCount.
  ///
  /// In en, this message translates to:
  /// **'Tap to count'**
  String get athkarTapCount;

  /// No description provided for @athkarLongPress.
  ///
  /// In en, this message translates to:
  /// **'Long-press to reset count'**
  String get athkarLongPress;

  /// No description provided for @athkarAccepted.
  ///
  /// In en, this message translates to:
  /// **'تقبّل الله منك'**
  String get athkarAccepted;

  /// No description provided for @athkarRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remembrances remaining'**
  String athkarRemaining(String count);

  /// No description provided for @athkarFinishedToday.
  ///
  /// In en, this message translates to:
  /// **'Completed {category} for today'**
  String athkarFinishedToday(String category);

  /// No description provided for @athkarReturnToFinish.
  ///
  /// In en, this message translates to:
  /// **'Go back to finish the remaining remembrances'**
  String get athkarReturnToFinish;

  /// No description provided for @athkarDedicate.
  ///
  /// In en, this message translates to:
  /// **'Dedicate the reward to my parent'**
  String get athkarDedicate;

  /// No description provided for @athkarFinishRemaining.
  ///
  /// In en, this message translates to:
  /// **'Finish remaining remembrances'**
  String get athkarFinishRemaining;

  /// No description provided for @athkarBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get athkarBack;

  /// No description provided for @athkarCopied.
  ///
  /// In en, this message translates to:
  /// **'Remembrance copied'**
  String get athkarCopied;

  /// No description provided for @duaTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer for a parent'**
  String get duaTitle;

  /// No description provided for @duaCollections.
  ///
  /// In en, this message translates to:
  /// **'Supplication collections'**
  String get duaCollections;

  /// No description provided for @duaCharity.
  ///
  /// In en, this message translates to:
  /// **'Ongoing prayer and charity'**
  String get duaCharity;

  /// No description provided for @duaMercy.
  ///
  /// In en, this message translates to:
  /// **'رحم الله والدي'**
  String get duaMercy;

  /// No description provided for @duaGlobalDedications.
  ///
  /// In en, this message translates to:
  /// **'{count} dedications from Fadl users'**
  String duaGlobalDedications(String count);

  /// No description provided for @duaLocalDedications.
  ///
  /// In en, this message translates to:
  /// **'{count} dedications recorded on this device'**
  String duaLocalDedications(String count);

  /// No description provided for @duaFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured supplication for the deceased'**
  String get duaFeatured;

  /// No description provided for @duaDedicate.
  ///
  /// In en, this message translates to:
  /// **'Dedicate this prayer to my parent'**
  String get duaDedicate;

  /// No description provided for @duaVerseLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplication from the Quran'**
  String get duaVerseLabel;

  /// No description provided for @duaTraditionLabel.
  ///
  /// In en, this message translates to:
  /// **'Traditional supplication'**
  String get duaTraditionLabel;

  /// No description provided for @duaVirtue.
  ///
  /// In en, this message translates to:
  /// **'Virtue: {virtue}'**
  String duaVirtue(String virtue);

  /// No description provided for @duaAmenCount.
  ///
  /// In en, this message translates to:
  /// **'Amen {count}'**
  String duaAmenCount(String count);

  /// No description provided for @duaReadCount.
  ///
  /// In en, this message translates to:
  /// **'Read {done}/{total}'**
  String duaReadCount(String done, String total);

  /// No description provided for @duaDedicateParent.
  ///
  /// In en, this message translates to:
  /// **'Dedicate reward to my parent'**
  String get duaDedicateParent;

  /// No description provided for @duaStats.
  ///
  /// In en, this message translates to:
  /// **'Dedication history'**
  String get duaStats;

  /// No description provided for @duaDedicationCount.
  ///
  /// In en, this message translates to:
  /// **'{count} dedications'**
  String duaDedicationCount(String count);

  /// No description provided for @duaKhatmaStat.
  ///
  /// In en, this message translates to:
  /// **'Reading plans dedicated'**
  String get duaKhatmaStat;

  /// No description provided for @duaTasbeehStat.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh counts dedicated'**
  String get duaTasbeehStat;

  /// No description provided for @duaPrayerStat.
  ///
  /// In en, this message translates to:
  /// **'Prayers dedicated'**
  String get duaPrayerStat;

  /// No description provided for @duaReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder of times for supplication'**
  String get duaReminder;

  /// No description provided for @duaReminderDescription.
  ///
  /// In en, this message translates to:
  /// **'بين الأذان والإقامة، الثلث الأخير من الليل، وساعة الجمعة — أكثر فيها من الدعاء لوالدك'**
  String get duaReminderDescription;

  /// No description provided for @duaReminderOn.
  ///
  /// In en, this message translates to:
  /// **'Reminders enabled'**
  String get duaReminderOn;

  /// No description provided for @duaReminderOff.
  ///
  /// In en, this message translates to:
  /// **'Reminders disabled'**
  String get duaReminderOff;

  /// No description provided for @duaPersonalTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a personal prayer for your parent'**
  String get duaPersonalTitle;

  /// No description provided for @duaPersonalDescription.
  ///
  /// In en, this message translates to:
  /// **'Write a prayer to save and dedicate its reward to your parent'**
  String get duaPersonalDescription;

  /// No description provided for @duaPersonalHint.
  ///
  /// In en, this message translates to:
  /// **'Write your own prayer...'**
  String get duaPersonalHint;

  /// No description provided for @duaSaveDedicate.
  ///
  /// In en, this message translates to:
  /// **'Save prayer and dedicate reward'**
  String get duaSaveDedicate;

  /// No description provided for @duaSaved.
  ///
  /// In en, this message translates to:
  /// **'My saved prayers'**
  String get duaSaved;

  /// No description provided for @duaEnterFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your prayer first'**
  String get duaEnterFirst;

  /// No description provided for @duaAmenConfirmed.
  ///
  /// In en, this message translates to:
  /// **'آمين، تقبّل الله'**
  String get duaAmenConfirmed;

  /// No description provided for @duaAmenAlready.
  ///
  /// In en, this message translates to:
  /// **'You already said Amen to this prayer today'**
  String get duaAmenAlready;

  /// No description provided for @duaCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get duaCopied;

  /// No description provided for @duaDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get duaDelete;

  /// No description provided for @athkarDedicationRecorded.
  ///
  /// In en, this message translates to:
  /// **'Reward dedicated to {name} 🤍'**
  String athkarDedicationRecorded(String name);

  /// No description provided for @librarySaved.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get librarySaved;

  /// No description provided for @libraryDownloadTab.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get libraryDownloadTab;

  /// No description provided for @librarySearch.
  ///
  /// In en, this message translates to:
  /// **'Search the library'**
  String get librarySearch;

  /// No description provided for @libraryCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get libraryCheckUpdates;

  /// No description provided for @libraryTafsir.
  ///
  /// In en, this message translates to:
  /// **'Tafsir'**
  String get libraryTafsir;

  /// No description provided for @libraryTajweed.
  ///
  /// In en, this message translates to:
  /// **'Color-coded Tajweed text'**
  String get libraryTajweed;

  /// No description provided for @libraryHadithBooks.
  ///
  /// In en, this message translates to:
  /// **'Hadith books'**
  String get libraryHadithBooks;

  /// No description provided for @libraryRecitations.
  ///
  /// In en, this message translates to:
  /// **'Recitations'**
  String get libraryRecitations;

  /// No description provided for @libraryUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates available'**
  String get libraryUpdates;

  /// No description provided for @libraryUpdateAll.
  ///
  /// In en, this message translates to:
  /// **'Update all'**
  String get libraryUpdateAll;

  /// No description provided for @libraryReciterCatalog.
  ///
  /// In en, this message translates to:
  /// **'Reciter recordings'**
  String get libraryReciterCatalog;

  /// No description provided for @libraryChooseReciter.
  ///
  /// In en, this message translates to:
  /// **'Choose a reciter and surah to download'**
  String get libraryChooseReciter;

  /// No description provided for @libraryUsedSpace.
  ///
  /// In en, this message translates to:
  /// **'Space used: {size}'**
  String libraryUsedSpace(String size);

  /// No description provided for @libraryApproxSize.
  ///
  /// In en, this message translates to:
  /// **'Approx. download size: {size}'**
  String libraryApproxSize(String size);

  /// No description provided for @libraryUnknownUpdate.
  ///
  /// In en, this message translates to:
  /// **'Updates cannot be checked for this source, or no previous download record exists'**
  String get libraryUnknownUpdate;

  /// No description provided for @libraryCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check {title} for updates. Check your internet connection.'**
  String libraryCheckFailed(String title);

  /// No description provided for @libraryDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {title}'**
  String libraryDownloaded(String title);

  /// No description provided for @libraryDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check your internet connection and try again.'**
  String get libraryDownloadFailed;

  /// No description provided for @libraryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}?'**
  String libraryDeleteConfirm(String title);

  /// No description provided for @libraryRedownloadNotice.
  ///
  /// In en, this message translates to:
  /// **'You can download it again when you have internet access.'**
  String get libraryRedownloadNotice;

  /// No description provided for @libraryDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete {title}'**
  String libraryDeleteFailed(String title);

  /// No description provided for @libraryAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About: {title}'**
  String libraryAboutTitle(String title);

  /// No description provided for @librarySourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String librarySourceLabel(String source);

  /// No description provided for @libraryAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get libraryAbout;

  /// No description provided for @libraryClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get libraryClose;

  /// No description provided for @libraryCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get libraryCancel;

  /// No description provided for @libraryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get libraryDelete;

  /// No description provided for @libraryDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get libraryDownloading;

  /// No description provided for @libraryUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get libraryUpdate;

  /// No description provided for @libraryRedownload.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get libraryRedownload;

  /// No description provided for @libraryDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get libraryDownload;

  /// No description provided for @libraryReceived.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {size}'**
  String libraryReceived(String size);

  /// No description provided for @libraryReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the library'**
  String get libraryReadError;

  /// No description provided for @downloadsUsedSpace.
  ///
  /// In en, this message translates to:
  /// **'Space used'**
  String get downloadsUsedSpace;

  /// No description provided for @downloadsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get downloadsDeleteAll;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recitations downloaded yet.\nDownload surahs from the audio library to listen offline.'**
  String get downloadsEmpty;

  /// No description provided for @downloadsReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load downloads'**
  String get downloadsReadError;

  /// No description provided for @downloadsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete downloads'**
  String get downloadsDeleteTitle;

  /// No description provided for @downloadsDeleteReciterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}\'s recitations from this device?'**
  String downloadsDeleteReciterConfirm(String name);

  /// No description provided for @downloadsDeletedReciter.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}\'s recitations'**
  String downloadsDeletedReciter(String name);

  /// No description provided for @downloadsDeleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloads'**
  String get downloadsDeleteAllTitle;

  /// No description provided for @downloadsDeleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'All downloaded recitations will be deleted. You cannot listen offline until you download them again.'**
  String get downloadsDeleteAllConfirm;

  /// No description provided for @downloadsDeletedAll.
  ///
  /// In en, this message translates to:
  /// **'All downloads deleted'**
  String get downloadsDeletedAll;

  /// No description provided for @downloadsCompleteSurahs.
  ///
  /// In en, this message translates to:
  /// **'{count} complete surahs'**
  String downloadsCompleteSurahs(String count);

  /// No description provided for @downloadsDeleteReciterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete reciter recordings'**
  String get downloadsDeleteReciterTooltip;

  /// No description provided for @quranReviewReminder.
  ///
  /// In en, this message translates to:
  /// **'Quran review reminder'**
  String get quranReviewReminder;

  /// No description provided for @quranReviewReminderHint.
  ///
  /// In en, this message translates to:
  /// **'Only on days with memorized pages due for review'**
  String get quranReviewReminderHint;

  /// No description provided for @quranReviewNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran review'**
  String get quranReviewNotificationTitle;

  /// No description provided for @quranReviewNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 memorized page is due for review today} other{{number} memorized pages are due for review today}}'**
  String quranReviewNotificationBody(int count, String number);

  /// No description provided for @a11yPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get a11yPreviousDay;

  /// No description provided for @a11yNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get a11yNextDay;

  /// No description provided for @a11yPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get a11yPreviousMonth;

  /// No description provided for @a11yNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get a11yNextMonth;

  /// No description provided for @a11yQadaDecrease.
  ///
  /// In en, this message translates to:
  /// **'Remove one makeup day'**
  String get a11yQadaDecrease;

  /// No description provided for @a11yQadaIncrease.
  ///
  /// In en, this message translates to:
  /// **'Add one makeup day'**
  String get a11yQadaIncrease;

  /// No description provided for @a11ySearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get a11ySearch;

  /// No description provided for @a11ySendQuestion.
  ///
  /// In en, this message translates to:
  /// **'Send question'**
  String get a11ySendQuestion;

  /// No description provided for @a11yClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get a11yClear;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// No description provided for @offlineFeatureMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature needs a connection to the Fadl service and will be available soon. The mushaf, recitations and memorization work offline.'**
  String get offlineFeatureMessage;

  /// No description provided for @dedicateRewardAction.
  ///
  /// In en, this message translates to:
  /// **'Dedicate the reward'**
  String get dedicateRewardAction;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(String error);

  /// No description provided for @occasionTasua.
  ///
  /// In en, this message translates to:
  /// **'Tasu\'a (9 Muharram)'**
  String get occasionTasua;

  /// No description provided for @occasionTashreeq.
  ///
  /// In en, this message translates to:
  /// **'Days of Tashreeq (no fasting)'**
  String get occasionTashreeq;

  /// No description provided for @trackerGoldKarat.
  ///
  /// In en, this message translates to:
  /// **'Gold karat'**
  String get trackerGoldKarat;

  /// No description provided for @trackerDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts you must pay now'**
  String get trackerDebts;

  /// No description provided for @trackerNetAssets.
  ///
  /// In en, this message translates to:
  /// **'Net after debts'**
  String get trackerNetAssets;

  /// No description provided for @trackerZakatNotice.
  ///
  /// In en, this message translates to:
  /// **'Nisab: 85 g of pure gold or 595 g of pure silver; zakat is 2.5% of the net once a full lunar year has passed on it. Jewelry worn for personal use is not zakatable according to the majority (Maliki, Shafi\'i, Hanbali) but is according to the Hanafis; leave it out or include it accordingly. Scholars differ on deducting debts; the Shafi\'is do not deduct them. Consult a qualified scholar for your situation.'**
  String get trackerZakatNotice;

  /// No description provided for @trackerKarat.
  ///
  /// In en, this message translates to:
  /// **'{karat}k'**
  String trackerKarat(String karat);

  /// No description provided for @exactAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact adhan timing'**
  String get exactAlarmTitle;

  /// No description provided for @exactAlarmAllowed.
  ///
  /// In en, this message translates to:
  /// **'The adhan can sound at the exact minute of prayer'**
  String get exactAlarmAllowed;

  /// No description provided for @exactAlarmMissing.
  ///
  /// In en, this message translates to:
  /// **'The adhan may be delayed by several minutes'**
  String get exactAlarmMissing;

  /// No description provided for @exactAlarmAdvice.
  ///
  /// In en, this message translates to:
  /// **'Android needs your permission (Alarms & reminders) for the adhan to sound exactly when the prayer time begins.'**
  String get exactAlarmAdvice;

  /// No description provided for @openExactAlarmSettings.
  ///
  /// In en, this message translates to:
  /// **'Allow exact alarms'**
  String get openExactAlarmSettings;

  /// No description provided for @libraryTranslationLabel.
  ///
  /// In en, this message translates to:
  /// **'English translation: {url}'**
  String libraryTranslationLabel(String url);

  /// No description provided for @adhanMadinah.
  ///
  /// In en, this message translates to:
  /// **'Prophet\'s Mosque, Madinah (recording)'**
  String get adhanMadinah;

  /// No description provided for @adhanMakkah.
  ///
  /// In en, this message translates to:
  /// **'Masjid al-Haram, Makkah (2013 recording)'**
  String get adhanMakkah;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
