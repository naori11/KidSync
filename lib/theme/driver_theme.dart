import 'package:flutter/material.dart';

/// Driver theme constants for consistent UI across driver screens
class DriverTheme {
  // Core Colors
  static const Color primaryGreen = Color(0xFF19AE61);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
  static const Color greyLight = Color(0xFFF5F5F5);
  static const Color greyMedium = Color(0xFFBDBDBD);
  static const Color greyDark = Color(0xFF757575);
  
  // Status Colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color infoBlue = Color(0xFF2196F3);
  
  // Spacing
  static EdgeInsets cardPadding(bool isMobile) => 
    EdgeInsets.all(isMobile ? 12 : 20);
  
  static EdgeInsets contentPadding(bool isMobile) => 
    EdgeInsets.all(isMobile ? 16 : 24);
  
  static EdgeInsets itemPadding(bool isMobile) => 
    EdgeInsets.all(isMobile ? 10 : 12);
  
  // Border Radius
  static BorderRadius cardBorderRadius(bool isMobile) => 
    BorderRadius.circular(isMobile ? 12 : 16);
  
  static BorderRadius buttonBorderRadius() => 
    BorderRadius.circular(8);
  
  static BorderRadius dialogBorderRadius() => 
    BorderRadius.circular(12);
  
  // Shadows
  static List<BoxShadow> cardShadow(Color primaryColor) => [
    BoxShadow(
      color: primaryColor.withOpacity(0.1),
      blurRadius: 10,
      offset: const Offset(0, 5),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> elevatedShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 12,
      offset: const Offset(0, 6),
      spreadRadius: 2,
    ),
  ];
  
  // Text Styles
  static TextStyle headerTextStyle(bool isMobile) => TextStyle(
    fontSize: isMobile ? 18 : 20,
    fontWeight: FontWeight.bold,
    color: black,
  );
  
  static TextStyle subHeaderTextStyle(bool isMobile) => TextStyle(
    fontSize: isMobile ? 16 : 18,
    fontWeight: FontWeight.w600,
    color: black,
  );
  
  static TextStyle bodyTextStyle(bool isMobile) => TextStyle(
    fontSize: isMobile ? 14 : 16,
    color: black,
  );
  
  static TextStyle captionTextStyle(bool isMobile) => TextStyle(
    fontSize: isMobile ? 12 : 14,
    color: black.withOpacity(0.7),
  );
}