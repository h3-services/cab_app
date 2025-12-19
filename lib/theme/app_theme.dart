import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGradientStart = Color(0xFFE8E8E8);
  static const Color primaryGradientEnd = Color(0xFF808080);
  static const Color buttonGradientStart = Color(0xFF616161);
  static const Color buttonGradientEnd = Color(0xFF000000);
  static const Color appBarColor = Color(0xFF424242);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color greenLight = Color(0xFF4F884F);
  static const Color greenDark = Color(0xFF2B4E2B);
  
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenLight, greenDark],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryGradientStart, primaryGradientEnd],
  );
  
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [buttonGradientStart, buttonGradientEnd],
  );
}