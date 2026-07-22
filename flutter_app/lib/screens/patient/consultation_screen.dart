import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../widgets/patient_bottom_nav.dart';

class ConsultationScreen extends StatefulWidget {
  final String phone;
  const ConsultationScreen({super.key, required this.phone});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  bool _isLoading = false;
  bool _isCreating = false;
  String? _meetLink;
  String? _roomId;
  List<Map<String, dynamic>> _historique = [];

  @override
  void initState() {
    super.initState();
    _loadHistorique();
  }

  Future<void> _loadHistorique() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/consultations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _historique = List<Map<String, dynamic>>.from(data['consultations'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _createConsultation() async {
    setState(() => _isCreating = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/consultation/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _meetLink = data['meet_link'];
          _roomId = data['room_id'];
        });
        _loadHistorique();
      } else {
        _showError('Erreur lors de la création');
      }
    } catch (_) {
      _showError('Erreur de connexion');
    }
    setState(() => _isCreating = false);
  }

  Future<void> _rejoindre(String link) async {
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('Impossible d\'ouvrir le lien');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppConstants.criticalColor,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildNewCard(),
                    const SizedBox(height: 20),
                    _buildHistoriqueSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PatientBottomNav(currentIndex: 0, phone: widget.phone),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 8),
          const Text('Téléconsultation', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Consultez votre médecin à distance', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _buildNewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppConstants.softPink.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.videocam_rounded, color: AppConstants.softPink, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Nouvelle consultation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
          const SizedBox(height: 6),
          Text('Générez un lien Meet sécurisé et partagez-le avec votre médecin',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (_meetLink != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F9F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Color(0xFF25D366), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_meetLink!, style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejoindre(_meetLink!),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Rejoindre'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF25D366),
                            side: const BorderSide(color: Color(0xFF25D366)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // share link
                          },
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Partager'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Salle: MamaGuard_$_roomId', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createConsultation,
                icon: _isCreating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_circle_outline_rounded, size: 22),
                label: Text(_isCreating ? 'Création...' : 'Créer un lien de téléconsultation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.softPink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppConstants.softPink.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoriqueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Consultations récentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_historique.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Icon(Icons.videocam_off_rounded, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucune consultation', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              ],
            ),
          )
        else
          ..._historique.map((c) => _buildConsultationItem(c)),
      ],
    );
  }

  Widget _buildConsultationItem(Map<String, dynamic> c) {
    final ts = c['created_at'] ?? '';
    final date = ts.length >= 10 ? ts.substring(0, 10) : ts;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: c['status'] == 'en_attente' ? AppConstants.softPink.withValues(alpha: 0.12) : const Color(0xFF25D366).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              c['status'] == 'en_attente' ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
              color: c['status'] == 'en_attente' ? AppConstants.softPink : const Color(0xFF25D366),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['status'] == 'en_attente' ? 'En attente' : 'Terminée',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c['status'] == 'en_attente' ? AppConstants.softPink : const Color(0xFF25D366))),
                const SizedBox(height: 2),
                Text('MamaGuard_${c['room_id'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (date.isNotEmpty) Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          if (c['status'] == 'en_attente')
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.videocam_rounded, color: Color(0xFF25D366), size: 22),
                onPressed: () => _rejoindre(c['meet_link'] ?? ''),
                tooltip: 'Rejoindre',
              ),
            ),
        ],
      ),
    );
  }
}