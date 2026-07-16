import 'package:flutter/material.dart';

class ManualInputScreen extends StatelessWidget {
  const ManualInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saisie manuelle')),
      body: const Center(child: Text('Formulaire de saisie manuelle')),
    );
  }
}
