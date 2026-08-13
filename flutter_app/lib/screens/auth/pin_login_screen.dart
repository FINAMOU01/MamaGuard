import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class PinLoginScreen extends StatefulWidget {
  final String phone;
  final String role;
  const PinLoginScreen({super.key, required this.phone, this.role = 'patient'});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  bool _isLoading = false;
  bool _isSendingOtp = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      _focusNodes[i].addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    for (final fn in _focusNodes) {
      fn.removeListener(_onFocusChange);
      fn.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
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



  Future<void> _forgotPin() async {
    setState(() => _isSendingOtp = true);

    try {
      await http.post(
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
      final endpoint = widget.role == 'doctor' ? '/doctor/pin/login' : '/pin/login';
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
        child: SingleChildScrollView(
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
              Row(
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
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('${widget.role}_phone');
                  if (!mounted) return;
                  final loginRoute = widget.role == 'doctor' ? AppRoutes.doctorLogin : AppRoutes.login;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    loginRoute,
                    (route) => false,
                  );
                },
                child: Text(
                  'Ce n\'est pas moi',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
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