import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class PinChangeScreen extends StatefulWidget {
  final String phone;
  const PinChangeScreen({super.key, required this.phone});

  @override
  State<PinChangeScreen> createState() => _PinChangeScreenState();
}

class _PinChangeScreenState extends State<PinChangeScreen> {
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  int _step = 0; // 0=old PIN, 1=new PIN, 2=confirm PIN
  String _oldPin = '';
  String _newPin = '';
  bool _isLoading = false;

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
    if (_step == 0) {
      setState(() {
        _oldPin = pin;
        _step = 1;
      });
      _resetControllers();
    } else if (_step == 1) {
      setState(() {
        _newPin = pin;
        _step = 2;
      });
      _resetControllers();
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
        _resetControllers();
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
          _resetControllers();
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
              Row(
                key: ValueKey(_step),
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
    );
  }
}