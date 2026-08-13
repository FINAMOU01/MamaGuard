import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class PinScreen extends StatefulWidget {
  final String phone;
  final String role;
  const PinScreen({super.key, required this.phone, this.role = 'patient'});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isConfirmStep = false;
  String _firstPin = '';
  String _confirmPin = '';

  @override
  void initState() {
    super.initState();
    for (final fn in _focusNodes) {
      fn.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final fn in _focusNodes) {
      fn.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetControllers() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      _controllers[index].text = value.substring(value.length - 1);
      _controllers[index].selection = TextSelection.collapsed(offset: 1);
    }
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length == 4) {
      _focusNodes[3].unfocus();
      _onPinComplete(pin);
    }
  }

  Future<void> _onPinComplete(String pin) async {
    if (!_isConfirmStep) {
      setState(() {
        _firstPin = pin;
        _isConfirmStep = true;
      });
      _resetControllers();
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
        _resetControllers();
        return;
      }

      setState(() => _isLoading = true);

      try {
        final endpoint = widget.role == 'doctor' ? '/doctor/pin/create' : '/pin/create';
        final response = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': widget.phone, 'pin': pin}),
        );

        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('${widget.role}_phone', widget.phone);
          if (!mounted) return;
          final homeRoute = widget.role == 'doctor' ? AppRoutes.doctorDashboard : AppRoutes.patientHome;
          Navigator.pushNamedAndRemoveUntil(
            context,
            homeRoute,
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
        child: SingleChildScrollView(
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
                Row(
                  key: ValueKey(_isConfirmStep),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final isFocused = _focusNodes[i].hasFocus;
                    final hasText = _controllers[i].text.isNotEmpty;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: i < 3 ? 8.0 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        clipBehavior: Clip.antiAlias,
                        width: 60,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isFocused ? AppConstants.softPink : Colors.grey[300]!,
                            width: isFocused ? 2 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isFocused
                                  ? AppConstants.softPink.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: isFocused ? 12 : 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D2D2D),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(bottom: 4),
                            hintText: hasText ? '' : '•',
                            hintStyle: TextStyle(fontSize: 24, color: Colors.grey[300]),
                          ),
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      ),
                    );
                  }),
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