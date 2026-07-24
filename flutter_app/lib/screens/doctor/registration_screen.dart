import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';
import 'pending_screen.dart';

class DoctorRegistrationScreen extends StatefulWidget {
  const DoctorRegistrationScreen({super.key});

  @override
  State<DoctorRegistrationScreen> createState() => _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _hospitalController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = '+237${_phoneController.text.trim()}';
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'name': _nameController.text.trim(),
          'specialty': _specialtyController.text.trim(),
          'hospital': _hospitalController.text.trim(),
        }),
      );

      setState(() => _isLoading = false);

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        final isExisting = body['deja_existant'] == true;
        final status = body['status'] as String? ?? 'en_attente';
        final name = body['name'] as String? ?? _nameController.text.trim();

        if (isExisting && status == 'valide') {
          Navigator.pushReplacementNamed(context, AppRoutes.doctorDashboard, arguments: {
            'phone': phone,
          });
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorPendingScreen(
                name: name,
                status: status,
                phone: phone,
              ),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['erreur'] ?? 'Erreur lors de l\'inscription'),
            backgroundColor: AppConstants.criticalColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur de connexion au serveur'),
          backgroundColor: AppConstants.criticalColor,
        ),
      );
    }
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
                child: _buildFormCard(),
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
            'Inscription médecin',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Créez votre compte professionnel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nom complet',
                hintText: 'Dr. Jean Dupont',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline, color: AppConstants.primaryColor, size: 22),
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _specialtyController,
              decoration: InputDecoration(
                labelText: 'Spécialité',
                hintText: 'Gynécologue obstétricien',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_hospital_outlined, color: AppConstants.primaryColor, size: 22),
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Spécialité requise' : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _hospitalController,
              decoration: InputDecoration(
                labelText: 'Hôpital / Centre de santé',
                hintText: 'Hôpital Général de Douala',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_outlined, color: AppConstants.primaryColor, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('🇨🇲', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 4),
                      const Text(
                        '+237',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
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
                    validator: (v) {
                      if (v == null || v.trim().length < 8) return 'Numéro invalide';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              height: 56,
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
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text('S\'inscrire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
