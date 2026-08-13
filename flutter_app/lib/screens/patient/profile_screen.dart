import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../services/pregnancy_service.dart';
import '../../widgets/patient_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  final String phone;
  const ProfileScreen({super.key, required this.phone});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _manualWeekController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _pregnancyMethod = '';
  DateTime? _lmpDate;
  DateTime? _referenceDate;
  int _manualWeek = 0;
  PregnancyInfo? _pregnancyInfo;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final profile = body['profile'] as Map?;
        if (profile != null) {
          _nameController.text = profile['name'] ?? '';
          _hospitalController.text = profile['hospital'] ?? '';
          _pregnancyMethod = profile['pregnancy_method'] ?? '';
          final lmp = profile['lmp_date'] as String?;
          if (lmp != null && lmp.isNotEmpty) {
            _lmpDate = DateTime.tryParse(lmp);
          }
          final ref = profile['reference_date'] as String?;
          if (ref != null && ref.isNotEmpty) {
            _referenceDate = DateTime.tryParse(ref);
          }
          _manualWeek = profile['manual_week'] as int? ?? 0;
          _manualWeekController.text = _manualWeek > 0 ? '$_manualWeek' : '';
          _recalculate();
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
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
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pregnancyMethod.isEmpty) {
      _showError('Veuillez choisir une méthode de suivi de grossesse');
      return;
    }
    if (_pregnancyMethod == 'manual') {
      final w = int.tryParse(_manualWeekController.text);
      if (w == null || w < 1 || w > 42) {
        _showError('La semaine doit être entre 1 et 42');
        return;
      }
      _manualWeek = w;
      _referenceDate = DateTime.now();
    }
    setState(() => _isSaving = true);
    try {
      final body = {
        'phone': widget.phone,
        'name': _nameController.text.trim(),
        'hospital': _hospitalController.text.trim(),
        'pregnancy_method': _pregnancyMethod,
        'lmp_date': _lmpDate?.toIso8601String().split('T')[0] ?? '',
        'manual_week': _manualWeek,
        'reference_date': _referenceDate?.toIso8601String().split('T')[0] ?? '',
      };
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      setState(() => _isSaving = false);
      if (response.statusCode == 200) {
        _recalculate();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil enregistré'),
            backgroundColor: AppConstants.normalColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      } else {
        final err = jsonDecode(response.body);
        _showError(err['erreur'] ?? 'Erreur');
      }
    } catch (_) {
      setState(() => _isSaving = false);
      _showError('Erreur de connexion');
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

  @override
  void dispose() {
    _nameController.dispose();
    _hospitalController.dispose();
    _manualWeekController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.softPink))
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildFormCard(),
                    ),
                  ),
                  PatientBottomNav(currentIndex: 4, phone: widget.phone),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.32,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 12,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _nameController.text.isNotEmpty
                          ? ClipOval(
                              child: Center(
                                child: Text(
                                  _nameController.text[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w600,
                                    color: AppConstants.softPink,
                                  ),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: AppConstants.softPink,
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: AppConstants.softPink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mon Profil',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gérez vos informations personnelles',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  icon: Icons.person_rounded,
                  label: 'Nom complet',
                  hint: 'Marie Claire Ndzi',
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  icon: Icons.local_hospital_rounded,
                  label: 'Hôpital habituel',
                  hint: 'Hôpital Central de Yaoundé',
                  controller: _hospitalController,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _buildPregnancySection(),
                if (_pregnancyInfo != null && _pregnancyInfo!.isValid) ...[
                  const SizedBox(height: 20),
                  _buildPregnancySummary(),
                ],
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.patientContacts,
                      arguments: {'phone': widget.phone},
                    ),
                    icon: const Icon(Icons.contact_emergency_rounded, size: 18, color: AppConstants.softPink),
                    label: const Text(
                      'Gérer les contacts d\'urgence',
                      style: TextStyle(color: AppConstants.softPink, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF06292).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Enregistrer les modifications',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPregnancySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.pregnant_woman_rounded, size: 22, color: AppConstants.primaryColor),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Suivi de grossesse',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          selected: _pregnancyMethod == 'lmp',
          title: 'Méthode recommandée',
          subtitle: 'Date des dernières règles',
          description: 'Cette information permettra à MamaGuard de calculer automatiquement votre semaine de grossesse ainsi que votre date probable d\'accouchement.',
          onTap: () => setState(() => _pregnancyMethod = 'lmp'),
          child: _pregnancyMethod == 'lmp' ? _buildLmpInput() : null,
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          selected: _pregnancyMethod == 'manual',
          title: 'Méthode alternative',
          subtitle: 'Je connais déjà ma semaine de grossesse',
          description: '',
          onTap: () => setState(() => _pregnancyMethod = 'manual'),
          child: _pregnancyMethod == 'manual' ? _buildManualInput() : null,
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required bool selected,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppConstants.backgroundColor.withValues(alpha: 0.3) : const Color(0xFFF8F8FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppConstants.primaryColor : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<String>(
                  value: title.contains('recommandée') ? 'lmp' : 'manual',
                  groupValue: _pregnancyMethod,
                  onChanged: (_) => onTap(),
                  activeColor: AppConstants.primaryColor,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppConstants.primaryColor : Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
                      ),
                    ],
                  ),
                ),
                if (title.contains('recommandée'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppConstants.normalColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Recommandé',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppConstants.normalColor),
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description,
                style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.4),
              ),
            ],
            if (child != null) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLmpInput() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _lmpDate ?? DateTime.now().subtract(const Duration(days: 80)),
          firstDate: DateTime.now().subtract(const Duration(days: 300)),
          lastDate: DateTime.now(),
          helpText: 'Premier jour des dernières règles',
          cancelText: 'Annuler',
          confirmText: 'Valider',
        );
        if (picked != null) {
          setState(() => _lmpDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 20, color: AppConstants.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _lmpDate != null
                    ? 'Premier jour des règles : ${PregnancyService.formatDate(_lmpDate)}'
                    : 'Tapez pour choisir la date',
                style: TextStyle(
                  fontSize: 14,
                  color: _lmpDate != null ? const Color(0xFF2D2D2D) : Colors.grey[400],
                  fontWeight: _lmpDate != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildManualInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            child: const Icon(Icons.looks_one_rounded, size: 22, color: AppConstants.primaryColor),
          ),
          Expanded(
            child: TextFormField(
              controller: _manualWeekController,
              keyboardType: TextInputType.number,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: 'Semaine actuelle',
                hintText: '18',
                counterText: '',
                labelStyle: const TextStyle(color: AppConstants.softPink, fontSize: 13, fontWeight: FontWeight.w600),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            child: Text('semaines', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }

  Widget _buildPregnancySummary() {
    final info = _pregnancyInfo!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.backgroundColor.withValues(alpha: 0.5),
            AppConstants.softPink.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.softPink.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppConstants.softPink.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Center(child: Text('🤰', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${info.week} semaines • ${info.trimester}e trimestre',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
                ),
                if (info.dueDate != null) ...[
                  const SizedBox(height: 2),
                  Text('Naissance prévue : ${PregnancyService.formatDate(info.dueDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: Color(0xFF2D2D2D), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[300], fontSize: 14),
          labelStyle: const TextStyle(color: AppConstants.softPink, fontSize: 13, fontWeight: FontWeight.w600),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(icon, color: AppConstants.softPink, size: 22),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppConstants.softPink, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(0, size.height, 40, size.height);
    path.lineTo(size.width - 40, size.height);
    path.quadraticBezierTo(size.width, size.height, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}