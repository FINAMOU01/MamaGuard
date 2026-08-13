import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String phone;
  const DoctorProfileScreen({super.key, required this.phone});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Map<String, dynamic>? _doctor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (mounted) setState(() => _doctor = data['doctor'] as Map<String, dynamic>?);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: SafeArea(child: Center(child: CircularProgressIndicator(color: AppConstants.softPink))));
    }
    final d = _doctor;
    if (d == null) {
      return Scaffold(body: SafeArea(child: Center(child: Text('Impossible de charger le profil', style: TextStyle(color: Colors.grey[500])))));
    }

    final name = d['name'] as String? ?? '';
    final specialty = d['specialty'] as String? ?? '';
    final hospital = d['hospital'] as String? ?? '';
    final phone = d['phone'] as String? ?? '';
    final liaisonCode = d['liaison_code'] as String? ?? '';
    final status = d['status'] as String? ?? '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, name, specialty),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildInfoCard(name, specialty, hospital, phone),
                    const SizedBox(height: 16),
                    _buildLiaisonCodeCard(context, liaisonCode),
                    const SizedBox(height: 16),
                    _buildStatusCard(status),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String specialty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const Text('Mon profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  name.isNotEmpty ? name[name.length - 1].toUpperCase() : 'D',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(specialty, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String name, String specialty, String hospital, String phone) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.person_outline, 'Nom', name),
          const Divider(height: 20),
          _infoRow(Icons.local_hospital_outlined, 'Spécialité', specialty),
          const Divider(height: 20),
          _infoRow(Icons.business_outlined, 'Hôpital', hospital),
          const Divider(height: 20),
          _infoRow(Icons.phone_outlined, 'Téléphone', phone),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppConstants.primaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiaisonCodeCard(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2, size: 20, color: AppConstants.primaryColor),
              ),
              const SizedBox(width: 14),
              const Text('Code de liaison', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppConstants.backgroundColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppConstants.softPink.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 8, color: AppConstants.primaryColor)),
                const SizedBox(height: 4),
                Text('Partagez ce code à vos patientes', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copié !'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: const Text('Copier le code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    final isValide = status == 'valide';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isValide ? AppConstants.normalColor.withValues(alpha: 0.08) : AppConstants.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isValide ? AppConstants.normalColor.withValues(alpha: 0.3) : AppConstants.warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isValide ? Icons.verified_rounded : Icons.hourglass_empty_rounded,
            color: isValide ? AppConstants.normalColor : AppConstants.warningColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValide ? 'Compte validé' : 'En attente de validation',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isValide ? AppConstants.normalColor : AppConstants.warningColor, fontSize: 14),
                ),
                Text(
                  isValide ? 'Vous pouvez utiliser toutes les fonctionnalités.' : 'L\'équipe administrative vérifie votre compte.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}