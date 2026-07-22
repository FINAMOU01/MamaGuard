import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class PinScreen extends StatefulWidget {
  final String phone;
  const PinScreen({super.key, required this.phone});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isConfirmStep = false;
  String _firstPin = '';
  String _confirmPin = '';

  Future<void> _onPinComplete(String pin) async {
    if (!_isConfirmStep) {
      setState(() {
        _firstPin = pin;
        _isConfirmStep = true;
      });
    } else {
      _confirmPin = pin;
      if (_firstPin != _confirmPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Les codes PIN ne correspondent pas'),
            backgroundColor: AppConstants.criticalColor,
          ),
        );
        setState(() {
          _isConfirmStep = false;
          _firstPin = '';
          _confirmPin = '';
        });
        return;
      }

      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/pin/create'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['erreur'] ?? 'Erreur'),
              backgroundColor: AppConstants.criticalColor,
            ),
          );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code PIN'),
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
                  _isConfirmStep ? Icons.lock_outline : Icons.lock_open,
                  size: 80,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  _isConfirmStep ? 'Confirmer le code PIN' : 'Créer un code PIN',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isConfirmStep
                      ? 'Rentrez à nouveau le code à 4 chiffres'
                      : 'Choisissez un code secret à 4 chiffres',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                PinCodeTextField(
                  appContext: context,
                  length: 4,
                  key: ValueKey(_isConfirmStep),
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
                const SizedBox(height: 32),
                if (_isLoading)
                  const CircularProgressIndicator(color: AppConstants.primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}