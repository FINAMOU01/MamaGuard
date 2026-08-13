import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../widgets/patient_bottom_nav.dart';

class LinkDoctorScreen extends StatefulWidget {
  final String phone;
  const LinkDoctorScreen({super.key, required this.phone});

  @override
  State<LinkDoctorScreen> createState() => _LinkDoctorScreenState();
}

class _LinkDoctorScreenState extends State<LinkDoctorScreen> {
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isLinking = false;
  bool _isLoading = true;
  Map<String, dynamic>? _linkedDoctor;

  @override
  void initState() {
    super.initState();
    _checkLinked();
  }

  @override
  void dispose() {
    for (var c in _codeControllers) { c.dispose(); }
    for (var f in _codeFocusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _codeControllers.map((c) => c.text).join();

  Future<void> _checkLinked() async {
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/doctor-info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        _linkedDoctor = data['docteur'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _linkDoctor() async {
    if (_code.length != 6) {
      _showError('Entrez le code de liaison à 6 chiffres');
      return;
    }
    setState(() => _isLinking = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/link-doctor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'code': _code}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() {
          _linkedDoctor = {
            'doctor_name': data['doctor_name'],
            'doctor_phone': data['doctor_phone'],
            'doctor_specialty': data['doctor_specialty'],
          };
          for (var c in _codeControllers) { c.clear(); }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liée au Dr ${data['doctor_name']}'),
            backgroundColor: AppConstants.normalColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      } else {
        final err = jsonDecode(r.body)['erreur'] ?? 'Code invalide';
        _showError(err);
      }
    } catch (_) {
      _showError('Erreur de connexion');
    }
    setState(() => _isLinking = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppConstants.criticalColor,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _codeFocusNodes[index + 1].requestFocus();
    }
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
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                    else if (_linkedDoctor != null)
                      _buildLinkedCard()
                    else
                      _buildLinkForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PatientBottomNav(currentIndex: 4, phone: widget.phone),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0, left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.medical_services_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text('Mon médecin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              Text('Liez-vous à votre médecin traitant', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppConstants.backgroundColor, shape: BoxShape.circle),
            child: const Icon(Icons.link_rounded, size: 36, color: AppConstants.primaryColor),
          ),
          const SizedBox(height: 20),
          const Text('Code de liaison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
          const SizedBox(height: 6),
          Text('Demandez ce code à votre médecin', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),
          Row(
            children: List.generate(6, (i) => Expanded(child: _buildCodeBox(i))),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)], begin: Alignment.centerLeft, end: Alignment.centerRight),
              boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ElevatedButton(
              onPressed: _isLinking ? null : _linkDoctor,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLinking
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text('Lier mon médecin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _codeFocusNodes[index].hasFocus ? AppConstants.primaryColor : Colors.grey[200]!,
            width: _codeFocusNodes[index].hasFocus ? 2.0 : 1.0,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: TextField(
            controller: _codeControllers[index],
            focusNode: _codeFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
            onChanged: (v) => _onDigitChanged(index, v),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedCard() {
    final d = _linkedDoctor!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                (d['doctor_name'] as String? ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(d['doctor_name'] ?? 'Médecin', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppConstants.softPink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(d['doctor_specialty'] ?? 'Généraliste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.softPink)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF25D366)),
              const SizedBox(width: 6),
              Text(d['doctor_phone'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _linkedDoctor = null),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Changer de médecin'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.softPink,
                side: const BorderSide(color: AppConstants.softPink),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}