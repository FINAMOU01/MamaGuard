import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../widgets/patient_bottom_nav.dart';

class SensorScreen extends StatefulWidget {
  final String phone;
  const SensorScreen({super.key, required this.phone});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  bool _isMonitoring = false;
  bool _isAnalyzing = false;
  int _pregnancyWeek = 0;
  Timer? _timer;

  final _bpm = ValueNotifier<double>(0);
  final _spo2 = ValueNotifier<double>(0);
  final _temp = ValueNotifier<double>(0);
  final _fsr = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _loadPregnancyWeek();
  }

  Future<void> _loadPregnancyWeek() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _pregnancyWeek = (body['profile']?['pregnancy_week'] as int?) ?? 0;
      }
    } catch (_) {}
  }

  Future<void> _fetchLiveVitals() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/vitals/live'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final v = data['vitals'] as Map? ?? {};
        final bpm = (v['bpm'] as num?)?.toDouble() ?? 0;
        final spo2 = (v['spo2'] as num?)?.toDouble() ?? 0;
        final temp = (v['temperature'] as num?)?.toDouble() ?? 0;
        final ctx = (v['contractions_par_10min'] as num?)?.toDouble() ?? 0;
        if (bpm > 0) _bpm.value = bpm;
        if (spo2 > 0) _spo2.value = spo2;
        if (temp > 0) _temp.value = temp;
        _fsr.value = ctx;
      }
    } catch (_) {}
  }

  Future<void> _analyze() async {
    if (_bpm.value == 0) {
      _showError('Démarrez le moniteur d\'abord');
      return;
    }
    setState(() => _isAnalyzing = true);

    int tensionS = 0;
    int tensionD = 0;
    int contractions = _fsr.value.round();
    try {
      final manualResp = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/manual-measure'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (manualResp.statusCode == 200) {
        final manual = jsonDecode(manualResp.body)['pending_manual'] as Map? ?? {};
        tensionS = (manual['tension_s'] as num?)?.toInt() ?? 0;
        tensionD = (manual['tension_d'] as num?)?.toInt() ?? 0;
        final manualCtx = (manual['contractions'] as num?)?.toInt() ?? 0;
        if (manualCtx > 0) contractions = manualCtx;
      }
    } catch (_) {}

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bpm': _bpm.value.round(),
          'temperature': double.parse(_temp.value.toStringAsFixed(1)),
          'spo2': _spo2.value.round(),
          'tension_systolique': tensionS,
          'tension_diastolique': tensionD,
          'contractions_par_10min': contractions,
          'semaine_grossesse': _pregnancyWeek,
        }),
      );
      setState(() => _isAnalyzing = false);
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _saveMeasure(result, tensionS, tensionD, contractions);
        http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/patient/manual-measure/clear'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': widget.phone}),
        );
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.patientScore, arguments: {
          'phone': widget.phone,
          'result': result,
        });
      } else {
        _showError('Erreur lors de l\'analyse');
      }
    } catch (_) {
      setState(() => _isAnalyzing = false);
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

  void _saveMeasure(Map result, int tensionS, int tensionD, int contractions) {
    http.post(
      Uri.parse('${AppConstants.apiBaseUrl}/patient/measure/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': widget.phone,
        'date': result['date'] ?? '',
        'heure': result['heure'] ?? '',
        'bpm': _bpm.value.round(),
        'temperature': double.parse(_temp.value.toStringAsFixed(1)),
        'spo2': _spo2.value.round(),
        'tension_s': tensionS,
        'tension_d': tensionD,
        'contractions': contractions,
        'semaine': _pregnancyWeek,
        'score': result['score'] ?? '',
        'couleur': result['couleur'] ?? '',
      }),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bpm.dispose();
    _spo2.dispose();
    _temp.dispose();
    _fsr.dispose();
    super.dispose();
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _timer?.cancel();
      setState(() => _isMonitoring = false);
    } else {
      setState(() => _isMonitoring = true);
      _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
        await _fetchLiveVitals();
      });
    }
  }

  Color _getBpmColor(double v) => v >= 60 && v <= 100 ? AppConstants.normalColor
      : v > 100 || v < 50 ? AppConstants.criticalColor
      : AppConstants.warningColor;

  Color _getSpo2Color(double v) => v >= 95 ? AppConstants.normalColor
      : v >= 90 ? AppConstants.warningColor
      : AppConstants.criticalColor;

  Color _getTempColor(double v) => v >= 36.5 && v <= 37.5 ? AppConstants.normalColor
      : v > 38 || v < 36 ? AppConstants.criticalColor
      : AppConstants.warningColor;

  Color _getFsrColor(double v) => v < 40 ? AppConstants.normalColor
      : v < 70 ? AppConstants.warningColor
      : AppConstants.criticalColor;

  double _toPercent(double value, double max) => (value / max).clamp(0.0, 1.0);

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: _buildSensorGrid(),
              ),
            ),
            PatientBottomNav(currentIndex: 2, phone: widget.phone),
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
              const Icon(Icons.favorite_rounded, size: 48, color: Colors.white),
              const SizedBox(height: 8),
              const Text(
                'Moniteur temps réel',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              Text(
                _isMonitoring ? 'Lecture des capteurs en cours...' : 'Appuyez pour démarrer',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.9,
              children: [
                _buildSensorCard(
                  icon: Icons.favorite_rounded,
                  label: 'BPM',
                  unit: 'bpm',
                  valueNotifier: _bpm,
                  formatValue: (v) => v.toStringAsFixed(0),
                  colorFn: _getBpmColor,
                  maxVal: 160,
                ),
                _buildSensorCard(
                  icon: Icons.air_rounded,
                  label: 'SpO₂',
                  unit: '%',
                  valueNotifier: _spo2,
                  formatValue: (v) => v.toStringAsFixed(0),
                  colorFn: _getSpo2Color,
                  maxVal: 100,
                ),
                _buildSensorCard(
                  icon: Icons.thermostat_rounded,
                  label: 'Température',
                  unit: '°C',
                  valueNotifier: _temp,
                  formatValue: (v) => v.toStringAsFixed(1),
                  colorFn: _getTempColor,
                  maxVal: 40,
                ),
                _buildSensorCard(
                  icon: Icons.timeline_rounded,
                  label: 'FSR',
                  unit: '',
                  valueNotifier: _fsr,
                  formatValue: (v) => v.toStringAsFixed(0),
                  colorFn: _getFsrColor,
                  maxVal: 100,
                ),
              ],
            ),
          const SizedBox(height: 8),
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF06292).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Analyser mes signes',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: _isMonitoring
                  ? null
                  : const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
              color: _isMonitoring ? Colors.grey[200] : null,
              boxShadow: _isMonitoring
                  ? []
                  : [BoxShadow(
                      color: const Color(0xFFF06292).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )],
            ),
            child: ElevatedButton(
              onPressed: _toggleMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: _isMonitoring ? Colors.grey[600] : Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isMonitoring ? 'Arrêter le moniteur' : 'Démarrer le moniteur',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _isMonitoring ? Colors.grey[600] : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String label,
    required String unit,
    required ValueNotifier<double> valueNotifier,
    required String Function(double) formatValue,
    required Color Function(double) colorFn,
    required double maxVal,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
        final color = value > 0 ? colorFn(value) : Colors.grey[300]!;
        final percent = value > 0 ? _toPercent(value, maxVal) : 0.0;
        return Container(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: percent,
                        strokeWidth: 5,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isMonitoring ? color : Colors.grey[300]!,
                        ),
                      ),
                    ),
                    Icon(
                      icon,
                      size: 26,
                      color: _isMonitoring ? color : Colors.grey[300],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  value > 0 ? '${formatValue(value)} $unit'.trim() : '-- $unit'.trim(),
                  key: ValueKey(value),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _isMonitoring ? color : Colors.grey[300],
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
