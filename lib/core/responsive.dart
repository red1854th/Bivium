import 'package:flutter/material.dart';

/// Screen type enum for responsive layout
enum ScreenType {
  mobile, // < 600px
  tablet, // 600-1000px
  desktop, // >= 1000px
}

/// Responsive layout utility for Bivium desktop optimization.
/// Provides breakpoints, helpers, and a responsive widget builder.
class Responsive {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1000;

  /// Maximum content width for desktop layouts
  static const double maxContentWidth = 1200;

  /// Get the current [ScreenType] based on screen width
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tabletBreakpoint) return ScreenType.desktop;
    if (width >= mobileBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  /// Check if the current screen is desktop (>= 1000px)
  static bool isDesktop(BuildContext context) {
    return getScreenType(context) == ScreenType.desktop;
  }

  /// Check if the current screen is tablet (600-1000px)
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == ScreenType.tablet;
  }

  /// Check if the current screen is mobile (< 600px)
  static bool isMobile(BuildContext context) {
    return getScreenType(context) == ScreenType.mobile;
  }

  /// Check if the current screen is desktop or tablet (>= 600px)
  static bool isDesktopOrTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }
}

/// A widget that builds different layouts based on screen type.
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext) mobile;
  final Widget Function(BuildContext)? tablet;
  final Widget Function(BuildContext) desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = Responsive.getScreenType(context);
    switch (screenType) {
      case ScreenType.desktop:
        return desktop(context);
      case ScreenType.tablet:
        return tablet?.call(context) ?? desktop(context);
      case ScreenType.mobile:
        return mobile(context);
    }
  }
}

/// A convenience widget that constrains content width on desktop.
/// On mobile/tablet, it fills the available width.
class ConstrainedContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ConstrainedContent({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.maxContentWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: child,
      ),
    );
  }
}
