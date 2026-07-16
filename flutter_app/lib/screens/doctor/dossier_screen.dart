import 'package:flutter/material.dart';

class DossierScreen extends StatelessWidget {
  const DossierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dossier patiente')),
      body: const Center(child: Text('Dossier médical complet')),
    );
  }
}
