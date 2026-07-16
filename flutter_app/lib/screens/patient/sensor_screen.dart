import 'package:flutter/material.dart';

class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capteurs')),
      body: const Center(child: Text('Données capteurs temps réel')),
    );
  }
}
