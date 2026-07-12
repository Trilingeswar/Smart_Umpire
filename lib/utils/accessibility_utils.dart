import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Utility class for accessibility features and compliance
class AccessibilityUtils {
  /// Create semantic labels for interactive elements
  static String createSemanticLabel(String primaryText, [String? secondaryText]) {
    if (secondaryText != null && secondaryText.isNotEmpty) {
      return '$primaryText, $secondaryText';
    }
    return primaryText;
  }

  /// Create semantic hints for buttons and actions
  static String createSemanticHint(String action, [String? additionalInfo]) {
    final hint = 'Tap to $action';
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      return '$hint. $additionalInfo';
    }
    return hint;
  }

  /// Configure accessibility for video player controls
  static void configureVideoPlayerSemantics({
    required BuildContext context,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required VoidCallback onPlayPause,
    required VoidCallback onSeekForward,
    required VoidCallback onSeekBackward,
  }) {
    SemanticsService.announce(
      isPlaying ? 'Video is playing' : 'Video is paused',
      TextDirection.ltr,
    );
  }

  /// Create accessible progress indicator
  static Widget createAccessibleProgressIndicator({
    required double value,
    required String label,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: '${(value * 100).round()}%',
      child: LinearProgressIndicator(
        value: value,
      ),
    );
  }

  /// Create accessible button with proper semantics
  static Widget createAccessibleButton({
    required Widget child,
    required VoidCallback onPressed,
    required String label,
    String? hint,
    bool enabled = true,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      enabled: enabled,
      button: true,
      child: child,
    );
  }

  /// Create accessible card with proper semantics
  static Widget createAccessibleCard({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: onTap != null,
      child: child,
    );
  }

  /// Create accessible list item
  static Widget createAccessibleListItem({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      selected: selected,
      button: onTap != null,
      child: child,
    );
  }

  /// Create accessible tab with proper semantics
  static Widget createAccessibleTab({
    required Widget child,
    required String label,
    required bool selected,
    int? index,
    int? totalTabs,
  }) {
    return Semantics(
      label: label,
      selected: selected,
      hint: selected
          ? 'Tab ${index ?? 0} of ${totalTabs ?? 0}, selected'
          : 'Tab ${index ?? 0} of ${totalTabs ?? 0}',
      child: child,
    );
  }

  /// Create accessible navigation bar item
  static Widget createAccessibleNavItem({
    required Widget child,
    required String label,
    required bool selected,
  }) {
    return Semantics(
      label: selected ? '$label, selected' : label,
      selected: selected,
      hint: 'Tap to navigate to $label',
      button: true,
      child: child,
    );
  }

  /// Create accessible slider/progress bar
  static Widget createAccessibleSlider({
    required Widget child,
    required String label,
    required double value,
    required double min,
    required double max,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: '${value.round()}',
      increasedValue: '${(value + 1).clamp(min, max).round()}',
      decreasedValue: '${(value - 1).clamp(min, max).round()}',
      slider: true,
      child: child,
    );
  }

  /// Create accessible time display
  static Widget createAccessibleTimeDisplay({
    required Widget child,
    required Duration currentTime,
    required Duration totalTime,
  }) {
    final current = _formatDuration(currentTime);
    final total = _formatDuration(totalTime);
    final label = 'Video time: $current of $total';

    return Semantics(
      label: label,
      liveRegion: true,
      child: child,
    );
  }

  /// Create accessible status indicator
  static Widget createAccessibleStatus({
    required Widget child,
    required String status,
    required Color color,
  }) {
    return Semantics(
      label: status,
      hint: 'Status indicator',
      child: ExcludeSemantics(
        child: child,
      ),
    );
  }

  /// Announce important status changes
  static void announceStatusChange(String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Create accessible error message
  static Widget createAccessibleError({
    required Widget child,
    required String errorMessage,
  }) {
    return Semantics(
      label: 'Error: $errorMessage',
      hint: 'This is an error message',
      child: child,
    );
  }

  /// Create accessible loading state
  static Widget createAccessibleLoading({
    required Widget child,
    required String loadingMessage,
  }) {
    return Semantics(
      label: loadingMessage,
      liveRegion: true,
      child: child,
    );
  }

  /// Create accessible success message
  static Widget createAccessibleSuccess({
    required Widget child,
    required String successMessage,
  }) {
    return Semantics(
      label: 'Success: $successMessage',
      liveRegion: true,
      child: child,
    );
  }

  /// Configure accessibility for camera preview
  static Widget createAccessibleCameraPreview({
    required Widget child,
    required bool isRecording,
  }) {
    return Semantics(
      label: isRecording
          ? 'Camera is recording video'
          : 'Camera preview, ready to record',
      hint: isRecording
          ? 'Recording in progress'
          : 'Tap record button to start recording',
      liveRegion: true,
      image: true,
      child: child,
    );
  }

  /// Create accessible recording indicator
  static Widget createAccessibleRecordingIndicator({
    required Widget child,
    required bool isRecording,
  }) {
    return Semantics(
      label: isRecording ? 'Recording active' : 'Not recording',
      hint: isRecording
          ? 'Video recording is in progress'
          : 'Tap to start recording',
      liveRegion: true,
      child: child,
    );
  }

  /// Create accessible buffer status
  static Widget createAccessibleBufferStatus({
    required Widget child,
    required int usedMB,
    required int totalMB,
    required int clipsCount,
  }) {
    final percentage = ((usedMB / totalMB) * 100).round();
    final label = 'Buffer: ${usedMB}MB of ${totalMB}MB used, $clipsCount clips stored, $percentage% full';

    return Semantics(
      label: label,
      hint: 'Buffer storage status',
      value: '$percentage%',
      child: child,
    );
  }

  /// Create accessible decision buttons
  static Widget createAccessibleDecisionButton({
    required Widget child,
    required String decision,
    required String ballNumber,
  }) {
    final label = 'Mark $ballNumber as $decision delivery';

    return Semantics(
      label: label,
      hint: 'Tap to mark this ball as $decision',
      button: true,
      child: child,
    );
  }

  /// Create accessible video clip item
  static Widget createAccessibleVideoClip({
    required Widget child,
    required String ballNumber,
    required String duration,
    required String timestamp,
    required bool isUploaded,
  }) {
    final status = isUploaded ? 'uploaded to cloud' : 'stored locally';
    final label = 'Ball $ballNumber, duration $duration, recorded $timestamp, $status';

    return Semantics(
      label: label,
      hint: 'Tap to review this ball delivery',
      button: true,
      child: child,
    );
  }

  /// Configure accessibility for FAB (Floating Action Button)
  static Widget createAccessibleFAB({
    required Widget child,
    required String action,
    required String context,
  }) {
    final label = '$action button for $context';

    return Semantics(
      label: label,
      hint: 'Tap to $action',
      button: true,
      child: child,
    );
  }

  /// Create accessible speed control
  static Widget createAccessibleSpeedControl({
    required Widget child,
    required double currentSpeed,
  }) {
    final label = 'Playback speed: ${currentSpeed}x';

    return Semantics(
      label: label,
      hint: 'Tap to change playback speed',
      button: true,
      value: '${currentSpeed}x',
      child: child,
    );
  }

  /// Create accessible time controls
  static Widget createAccessibleTimeControl({
    required Widget child,
    required String action,
    required int seconds,
  }) {
    final label = '$action $seconds seconds';

    return Semantics(
      label: label,
      hint: 'Tap to $action by $seconds seconds',
      button: true,
      child: child,
    );
  }

  /// Create accessible frame controls
  static Widget createAccessibleFrameControl({
    required Widget child,
    required String direction,
  }) {
    final label = 'Move to $direction frame';

    return Semantics(
      label: label,
      hint: 'Tap to advance to the $direction frame',
      button: true,
      child: child,
    );
  }

  /// Helper method to format duration for accessibility
  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes minutes and $seconds seconds';
  }

  /// Check if screen reader is enabled
  static Future<bool> isScreenReaderEnabled() async {
    // This would typically check platform-specific accessibility settings
    // For now, return false as we can't easily detect this in Flutter
    return false;
  }

  /// Configure high contrast mode support
  static bool shouldUseHighContrast(BuildContext context) {
    // Check for high contrast mode preference
    // This could be extended to check system settings
    return MediaQuery.of(context).highContrast;
  }

  /// Get appropriate text scale factor for accessibility
  static double getAccessibleTextScale(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.textScaleFactor.clamp(0.8, 2.0);
  }

  /// Create accessible focus order for complex layouts
  static List<FocusNode> createFocusOrder(int count) {
    return List.generate(count, (index) => FocusNode());
  }

  /// Dispose focus nodes
  static void disposeFocusNodes(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.dispose();
    }
  }
}

/// Extension methods for accessibility
extension AccessibilityExtension on Widget {
  /// Add accessibility semantics
  Widget withSemantics({
    String? label,
    String? hint,
    bool? enabled,
    bool? selected,
    bool? button,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      enabled: enabled,
      selected: selected,
      button: button,
      child: this,
    );
  }

  /// Add accessibility for images
  Widget asImage({
    String? label,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      image: true,
      child: this,
    );
  }

  /// Add accessibility for live regions
  Widget asLiveRegion({
    String? label,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      liveRegion: true,
      child: this,
    );
  }
}

/// Accessibility constants
class AccessibilityConstants {
  static const double minimumTouchTarget = 44.0;
  static const double minimumTextSize = 14.0;
  static const double recommendedTextSize = 16.0;
  static const double maximumTextScale = 2.0;
  static const double minimumContrastRatio = 4.5;
  static const Duration announcementDelay = Duration(milliseconds: 500);
}