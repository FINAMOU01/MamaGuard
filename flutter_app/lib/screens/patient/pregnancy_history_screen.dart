import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../services/pregnancy_service.dart';

class PregnancyHistoryScreen extends StatefulWidget {
  final String phone;
  const PregnancyHistoryScreen({super.key, required this.phone});

  @override
  State<PregnancyHistoryScreen> createState() => _PregnancyHistoryScreenState();
}

class _PregnancyHistoryScreenState extends State<PregnancyHistoryScreen> {
  bool _isLoading = true;
  List<PregnancyData> _pregnancies = [];
  String _activeId = '';

  @override
  void initState() {
    super.initState();
    _loadPregnancies();
  }

  Future<void> _loadPregnancies() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/pregnancy/list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['pregnancies'] as List? ?? []);
        setState(() {
          _pregnancies = list.map((p) {
            final data = PregnancyData.fromJson(p);
            final info = _calcInfo(data);
            return PregnancyData(
              id: data.id,
              status: data.status,
              pregnancyMethod: data.pregnancyMethod,
              lmpDate: data.lmpDate,
              manualWeek: data.manualWeek,
              referenceDate: data.referenceDate,
              dueDate: data.dueDate,
              actualBirthDate: data.actualBirthDate,
              doctorName: data.doctorName,
              doctorPhone: data.doctorPhone,
              isActive: data.isActive,
              createdAt: data.createdAt,
              info: info,
            );
          }).toList();
          _activeId = body['active_id'] ?? '';
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  PregnancyInfo? _calcInfo(PregnancyData p) {
    if (p.isCompleted) return null;
    final method = p.pregnancyMethod;
    DateTime? lmp;
    int? manualWeek;
    DateTime? refDate;
    if (method == 'lmp' && p.lmpDate.isNotEmpty) {
      lmp = DateTime.tryParse(p.lmpDate);
    } else if (method == 'manual') {
      manualWeek = p.manualWeek;
      if (p.referenceDate.isNotEmpty) {
        refDate = DateTime.tryParse(p.referenceDate);
      }
    }
    if ((method == 'lmp' && lmp == null) || (method == 'manual' && refDate == null && manualWeek == null)) {
      return null;
    }
    return PregnancyService.calculate(
      lmpDate: lmp,
      manualWeek: manualWeek,
      referenceDate: refDate,
      method: method,
    );
  }

  Future<void> _confirmEndPregnancy(PregnancyData preg) async {
    final birthDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      helpText: "Date d'accouchement",
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
      locale: const Locale('fr'),
    );
    if (birthDate == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation'),
        content: Text('Confirmez-vous que cette grossesse est terminée le ${PregnancyService.formatDate(birthDate)} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/pregnancy/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
          'pregnancy_id': preg.id,
          'birth_date': '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        }),
      );
      if (response.statusCode == 200) {
        _loadPregnancies();
      }
    } catch (_) {}
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
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                  : _buildContent(),
            ),
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
            top: 0, left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          const Column(
            children: [
              Icon(Icons.favorite_rounded, size: 48, color: Colors.white),
              SizedBox(height: 8),
              Text('Mon parcours', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              SizedBox(height: 4),
              Text('Mes grossesses', style: TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_pregnancies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Aucune grossesse enregistrée', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pregnancies.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('${_pregnancies.length} grossesse${_pregnancies.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
            ),
          );
        }
        final p = _pregnancies[i - 1];
        return _buildPregnancyCard(p);
      },
    );
  }

  Widget _buildPregnancyCard(PregnancyData p) {
    final isActive = p.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE91E63).withValues(alpha: 0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(p.isCompleted ? '👶' : '🤰', style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isActive ? 'Grossesse en cours' : 'Grossesse terminée',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isActive ? const Color(0xFFE91E63) : Colors.grey[600],
                      )),
                    if (p.info != null && p.info!.isValid)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('${p.info!.week} semaines • ${p.info!.trimester}e trimestre',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE91E63).withValues(alpha: 0.1) : Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'En cours' : 'Terminée',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: isActive ? const Color(0xFFE91E63) : Colors.green[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.doctorName.isNotEmpty)
            _buildInfoRow(Icons.person_outline_rounded, p.doctorName),
          if (p.dueDate.isNotEmpty && !p.isCompleted)
            _buildInfoRow(Icons.calendar_today_rounded, 'Naissance prévue : ${PregnancyService.formatDateStr(p.dueDate)}'),
          if (p.actualBirthDate.isNotEmpty && p.isCompleted)
            _buildInfoRow(Icons.celebration_rounded, 'Naissance : ${PregnancyService.formatDateStr(p.actualBirthDate)}'),
          if (p.lmpDate.isNotEmpty && !p.isCompleted)
            _buildInfoRow(Icons.date_range_rounded, 'DDR : ${PregnancyService.formatDateStr(p.lmpDate)}'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isActive)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmEndPregnancy(p),
                    icon: const Icon(Icons.child_care_rounded, size: 18),
                    label: const Text("J'ai accouché"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE91E63),
                      side: const BorderSide(color: Color(0xFFE91E63)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (!isActive) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewPregnancyDetails(p),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Voir le dossier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: const Color(0xFF2D2D2D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  void _viewPregnancyDetails(PregnancyData p) {
    // Read-only view of an archived pregnancy
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PregnancyDetailScreen(phone: widget.phone, pregnancy: p),
    ));
  }
}

class _PregnancyDetailScreen extends StatefulWidget {
  final String phone;
  final PregnancyData pregnancy;
  const _PregnancyDetailScreen({required this.phone, required this.pregnancy});

  @override
  State<_PregnancyDetailScreen> createState() => _PregnancyDetailScreenState();
}

class _PregnancyDetailScreenState extends State<_PregnancyDetailScreen> {
  late PregnancyData _pregnancy;

  @override
  void initState() {
    super.initState();
    _pregnancy = widget.pregnancy;
    _loadMeasures();
  }

  Future<void> _loadMeasures() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/pregnancy/measures'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
          'pregnancy_id': widget.pregnancy.id,
        }),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: Text('Grossesse terminée'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2D2D2D),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                      const SizedBox(width: 8),
                      const Text('Dossier archivé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_pregnancy.actualBirthDate.isNotEmpty)
                    _buildDetailRow('Date d\'accouchement', PregnancyService.formatDateStr(_pregnancy.actualBirthDate)),
                  if (_pregnancy.doctorName.isNotEmpty)
                    _buildDetailRow('Médecin', _pregnancy.doctorName),
                  if (_pregnancy.lmpDate.isNotEmpty)
                    _buildDetailRow('Date des dernières règles', PregnancyService.formatDateStr(_pregnancy.lmpDate)),
                  if (_pregnancy.dueDate.isNotEmpty)
                    _buildDetailRow('Date prévue', PregnancyService.formatDateStr(_pregnancy.dueDate)),
                  if (_pregnancy.createdAt.isNotEmpty)
                    _buildDetailRow('Début du suivi', _formatIsoDate(_pregnancy.createdAt)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Ce dossier est en lecture seule. Les mesures et analyses sont consultables dans l\'historique.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D))),
          ),
        ],
      ),
    );
  }

  String _formatIsoDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return PregnancyService.formatDate(dt);
    } catch (_) {
      return iso;
    }
  }
}
