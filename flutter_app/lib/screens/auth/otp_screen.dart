import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  String _otp = '';
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'code': _otp}),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.pin, arguments: {
          'phone': widget.phone,
        });
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['erreur'] ?? 'Code invalide'),
            backgroundColor: AppConstants.criticalColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur de connexion au serveur'),
          backgroundColor: AppConstants.criticalColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppConstants.primaryColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.sms,
                  size: 80,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Code de vérification',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez le code reçu par SMS',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  onChanged: (v) => _otp = v,
                  onCompleted: (_) => _verifyOtp(),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 56,
                    fieldWidth: 48,
                    activeColor: AppConstants.primaryColor,
                    inactiveColor: Colors.grey[300]!,
                    selectedColor: AppConstants.secondaryColor,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.grey[50]!,
                    selectedFillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
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
                            'Vérifier',
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