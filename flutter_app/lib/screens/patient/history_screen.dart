import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../widgets/patient_bottom_nav.dart';

class HistoryScreen extends StatefulWidget {
  final String phone;
  const HistoryScreen({super.key, required this.phone});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List _mesures = [];
  int _selectedChart = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/measure/history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() => _mesures = (body['mesures'] as List? ?? []).reversed.toList());
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  List<FlSpot> _spots(String key) {
    return List.generate(_mesures.length, (i) {
      final v = (_mesures[i][key] as num?)?.toDouble() ?? 0;
      return FlSpot(i.toDouble(), v);
    });
  }

  Widget _buildChart() {
    if (_mesures.isEmpty) {
      return const Center(child: Text('Aucune mesure', style: TextStyle(color: Colors.grey)));
    }

    final labels = [_mesures.length - 1, _mesures.length ~/ 2, 0];
    final colors = [
      [AppConstants.softPink, AppConstants.secondaryColor],
      [AppConstants.warningColor, AppConstants.criticalColor],
      [Colors.blue, Colors.lightBlue],
      [Colors.purple, Colors.deepPurple],
      [Colors.orange, Colors.deepOrange],
    ];

    final chartConfigs = [
      ('BPM', 'bpm', 140.0, 50.0),
      ('SpO₂', 'spo2', 100.0, 85.0),
      ('Tension sys.', 'tension_s', 160.0, 80.0),
      ('Tension dia.', 'tension_d', 100.0, 50.0),
      ('Température', 'temperature', 40.0, 35.0),
    ];

    final cfg = chartConfigs[_selectedChart];
    final spots = _spots(cfg.$2);

    // Bornes dynamiques : couvrent toujours toutes les valeurs avec une marge
    final dataMin = spots.isEmpty ? cfg.$4 : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final dataMax = spots.isEmpty ? cfg.$3 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final margin = (dataMax - dataMin) * 0.15 + 1;
    final minY = dataMin - margin < cfg.$4 ? dataMin - margin : cfg.$4;
    final maxY = dataMax + margin > cfg.$3 ? dataMax + margin : cfg.$3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.grey[100]!,
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (_) => const FlLine(color: Colors.transparent),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i >= 0 && i < _mesures.length && labels.contains(i)) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _mesures[i]['date']?.toString().substring(5) ?? '',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: minY,
              maxY: maxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    '${cfg.$1}: ${s.y.toInt()}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  )).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: colors[_selectedChart][0],
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 3,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: colors[_selectedChart][0],
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colors[_selectedChart][0].withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.softPink))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildContent(),
                    ),
            ),
            PatientBottomNav(currentIndex: 3, phone: widget.phone),
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
          Column(
            children: [
              const Icon(Icons.timeline_rounded, size: 48, color: Colors.white),
              const SizedBox(height: 8),
              const Text('Historique', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              Text('7 jours de mesures', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final chartLabels = ['BPM', 'SpO₂', 'Tension sys.', 'Tension dia.', 'Température'];
    final chartIcons = [Icons.favorite_rounded, Icons.air_rounded, Icons.arrow_upward_rounded, Icons.arrow_downward_rounded, Icons.thermostat_rounded];

    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: chartLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final selected = i == _selectedChart;
              return GestureDetector(
                onTap: () => setState(() => _selectedChart = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppConstants.softPink : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selected ? [] : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(chartIcons[i], size: 16, color: selected ? Colors.white : AppConstants.softPink),
                      const SizedBox(width: 6),
                      Text(chartLabels[i], style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF2D2D2D),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: _buildChart(),
        ),
        const SizedBox(height: 16),
        if (_mesures.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dernières mesures', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
                const SizedBox(height: 12),
                ..._mesures.take(5).map((m) => _buildMeasureRow(m)),
              ],
            ),
          ),
        ],
        if (_mesures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: Color(0xFFE91E63)),
                    SizedBox(width: 8),
                    Text('Résultats d\'analyse', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
                  ],
                ),
                const SizedBox(height: 12),
                ..._mesures.take(15).map((m) => _buildAnalysisRow(m)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAnalysisRow(Map m) {
    Color dotColor;
    String label;
    switch (m['couleur']) {
      case 'rouge':
        dotColor = AppConstants.criticalColor;
        label = 'Critique';
      case 'orange':
        dotColor = AppConstants.warningColor;
        label = 'Surveillance';
      default:
        dotColor = AppConstants.normalColor;
        label = 'Normal';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dotColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dotColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dotColor)),
                ),
                const Spacer(),
                Text('${m['date']} à ${m['heure']}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMiniStat('BPM', '${m['bpm']}', dotColor),
                _buildMiniStat('SpO₂', '${m['spo2']}%', dotColor),
                _buildMiniStat('TA', '${m['tension_s']}/${m['tension_d']}', dotColor),
                _buildMiniStat('Temp', '${m['temperature']}°C', dotColor),
              ],
            ),
            if (m['score'] != null && m['score'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Analyse : ${m['score']}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildMeasureRow(Map m) {
    Color dotColor;
    switch (m['couleur']) {
      case 'rouge': dotColor = AppConstants.criticalColor;
      case 'orange': dotColor = AppConstants.warningColor;
      default: dotColor = AppConstants.normalColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m['date']} à ${m['heure']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D))),
                Text('BPM ${m['bpm']} · SpO₂ ${m['spo2']}% · Tension ${m['tension_s']}/${m['tension_d']} · Temp ${m['temperature']}°C', 
                     style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(m['score'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dotColor)),
        ],
      ),
    );
  }

}
