import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _savedPatientPhone;
  String? _savedDoctorPhone;

  @override
  void initState() {
    super.initState();
    _loadSavedPhones();
  }

  Future<void> _loadSavedPhones() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPatientPhone = prefs.getString('patient_phone');
      _savedDoctorPhone = prefs.getString('doctor_phone');
    });
  }

  Future<void> _onPatientTap() async {
    if (_savedPatientPhone != null) {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.pinLogin, arguments: {
        'phone': _savedPatientPhone,
      });
    } else {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.login);
    }
  }

  Future<void> _onDoctorTap() async {
    if (_savedDoctorPhone != null) {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.pinLogin, arguments: {
        'phone': _savedDoctorPhone,
        'role': 'doctor',
      });
    } else {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.doctorLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppConstants.backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4DD81B60),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.appSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _onPatientTap,
                  icon: const Icon(Icons.person),
                  label: const Text(
                    "Je suis une patiente",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _onDoctorTap,
                  icon: const Icon(Icons.medical_services),
                  label: const Text(
                    "Je suis un médecin",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryColor,
                    side: const BorderSide(color: AppConstants.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}