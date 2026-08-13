import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../widgets/patient_bottom_nav.dart';

class InputScreen extends StatefulWidget {
  final String phone;
  final int pregnancyWeek;
  const InputScreen({super.key, required this.phone, this.pregnancyWeek = 0});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tensionSController = TextEditingController();
  final _tensionDController = TextEditingController();
  final _contractionsController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;
  int _pregnancyWeek = 0;

  @override
  void initState() {
    super.initState();
    _loadPregnancyWeek();
  }

  Future<void> _loadPregnancyWeek() async {
    if (widget.pregnancyWeek > 0) {
      _pregnancyWeek = widget.pregnancyWeek;
      setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _pregnancyWeek = (body['profile']?['pregnancy_week'] as int?) ?? 0;
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tensionSController.dispose();
    _tensionDController.dispose();
    _contractionsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/manual-measure/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
          'tension_s': int.parse(_tensionSController.text),
          'tension_d': int.parse(_tensionDController.text),
          'contractions': int.parse(_contractionsController.text),
          'semaine': _pregnancyWeek,
        }),
      );

      setState(() => _isSaving = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mesures enregistrées. Utilisez le moniteur temps réel pour l\'analyse complète.'),
            backgroundColor: AppConstants.normalColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
        Navigator.pushNamed(context, AppRoutes.patientSensor, arguments: {
          'phone': widget.phone,
        });
      } else {
        _showError('Erreur lors de l\'enregistrement');
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildForm(),
              ),
            ),
            PatientBottomNav(currentIndex: 1, phone: widget.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Icon(Icons.edit_note_rounded, size: 34, color: Colors.white),
          const SizedBox(height: 4),
          const Text(
            'Saisie manuelle',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
          ),
          const SizedBox(height: 2),
          Text(
            'Entrez vos mesures du moment',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 24),
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
            const Text(
              'Tension artérielle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Votre tension du moment (mmHg)',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _tensionSController,
                    label: 'Systolique',
                    hint: '120',
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('/', style: TextStyle(fontSize: 24, color: Colors.grey)),
                ),
                Expanded(
                  child: _buildField(
                    controller: _tensionDController,
                    label: 'Diastolique',
                    hint: '80',
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Contractions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nombre ressenti ces dernières heures',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _contractionsController,
              label: 'Contractions',
              hint: '3',
              icon: Icons.timeline_rounded,
              suffix: '/ 10 min',
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context, AppRoutes.patientSensor,
                  arguments: {'phone': widget.phone},
                ),
                icon: const Icon(Icons.favorite_rounded, size: 18, color: AppConstants.softPink),
                label: const Text(
                  'Moniteur temps réel',
                  style: TextStyle(color: AppConstants.softPink, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF06292)],
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
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Enregistrer mes mesures',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
      style: const TextStyle(fontSize: 15, color: Color(0xFF2D2D2D), fontWeight: FontWeight.w500),
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
        prefixIcon: Icon(icon, color: AppConstants.softPink, size: 20),
        suffixText: suffix,
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
        fillColor: const Color(0xFFF8F8FF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

}
