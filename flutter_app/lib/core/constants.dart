import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'MamaGuard';

  // API
  static const String apiBaseUrl = 'http://10.11.12.160:5000';
  static const String predictEndpoint = '/predict';

  // Colors
  static const Color primaryColor = Color(0xFFE91E63);
  static const Color softPink = Color(0xFFFF7EB6);
  static const Color secondaryColor = Color(0xFFF06292);
  static const Color backgroundColor = Color(0xFFFCE4EC);
  static const Color normalColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color criticalColor = Color(0xFFF44336);

  // Text
  static const String appSubtitle = 'Votre santé et celle de votre bébé méritent une attention de chaque instant';
}
