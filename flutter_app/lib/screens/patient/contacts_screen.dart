import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../widgets/patient_bottom_nav.dart';

class ContactsScreen extends StatefulWidget {
  final String phone;
  const ContactsScreen({super.key, required this.phone});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final _doctorName = TextEditingController();
  final _doctorPhone = TextEditingController();
  final _spouseName = TextEditingController();
  final _spousePhone = TextEditingController();
  final _trustedName = TextEditingController();
  final _trustedPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['contacts'] as List? ?? [];
        for (final c in list) {
          final type = c['type'] as String?;
          if (type == 'doctor') {
            _doctorName.text = c['name'] ?? '';
            _doctorPhone.text = c['phone'] ?? '';
          } else if (type == 'spouse') {
            _spouseName.text = c['name'] ?? '';
            _spousePhone.text = c['phone'] ?? '';
          } else if (type == 'trusted') {
            _trustedName.text = c['name'] ?? '';
            _trustedPhone.text = c['phone'] ?? '';
          }
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    final contacts = [
      {
        'type': 'doctor',
        'label': 'Médecin traitant',
        'name': _doctorName.text.trim(),
        'phone': _doctorPhone.text.trim(),
      },
      {
        'type': 'spouse',
        'label': 'Conjoint',
        'name': _spouseName.text.trim(),
        'phone': _spousePhone.text.trim(),
      },
      {
        'type': 'trusted',
        'label': 'Personne de confiance',
        'name': _trustedName.text.trim(),
        'phone': _trustedPhone.text.trim(),
      },
    ];

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'contacts': contacts}),
      );
      setState(() => _isSaving = false);
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contacts enregistrés'),
            backgroundColor: AppConstants.normalColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      } else {
        _showError('Erreur lors de la sauvegarde');
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
    _doctorName.dispose();
    _doctorPhone.dispose();
    _spouseName.dispose();
    _spousePhone.dispose();
    _trustedName.dispose();
    _trustedPhone.dispose();
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
                      child: _buildForm(),
                    ),
                  ),
                  PatientBottomNav(currentIndex: 4, phone: widget.phone),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
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
            children: [
              const Icon(Icons.contact_emergency_rounded, size: 48, color: Colors.white),
              const SizedBox(height: 8),
              const Text(
                'Contacts d\'urgence',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Personnes à prévenir en cas d\'urgence',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildContactCard(
            icon: Icons.medical_services_rounded,
            title: 'Médecin traitant',
            nameController: _doctorName,
            phoneController: _doctorPhone,
            nameHint: 'Dr. Nomo',
            phoneHint: '+237 6XX XX XX XX',
          ),
          const SizedBox(height: 16),
          _buildContactCard(
            icon: Icons.favorite_rounded,
            title: 'Conjoint',
            nameController: _spouseName,
            phoneController: _spousePhone,
            nameHint: 'Jean Ndzi',
            phoneHint: '+237 6XX XX XX XX',
          ),
          const SizedBox(height: 16),
          _buildContactCard(
            icon: Icons.people_rounded,
            title: 'Personne de confiance',
            nameController: _trustedName,
            phoneController: _trustedPhone,
            nameHint: 'Marie Ngono',
            phoneHint: '+237 6XX XX XX XX',
          ),
          const SizedBox(height: 28),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Enregistrer les contacts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required String nameHint,
    required String phoneHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.softPink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppConstants.softPink, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D2D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Nom complet',
              hintText: nameHint,
              hintStyle: TextStyle(color: Colors.grey[300], fontSize: 13),
              labelStyle: const TextStyle(
                color: AppConstants.softPink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppConstants.softPink, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Téléphone',
              hintText: phoneHint,
              hintStyle: TextStyle(color: Colors.grey[300], fontSize: 13),
              labelStyle: const TextStyle(
                color: AppConstants.softPink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppConstants.softPink, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

}
