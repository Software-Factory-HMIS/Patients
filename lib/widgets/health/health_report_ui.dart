import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../models/portal_models.dart';
import '../../utils/app_date_format.dart';
import '../punjab_ui.dart';

/// Next.js-inspired health report theming (cyan lab, indigo radiology, emerald Rx).
class HealthReportTheme {
  final Color accent;
  final Color surface;
  final Color border;
  final Color onAccent;

  const HealthReportTheme({
    required this.accent,
    required this.surface,
    required this.border,
    required this.onAccent,
  });

  static HealthReportTheme lab(BuildContext context, {bool dark = false}) {
    if (dark) {
      return const HealthReportTheme(
        accent: Color(0xFF22D3EE),
        surface: Color(0xFF0C2A33),
        border: Color(0xFF155E75),
        onAccent: Color(0xFFA5F3FC),
      );
    }
    return const HealthReportTheme(
      accent: Color(0xFF0891B2),
      surface: Color(0xFFECFEFF),
      border: Color(0xFFA5F3FC),
      onAccent: Color(0xFF0E7490),
    );
  }

  static HealthReportTheme radiology(BuildContext context, {bool dark = false}) {
    if (dark) {
      return const HealthReportTheme(
        accent: Color(0xFF818CF8),
        surface: Color(0xFF1E1B4B),
        border: Color(0xFF3730A3),
        onAccent: Color(0xFFC7D2FE),
      );
    }
    return const HealthReportTheme(
      accent: Color(0xFF4F46E5),
      surface: Color(0xFFEEF2FF),
      border: Color(0xFFC7D2FE),
      onAccent: Color(0xFF4338CA),
    );
  }

  static HealthReportTheme prescription(BuildContext context, {bool dark = false}) {
    if (dark) {
      return const HealthReportTheme(
        accent: Color(0xFF34D399),
        surface: Color(0xFF052E1C),
        border: Color(0xFF065F46),
        onAccent: Color(0xFFA7F3D0),
      );
    }
    return const HealthReportTheme(
      accent: PunjabColors.rxGreen,
      surface: Color(0xFFECFDF5),
      border: Color(0xFFA7F3D0),
      onAccent: Color(0xFF047857),
    );
  }
}

class HealthSummaryPanel extends StatelessWidget {
  final HealthReportTheme theme;
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> metrics;
  final Widget? footer;

  const HealthSummaryPanel({
    super.key,
    required this.theme,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.metrics,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: dark ? 0.2 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.accent, size: 20),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.onAccent,
                          ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics,
            ),
          ],
          if (footer != null) ...[
            const Gap(10),
            footer!,
          ],
        ],
      ),
    );
  }
}

class HealthMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  final bool emphasize;

  const HealthMetricPill({
    super.key,
    required this.label,
    required this.value,
    this.accent,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Gap(2),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 18 : 16,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class HealthBorderStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const HealthBorderStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accent, width: 4),
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
          right: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const Gap(2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class HealthReportListCard extends StatelessWidget {
  final HealthReportTheme theme;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? meta;
  final String statusLabel;
  final Color statusColor;
  final String? preview;
  final VoidCallback? onTap;

  const HealthReportListCard({
    super.key,
    required this.theme,
    required this.icon,
    required this.title,
    this.subtitle,
    this.meta,
    required this.statusLabel,
    required this.statusColor,
    this.preview,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.accent, size: 22),
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
                              title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const Gap(8),
                          _OutlineBadge(label: statusLabel, color: statusColor),
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const Gap(4),
                        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (preview != null && preview!.trim().isNotEmpty) ...[
                        const Gap(6),
                        Text(
                          preview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ],
                      if (meta != null && meta!.isNotEmpty) ...[
                        const Gap(6),
                        Text(
                          meta!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HealthDetailHero extends StatelessWidget {
  final HealthReportTheme theme;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String statusLabel;
  final Color statusColor;
  final List<HealthMetaItem> metaItems;

  const HealthDetailHero({
    super.key,
    required this.theme,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    this.metaItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    return HealthSummaryPanel(
      theme: theme,
      icon: icon,
      title: title,
      subtitle: subtitle,
      metrics: [
        _OutlineBadge(label: statusLabel, color: statusColor),
      ],
      footer: metaItems.isEmpty
          ? null
          : HealthMetadataGrid(items: metaItems),
    );
  }
}

class HealthMetaItem {
  final String label;
  final String value;

  const HealthMetaItem({required this.label, required this.value});
}

class HealthMetadataGrid extends StatelessWidget {
  final List<HealthMetaItem> items;

  const HealthMetadataGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: scheme.brightness == Brightness.dark ? 0.45 : 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoCol = constraints.maxWidth > 280;
          if (!twoCol) {
            return Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MetaRow(item: item),
                    ),
                  )
                  .toList(),
            );
          }

          final rows = <Widget>[];
          for (var i = 0; i < items.length; i += 2) {
            rows.add(
              Padding(
                padding: EdgeInsets.only(bottom: i + 2 < items.length ? 8 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _MetaRow(item: items[i])),
                    if (i + 1 < items.length) ...[
                      const Gap(12),
                      Expanded(child: _MetaRow(item: items[i + 1])),
                    ],
                  ],
                ),
              ),
            );
          }
          return Column(children: rows);
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final HealthMetaItem item;

  const _MetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const Gap(2),
        Text(
          item.value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class HealthDetailSection extends StatelessWidget {
  final HealthReportTheme theme;
  final String title;
  final String body;
  final bool highlight;

  const HealthDetailSection({
    super.key,
    required this.theme,
    required this.title,
    required this.body,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.onAccent,
                ),
          ),
          const Gap(10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
            ),
            child: Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    color: highlight ? PunjabColors.danger : scheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class HealthPendingBanner extends StatelessWidget {
  final HealthReportTheme theme;
  final String message;

  const HealthPendingBanner({
    super.key,
    required this.theme,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top_rounded, color: theme.accent, size: 22),
          const Gap(12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _OutlineBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

Color labStatusColor(LabReport report) {
  if (report.isCritical) return PunjabColors.danger;
  final status = (report.status ?? '').toLowerCase();
  if (status.contains('abnormal') ||
      status.contains('high') ||
      status.contains('low') ||
      status.contains('elevated')) {
    return PunjabColors.warning;
  }
  if (status.contains('normal')) return PunjabColors.success;
  if (!report.hasResult) return PunjabColors.textSecondary;
  return PunjabColors.labBlue;
}

String labStatusLabel(LabReport report) {
  if (report.isCritical) return 'Critical';
  if (!report.hasResult) return 'Pending';
  return report.status ?? 'Result';
}

String formatReportDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  return AppDateFormat.formatDate(raw);
}
