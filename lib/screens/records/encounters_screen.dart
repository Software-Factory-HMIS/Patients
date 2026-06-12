import 'package:flutter/material.dart';
import '../../utils/app_localizations_ext.dart';
import '../../widgets/punjab_ui.dart';
import '../patient_file_screen.dart';

class EncountersScreen extends StatelessWidget {
  final Map<String, dynamic> patient;

  const EncountersScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: PunjabPageHeader.screenInsets,
          child: PunjabPageHeader(
            title: l.tabMyVisits,
            subtitle: l.myVisitsSubtitle,
          ),
        ),
        Expanded(
          child: PatientFileScreen(
            patient: patient,
            embedded: true,
            autoLoad: true,
          ),
        ),
      ],
    );
  }
}
