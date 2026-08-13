import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class PatientAlertHistoryScreen extends StatefulWidget {
  final String phone;
  const PatientAlertHistoryScreen({super.key, required this.phone});

  @override
  State<PatientAlertHistoryScreen> createState() => _PatientAlertHistoryScreenState();
}

class _PatientAlertHistoryScreenState extends State<PatientAlertHistoryScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/alerts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['succes'] == true) {
          _alerts = (data['alerts'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Color _riskColor(String? score) {
    switch (score) {
      case 'Eleve': return AppConstants.criticalColor;
      case 'Modere': return AppConstants.warningColor;
      default: return AppConstants.normalColor;
    }
  }

  IconData _riskIcon(String? score) {
    switch (score) {
      case 'Eleve': return Icons.cancel_rounded;
      case 'Modere': return Icons.warning_amber_rounded;
      default: return Icons.check_circle_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'alerte_vue': return 'Prise en compte';
      case 'escalade_en_cours': return 'En cours de traitement';
      default: return status;
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                  : _alerts.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
      child: Row(
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
            'Mes alertes sanitaires',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.health_and_safety_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Aucune alerte sanitaire', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppConstants.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _alerts.length,
        itemBuilder: (_, i) => _buildCard(_alerts[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> a) {
    final score = a['score'] as String? ?? '';
    final color = _riskColor(score);
    final vu = a['vu'] as bool? ?? false;
    final alertes = (a['alertes'] as List?)?.cast<String>() ?? [];
    final createdAt = a['createdAt'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vu ? Colors.grey[200]! : color.withValues(alpha: 0.3),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_riskIcon(score), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Risque $score',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                    if (createdAt.isNotEmpty)
                      Text(createdAt.replaceFirst('T', ' ').substring(0, 16),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: vu ? AppConstants.normalColor.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vu ? 'Traitée' : 'Active',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: vu ? AppConstants.normalColor : color),
                ),
              ),
            ],
          ),
          if (alertes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: alertes.map((al) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Text(al, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9))),
              )).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(_statusLabel(a['status'] as String? ?? ''),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])),
        ],
      ),
    );
  }
}