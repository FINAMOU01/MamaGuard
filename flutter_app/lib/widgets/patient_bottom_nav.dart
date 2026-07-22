import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/routes.dart';

class PatientBottomNav extends StatelessWidget {
  final int currentIndex;
  final String phone;

  const PatientBottomNav({
    super.key,
    required this.currentIndex,
    required this.phone,
  });

  void _onTap(BuildContext context, int i) {
    if (i == currentIndex) return;
    final route = _routeForIndex(i);
    Navigator.pushReplacementNamed(context, route, arguments: {'phone': phone});
  }

  String _routeForIndex(int i) {
    switch (i) {
      case 0: return AppRoutes.patientHome;
      case 1: return AppRoutes.patientInput;
      case 2: return AppRoutes.patientSensor;
      case 3: return AppRoutes.patientHistory;
      case 4: return AppRoutes.patientProfile;
      default: return AppRoutes.patientHome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Accueil'),
      (Icons.edit_note_rounded, 'Saisie'),
      (Icons.sensors_rounded, 'Capteurs'),
      (Icons.timeline_rounded, 'Historique'),
      (Icons.person_rounded, 'Profil'),
    ];

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = i == currentIndex;
          return GestureDetector(
            onTap: () => _onTap(context, i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppConstants.softPink.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i].$1, size: 24, color: selected ? AppConstants.softPink : Colors.grey[400]),
                  const SizedBox(height: 2),
                  Text(items[i].$2, style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppConstants.softPink : Colors.grey[400],
                  )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}