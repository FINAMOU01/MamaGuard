import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';

class NotificationScreen extends StatefulWidget {
  final String phone;
  const NotificationScreen({super.key, required this.phone});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
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
        Uri.parse('${AppConstants.apiBaseUrl}/patient/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['succes'] == true) {
          _notifications = (data['notifications'] as List).cast<Map<String, dynamic>>();
          _markAllRead();
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _markAllRead() async {
    try {
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/notifications/lu'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'alerte_vue':
        return Icons.check_circle_outline;
      case 'teleconsultation':
        return Icons.videocam_rounded;
      case 'rendez_vous':
        return Icons.calendar_month_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'alerte_vue':
        return AppConstants.normalColor;
      case 'teleconsultation':
        return Colors.blue;
      case 'rendez_vous':
        return AppConstants.primaryColor;
      default:
        return AppConstants.primaryColor;
    }
  }

  void _onTap(Map<String, dynamic> n) {
    final type = n['type'] as String? ?? '';
    if (type == 'teleconsultation') {
      _showTeleconsultationDialog(n);
    } else if (type == 'rendez_vous') {
      _showAppointmentDialog(n);
    }
  }

  void _showTeleconsultationDialog(Map<String, dynamic> n) {
    final meetLink = n['meet_link'] as String? ?? '';
    final doctorMessage = n['doctor_message'] as String? ?? '';
    final title = n['title'] as String? ?? 'Téléconsultation';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_rounded, size: 32, color: Colors.blue),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
            if (doctorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(doctorMessage, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
            const SizedBox(height: 16),
            if (meetLink.isNotEmpty) ...[
              GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(meetLink);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_rounded, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ouvrir la visio',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                          onTap: () => Clipboard.setData(ClipboardData(text: meetLink)),
                          child: Icon(Icons.copy, size: 18, color: Colors.grey[400]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentDialog(Map<String, dynamic> n) {
    final message = n['message'] as String? ?? '';
    final title = n['title'] as String? ?? 'Rendez-vous';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_rounded, size: 32, color: AppConstants.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  : _notifications.isEmpty
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
            'Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Aucune notification', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
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
        itemCount: _notifications.length,
        itemBuilder: (_, i) => _buildCard(_notifications[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final type = n['type'] as String? ?? '';
    final title = n['title'] as String? ?? '';
    final message = n['message'] as String? ?? '';
    final createdAt = n['created_at'] as String? ?? '';

    return GestureDetector(
      onTap: () => _onTap(n),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _colorForType(type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForType(type), color: _colorForType(type), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(createdAt, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
