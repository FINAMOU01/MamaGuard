import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';

class DoctorTeleconsultationScreen extends StatefulWidget {
  final String patientPhone;
  final String patientName;
  final String doctorName;

  const DoctorTeleconsultationScreen({
    super.key,
    required this.patientPhone,
    required this.patientName,
    this.doctorName = 'Dr.',
  });

  @override
  State<DoctorTeleconsultationScreen> createState() => _DoctorTeleconsultationScreenState();
}

class _DoctorTeleconsultationScreenState extends State<DoctorTeleconsultationScreen> {
  final _messageController = TextEditingController();
  bool _isGenerating = false;
  bool _isSending = false;
  String? _generatedLink;
  String? _consultationId;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _generateLink() async {
    setState(() => _isGenerating = true);

    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/generate-teleconsultation-link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_phone': widget.patientPhone,
          'doctor_name': widget.doctorName,
          'doctor_phone': '',
        }),
      );
      setState(() => _isGenerating = false);

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        setState(() {
          _generatedLink = body['meet_link'] as String?;
          _consultationId = body['consultation_id'] as String?;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de génération'), backgroundColor: AppConstants.criticalColor),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _sendInvitation() async {
    if (_consultationId == null) return;
    setState(() => _isSending = true);

    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/send-teleconsultation-invitation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'consultation_id': _consultationId,
          'doctor_name': widget.doctorName,
          'message': _messageController.text.trim().isEmpty
              ? 'J\'ai besoin de causer avec vous maintenant ou dans 2h pour me rassurer. Si vous avez un malaise, un mot, vous voyez?'
              : _messageController.text.trim(),
        }),
      );
      setState(() => _isSending = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(r.statusCode == 200 ? 'Invitation envoyée !' : 'Erreur lors de l\'envoi'),
          backgroundColor: r.statusCode == 200 ? AppConstants.normalColor : AppConstants.criticalColor,
        ),
      );
    } catch (e) {
      setState(() => _isSending = false);
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCard(),
              ),
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
                'Téléconsultation',
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
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  widget.patientName.isNotEmpty ? widget.patientName[0].toUpperCase() : 'P',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.patientName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(widget.patientPhone,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppConstants.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_rounded, size: 36, color: AppConstants.primaryColor),
          ),
          const SizedBox(height: 20),
          const Text(
            'Téléconsultation Jitsi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 8),
          Text(
            'Générez d\'abord le lien, puis envoyez\nl\'invitation à la patiente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
          ),
          const SizedBox(height: 24),

          // Step 1: Generate link
          if (_generatedLink == null) ...[
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isGenerating
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Flexible(child: Text('Générer le lien Jitsi',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              overflow: TextOverflow.ellipsis)),
                        ],
                      ),
              ),
            ),
          ],

          // Link generated
          if (_generatedLink != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.normalColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.normalColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppConstants.normalColor, size: 20),
                      const SizedBox(width: 8),
                      const Text('Lien généré', style: TextStyle(fontWeight: FontWeight.w600, color: AppConstants.normalColor, fontSize: 14)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _generatedLink!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lien copié !'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppConstants.normalColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 14, color: AppConstants.normalColor),
                              SizedBox(width: 4),
                              Text('Copier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.normalColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.tryParse(_generatedLink!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.normalColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ouvrir la visio',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Step 2: Send invitation with message
            const Text('Envoyer l\'invitation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message personnel',
                hintText: 'J\'ai besoin de causer avec vous maintenant ou dans 2h...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppConstants.primaryColor),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'La patiente recevra une notification push haute priorité avec votre message et le lien.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: (_isSending || _consultationId == null) ? null : _sendInvitation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSending
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Flexible(child: Text('Envoyer l\'invitation',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              overflow: TextOverflow.ellipsis)),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
