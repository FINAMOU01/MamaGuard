import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

/// Gère la persistance locale des mesures quand le réseau est indisponible.
///
/// - Les mesures analysées hors-ligne sont stockées ici.
/// - [syncPendingMeasures] les renvoie à l'API dès que le réseau revient.
class OfflineMeasureService {
  static const _pendingKey = 'pending_measures';
  static const _lastVitalsKey = 'last_vitals';

  // ─── Mesures en attente de synchronisation ─────────────────────────────

  static Future<void> savePendingMeasure(Map<String, dynamic> measure) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = jsonDecode(prefs.getString(_pendingKey) ?? '[]') as List;
      list.add(measure);
      await prefs.setString(_pendingKey, jsonEncode(list));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getPendingMeasures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = jsonDecode(prefs.getString(_pendingKey) ?? '[]') as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _setPendingMeasures(List<Map<String, dynamic>> measures) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, jsonEncode(measures));
    } catch (_) {}
  }

  /// Tente d'envoyer toutes les mesures en attente à l'API.
  /// Retourne le nombre de mesures synchronisées.
  static Future<int> syncPendingMeasures(String phone) async {
    final pending = await getPendingMeasures();
    if (pending.isEmpty) return 0;

    var synced = 0;
    final remaining = <Map<String, dynamic>>[];

    for (final m in pending) {
      try {
        final response = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/patient/measure/save'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({...m, 'phone': phone}),
        );
        if (response.statusCode == 200) {
          synced++;
        } else {
          remaining.add(m);
        }
      } catch (_) {
        remaining.add(m);
      }
    }

    await _setPendingMeasures(remaining);
    return synced;
  }

  // ─── Dernières valeurs temps réel (cache) ──────────────────────────────

  static Future<void> saveLastVitals(Map<String, dynamic> vitals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastVitalsKey, jsonEncode(vitals));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getLastVitals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastVitalsKey);
      if (raw == null) return {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Vérifie rapidement si l'API est joignable.
  /// Toute réponse HTTP (même 404) signifie que le serveur est accessible.
  static Future<bool> isOnline() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConstants.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode > 0;
    } catch (_) {
      return false;
    }
  }
}
