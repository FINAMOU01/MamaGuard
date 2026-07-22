import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class PinChangeScreen extends StatefulWidget {
  final String phone;
  const PinChangeScreen({super.key, required this.phone});

  @override
  State<PinChangeScreen> createState() => _PinChangeScreenState();
}

class _PinChangeScreenState extends State<PinChangeScreen> {
  int _step = 0; // 0=old PIN, 1=new PIN, 2=confirm PIN
  String _oldPin = '';
  String _newPin = '';
  bool _isLoading = false;

  Future<void> _onPinComplete(String pin) async {
    if (_step == 0) {
      setState(() {
        _oldPin = pin;
        _step = 1;
      });
    } else if (_step == 1) {
      setState(() {
        _newPin = pin;
        _step = 2;
      });
    } else {
      if (pin != _newPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Les nouveaux PIN ne correspondent pas'),
            backgroundColor: AppConstants.criticalColor,
          ),
        );
        setState(() {
          _step = 1;
          _newPin = '';
        });
        return;
      }

      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/pin/change'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': widget.phone,
            'old_pin': _oldPin,
            'new_pin': _newPin,
          }),
        );

        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code PIN changé avec succès'),
              backgroundColor: AppConstants.normalColor,
            ),
          );
          Navigator.pop(context);
        } else {
          final body = jsonDecode(response.body);
          setState(() {
            _step = 0;
            _oldPin = '';
            _newPin = '';
          });
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

  String get _title {
    switch (_step) {
      case 0:
        return 'Ancien code PIN';
      case 1:
        return 'Nouveau code PIN';
      case 2:
        return 'Confirmer le nouveau PIN';
      default:
        return '';
    }
  }

  String get _subtitle {
    switch (_step) {
      case 0:
        return 'Entrez votre code PIN actuel';
      case 1:
        return 'Choisissez un nouveau code à 4 chiffres';
      case 2:
        return 'Rentrez à nouveau le nouveau code';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changer le PIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppConstants.primaryColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(
                _step == 0 ? Icons.lock_outline : Icons.lock_reset,
                size: 80,
                color: AppConstants.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                _title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              PinCodeTextField(
                appContext: context,
                length: 4,
                key: ValueKey(_step),
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
    );
  }
}