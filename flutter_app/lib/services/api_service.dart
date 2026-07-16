import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> predict({
    required double bpm,
    required double temperature,
    required double spo2,
    required int tensionSystolique,
    required int tensionDiastolique,
    required int contractions,
    required int semaine,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.predictEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bpm': bpm,
        'temperature': temperature,
        'spo2': spo2,
        'tension_systolique': tensionSystolique,
        'tension_diastolique': tensionDiastolique,
        'contractions_par_10min': contractions,
        'semaine_grossesse': semaine,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur API: ${response.statusCode}');
  }
}
