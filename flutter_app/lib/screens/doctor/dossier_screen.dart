import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';

class DoctorDossierScreen extends StatefulWidget {
  final String phone;
  final String patientName;

  const DoctorDossierScreen({
    super.key,
    required this.phone,
    this.patientName = 'Patiente',
  });

  @override
  State<DoctorDossierScreen> createState() => _DoctorDossierScreenState();
}

class _DoctorDossierScreenState extends State<DoctorDossierScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _measures = [];
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDossier();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDossier() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/patient-dossier'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['succes'] == true && mounted) {
          setState(() {
            _profile = Map<String, dynamic>.from(data['profile'] ?? {});
            _measures = (data['measures'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            _alerts = (data['alerts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _markAlertVu(String alertId) async {
    try {
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/alert/$alertId/vu'),
      );
      if (mounted) {
        setState(() {
          final idx = _alerts.indexWhere((a) => a['id'] == alertId);
          if (idx != -1) {
            _alerts[idx]['vu'] = true;
            _alerts[idx]['status'] = 'alerte_vue';
          }
        });
      }
    } catch (_) {}
  }

  Color _riskColor(String color) {
    switch (color) {
      case 'danger':
        return const Color(0xFFB71C1C);
      case 'critique':
        return AppConstants.criticalColor;
      case 'surveillance':
        return AppConstants.warningColor;
      case 'rouge':
        return AppConstants.criticalColor;
      case 'orange':
        return AppConstants.warningColor;
      case 'vert':
      case 'normal':
        return AppConstants.normalColor;
      default:
        return AppConstants.normalColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMeasuresTab(),
                        _buildAlertsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profile['name'] as String? ?? widget.patientName;
    final week = _profile['pregnancy_week'] ?? 0;
    final hospital = _profile['hospital'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
              const Text(
                'Dossier patiente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(widget.phone,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (week > 0) ...[
                          Icon(Icons.pregnant_woman, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text('$week sem', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                          const SizedBox(width: 12),
                        ],
                        if (hospital.isNotEmpty) ...[
                          Icon(Icons.local_hospital, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(hospital,
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                            overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.doctorAppointment, arguments: {
                        'phone': widget.phone,
                        'name': widget.patientName,
                        'doctor_name': 'Dr.',
                      });
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Rendez-vous', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.doctorTeleconsultation, arguments: {
                        'phone': widget.phone,
                        'name': widget.patientName,
                        'doctor_name': 'Dr.',
                      });
                    },
                    icon: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Téléconsultation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppConstants.primaryColor,
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppConstants.primaryColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: [
          Tab(text: 'Mesures (${_measures.length})'),
          Tab(text: 'Alertes (${_alerts.length})'),
        ],
      ),
    );
  }

  Widget _buildMeasuresTab() {
    if (_measures.isEmpty) {
      return Center(
        child: Text('Aucune mesure', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _measures.length,
      itemBuilder: (_, i) => _buildMeasureCard(_measures[i]),
    );
  }

  Widget _buildMeasureCard(Map<String, dynamic> m) {
    final couleur = m['couleur'] as String? ?? 'normal';
    final riskColor = _riskColor(couleur);
    final score = m['score'] as String? ?? '';
    final date = m['date'] as String? ?? '';
    final heure = m['heure'] as String? ?? '';
    final bpm = m['bpm'] ?? 0;
    final spo2 = m['spo2'] ?? 0;
    final temp = m['temperature'] ?? 0;
    final ts = m['tension_s'] ?? 0;
    final td = m['tension_d'] ?? 0;
    final ctx = m['contractions'] ?? 0;
    final analyse = (m['analyse'] as Map?) ?? {};
    final analyseResume = analyse['resume'] as String? ?? '';
    final analyseRecommandation = analyse['recommandation'] as String? ?? '';
    final analyseUrgence = analyse['urgence'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('$date  $heure',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const Spacer(),
              if (score.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(score, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: riskColor)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildVital(Icons.favorite, 'BPM', '$bpm', Colors.red),
              _buildVital(Icons.air, 'SpO2', '$spo2%', Colors.blue),
              _buildVital(Icons.thermostat, 'Temp', '$temp°C', Colors.orange),
              _buildVital(Icons.monitor_heart, 'TA', '$ts/$td', Colors.purple),
              _buildVital(Icons.child_friendly, 'Ctx', '$ctx/10\'', Colors.teal),
            ],
          ),
          if (analyseResume.isNotEmpty || analyseRecommandation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: riskColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy_outlined, size: 15, color: riskColor),
                      const SizedBox(width: 6),
                      Text('Analyse IA',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: riskColor)),
                      const Spacer(),
                      if (analyseUrgence.isNotEmpty)
                        Text(analyseUrgence,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: riskColor)),
                    ],
                  ),
                  if (analyseResume.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(analyseResume,
                      style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.4)),
                  ],
                  if (analyseRecommandation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(analyseRecommandation,
                      style: TextStyle(fontSize: 12, color: riskColor, height: 1.4, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVital(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[800])),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return Center(
        child: Text('Aucune alerte', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _alerts.length,
      itemBuilder: (_, i) => _buildAlertCard(_alerts[i]),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> a) {
    final vu = a['vu'] as bool? ?? false;
    final score = a['score'] as String? ?? '';
    final alertes = (a['alertes'] as List?)?.cast<String>() ?? [];
    const riskColor = AppConstants.criticalColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vu ? Colors.grey[200]! : riskColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                vu ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 20,
                color: vu ? AppConstants.normalColor : riskColor,
              ),
              const SizedBox(width: 8),
              Text(score,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: vu ? Colors.grey[600] : riskColor,
                )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: vu ? AppConstants.normalColor.withValues(alpha: 0.1) : riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vu ? 'Vu' : 'Nouveau',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: vu ? AppConstants.normalColor : riskColor),
                ),
              ),
            ],
          ),
          if (alertes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...alertes.map((msg) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  Expanded(child: Text(msg,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.3))),
                ],
              ),
            )),
          ],
          const SizedBox(height: 6),
          Text(
            vu ? 'Traitée' : 'En cours d\'escalade',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
          if (!vu) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => _markAlertVu(a['id'] as String? ?? ''),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Marquer vu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.normalColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
