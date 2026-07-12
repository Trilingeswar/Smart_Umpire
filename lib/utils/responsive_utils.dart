import 'package:flutter/material.dart';

/// Utility class for responsive design across different screen sizes
class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get screen type based on width
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return getScreenType(context) == ScreenType.mobile;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == ScreenType.tablet;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return getScreenType(context) == ScreenType.desktop;
  }

  /// Get responsive value based on screen size
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0; // Base width for iPhone 6/7/8
    return baseSize * scaleFactor.clamp(0.8, 1.5);
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double horizontal = 16.0,
    double vertical = 16.0,
  }) {
    return responsiveValue(
      context: context,
      mobile: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      tablet: EdgeInsets.symmetric(horizontal: horizontal * 1.5, vertical: vertical * 1.2),
      desktop: EdgeInsets.symmetric(horizontal: horizontal * 2.0, vertical: vertical * 1.5),
    );
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    return responsiveValue(
      context: context,
      mobile: baseSpacing,
      tablet: baseSpacing * 1.2,
      desktop: baseSpacing * 1.5,
    );
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    return responsiveValue(
      context: context,
      mobile: baseSize,
      tablet: baseSize * 1.1,
      desktop: baseSize * 1.2,
    );
  }

  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context, double baseRadius) {
    return responsiveValue(
      context: context,
      mobile: baseRadius,
      tablet: baseRadius * 1.1,
      desktop: baseRadius * 1.2,
    );
  }

  /// Get responsive elevation
  static double getResponsiveElevation(BuildContext context, double baseElevation) {
    return responsiveValue(
      context: context,
      mobile: baseElevation,
      tablet: baseElevation * 1.2,
      desktop: baseElevation * 1.5,
    );
  }

  /// Get responsive container width
  static double getResponsiveContainerWidth(BuildContext context, {
    double? maxWidth,
    double fraction = 1.0,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth * fraction;

    if (maxWidth != null && containerWidth > maxWidth) {
      return maxWidth;
    }

    return responsiveValue(
      context: context,
      mobile: containerWidth * 0.9,
      tablet: containerWidth * 0.8,
      desktop: containerWidth * 0.7,
    );
  }

  /// Get responsive grid columns
  static int getResponsiveGridColumns(BuildContext context) {
    return responsiveValue(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }

  /// Get responsive aspect ratio for video containers
  static double getResponsiveVideoAspectRatio(BuildContext context) {
    return responsiveValue(
      context: context,
      mobile: 16 / 9,
      tablet: 16 / 10,
      desktop: 21 / 9,
    );
  }

  /// Check if device has small screen
  static bool hasSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  /// Check if device has large screen
  static bool hasLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 1200;
  }

  /// Get safe area aware padding
  static EdgeInsets getSafeAreaPadding(BuildContext context, {
    double horizontal = 16.0,
    double vertical = 16.0,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final safeAreaPadding = mediaQuery.padding;

    return EdgeInsets.fromLTRB(
      safeAreaPadding.left + horizontal,
      safeAreaPadding.top + vertical,
      safeAreaPadding.right + horizontal,
      safeAreaPadding.bottom + vertical,
    );
  }

  /// Get orientation aware value
  static T orientationValue<T>({
    required BuildContext context,
    required T portrait,
    required T landscape,
  }) {
    final orientation = MediaQuery.of(context).orientation;
    return orientation == Orientation.portrait ? portrait : landscape;
  }

  /// Get responsive button size
  static Size getResponsiveButtonSize(BuildContext context, {
    double width = 200.0,
    double height = 48.0,
  }) {
    return responsiveValue(
      context: context,
      mobile: Size(width, height),
      tablet: Size(width * 1.2, height * 1.1),
      desktop: Size(width * 1.4, height * 1.2),
    );
  }

  /// Get responsive card size
  static Size getResponsiveCardSize(BuildContext context, {
    double width = 300.0,
    double height = 200.0,
  }) {
    return responsiveValue(
      context: context,
      mobile: Size(width, height),
      tablet: Size(width * 1.1, height * 1.1),
      desktop: Size(width * 1.2, height * 1.2),
    );
  }
}

enum ScreenType {
  mobile,
  tablet,
  desktop,
}

/// Extension methods for responsive widgets
extension ResponsiveExtension on BuildContext {
  ScreenType get screenType => ResponsiveUtils.getScreenType(this);
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);

  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) => ResponsiveUtils.responsiveValue(
    context: this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );

  double responsiveFontSize(double baseSize) =>
      ResponsiveUtils.getResponsiveFontSize(this, baseSize);

  EdgeInsets responsivePadding({
    double horizontal = 16.0,
    double vertical = 16.0,
  }) => ResponsiveUtils.getResponsivePadding(
    this,
    horizontal: horizontal,
    vertical: vertical,
  );

  double responsiveSpacing(double baseSpacing) =>
      ResponsiveUtils.getResponsiveSpacing(this, baseSpacing);

  double responsiveIconSize(double baseSize) =>
      ResponsiveUtils.getResponsiveIconSize(this, baseSize);

  double responsiveBorderRadius(double baseRadius) =>
      ResponsiveUtils.getResponsiveBorderRadius(this, baseRadius);

  double responsiveElevation(double baseElevation) =>
      ResponsiveUtils.getResponsiveElevation(this, baseElevation);

  double responsiveContainerWidth({
    double? maxWidth,
    double fraction = 1.0,
  }) => ResponsiveUtils.getResponsiveContainerWidth(
    this,
    maxWidth: maxWidth,
    fraction: fraction,
  );

  int get responsiveGridColumns => ResponsiveUtils.getResponsiveGridColumns(this);

  double get responsiveVideoAspectRatio =>
      ResponsiveUtils.getResponsiveVideoAspectRatio(this);

  bool get hasSmallScreen => ResponsiveUtils.hasSmallScreen(this);

  bool get hasLargeScreen => ResponsiveUtils.hasLargeScreen(this);

  EdgeInsets safeAreaPadding({
    double horizontal = 16.0,
    double vertical = 16.0,
  }) => ResponsiveUtils.getSafeAreaPadding(
    this,
    horizontal: horizontal,
    vertical: vertical,
  );

  T orientationValue<T>({
    required T portrait,
    required T landscape,
  }) => ResponsiveUtils.orientationValue(
    context: this,
    portrait: portrait,
    landscape: landscape,
  );

  Size responsiveButtonSize({
    double width = 200.0,
    double height = 48.0,
  }) => ResponsiveUtils.getResponsiveButtonSize(
    this,
    width: width,
    height: height,
  );

  Size responsiveCardSize({
    double width = 300.0,
    double height = 200.0,
  }) => ResponsiveUtils.getResponsiveCardSize(
    this,
    width: width,
    height: height,
  );
}