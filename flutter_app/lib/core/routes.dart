import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/pin_screen.dart';
import '../screens/auth/pin_login_screen.dart';
import '../screens/auth/pin_change_screen.dart';
import '../screens/patient/home_screen.dart';
import '../screens/patient/profile_screen.dart';
import '../screens/patient/contacts_screen.dart';
import '../screens/patient/input_screen.dart';
import '../screens/patient/sensor_screen.dart';
import '../screens/patient/score_screen.dart';
import '../screens/patient/history_screen.dart';
import '../screens/patient/consultation_screen.dart';
import '../screens/patient/reminder_screen.dart';
import '../screens/patient/link_doctor_screen.dart';
import '../screens/doctor/dashboard_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/auth/login';
  static const String otp = '/auth/otp';
  static const String pin = '/auth/pin';
  static const String pinLogin = '/auth/pin-login';
  static const String pinChange = '/auth/pin-change';
  static const String patientHome = '/patient/home';
  static const String patientInput = '/patient/input';
  static const String patientSensor = '/patient/sensor';
  static const String patientScore = '/patient/score';
  static const String patientHistory = '/patient/history';
  static const String patientConsultation = '/patient/consultation';
  static const String patientReminder = '/patient/reminder';
  static const String patientLinkDoctor = '/patient/link-doctor';
  static const String patientProfile = '/patient/profile';
  static const String patientContacts = '/patient/contacts';
  static const String patientAppointment = '/patient/appointment';
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorDossier = '/doctor/dossier';
  static const String doctorAlert = '/doctor/alert';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
      case welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      case otp:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => OtpScreen(phone: args?['phone'] as String? ?? ''),
        );
      case pin:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => PinScreen(phone: args?['phone'] as String? ?? ''),
        );
      case pinLogin:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => PinLoginScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientHome:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => HomeScreen(phone: args?['phone'] as String?),
        );
      case pinChange:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => PinChangeScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientProfile:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => ProfileScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientContacts:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => ContactsScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientInput:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => InputScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientSensor:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => SensorScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientScore:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => ScoreScreen(
            phone: args?['phone'] as String? ?? '',
            result: (args?['result'] as Map?) ?? {},
          ),
        );
      case patientHistory:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => HistoryScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientConsultation:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => ConsultationScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientReminder:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => ReminderScreen(phone: args?['phone'] as String? ?? ''),
        );
      case patientLinkDoctor:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => LinkDoctorScreen(phone: args?['phone'] as String? ?? ''),
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
