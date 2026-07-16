import 'package:flutter/material.dart';
import 'constants.dart';

final ThemeData mamaGuardTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppConstants.primaryColor,
    primary: AppConstants.primaryColor,
    secondary: AppConstants.secondaryColor,
    surface: AppConstants.backgroundColor,
  ),
  scaffoldBackgroundColor: AppConstants.backgroundColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppConstants.primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppConstants.primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);
