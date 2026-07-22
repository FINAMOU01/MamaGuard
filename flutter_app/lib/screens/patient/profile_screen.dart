import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../widgets/patient_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  final String phone;
  const ProfileScreen({super.key, required this.phone});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weekController = TextEditingController();
  final _hospitalController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final profile = body['profile'] as Map?;
        if (profile != null) {
          _nameController.text = profile['name'] ?? '';
          _weekController.text = (profile['pregnancy_week'] ?? 0).toString();
          _hospitalController.text = profile['hospital'] ?? '';
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
          'name': _nameController.text.trim(),
          'pregnancy_week': int.tryParse(_weekController.text) ?? 0,
          'hospital': _hospitalController.text.trim(),
        }),
      );
      setState(() => _isSaving = false);
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil enregistré'),
            backgroundColor: AppConstants.normalColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      } else {
        final body = jsonDecode(response.body);
        _showError(body['erreur'] ?? 'Erreur');
      }
    } catch (_) {
      setState(() => _isSaving = false);
      _showError('Erreur de connexion');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppConstants.criticalColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weekController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.softPink))
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildFormCard(),
                    ),
                  ),
                  PatientBottomNav(currentIndex: 4, phone: widget.phone),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.32,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 12,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _nameController.text.isNotEmpty
                          ? ClipOval(
                              child: Center(
                                child: Text(
                                  _nameController.text[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w600,
                                    color: AppConstants.softPink,
                                  ),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: AppConstants.softPink,
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: AppConstants.softPink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mon Profil',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gérez vos informations personnelles',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            _buildField(
              icon: Icons.person_rounded,
              label: 'Nom complet',
              hint: 'Marie Claire Ndzi',
              controller: _nameController,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              icon: Icons.calendar_month_rounded,
              label: 'Semaine de grossesse',
              hint: '28 semaines',
              controller: _weekController,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis';
                final w = int.tryParse(v);
                if (w == null || w < 1 || w > 42) return 'Entre 1 et 42';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildField(
              icon: Icons.local_hospital_rounded,
              label: 'Hôpital habituel',
              hint: 'Hôpital Central de Yaoundé',
              controller: _hospitalController,
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context, AppRoutes.patientContacts,
                  arguments: {'phone': widget.phone},
                ),
                icon: const Icon(Icons.contact_emergency_rounded, size: 18, color: AppConstants.softPink),
                label: const Text(
                  'Gérer les contacts d\'urgence',
                  style: TextStyle(color: AppConstants.softPink, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF06292).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enregistrer les modifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF2D2D2D),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[300], fontSize: 14),
          labelStyle: const TextStyle(
            color: AppConstants.softPink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(icon, color: AppConstants.softPink, size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppConstants.softPink, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(0, size.height, 40, size.height);
    path.lineTo(size.width - 40, size.height);
    path.quadraticBezierTo(size.width, size.height, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
