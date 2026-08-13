import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class DoctorNotificationScreen extends StatefulWidget {
  final String phone;
  const DoctorNotificationScreen({super.key, required this.phone});

  @override
  State<DoctorNotificationScreen> createState() => _DoctorNotificationScreenState();
}

class _DoctorNotificationScreenState extends State<DoctorNotificationScreen> {
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
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/notifications'),
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
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/notifications/lu'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'nouvelle_patiente':
        return Icons.person_add_alt_1;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'nouvelle_patiente':
        return AppConstants.normalColor;
      default:
        return AppConstants.primaryColor;
    }
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

    return Container(
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
    );
  }
}
