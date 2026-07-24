import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';

class DoctorPendingScreen extends StatelessWidget {
  final String name;
  final String status;
  final String? phone;

  const DoctorPendingScreen({
    super.key,
    required this.name,
    this.status = 'en_attente',
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCard(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                child: const Icon(Icons.hourglass_empty_rounded, size: 44, color: Colors.white),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Inscription en cours',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'Validation requise',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
            child: const Icon(Icons.access_time_rounded, size: 40, color: AppConstants.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Bonjour $name,',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre inscription a bien été reçue.\n'
            'Elle est actuellement en cours de validation\n'
            'par notre équipe administrative.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Color(0xFFE65100)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vous recevrez un SMS dès que votre compte sera activé.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFE65100), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                if (phone != null) {
                  Navigator.pushNamed(context, AppRoutes.doctorActivation, arguments: {'phone': phone, 'name': name});
                }
              },
              icon: const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 20),
              label: const Text('J\'ai reçu mon code', style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => route.isFirst);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
                side: const BorderSide(color: AppConstants.primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Retour à l\'accueil', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
