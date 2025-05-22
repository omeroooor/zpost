import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme configuration with light and dark themes
class AppTheme {
  // Light theme colors
  static const Color _lightPrimaryColor = Color(0xFF3F51B5);       // Indigo
  static const Color _lightSecondaryColor = Color(0xFF03A9F4);     // Light Blue
  static const Color _lightBackgroundColor = Color(0xFFF5F7FA);    // Light Gray
  static const Color _lightSurfaceColor = Colors.white;
  static const Color _lightErrorColor = Color(0xFFE53935);         // Red
  static const Color _lightTextColor = Color(0xFF2D3748);          // Dark Gray
  static const Color _lightIconColor = Color(0xFF718096);          // Medium Gray
  
  // Dark theme colors
  static const Color _darkPrimaryColor = Color(0xFF5C6BC0);        // Lighter Indigo
  static const Color _darkSecondaryColor = Color(0xFF29B6F6);      // Lighter Blue
  static const Color _darkBackgroundColor = Color(0xFF1A202C);     // Dark Gray
  static const Color _darkSurfaceColor = Color(0xFF2D3748);        // Medium Dark Gray
  static const Color _darkErrorColor = Color(0xFFEF5350);          // Lighter Red
  static const Color _darkTextColor = Color(0xFFE2E8F0);           // Light Gray
  static const Color _darkIconColor = Color(0xFFA0AEC0);           // Medium Light Gray

  // Accent colors for both themes
  static const Color accentGreen = Color(0xFF38B2AC);              // Teal
  static const Color accentYellow = Color(0xFFF6E05E);             // Yellow
  static const Color accentPurple = Color(0xFF9F7AEA);             // Purple
  static const Color accentPink = Color(0xFFED64A6);               // Pink

  // Card and container styling
  static final BorderRadius borderRadius = BorderRadius.circular(12);
  static const double elevation = 2.0;
  static const EdgeInsets padding = EdgeInsets.all(16.0);
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  /// Get the light theme
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _lightPrimaryColor,
        secondary: _lightSecondaryColor,
        background: _lightBackgroundColor,
        surface: _lightSurfaceColor,
        error: _lightErrorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: _lightTextColor,
        onSurface: _lightTextColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _lightBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: _lightPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
          color: _lightTextColor,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.poppins(
          color: _lightTextColor,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.poppins(
          color: _lightTextColor,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.poppins(
          color: _lightTextColor,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.poppins(
          color: _lightTextColor,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.poppins(
          color: _lightTextColor,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.poppins(
          color: _lightTextColor,
        ),
      ),
      cardTheme: CardTheme(
        color: _lightSurfaceColor,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimaryColor,
          foregroundColor: Colors.white,
          elevation: elevation,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightPrimaryColor,
          side: BorderSide(color: _lightPrimaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightPrimaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lightSecondaryColor,
        foregroundColor: Colors.white,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _lightIconColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _lightIconColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _lightPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _lightErrorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
          color: _lightIconColor,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.poppins(
          color: _lightTextColor,
          fontSize: 14,
        ),
      ),
      iconTheme: IconThemeData(
        color: _lightIconColor,
        size: 24,
      ),
      dividerTheme: DividerThemeData(
        color: _lightIconColor.withOpacity(0.2),
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightSurfaceColor,
        contentTextStyle: GoogleFonts.poppins(
          color: _lightTextColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightBackgroundColor,
        disabledColor: _lightIconColor.withOpacity(0.1),
        selectedColor: _lightPrimaryColor.withOpacity(0.2),
        secondarySelectedColor: _lightSecondaryColor.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: GoogleFonts.poppins(
          color: _lightTextColor,
          fontSize: 14,
        ),
        secondaryLabelStyle: GoogleFonts.poppins(
          color: _lightSecondaryColor,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurfaceColor,
        selectedItemColor: _lightPrimaryColor,
        unselectedItemColor: _lightIconColor,
        type: BottomNavigationBarType.fixed,
        elevation: elevation,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
        ),
      ),
    );
  }

  /// Get the dark theme
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _darkPrimaryColor,
        secondary: _darkSecondaryColor,
        background: _darkBackgroundColor,
        surface: _darkSurfaceColor,
        error: _darkErrorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: _darkTextColor,
        onSurface: _darkTextColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _darkBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSurfaceColor,
        foregroundColor: _darkTextColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkTextColor,
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
          color: _darkTextColor,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.poppins(
          color: _darkTextColor,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.poppins(
          color: _darkTextColor,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.poppins(
          color: _darkTextColor,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.poppins(
          color: _darkTextColor,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.poppins(
          color: _darkTextColor,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.poppins(
          color: _darkTextColor,
        ),
      ),
      cardTheme: CardTheme(
        color: _darkSurfaceColor,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimaryColor,
          foregroundColor: Colors.white,
          elevation: elevation,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimaryColor,
          side: BorderSide(color: _darkPrimaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _darkSecondaryColor,
        foregroundColor: Colors.white,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceColor.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _darkIconColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _darkIconColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _darkPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _darkErrorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
          color: _darkIconColor,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.poppins(
          color: _darkTextColor,
          fontSize: 14,
        ),
      ),
      iconTheme: IconThemeData(
        color: _darkIconColor,
        size: 24,
      ),
      dividerTheme: DividerThemeData(
        color: _darkIconColor.withOpacity(0.2),
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurfaceColor,
        contentTextStyle: GoogleFonts.poppins(
          color: _darkTextColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkBackgroundColor,
        disabledColor: _darkIconColor.withOpacity(0.1),
        selectedColor: _darkPrimaryColor.withOpacity(0.2),
        secondarySelectedColor: _darkSecondaryColor.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: GoogleFonts.poppins(
          color: _darkTextColor,
          fontSize: 14,
        ),
        secondaryLabelStyle: GoogleFonts.poppins(
          color: _darkSecondaryColor,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurfaceColor,
        selectedItemColor: _darkPrimaryColor,
        unselectedItemColor: _darkIconColor,
        type: BottomNavigationBarType.fixed,
        elevation: elevation,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
        ),
      ),
    );
  }
}
