import 'package:flutter/material.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
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
      case splash:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
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
