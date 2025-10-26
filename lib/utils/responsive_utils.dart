import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return 16.0;
    } else if (isTablet(context)) {
      return 24.0;
    } else {
      return 32.0;
    }
  }

  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return baseFontSize * 0.9;
    } else if (screenWidth > 600) {
      return baseFontSize * 1.1;
    }
    return baseFontSize;
  }

  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) {
      return isLandscape(context) ? 3 : 2;
    } else if (isTablet(context)) {
      return isLandscape(context) ? 4 : 3;
    } else {
      return 5;
    }
  }

  static double getCardWidth(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (isMobile(context)) {
      return screenWidth - (getResponsivePadding(context) * 2);
    } else if (isTablet(context)) {
      return (screenWidth - (getResponsivePadding(context) * 3)) / 2;
    } else {
      return (screenWidth - (getResponsivePadding(context) * 4)) / 3;
    }
  }

  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final padding = getResponsivePadding(context);
    return EdgeInsets.all(padding / 2);
  }

  static EdgeInsets getResponsivePaddingInsets(BuildContext context) {
    final padding = getResponsivePadding(context);
    return EdgeInsets.all(padding);
  }

  static double getAppBarHeight(BuildContext context) {
    return kToolbarHeight + MediaQuery.of(context).padding.top;
  }

  static double getBottomSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  static double getTopSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  static bool shouldUseCompactLayout(BuildContext context) {
    return isMobile(context) && isPortrait(context);
  }

  static double getStatCardWidth(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    final padding = getResponsivePadding(context);
    final availableWidth = screenWidth - (padding * 2);
    
    if (isMobile(context)) {
      return (availableWidth - 36) / 4; // 4 cards with 12px spacing
    } else if (isTablet(context)) {
      return (availableWidth - 48) / 4; // 4 cards with 16px spacing
    } else {
      return (availableWidth - 60) / 4; // 4 cards with 20px spacing
    }
  }

  static double getButtonHeight(BuildContext context) {
    if (isMobile(context)) {
      return 48.0;
    } else if (isTablet(context)) {
      return 52.0;
    } else {
      return 56.0;
    }
  }

  static double getIconSize(BuildContext context, double baseSize) {
    if (isMobile(context)) {
      return baseSize;
    } else if (isTablet(context)) {
      return baseSize * 1.2;
    } else {
      return baseSize * 1.4;
    }
  }
}