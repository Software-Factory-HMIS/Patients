import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../models/portal_models.dart';
import '../../services/patient_portal_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../../utils/app_localizations_ext.dart';
import '../../widgets/punjab_ui.dart';

class PrescriptionsScreen extends StatefulWidget {
  final int patientId;

  const PrescriptionsScreen({super.key, required this.patientId});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen>
    with SingleTickerProviderStateMixin {
  final _portal = PatientPortalService();
  late TabController _tabController;
  List<PrescriptionItem> _history = [];
  bool _loading = true;
  String? _error;

  List<PrescriptionItem> get _active =>
      _history.where((rx) => rx.isActive).toList();

  List<PrescriptionItem> get _discontinued =>
      _history.where((rx) => !rx.isActive).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _portal.loadPrescriptionHistory(widget.patientId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildList(List<PrescriptionItem> items, {required bool activeTab}) {
    final l = context.l10n;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyStateWidget(
            icon: Icons.medication_outlined,
            title: activeTab ? l.noActivePrescriptionsHistory : l.noDiscontinuedPrescriptions,
            message: activeTab
                ? l.noActivePrescriptionsHistoryMessage
                : l.noDiscontinuedPrescriptionsMessage,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _PrescriptionHistoryCard(
        rx: items[i],
        showActiveBadge: activeTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.prescriptionHistory),
        bottom: TabBar(
          controller: _tabController,
          labelColor: PunjabColors.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: PunjabColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: '${l.tabActive} (${_active.length})'),
            Tab(text: '${l.tabDiscontinued} (${_discontinued.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PunjabColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const Gap(16),
                      FilledButton(onPressed: _load, child: Text(l.retry)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: PunjabColors.primary,
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_active, activeTab: true),
                      _buildList(_discontinued, activeTab: false),
                    ],
                  ),
                ),
    );
  }
}

class _PrescriptionHistoryCard extends StatelessWidget {
  final PrescriptionItem rx;
  final bool showActiveBadge;

  const _PrescriptionHistoryCard({
    required this.rx,
    required this.showActiveBadge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeColor = showActiveBadge ? PunjabColors.success : PunjabColors.textSecondary;
    final badgeLabel = showActiveBadge ? 'Active' : 'Discontinued';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PunjabColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication_rounded, color: PunjabColors.primary, size: 22),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        rx.medication,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (rx.frequency != null && rx.frequency!.isNotEmpty)
                      _Meta(icon: Icons.schedule_rounded, label: rx.frequency!),
                    if (rx.startDate != null && rx.startDate!.isNotEmpty)
                      _Meta(icon: Icons.event_rounded, label: 'Start: ${rx.startDate}'),
                    if (rx.dosage != null && rx.dosage!.isNotEmpty)
                      _Meta(icon: Icons.medication_outlined, label: rx.dosage!),
                  ],
                ),
                if (rx.discontinuedDate != null && rx.discontinuedDate!.isNotEmpty) ...[
                  const Gap(6),
                  Text(
                    'Discontinued: ${rx.discontinuedDate}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
                if (rx.indication != null && rx.indication!.trim().isNotEmpty) ...[
                  const Gap(6),
                  Text(
                    rx.indication!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.onSurfaceVariant),
        const Gap(4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
