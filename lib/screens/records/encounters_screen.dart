import 'package:flutter/material.dart';
import '../../utils/app_localizations_ext.dart';
import '../../widgets/punjab_ui.dart';
import '../patient_file_screen.dart';
import '../patient_history_dashboard_screen.dart';

/// My Visits: timeline (PatientFileScreen) or category tabs (History dashboard).
class EncountersScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const EncountersScreen({super.key, required this.patient});

  @override
  State<EncountersScreen> createState() => _EncountersScreenState();
}

class _EncountersScreenState extends State<EncountersScreen> {
  /// 0 = single timeline file, 1 = category-wise history
  int _viewMode = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: PunjabPageHeader.screenInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PunjabPageHeader(
                title: l.tabMyVisits,
                subtitle: l.myVisitsSubtitle,
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Timeline'),
                    icon: Icon(Icons.view_agenda_outlined, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('By category'),
                    icon: Icon(Icons.dashboard_outlined, size: 18),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  setState(() => _viewMode = s.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return scheme.primaryContainer;
                    }
                    return scheme.surface;
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _viewMode == 0
              ? PatientFileScreen(
                  patient: widget.patient,
                  embedded: true,
                  autoLoad: true,
                )
              : PatientHistoryDashboardScreen(
                  patient: widget.patient,
                ),
        ),
      ],
    );
  }
}
