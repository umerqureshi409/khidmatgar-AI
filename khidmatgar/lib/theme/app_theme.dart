import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Deep Space Colors
  static const Color backgroundDark = Color(0xFF090C15);
  static const Color cardNavy = Color(0xFF161B28);
  static const Color glassPanel = Color(0x99161B28); // 60% opacity for blur
  
  // Glowing Accents
  static const Color primaryNeon = Color(0xFF00E676);
  static const Color secondaryNeon = Color(0xFF00B0FF);
  static const Color goldAccent = Color(0xFFFFD700);
  
  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B9BB4);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeon,
        secondary: secondaryNeon,
        surface: cardNavy,
        background: backgroundDark,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        bodyLarge: GoogleFonts.outfit(color: textPrimary),
        bodyMedium: GoogleFonts.outfit(color: textSecondary),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary, 
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark.withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryNeon),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Glassmorphism Utility Box Decoration
  static BoxDecoration glassDecoration({double borderRadius = 16}) {
    return BoxDecoration(
      color: glassPanel,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 20,
          spreadRadius: -5,
        ),
      ],
    );
  }
}
