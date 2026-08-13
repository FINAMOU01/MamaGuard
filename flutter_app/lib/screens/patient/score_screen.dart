import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../widgets/patient_bottom_nav.dart';

class ScoreScreen extends StatefulWidget {
  final String phone;
  final Map result;
  final bool offline;
  const ScoreScreen({super.key, required this.phone, required this.result, this.offline = false});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  String _patientName = '';
  String _doctorPhone = '';
  bool _isSendingSms = false;

  @override
  void initState() {
    super.initState();
    _loadInfos();
  }

  Future<void> _loadInfos() async {
    try {
      final profileRes = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (profileRes.statusCode == 200) {
        final p = jsonDecode(profileRes.body);
        _patientName = (p['profile']?['name'] as String?) ?? '';
      }

      final contactsRes = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (contactsRes.statusCode == 200) {
        final c = jsonDecode(contactsRes.body);
        final contacts = c['contacts'] as List? ?? [];
        final doctor = contacts.where((ct) => ct['type'] == 'doctor').firstOrNull;
        if (doctor != null) {
          _doctorPhone = doctor['phone'] ?? '';
        }
      }
    } catch (_) {}
  }

  Future<void> _sendSmsReport() async {
    if (_doctorPhone.isEmpty) {
      _showError('Aucun médecin enregistré. Ajoutez un contact d\'abord.');
      return;
    }
    setState(() => _isSendingSms = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/report/sms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
          'doctor_phone': _doctorPhone,
          'patient_name': _patientName.isNotEmpty ? _patientName : 'Patiente',
          'score': widget.result['score'] ?? '',
          'bpm': widget.result['parametres_recus']?['bpm'] ?? 0,
          'spo2': widget.result['parametres_recus']?['spo2'] ?? 0,
          'tension_s': widget.result['parametres_recus']?['tension_s'] ?? 0,
          'tension_d': widget.result['parametres_recus']?['tension_d'] ?? 0,
          'contractions': widget.result['parametres_recus']?['contractions'] ?? 0,
        }),
      );
      setState(() => _isSendingSms = false);
      setState(() => _isSendingSms = false);
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rapport envoyé par SMS au médecin'),
            backgroundColor: AppConstants.normalColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      } else {
        final errMsg = _extractError(response.body);
        _showError(errMsg);
      }
    } catch (_) {
      setState(() => _isSendingSms = false);
      _showError('Erreur de connexion');
    }
  }

  String _extractError(String body) {
    try {
      final json = jsonDecode(body);
      return json['erreur'] as String? ?? 'Erreur lors de l\'envoi du SMS';
    } catch (_) {
      return 'Erreur lors de l\'envoi du SMS';
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

  Color get _riskColor {
    switch (widget.result['couleur']) {
      case 'rouge': return AppConstants.criticalColor;
      case 'orange': return AppConstants.warningColor;
      default: return AppConstants.normalColor;
    }
  }

  IconData get _riskIcon {
    switch (widget.result['couleur']) {
      case 'rouge': return Icons.report_rounded;
      case 'orange': return Icons.warning_amber_rounded;
      default: return Icons.check_circle_rounded;
    }
  }

  String get _riskLabel {
    switch (widget.result['score']) {
      case 'Eleve': return 'Élevé';
      case 'Modere': return 'Modéré';
      default: return 'Normal';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CRITIQUE': return AppConstants.criticalColor;
      case 'ATTENTION': return AppConstants.warningColor;
      default: return AppConstants.normalColor;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'CRITIQUE': return Icons.cancel_rounded;
      case 'ATTENTION': return Icons.error_outline_rounded;
      default: return Icons.check_circle_outline_rounded;
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
                    _buildScoreCard(),
                    const SizedBox(height: 16),
                    _buildRecommendation(),
                    const SizedBox(height: 16),
                    _buildShareButtons(),
                    const SizedBox(height: 16),
                    _buildDetails(),
                    const SizedBox(height: 16),
                    _buildProbabilities(),
                    const SizedBox(height: 24),
                  ],
                ),
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
              const Icon(Icons.analytics_rounded, size: 48, color: Colors.white),
              const SizedBox(height: 8),
              const Text(
                'Résultat de l\'analyse',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyse IA de vos signes vitaux',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final details = widget.result['details'] as List? ?? [];
    final warns = details.where((d) => d['statut'] != 'NORMAL' && d['statut'] != 'INFO').length;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      width: double.infinity,
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
        children: [
          if (widget.offline) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppConstants.warningColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.warningColor.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: AppConstants.warningColor, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Analyse locale approximative (hors ligne). '
                      'La mesure sera synchronisée au retour du réseau.',
                      style: TextStyle(fontSize: 12, color: AppConstants.warningColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _riskColor.withValues(alpha: 0.12),
                ),
              ),
              Icon(_riskIcon, size: 56, color: _riskColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Risque $_riskLabel',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _riskColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (widget.result['niveau_urgence'] as String?)?.replaceAll('_', ' ') ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _riskColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat(Icons.analytics_rounded, 'Confiance', '${widget.result['confiance']}'),
              const SizedBox(width: 32),
              _buildStat(Icons.warning_rounded, 'Alertes', '$warns'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppConstants.softPink),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildRecommendation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_riskIcon, color: _riskColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommandation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.result['recommandation'] ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButtons() {
    final rapport = Uri.encodeComponent(
      'MamaGuard - ${widget.result['score'] ?? ''}\n'
      'BPM: ${widget.result['parametres_recus']?['bpm'] ?? '--'} SpO2: ${widget.result['parametres_recus']?['spo2'] ?? '--'}%\n'
      'TA: ${widget.result['parametres_recus']?['tension_s'] ?? '--'}/${widget.result['parametres_recus']?['tension_d'] ?? '--'}\n'
      'Ctx: ${widget.result['parametres_recus']?['contractions'] ?? '--'}/10min\n'
      'Recommandation: ${widget.result['recommandation'] ?? ''}'
    );

    Future<void> openWhatsApp() async {
      if (_doctorPhone.isEmpty) {
        _showError('Aucun médecin enregistré. Ajoutez un contact d\'abord.');
        return;
      }
      final phone = _doctorPhone.replaceAll(RegExp(r'[^\d+]'), '');
      final waIntent = Uri.parse('whatsapp://send?phone=$phone&text=$rapport');
      final waFallback = Uri.parse('https://wa.me/$phone?text=$rapport');
      try {
        if (await canLaunchUrl(waIntent)) {
          await launchUrl(waIntent, mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrl(waFallback)) {
          await launchUrl(waFallback, mode: LaunchMode.externalApplication);
        } else {
          _showError('WhatsApp n\'est pas installé');
        }
      } catch (_) {
        _showError('Impossible d\'ouvrir WhatsApp');
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Partager le rapport', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSendingSms ? null : _sendSmsReport,
                  icon: _isSendingSms
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sms_rounded, size: 18),
                  label: Text(_isSendingSms ? '...' : 'SMS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.softPink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppConstants.softPink.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: openWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final details = widget.result['details'] as List? ?? [];
    if (details.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails des paramètres',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 14),
          ...details.map((d) => _buildParamRow(d)),
        ],
      ),
    );
  }

  Widget _buildParamRow(Map d) {
    final status = d['statut'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(_statusIcon(status), size: 20, color: _statusColor(status)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['parametre'] ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D)),
                ),
                Text(
                  d['message'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              d['valeur'] ?? '',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilities() {
    final probs = widget.result['probabilites'] as Map?;
    if (probs == null) return const SizedBox.shrink();

    final classes = ['Normal', 'Modere', 'Eleve'];
    final colors = [AppConstants.normalColor, AppConstants.warningColor, AppConstants.criticalColor];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Probabilités par classe',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 16),
          ...classes.map((c) {
            final pct = (probs[c] as num?)?.toDouble() ?? 0.0;
            final color = colors[classes.indexOf(c)];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D))),
                      Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.grey[100],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

}
