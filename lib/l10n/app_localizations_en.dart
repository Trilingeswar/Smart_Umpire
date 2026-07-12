// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Smart Cricket Umpiring';

  @override
  String get tagline => 'Professional Umpiring System';

  @override
  String get live => 'Live';

  @override
  String get replay => 'Replay';

  @override
  String get ballReplays => 'Ball Replays';

  @override
  String get reviewAndAnalyze => 'Review and analyze ball deliveries';

  @override
  String get buffered => 'Buffered';

  @override
  String get cloud => 'Cloud';

  @override
  String get noBufferedClips => 'No buffered clips yet';

  @override
  String get startRecording => 'Start recording to create ball clips';

  @override
  String get noUploadedClips => 'No uploaded clips';

  @override
  String get uploadClips => 'Upload clips to store them in the cloud';

  @override
  String get loadingClips => 'Loading clips...';

  @override
  String get loadingVideo => 'Loading video...';

  @override
  String get ballReview => 'Ball Review';

  @override
  String get validDelivery => 'Valid Delivery';

  @override
  String get noBall => 'No Ball';

  @override
  String get addNote => 'Add Note';

  @override
  String get slowMotion => 'Slow Motion';

  @override
  String get share => 'Share';

  @override
  String get review => 'Review';

  @override
  String get upload => 'Upload';

  @override
  String get startRecordingButton => 'Start Recording';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get markBall => 'Mark Ball';

  @override
  String get refreshBuffer => 'Refresh Buffer';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get uploadToS3 => 'Upload to S3';

  @override
  String get uploadToCloud => 'Upload to Cloud';

  @override
  String get clipUploaded => 'Clip uploaded to S3 successfully!';

  @override
  String get markedAsValid => 'Marked as valid delivery';

  @override
  String get markedAsNoBall => 'Marked as no-ball';

  @override
  String get shareComingSoon => 'Share functionality coming soon';

  @override
  String get addNoteComingSoon => 'Add note functionality coming soon';

  @override
  String get slowMotionComingSoon => 'Slow motion analysis coming soon';

  @override
  String get error => 'Error';

  @override
  String get cameraError => 'Camera Error';

  @override
  String get videoLoadError => 'Failed to load video';

  @override
  String get checkConnection => 'Please check your connection and try again';

  @override
  String get cloudStorage => 'Cloud Storage';

  @override
  String get duration => 'Duration';

  @override
  String get recorded => 'Recorded';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(Object count) {
    return '$count minutes ago';
  }

  @override
  String hoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get buffer => 'Buffer';

  @override
  String get clips => 'Clips';

  @override
  String get used => 'used';

  @override
  String currentBall(Object number) {
    return 'Ball $number';
  }
}
