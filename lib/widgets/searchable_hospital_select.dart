import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../models/appointment_models.dart';
import '../services/nearest_hospital_service.dart';
import '../utils/app_localizations_ext.dart';
import '../utils/geo_utils.dart';
import 'punjab_ui.dart';

typedef HospitalSearchCallback =
    Future<List<Hospital>> Function(String searchTerm);
typedef NearbyHospitalsLoader = Future<NearbyHospitalsResponse> Function();

/// Searchable hospital picker aligned with hmis-frontend super-admin SearchableSelect:
/// single combobox trigger, integrated search, debounced server-side lookup.
class SearchableHospitalSelect extends StatelessWidget {
  final Hospital? selectedHospital;
  final ValueChanged<Hospital?> onSelected;
  final HospitalSearchCallback onSearch;
  final NearbyHospitalsLoader? loadNearbyHospitals;
  final bool enabled;
  final bool showHeader;
  final String label;
  final String placeholder;
  final String searchPlaceholder;
  final String emptyText;

  const SearchableHospitalSelect({
    super.key,
    required this.selectedHospital,
    required this.onSelected,
    required this.onSearch,
    this.loadNearbyHospitals,
    this.enabled = true,
    this.showHeader = true,
    this.label = 'Hospital',
    this.placeholder = 'Search and select a hospital...',
    this.searchPlaceholder = 'Search hospitals...',
    this.emptyText = 'No hospitals found.',
  });

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;

    final picked = await showModalBottomSheet<Hospital?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _HospitalPickerSheet(
        initialSelection: selectedHospital,
        onSearch: onSearch,
        loadNearbyHospitals: loadNearbyHospitals,
        searchPlaceholder: searchPlaceholder,
        emptyText: emptyText,
      ),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                color: colorScheme.primary,
                size: 22,
              ),
              const Gap(8),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const Gap(4),
              Text(
                '*',
                style: TextStyle(color: colorScheme.error, fontSize: 18),
              ),
            ],
          ),
          const Gap(12),
        ],
        Material(
          color: selectedHospital != null
              ? PunjabColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? () => _openPicker(context) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedHospital != null
                      ? PunjabColors.primary.withValues(alpha: 0.35)
                      : PunjabColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: selectedHospital == null
                        ? Text(
                            placeholder,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: PunjabColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedHospital!.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: PunjabColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (selectedHospital!.location !=
                                  'Location not specified') ...[
                                Text(
                                  selectedHospital!.location,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: PunjabColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (selectedHospital != null && enabled) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: PunjabColors.textSecondary,
                      ),
                      onPressed: () => onSelected(null),
                    ),
                    const Gap(4),
                  ],
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: PunjabColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HospitalPickerSheet extends StatefulWidget {
  final Hospital? initialSelection;
  final HospitalSearchCallback onSearch;
  final NearbyHospitalsLoader? loadNearbyHospitals;
  final String searchPlaceholder;
  final String emptyText;

  const _HospitalPickerSheet({
    required this.initialSelection,
    required this.onSearch,
    required this.loadNearbyHospitals,
    required this.searchPlaceholder,
    required this.emptyText,
  });

  @override
  State<_HospitalPickerSheet> createState() => _HospitalPickerSheetState();
}

class _HospitalPickerSheetState extends State<_HospitalPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Hospital> _results = [];
  final Map<int, double> _distancesKm = {};
  bool _loading = false;
  bool _showingNearby = false;
  String? _error;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadNearbyHospitals();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(_searchController.text);
    });
  }

  Future<void> _loadNearbyHospitals() async {
    final loader = widget.loadNearbyHospitals;
    if (loader == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final nearby = await loader();
      if (!mounted) return;

      _userLatitude = nearby.latitude;
      _userLongitude = nearby.longitude;

      final hospitals = <Hospital>[];
      _distancesKm.clear();

      if (widget.initialSelection != null) {
        hospitals.add(widget.initialSelection!);
      }

      for (final item in nearby.results) {
        if (hospitals.any((h) => h.hospitalID == item.hospital.hospitalID))
          continue;
        hospitals.add(item.hospital);
        _distancesKm[item.hospital.hospitalID] = item.distanceKm;
      }

      setState(() {
        _results = hospitals;
        _loading = false;
        _showingNearby = nearby.results.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _showingNearby = false;
        _results = widget.initialSelection != null
            ? [widget.initialSelection!]
            : [];
      });
    }
  }

  void _rankByDistance(List<Hospital> hospitals) {
    if (_userLatitude == null || _userLongitude == null) return;

    hospitals.sort((a, b) {
      final da = _distanceFor(a) ?? double.infinity;
      final db = _distanceFor(b) ?? double.infinity;
      return da.compareTo(db);
    });
  }

  double? _distanceFor(Hospital hospital) {
    final cached = _distancesKm[hospital.hospitalID];
    if (cached != null) return cached;

    if (_userLatitude == null || _userLongitude == null) return null;

    final coords = hospital.resolvedCoordinates;
    if (coords == null) return null;

    final distance = haversineDistanceKm(
      _userLatitude!,
      _userLongitude!,
      coords.$1,
      coords.$2,
    );
    _distancesKm[hospital.hospitalID] = distance;
    return distance;
  }

  String _formatDistance(double km) {
    if (km < 10) return km.toStringAsFixed(1);
    return km.round().toString();
  }

  String? _subtitleFor(Hospital hospital) {
    final l = context.l10n;
    final distance = _distanceFor(hospital);
    final location = hospital.location == 'Location not specified'
        ? null
        : hospital.location;

    if (distance != null && location != null) {
      return '$location · ${l.distanceAwayKm(_formatDistance(distance))}';
    }
    if (distance != null) {
      return l.distanceAwayKm(_formatDistance(distance));
    }
    return location;
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await _loadNearbyHospitals();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _showingNearby = false;
    });

    try {
      final hospitals = await widget.onSearch(trimmed);
      if (!mounted) return;

      final merged = <Hospital>[];
      if (widget.initialSelection != null &&
          !hospitals.any(
            (h) => h.hospitalID == widget.initialSelection!.hospitalID,
          )) {
        merged.add(widget.initialSelection!);
      }
      merged.addAll(hospitals);
      _rankByDistance(merged);

      setState(() {
        _results = merged;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to search hospitals';
        _results = widget.initialSelection != null
            ? [widget.initialSelection!]
            : [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l = context.l10n;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          const Gap(8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.selectHospital,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchPlaceholder,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_showingNearby && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.nearestHospitals,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: PunjabColors.primary,
                  ),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _error!,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: PunjabColors.primary,
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? l.typeToSearchMoreHospitals
                          : widget.emptyText,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (context, index) {
                      final hospital = _results[index];
                      final isSelected =
                          widget.initialSelection?.hospitalID ==
                          hospital.hospitalID;
                      final subtitle = _subtitleFor(hospital);

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outline.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        tileColor: isSelected
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.35,
                              )
                            : colorScheme.surfaceContainerHighest,
                        leading: const Icon(
                          Icons.local_hospital,
                          color: PunjabColors.primary,
                        ),
                          title: Text(
                            hospital.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: subtitle == null ? null : Text(subtitle),
                          trailing: isSelected
                              ? Icon(Icons.check, color: colorScheme.primary)
                              : null,
                          onTap: () => Navigator.of(context).pop(hospital),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
