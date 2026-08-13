import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../services/pregnancy_service.dart';
import '../../widgets/patient_bottom_nav.dart';
import 'pregnancy_history_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? phone;
  const HomeScreen({super.key, this.phone});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _name = '';
  String _hospital = '';
  int _unreadCount = 0;
  String _pregnancyMethod = '';
  DateTime? _lmpDate;
  DateTime? _referenceDate;
  int _manualWeek = 0;
  PregnancyInfo? _pregnancyInfo;
  bool _hasActivePregnancy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotifications();
    _registerFcm();
  }

  Future<void> _registerFcm() async {
    if (widget.phone == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/patient/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': widget.phone, 'fcm_token': token}),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    if (widget.phone == null) return;
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['succes'] == true) {
          _unreadCount = data['unread'] as int? ?? 0;
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    if (widget.phone == null) return;
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final profile = data['profile'] as Map? ?? {};
        _name = (profile['name'] as String? ?? '').trim();
        _hospital = (profile['hospital'] as String? ?? '').trim();
        _pregnancyMethod = profile['pregnancy_method'] as String? ?? '';
        final lmp = profile['lmp_date'] as String?;
        if (lmp != null && lmp.isNotEmpty) {
          _lmpDate = DateTime.tryParse(lmp);
        }
        final ref = profile['reference_date'] as String?;
        if (ref != null && ref.isNotEmpty) {
          _referenceDate = DateTime.tryParse(ref);
        }
        _manualWeek = profile['manual_week'] as int? ?? 0;
        _hasActivePregnancy = profile['has_active_pregnancy'] as bool? ?? false;
        _recalculate();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _recalculate() {
    if (_pregnancyMethod == 'lmp') {
      _pregnancyInfo = PregnancyService.calculate(
        method: 'lmp',
        lmpDate: _lmpDate,
      );
    } else if (_pregnancyMethod == 'manual') {
      _pregnancyInfo = PregnancyService.calculate(
        method: 'manual',
        manualWeek: _manualWeek,
        referenceDate: _referenceDate,
      );
    } else {
      _pregnancyInfo = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildPregnancyCard(),
                    const SizedBox(height: 14),
                    _buildQuickInfo(),
                    const SizedBox(height: 20),
                    _buildMainAction(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Autres actions'),
                    const SizedBox(height: 12),
                    _buildSecondaryActions(),
                    const SizedBox(height: 20),
                    _buildPinChange(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PatientBottomNav(currentIndex: 0, phone: widget.phone ?? ''),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 8),
                Text('MamaGuard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.patientProfile, arguments: {'phone': widget.phone}),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.patientNotifications, arguments: {'phone': widget.phone}).then((_) => _loadNotifications());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB71C1C),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.pinChange, arguments: {'phone': widget.phone}),
          ),
        ],
      ),
    );
  }

  Widget _buildPregnancyCard() {
    final info = _pregnancyInfo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppConstants.backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 3))],
                ),
                child: Center(
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '👤',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppConstants.primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isNotEmpty ? 'Bonjour $_name' : 'Bonjour',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                    ),
                    if (widget.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.phone!, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (info != null && info.isValid) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppConstants.normalColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppConstants.normalColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Votre grossesse évolue normalement.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppConstants.normalColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('🤰', '${info.week} semaines de grossesse'),
            const SizedBox(height: 12),
            _buildInfoRow('🌸', '${info.trimester}e trimestre'),
            if (info.dueDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('📅', 'Naissance prévue : ${PregnancyService.formatDate(info.dueDate)}'),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.softPink.withValues(alpha: 0.2)),
              ),
              child: Text(
                info.message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5, fontStyle: FontStyle.italic),
              ),
            ),
            ] else ...[
            const SizedBox(height: 16),
            _TapScale(
              onTap: () => Navigator.pushNamed(context, AppRoutes.patientProfile, arguments: {'phone': widget.phone}),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Color(0xFFE91E63).withValues(alpha: 0.25), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('\u{2795}', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text('Commencer une nouvelle grossesse',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String text) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF8BBD0).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('🤰', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Semaine de grossesse', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(height: 2),
                      Text(
                        _pregnancyInfo != null && _pregnancyInfo!.isValid
                            ? '${_pregnancyInfo!.week} semaines'
                            : 'Non renseigné',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFF0F0F0)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF8BBD0).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('🏥', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hôpital', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(height: 2),
                      Text(
                        _hospital.isNotEmpty ? _hospital : 'Non renseigné',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainAction() {
    return _TapScale(
      onTap: () => Navigator.pushNamed(context, AppRoutes.patientInput, arguments: {'phone': widget.phone}),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFF06292)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18)),
              child: const Center(child: Text('❤️', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saisir mes mesures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Enregistrez vos paramètres de santé quotidiens.', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
    );
  }

  Widget _buildSecondaryActions() {
    final cards = [
      _ActionCardData(Icons.favorite_rounded, '🤰', 'Mon parcours', 'Toutes mes grossesses.', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PregnancyHistoryScreen(phone: widget.phone ?? ''),
        ));
      }),
      _ActionCardData(Icons.timeline_rounded, '📈', 'Historique', 'Consultez toutes vos anciennes mesures.', () {
        Navigator.pushNamed(context, AppRoutes.patientHistory, arguments: {'phone': widget.phone});
      }),
      _ActionCardData(Icons.videocam_rounded, '🎥', 'Téléconsultation', 'Demandez une consultation vidéo avec votre médecin.', () {
        Navigator.pushNamed(context, AppRoutes.patientConsultation, arguments: {'phone': widget.phone});
      }),
      _ActionCardData(Icons.notifications_active_rounded, '🔔', 'Rappel de consultation', 'Consultez vos prochains rendez-vous.', () {
        Navigator.pushNamed(context, AppRoutes.patientReminder, arguments: {'phone': widget.phone});
      }),
      _ActionCardData(Icons.medical_services_rounded, '👨‍⚕️', 'Mon médecin', 'Voir les informations de votre médecin traitant.', () {
        Navigator.pushNamed(context, AppRoutes.patientLinkDoctor, arguments: {'phone': widget.phone});
      }),
      _ActionCardData(Icons.health_and_safety_rounded, '🚨', 'Mes alertes sanitaires', 'Historique de vos alertes et leur suivi.', () {
        Navigator.pushNamed(context, AppRoutes.patientAlertHistory, arguments: {'phone': widget.phone});
      }),
    ];

    return Column(
      children: cards.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildActionCard(c),
      )).toList(),
    );
  }

  Widget _buildActionCard(_ActionCardData data) {
    return _TapScale(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: const Color(0xFFF8BBD0).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(data.emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
                  const SizedBox(height: 2),
                  Text(data.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPinChange() {
    return _TapScale(
      onTap: () => Navigator.pushNamed(context, AppRoutes.pinChange, arguments: {'phone': widget.phone}),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFE91E63)),
            const SizedBox(width: 8),
            const Text('Changer le code PIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE91E63))),
          ],
        ),
      ),
    );
  }
}

class _ActionCardData {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _ActionCardData(this.icon, this.emoji, this.title, this.subtitle, this.onTap);
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}