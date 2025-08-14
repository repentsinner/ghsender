import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VS Code-inspired theme colors and styling for the graphics performance spike
class VSCodeTheme {
  // VS Code Dark Theme Colors
  static const Color activityBarBackground = Color(0xFF333333);
  static const Color sideBarBackground = Color(0xFF252526);
  static const Color editorBackground = Color(0xFF1E1E1E);
  static const Color panelBackground = Color(0xFF1E1E1E);
  static const Color statusBarBackground = Color(0xFF007ACC);

  // Text Colors
  static const Color primaryText = Color(0xFFCCCCCC);
  static const Color secondaryText = Color(0xFF969696);
  static const Color infoTooltip = Color.fromARGB(255, 85, 103, 118);
  static const Color accentText = Color(0xFF569CD6);

  // Border and Divider Colors
  static const Color border = Color(0xFF464647);
  static const Color divider = Color(0xFF2D2D30);

  // Interactive Colors
  static const Color hover = Color(0xFF2A2D2E);
  static const Color selection = Color(0xFF094771);
  static const Color focus = Color(0xFF007ACC);
  static const Color accent = Color(0xFF007ACC);

  // Input Colors
  static const Color inputBackground = Color(0xFF3C3C3C);
  static const Color dropdownBackground = Color(0xFF3C3C3C);

  // Activity Bar Icon Colors
  static const Color activeIcon = Color(0xFFFFFFFF);
  static const Color inactiveIcon = Color(0xFF858585);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF2196F3);

  /// Activity Bar theme data
  static ThemeData get activityBarTheme => ThemeData(
    scaffoldBackgroundColor: activityBarBackground,
    iconTheme: const IconThemeData(color: inactiveIcon, size: 24),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: primaryText,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),
  );

  /// Sidebar theme data
  static ThemeData get sidebarTheme => ThemeData(
    scaffoldBackgroundColor: sideBarBackground,
    cardColor: sideBarBackground,
    dividerColor: divider,
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        color: primaryText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: primaryText,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: focus,
      inactiveTrackColor: border,
      thumbColor: focus,
      overlayColor: Color(0x29007ACC),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: focus,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
  );

  /// Main editor theme data
  static ThemeData get editorTheme => ThemeData(
    scaffoldBackgroundColor: editorBackground,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: primaryText,
        fontSize: 12,
        fontFamily: 'Inconsolata',
      ),
    ),
  );

  /// Panel theme data
  static ThemeData get panelTheme => ThemeData(
    scaffoldBackgroundColor: panelBackground,
    tabBarTheme: const TabBarThemeData(
      labelColor: primaryText,
      unselectedLabelColor: secondaryText,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: focus, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: primaryText,
        fontSize: 12,
        fontFamily: 'Inconsolata',
      ),
      bodySmall: TextStyle(
        color: secondaryText,
        fontSize: 11,
        fontFamily: 'Inconsolata',
      ),
    ),
  );

  /// Status bar theme data
  static ThemeData get statusBarTheme => ThemeData(
    scaffoldBackgroundColor: statusBarBackground,
    textTheme: const TextTheme(
      bodySmall: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
  );

  /// Common styling constants
  static const double activityBarWidth = 48.0;
  static const double sidebarDefaultWidth = 300.0;
  static const double sidebarMinWidth = 200.0;
  static const double sidebarMaxWidth = 600.0;
  static const double panelDefaultHeight = 200.0;
  static const double panelMinHeight = 100.0;
  static const double panelMaxHeight = 400.0;
  static const double statusBarHeight = 22.0;
  static const double splitterWidth = 2.0;

  /// Border radius for containers
  static const BorderRadius containerRadius = BorderRadius.all(
    Radius.circular(4),
  );

  /// Box shadows for elevated elements
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// Log line text styles - consistent sizing and Inconsolata font
  static TextStyle get loglineTime => GoogleFonts.inconsolata(
    color: secondaryText,
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get loglineName => GoogleFonts.inconsolata(
    color: const Color(0xFF4FC1FF), // VS Code cyan
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get loglineLevel =>
      GoogleFonts.inconsolata(fontSize: 11, fontWeight: FontWeight.w600);

  static TextStyle get loglineMessage => GoogleFonts.inconsolata(
    color: primaryText,
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );
}
