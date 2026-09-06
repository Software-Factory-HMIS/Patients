import 'package:flutter/material.dart';

/// Placeholder for a full encounter “checkup” view; keeps IPD navigation working until the full screen is implemented.
class CheckUpScreen extends StatelessWidget {
  final Map<String, dynamic> patient;

  const CheckUpScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final eid =
        patient['encounterId'] ??
        patient['EncounterID'] ??
        patient['encounterID'];
    return Scaffold(
      appBar: AppBar(title: Text('Encounter ${eid ?? ""}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Encounter details for ID $eid are not yet available in this build.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
