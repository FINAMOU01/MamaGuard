import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  PdfReportService._();

  static final pw.Font _normal = pw.Font.helvetica();
  static final pw.Font _bold = pw.Font.helveticaBold();
  static final pw.Font _italic = pw.Font.helveticaOblique();

  static final PdfColor _rose = PdfColors.pink800;
  static final PdfColor _roseBg = PdfColor.fromInt(0xFFFFE4EC);
  static final PdfColor _red = PdfColors.red800;
  static final PdfColor _redBg = PdfColor.fromInt(0xFFFDECEA);
  static final PdfColor _orange = PdfColors.orange800;
  static final PdfColor _orangeBg = PdfColor.fromInt(0xFFFFF4E5);
  static final PdfColor _green = PdfColors.green700;
  static final PdfColor _greenBg = PdfColor.fromInt(0xFFE7F6EC);
  static final PdfColor _dark = PdfColor.fromInt(0xFF2D2D2D);
  static final PdfColor _grey = PdfColor.fromInt(0xFF757575);

  static PdfColor _riskColor(String? couleur) {
    switch (couleur) {
      case 'rouge':
      case 'critique':
        return _red;
      case 'orange':
      case 'surveillance':
        return _orange;
      default:
        return _green;
    }
  }

  static PdfColor _riskBg(String? couleur) {
    switch (couleur) {
      case 'rouge':
      case 'critique':
        return _redBg;
      case 'orange':
      case 'surveillance':
        return _orangeBg;
      default:
        return _greenBg;
    }
  }

  static String _riskLabel(String? score) {
    switch (score) {
      case 'Eleve':
      case 'danger':
        return 'Élevé';
      case 'Modere':
        return 'Modéré';
      default:
        return 'Normal';
    }
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} à ${two(dt.hour)}h${two(dt.minute)}';
  }

  static String _v(Object? v, [String suffix = '']) => v == null || v.toString().isEmpty ? '—' : '$v$suffix';

  // ---------------------------------------------------------------------------
  // boîte de dialogue : imprimer / partager
  // ---------------------------------------------------------------------------
  static Future<void> showPdfExportOptions(
    BuildContext context, {
    required String filename,
    required Uint8List bytes,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46, height: 5,
                decoration: BoxDecoration(color: const Color(0xFFF8BBD0), borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              const Text('Exporter le PDF',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
              const SizedBox(height: 6),
              const Text('Imprimez-le ou partagez-le à votre convenance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Printing.layoutPdf(onLayout: (_) async => bytes);
                      },
                      icon: const Icon(Icons.print_rounded, color: Color(0xFFE91E63)),
                      label: const Text('Imprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE91E63),
                        side: const BorderSide(color: Color(0xFFE91E63)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Printing.sharePdf(bytes: bytes, filename: filename);
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Partager'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rapports
  // ---------------------------------------------------------------------------
  static Future<Uint8List> buildAnalysisPdf({
    required String patientName,
    required Map<String, dynamic> result,
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();
    final dateStr = _formatDate(now);

    final score = result['score'] as String? ?? 'Normal';
    const couleur = 'vert';
    final riskColor = _riskColor(result['couleur'] as String? ?? couleur);
    final riskBg = _riskBg(result['couleur'] as String? ?? couleur);
    final params = (result['parametres_recus'] as Map?) ?? {};
    final details = (result['details'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final probs = (result['probabilites'] as Map?) ?? {};
    final analyseList = (result['analyse'] as List?)?.cast<String>() ?? [];
    final resume = result['resume'] as String? ?? '';
    final recommandation = result['recommandation'] as String? ?? '';
    final niveau = result['niveau_urgence'] as String? ?? '';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: _buildFooter,
        build: (_) => [
          _pageHeader('Rapport d\'analyse IA', 'Exported via MamaGuard'),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(patientName.isNotEmpty ? 'Patiente : $patientName' : 'Patiente',
                style: pw.TextStyle(font: _bold, fontSize: 12, color: _dark)),
              pw.Text(dateStr, style: pw.TextStyle(font: _normal, fontSize: 10, color: _grey)),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(color: riskBg, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Risque ${_riskLabel(score)}',
                  style: pw.TextStyle(font: _bold, fontSize: 18, color: riskColor)),
                if (niveau.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Niveau d\'urgence : ${niveau.replaceAll('_', ' ')}',
                    style: pw.TextStyle(font: _normal, fontSize: 11, color: riskColor)),
                ],
                if (result['confiance'] != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Confiance du modèle : ${result['confiance']}',
                    style: pw.TextStyle(font: _bold, fontSize: 11, color: _dark)),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _roseBg,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _vital('BPM', _v(params['bpm'])),
                _vital('SpO₂', _v(params['spo2'], '%')),
                _vital('Temp.', _v(params['temperature'], '°C')),
                _vital('Tension', _v(params['tension'])),
                _vital('Ctx', _v(params['contractions'])),
              ],
            ),
          ),
          if (resume.isNotEmpty || recommandation.isNotEmpty) ...[
            _sectionTitle('Analyse IA'),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: riskBg,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (resume.isNotEmpty)
                    pw.Text(resume, style: pw.TextStyle(font: _normal, fontSize: 10.5, color: _dark, lineSpacing: 2)),
                  if (recommandation.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text('Recommandation : $recommandation',
                      style: pw.TextStyle(font: _bold, fontSize: 10.5, color: riskColor, lineSpacing: 2)),
                  ],
                ],
              ),
            ),
          ],
          if (analyseList.isNotEmpty) ...[
            _sectionTitle('Détail de l\'analyse'),
            for (final line in analyseList)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('•  $line',
                  style: pw.TextStyle(font: _normal, fontSize: 10, color: _dark, lineSpacing: 2)),
              ),
          ],
          if (details.isNotEmpty) ...[
            _sectionTitle('Paramètres & statuts'),
            pw.TableHelper.fromTextArray(
              headers: ['Paramètre', 'Valeur', 'Statut'],
              data: details.map((d) => [
                d['parametre'] ?? '',
                d['valeur'] ?? '',
                d['statut'] ?? '',
              ]).toList(),
              headerStyle: pw.TextStyle(font: _bold, fontSize: 10, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: _rose),
              cellStyle: pw.TextStyle(font: _normal, fontSize: 9.5, color: _dark),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
              oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFF8FB)),
            ),
          ],
          if (probs.isNotEmpty) ...[
            _sectionTitle('Probabilités par classe'),
            for (final c in ['Normal', 'Modere', 'Eleve'])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(c == 'Modere' ? 'Modéré' : c == 'Eleve' ? 'Élevé' : 'Normal',
                      style: pw.TextStyle(font: _normal, fontSize: 11, color: _dark)),
                    pw.Text('${(probs[c] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
                      style: pw.TextStyle(font: _bold, fontSize: 11, color: _riskColor(result['couleur'] as String?))),
                  ],
                ),
              ),
          ],
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColor.fromInt(0xFFF0E3E9)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Ce rapport est généré automatiquement par MamaGuard à partir de mesures '
            'données par la patiente. Il ne remplace pas un avis médical professionnel.',
            style: pw.TextStyle(font: _italic, fontSize: 8.5, color: _grey, lineSpacing: 2),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> buildDossierPdf({
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> measures,
    required List<Map<String, dynamic>> alerts,
    required List<Map<String, dynamic>> journal,
    String doctorName = '',
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();

    final name = profile['name'] as String? ?? 'Patiente';
    final phone = profile['phone'] as String? ?? '';
    final hospital = profile['hospital'] as String? ?? '';
    final week = profile['pregnancy_week'] ?? 0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: _buildFooter,
        build: (_) => [
          _pageHeader('Dossier patiente', 'Document de consultation'),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _roseBg,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Patiente', name),
                if (phone.isNotEmpty) _infoRow('Téléphone', phone),
                if (hospital.isNotEmpty) _infoRow('Hôpital', hospital),
                if (week > 0) _infoRow('Semaine de grossesse', '$week'),
                if (doctorName.isNotEmpty) _infoRow('Médecin', doctorName),
                _infoRow('Généré le', _formatDate(now)),
              ],
            ),
          ),
          _sectionTitle('Mesures (${measures.length})'),
          if (measures.isEmpty) _emptyNote('Aucune mesure enregistrée'),
          for (final m in measures) _measureBlock(m),
          _sectionTitle('Alertes (${alerts.length})'),
          if (alerts.isEmpty) _emptyNote('Aucune alerte'),
          for (final a in alerts) _alertBlock(a),
          _sectionTitle('Journal de grossesse (${journal.length})'),
          if (journal.isEmpty) _emptyNote('Aucune note de journal'),
          for (final e in journal) _journalBlock(e),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // widgets PDF
  // ---------------------------------------------------------------------------
  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${ctx.pageNumber}/${ctx.pagesCount}  •  MamaGuard',
        style: pw.TextStyle(font: _normal, fontSize: 8, color: _grey),
      ),
    );
  }

  static pw.Widget _pageHeader(String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _rose,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: PdfColors.pink600, shape: pw.BoxShape.circle),
            child: pw.Text('🌺', style: pw.TextStyle(fontSize: 16)),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('MamaGuard',
                  style: pw.TextStyle(font: _bold, fontSize: 13, color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text(subtitle,
                  style: pw.TextStyle(font: _normal, fontSize: 9, color: PdfColors.pink100)),
                pw.SizedBox(height: 2),
                pw.Text(title,
                  style: pw.TextStyle(font: _bold, fontSize: 16, color: PdfColors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
      child: pw.Row(
        children: [
          pw.Container(width: 4, height: 14, decoration: pw.BoxDecoration(color: _rose, borderRadius: pw.BorderRadius.circular(2))),
          pw.SizedBox(width: 8),
          pw.Text(title, style: pw.TextStyle(font: _bold, fontSize: 13, color: _dark)),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
              style: pw.TextStyle(font: _normal, fontSize: 10, color: _grey)),
          ),
          pw.Expanded(
            child: pw.Text(value,
              style: pw.TextStyle(font: _bold, fontSize: 10, color: _dark)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _vital(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value,
          style: pw.TextStyle(font: _bold, fontSize: 12, color: _dark)),
        pw.Text(label,
          style: pw.TextStyle(font: _normal, fontSize: 8, color: _grey)),
      ],
    );
  }

  static pw.Widget _emptyNote(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(text,
        style: pw.TextStyle(font: _italic, fontSize: 10, color: _grey)),
    );
  }

  static pw.Widget _measureBlock(Map<String, dynamic> m) {
    final couleur = m['couleur'] as String? ?? 'normal';
    final analyse = (m['analyse'] as Map?) ?? {};
    final resume = analyse['resume'] as String? ?? '';
    final reco = analyse['recommandation'] as String? ?? '';
    final score = m['score'] as String? ?? '';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _riskColor(couleur), width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${m['date'] ?? ''} à ${m['heure'] ?? ''}',
                style: pw.TextStyle(font: _bold, fontSize: 10.5, color: _dark)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(color: _riskBg(couleur), borderRadius: pw.BorderRadius.circular(10)),
                child: pw.Text(_riskLabel(score),
                  style: pw.TextStyle(font: _bold, fontSize: 9, color: _riskColor(couleur))),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _vital('BPM', _v(m['bpm'])),
              _vital('SpO₂', _v(m['spo2'], '%')),
              _vital('Temp', _v(m['temperature'], '°C')),
              _vital('TA', '${m['tension_s'] ?? '—'}/${m['tension_d'] ?? '—'}'),
              _vital('Ctx', _v(m['contractions'], '/10min')),
            ],
          ),
          if (resume.isNotEmpty || reco.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: _riskBg(couleur), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (resume.isNotEmpty)
                    pw.Text('IA : $resume',
                      style: pw.TextStyle(font: _normal, fontSize: 9.5, color: _dark, lineSpacing: 2)),
                  if (reco.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text('→ $reco',
                      style: pw.TextStyle(font: _normal, fontSize: 9.5, color: _riskColor(couleur), lineSpacing: 2)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _alertBlock(Map<String, dynamic> a) {
    final alertes = (a['alertes'] as List?)?.cast<String>() ?? [];
    final score = a['score'] as String? ?? '';
    final vu = a['vu'] as bool? ?? false;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: vu ? PdfColor.fromInt(0xFFCCCCCC) : _red, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(score.isNotEmpty ? score : 'Alerte',
                style: pw.TextStyle(font: _bold, fontSize: 11, color: vu ? _grey : _red)),
              pw.Text(vu ? 'Traité' : 'En cours',
                style: pw.TextStyle(font: _bold, fontSize: 9, color: vu ? _green : _red)),
            ],
          ),
          for (final msg in alertes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text('•  $msg',
                style: pw.TextStyle(font: _normal, fontSize: 9.5, color: _dark, lineSpacing: 2)),
            ),
        ],
      ),
    );
  }

  static pw.Widget _journalBlock(Map<String, dynamic> e) {
    final feeling = e['feeling'] as String? ?? '';
    final text = e['text'] as String? ?? '';
    final date = e['date'] as String? ?? '';
    final week = (e['week'] as num?)?.toInt() ?? 0;
    final photos = (e['photos'] as List?)?.cast<String>() ?? [];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFFFDF6),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFF8BBD0), width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(date,
                style: pw.TextStyle(font: _bold, fontSize: 10.5, color: _rose)),
              if (week > 0)
                pw.Text('Semaine $week',
                  style: pw.TextStyle(font: _normal, fontSize: 9, color: _grey)),
            ],
          ),
          if (feeling.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(feeling, style: pw.TextStyle(fontSize: 18)),
          ],
          if (text.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(text,
              style: pw.TextStyle(font: _normal, fontSize: 10.5, color: _dark, lineSpacing: 2)),
          ],
          if (photos.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: photos.take(3).map(_journalPhoto).toList(),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _journalPhoto(String base64) {
    try {
      final bytes = base64Decode(base64);
      return pw.Container(
        width: 56,
        height: 56,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromInt(0xFFF8BBD0), width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Image(pw.MemoryImage(bytes), width: 56, height: 56, fit: pw.BoxFit.cover),
      );
    } catch (_) {
      return pw.SizedBox.shrink();
    }
  }
}