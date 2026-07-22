import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = '+237${_phoneController.text.trim()}';

      // Vérifier si un PIN existe déjà
      final checkResponse = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/pin/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (checkResponse.statusCode == 200) {
        final checkBody = jsonDecode(checkResponse.body);
        if (checkBody['exists'] == true) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          if (checkBody['is_locked'] == true) {
            _showError(checkBody['erreur'] ?? 'Compte verrouillé');
            return;
          }
          Navigator.pushNamed(context, AppRoutes.pinLogin, arguments: {
            'phone': phone,
          });
          return;
        }
      }

      // Pas de PIN → envoyer OTP
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      setState(() => _isLoading = false);

      final body = jsonDecode(response.body);
      final code = body['code'] as String?;

      if (body['succes'] == true) {
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.otp, arguments: {
          'phone': phone,
        });
      } else if (code != null) {
        if (!mounted) return;
        _showCodeDialog(phone, code);
      } else {
        _showError(body['erreur'] ?? 'Erreur lors de l\'envoi du code');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de connexion au serveur');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppConstants.criticalColor,
      ),
    );
  }

  void _showCodeDialog(String phone, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Code de vérification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SMS non envoyé (limite Twilio). Utilise ce code :'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: AppConstants.primaryColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.otp, arguments: {
                'phone': phone,
              });
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppConstants.primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.phone_android,
                  size: 80,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Bienvenue',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez votre numéro de téléphone\npour recevoir un code de vérification',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '🇨🇲',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '+237',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Numéro',
                          hintText: 'XX XX XX XX XX',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 8) {
                            return 'Numéro invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Envoyer le code',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
