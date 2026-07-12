import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Smart Cricket Umpiring'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Professional Umpiring System'**
  String get tagline;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @ballReplays.
  ///
  /// In en, this message translates to:
  /// **'Ball Replays'**
  String get ballReplays;

  /// No description provided for @reviewAndAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Review and analyze ball deliveries'**
  String get reviewAndAnalyze;

  /// No description provided for @buffered.
  ///
  /// In en, this message translates to:
  /// **'Buffered'**
  String get buffered;

  /// No description provided for @cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloud;

  /// No description provided for @noBufferedClips.
  ///
  /// In en, this message translates to:
  /// **'No buffered clips yet'**
  String get noBufferedClips;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording to create ball clips'**
  String get startRecording;

  /// No description provided for @noUploadedClips.
  ///
  /// In en, this message translates to:
  /// **'No uploaded clips'**
  String get noUploadedClips;

  /// No description provided for @uploadClips.
  ///
  /// In en, this message translates to:
  /// **'Upload clips to store them in the cloud'**
  String get uploadClips;

  /// No description provided for @loadingClips.
  ///
  /// In en, this message translates to:
  /// **'Loading clips...'**
  String get loadingClips;

  /// No description provided for @loadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get loadingVideo;

  /// No description provided for @ballReview.
  ///
  /// In en, this message translates to:
  /// **'Ball Review'**
  String get ballReview;

  /// No description provided for @validDelivery.
  ///
  /// In en, this message translates to:
  /// **'Valid Delivery'**
  String get validDelivery;

  /// No description provided for @noBall.
  ///
  /// In en, this message translates to:
  /// **'No Ball'**
  String get noBall;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @slowMotion.
  ///
  /// In en, this message translates to:
  /// **'Slow Motion'**
  String get slowMotion;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @startRecordingButton.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecordingButton;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @markBall.
  ///
  /// In en, this message translates to:
  /// **'Mark Ball'**
  String get markBall;

  /// No description provided for @refreshBuffer.
  ///
  /// In en, this message translates to:
  /// **'Refresh Buffer'**
  String get refreshBuffer;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @uploadToS3.
  ///
  /// In en, this message translates to:
  /// **'Upload to S3'**
  String get uploadToS3;

  /// No description provided for @uploadToCloud.
  ///
  /// In en, this message translates to:
  /// **'Upload to Cloud'**
  String get uploadToCloud;

  /// No description provided for @clipUploaded.
  ///
  /// In en, this message translates to:
  /// **'Clip uploaded to S3 successfully!'**
  String get clipUploaded;

  /// No description provided for @markedAsValid.
  ///
  /// In en, this message translates to:
  /// **'Marked as valid delivery'**
  String get markedAsValid;

  /// No description provided for @markedAsNoBall.
  ///
  /// In en, this message translates to:
  /// **'Marked as no-ball'**
  String get markedAsNoBall;

  /// No description provided for @shareComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Share functionality coming soon'**
  String get shareComingSoon;

  /// No description provided for @addNoteComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Add note functionality coming soon'**
  String get addNoteComingSoon;

  /// No description provided for @slowMotionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Slow motion analysis coming soon'**
  String get slowMotionComingSoon;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera Error'**
  String get cameraError;

  /// No description provided for @videoLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get videoLoadError;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again'**
  String get checkConnection;

  /// No description provided for @cloudStorage.
  ///
  /// In en, this message translates to:
  /// **'Cloud Storage'**
  String get cloudStorage;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @recorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recorded;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgo(Object count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(Object count);

  /// No description provided for @buffer.
  ///
  /// In en, this message translates to:
  /// **'Buffer'**
  String get buffer;

  /// No description provided for @clips.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get clips;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'used'**
  String get used;

  /// No description provided for @currentBall.
  ///
  /// In en, this message translates to:
  /// **'Ball {number}'**
  String currentBall(Object number);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
