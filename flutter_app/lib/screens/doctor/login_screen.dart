import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final raw = _phoneController.text.trim();
    if (raw.length < 8) {
      _showError('Numéro de téléphone invalide');
      return;
    }
    final phone = '+237$raw';
    setState(() => _isLoading = true);

    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/pin/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      final data = jsonDecode(r.body);
      if (!mounted) return;

      if (data['succes'] == true && data['exists'] == true) {
        if (data['is_locked'] == true) {
          _showError(data['erreur'] ?? 'Compte verrouillé');
          setState(() => _isLoading = false);
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('doctor_phone', phone);
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.pinLogin, arguments: {
          'phone': phone,
          'role': 'doctor',
        });
      } else if (data['succes'] == true && data['exists'] == false) {
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.doctorActivation, arguments: {
          'phone': phone,
        });
      } else {
        _showError(data['erreur'] ?? 'Erreur');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    }
    setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medical_services_rounded, size: 44, color: Colors.white),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Espace médecin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'Connectez-vous avec votre code PIN',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppConstants.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_android_rounded, size: 36, color: AppConstants.primaryColor),
          ),
          const SizedBox(height: 20),
          const Text(
            'Connexion',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez votre numéro de téléphone',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Text('🇨🇲', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 4),
                    Text('+237', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Téléphone',
                    hintText: 'XX XX XX XX XX',
                    counterText: '',
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.phone_outlined, color: AppConstants.primaryColor, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.doctorRegistration),
            child: RichText(
              text: TextSpan(
                text: 'Je ne suis pas encore inscrit',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}