import 'package:flutter/material.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/patient/home_screen.dart';
import '../screens/doctor/dashboard_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String login = '/auth/login';
  static const String otp = '/auth/otp';
  static const String pin = '/auth/pin';
  static const String patientHome = '/patient/home';
  static const String patientInput = '/patient/input';
  static const String patientSensor = '/patient/sensor';
  static const String patientScore = '/patient/score';
  static const String patientHistory = '/patient/history';
  static const String patientProfile = '/patient/profile';
  static const String patientAppointment = '/patient/appointment';
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorDossier = '/doctor/dossier';
  static const String doctorAlert = '/doctor/alert';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      case patientHome:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
      case doctorDashboard:
        return MaterialPageRoute(
          builder: (_) => const DoctorDashboardScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page non trouvée')),
          ),
        );
    }
  }
}
