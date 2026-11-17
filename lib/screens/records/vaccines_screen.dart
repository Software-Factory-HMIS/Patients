import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../utils/app_date_format.dart';
import '../../utils/app_localizations_ext.dart';
import '../../utils/emr_api_client.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/punjab_ui.dart';

class VaccinesScreen extends StatefulWidget {
  final int patientId;

  const VaccinesScreen({super.key, required this.patientId});

  @override
  State<VaccinesScreen> createState() => _VaccinesScreenState();
}

class _VaccinesScreenState extends State<VaccinesScreen> {
  final _api = EmrApiClient();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final extras = await _api.getPatientSafeExtras(widget.patientId);
      final raw = extras['vaccines'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.vaccines)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PunjabColors.primary))
          : RefreshIndicator(
              color: PunjabColors.primary,
              onRefresh: _load,
              child: _failed
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        EmptyStateWidget(
                          icon: Icons.cloud_off_rounded,
                          title: l.vaccines,
                          message: l.recordsNotLoaded,
                          actionLabel: l.retry,
                          onAction: _load,
                        ),
                      ],
                    )
                  : _rows.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        EmptyStateWidget(
                          icon: Icons.vaccines_outlined,
                          title: l.noVaccinesYet,
                          message: l.noVaccinesMessage,
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final row = _rows[i];
                        final name = (row['vaccineName'] ?? row['VaccineName'] ?? l.vaccines)
                            .toString();
                        final when = row['givenAt'] ??
                            row['GivenAt'] ??
                            row['administeredDate'] ??
                            row['AdministeredDate'] ??
                            row['vaccineDate'] ??
                            row['date'];
                        final parsed = when == null
                            ? null
                            : (when is DateTime ? when : DateTime.tryParse(when.toString()));
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.vaccines, color: PunjabColors.primary),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: parsed == null
                                ? null
                                : Text(AppDateFormat.formatDate(parsed)),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
