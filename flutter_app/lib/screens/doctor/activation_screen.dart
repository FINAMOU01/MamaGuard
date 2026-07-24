import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/routes.dart';

class DoctorActivationScreen extends StatefulWidget {
  final String phone;
  final String name;
  const DoctorActivationScreen({super.key, required this.phone, this.name = ''});

  @override
  State<DoctorActivationScreen> createState() => _DoctorActivationScreenState();
}

class _DoctorActivationScreenState extends State<DoctorActivationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _activate() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer les 6 chiffres du code'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/doctor/activate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'code': _code}),
      );
      final data = jsonDecode(r.body);
      if (!mounted) return;

      if (r.statusCode == 200 && data['succes'] == true) {
        Navigator.pushReplacementNamed(context, AppRoutes.doctorDashboard, arguments: {'phone': widget.phone});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['erreur'] ?? 'Code incorrect'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de connexion au serveur'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_rounded, size: 44, color: Colors.white),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Activation du compte',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'Saisissez le code reçu par SMS',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppConstants.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sms_rounded, size: 36, color: AppConstants.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Code d\'activation',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 8),
          Text(
            'Un code à 6 chiffres vous a été envoyé\npar SMS après validation de votre compte.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) => _buildCodeBox(i)),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _activate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text('Activer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 52,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focusNodes[index].hasFocus ? AppConstants.primaryColor : Colors.grey[200]!,
          width: _focusNodes[index].hasFocus ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
      ),
    );
  }
}
