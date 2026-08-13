import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final String phone;
  const DoctorDashboardScreen({super.key, this.phone = ''});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadUnreadCount();
    _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    try {
      final messaging = await FirebaseMessaging.instance.getToken();
      if (messaging == null) return;
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'fcm_token': messaging}),
      );
    } catch (_) {}
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/patients'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['succes'] == true) {
          setState(() {
            _patients = (body['patients'] as List).cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadUnreadCount() async {
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['succes'] == true) {
          setState(() => _unreadCount = data['unread'] as int? ?? 0);
        }
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
      default:
        return AppConstants.normalColor;
    }
  }

  String _riskIcon(String color) {
    switch (color) {
      case 'danger':
        return '🆘';
      case 'critique':
        return '🔴';
      case 'surveillance':
        return '🟡';
      default:
        return '🟢';
    }
  }

  int get _dangerCount => _patients.where((p) => p['risk_color'] == 'danger').length;
  int get _critiqueCount => _patients.where((p) => p['risk_color'] == 'critique').length;
  int get _surveillanceCount => _patients.where((p) => p['risk_color'] == 'surveillance').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                  : _patients.isEmpty
                      ? _buildEmptyState()
                      : _buildPatientList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  iconSize: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tableau de bord',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                onPressed: _loadPatients,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.doctorNotifications, arguments: {'phone': widget.phone}).then((_) => _loadUnreadCount());
                    },
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xFFB71C1C), shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.doctorProfile, arguments: {'phone': widget.phone}),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Total', _patients.length.toString(), Icons.people_rounded, Colors.white),
              const SizedBox(width: 10),
              _buildStatCard('Critique', _critiqueCount.toString(), Icons.warning_rounded, AppConstants.criticalColor),
              const SizedBox(width: 10),
              _buildStatCard('Surv.', _surveillanceCount.toString(), Icons.info_rounded, AppConstants.warningColor),
              const SizedBox(width: 10),
              _buildStatCard('Danger', _dangerCount.toString(), Icons.gpp_bad_rounded, const Color(0xFFB71C1C)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label,
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Aucune patiente liée',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Les patientes utilisant votre code\nde liaison apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    final sections = _groupPatientsByRisk();
    return RefreshIndicator(
      onRefresh: _loadPatients,
      color: AppConstants.primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final section in sections)
            _buildSection(section),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupPatientsByRisk() {
    const order = {'critique': 0, 'danger': 0, 'surveillance': 1, 'normal': 2};
    final copy = [..._patients];
    copy.sort((a, b) {
      final ca = order[a['risk_color']] ?? 3;
      final cb = order[b['risk_color']] ?? 3;
      return ca.compareTo(cb);
    });
    final sections = <Map<String, dynamic>>[];
    for (final p in copy) {
      final color = p['risk_color'] as String? ?? 'normal';
      String key;
      if (color == 'critique' || color == 'danger') {
        key = 'critique';
      } else if (color == 'surveillance') {
        key = 'surveillance';
      } else {
        key = 'normal';
      }
      final existing = sections.where((s) => s['key'] == key).toList();
      if (existing.isEmpty) {
        sections.add({
          'key': key,
          'patients': <Map<String, dynamic>>[p],
        });
      } else {
        (existing.first['patients'] as List).add(p);
      }
    }
    return sections;
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final key = section['key'] as String;
    final patients = (section['patients'] as List).cast<Map<String, dynamic>>();
    final (label, color, icon) = switch (key) {
      'critique' => ('Risque élevé', AppConstants.criticalColor, Icons.warning_amber_rounded),
      'surveillance' => ('Risque modéré', AppConstants.warningColor, Icons.info_outline_rounded),
      _ => ('Risque normal', AppConstants.normalColor, Icons.check_circle_outline_rounded),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3,
                )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${patients.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
        for (final p in patients)
          _buildPatientCard(p, color),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> p, Color sectionColor) {
    final riskColor = _riskColor(p['risk_color'] as String? ?? 'normal');
    final riskLabel = p['risk_label'] as String? ?? 'Normal';
    final name = p['name'] as String? ?? 'Patiente';
    final week = p['pregnancy_week'] ?? 0;
    final lastDate = p['last_measure_date'] as String? ?? '';
    final bpm = p['last_bpm'] ?? 0;
    final spo2 = p['last_spo2'] ?? 0;

    final isHigh = p['risk_color'] == 'critique' || p['risk_color'] == 'danger';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isHigh
            ? Border.all(color: riskColor.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isHigh
                ? riskColor.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isHigh ? 14 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.doctorDossier, arguments: {
                'phone': p['phone'],
                'name': name,
              });
            },
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(_riskIcon(p['risk_color'] as String? ?? 'normal'), style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(riskLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: riskColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (week > 0) ...[
                            Icon(Icons.pregnant_woman, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text('$week sem', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(width: 12),
                          ],
                          if (bpm > 0) ...[
                            Icon(Icons.favorite, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text('$bpm', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(width: 12),
                          ],
                          if (spo2 > 0) ...[
                            Icon(Icons.air, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text('$spo2%', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ],
                      ),
                      if (lastDate.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Dernière mesure: $lastDate', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[300]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey[100]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _callPatient(p['phone'] as String? ?? ''),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.call_rounded, color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Text('Contacter la patiente', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callPatient(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de la patiente indisponible'), backgroundColor: Colors.red),
      );
      return;
    }
    final tel = Uri(scheme: 'tel', path: phone);
    try {
      final ok = await launchUrl(tel);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le téléphone'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le téléphone'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
