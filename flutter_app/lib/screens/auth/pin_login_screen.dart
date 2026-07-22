import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class PinLoginScreen extends StatefulWidget {
  final String phone;
  const PinLoginScreen({super.key, required this.phone});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  bool _isLoading = false;
  bool _isSendingOtp = false;
  String? _errorMsg;

  Future<void> _forgotPin() async {
    setState(() => _isSendingOtp = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );

      setState(() => _isSendingOtp = false);

      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.otp, arguments: {
        'phone': widget.phone,
      });
    } catch (e) {
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur de connexion au serveur'),
          backgroundColor: AppConstants.criticalColor,
        ),
      );
    }
  }

  Future<void> _onPinComplete(String pin) async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/pin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'pin': pin}),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.patientHome,
          (route) => route.isFirst,
          arguments: {'phone': widget.phone},
        );
      } else {
        final body = jsonDecode(response.body);
        if (body['locked'] == true) {
          setState(() => _errorMsg = body['erreur']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['erreur'] ?? 'PIN incorrect'),
              backgroundColor: AppConstants.criticalColor,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur de connexion au serveur'),
          backgroundColor: AppConstants.criticalColor,
        ),
      );
    }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              if (_errorMsg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppConstants.criticalColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: AppConstants.criticalColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                            color: AppConstants.criticalColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              Icon(
                _errorMsg != null ? Icons.lock : Icons.lock_outline,
                size: 80,
                color: _errorMsg != null ? AppConstants.criticalColor : AppConstants.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Entrez votre code PIN',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.phone,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (_) {},
                onCompleted: _onPinComplete,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 64,
                  fieldWidth: 56,
                  activeColor: AppConstants.primaryColor,
                  inactiveColor: Colors.grey[300]!,
                  selectedColor: AppConstants.secondaryColor,
                  activeFillColor: Colors.white,
                  inactiveFillColor: Colors.grey[50]!,
                  selectedFillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                enableActiveFill: true,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isSendingOtp ? null : _forgotPin,
                child: _isSendingOtp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'PIN oublié ?',
                        style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 15,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const CircularProgressIndicator(color: AppConstants.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}