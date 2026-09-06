import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../models/appointment_models.dart';
import '../../services/nearest_hospital_service.dart';
import '../../services/patient_location_service.dart';
import '../../services/patient_portal_service.dart';
import '../../utils/emr_api_client.dart';
import '../../utils/user_storage.dart';
import '../../utils/app_localizations_ext.dart';
import '../../widgets/punjab_ui.dart';
import '../../widgets/searchable_hospital_select.dart';
import '../appointment_success_screen.dart';

class BookAppointmentScreen extends StatefulWidget {
  final int patientId;
  final String patientIdentifier;
  final Map<String, dynamic> patient;
  final Map<String, dynamic>? savedUserData;
  final VoidCallback? onGoHome;

  const BookAppointmentScreen({
    super.key,
    required this.patientId,
    required this.patientIdentifier,
    required this.patient,
    this.savedUserData,
    this.onGoHome,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _portal = PatientPortalService();
  final _complaintController = TextEditingController();
  final _historyController = TextEditingController();
  EmrApiClient? _api;
  Hospital? _selectedHospital;
  HospitalDepartment? _selectedHospitalDepartment;
  List<HospitalDepartment>? _hospitalDepartments;
  bool _loadingHospitalDepartments = false;
  bool _submittingAppointment = false;
  bool _onConfirmStep = false;
  String? _appointmentError;
  List<Map<String, dynamic>>? _recentAppointments;
  bool _loadingRecentVisits = false;

  @override
  void initState() {
    super.initState();
    _api = EmrApiClient();
    _loadRecentAppointments();
    PatientLocationService.instance.warmUp();
    PatientPortalService.visitRevision.addListener(_loadRecentAppointments);
  }

  @override
  void dispose() {
    PatientPortalService.visitRevision.removeListener(_loadRecentAppointments);
    _complaintController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentAppointments() async {
    if (!mounted) return;
    setState(() => _loadingRecentVisits = true);
    try {
      final cnic = _patientCnicDigits();
      final visits = await _portal.loadRecentVisits(
        patientId: widget.patientId,
        patientCnic: cnic,
        patient: widget.patient,
      );
      if (!mounted) return;
      setState(() {
        _recentAppointments = visits;
        _loadingRecentVisits = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentAppointments = [];
        _loadingRecentVisits = false;
      });
    }
  }

  String _patientCnicDigits() {
    final raw =
        widget.savedUserData?['CNIC']?.toString() ??
        widget.savedUserData?['cnic']?.toString() ??
        widget.patient['CNIC']?.toString() ??
        widget.patient['cnic']?.toString() ??
        widget.patientIdentifier;
    return PatientPortalService.normalizeCnic(raw);
  }

  String _patientCnic() => _patientCnicDigits();

  Future<List<Hospital>> _searchHospitals(String searchTerm) async {
    final hospitalsData = await _api!.searchHospitals(searchTerm, limit: 50);
    return hospitalsData
        .map((json) => Hospital.fromJson(json as Map<String, dynamic>))
        .where((h) => h.isActive && h.hospitalID > 0 && h.name.isNotEmpty)
        .toList();
  }

  Future<NearbyHospitalsResponse> _loadNearbyHospitals() async {
    final position = await PatientLocationService.instance
        .requestCurrentPosition();
    if (position == null) {
      return const NearbyHospitalsResponse(results: []);
    }

    final results = await NearestHospitalService(api: _api)
        .findNearestHospitals(
          latitude: position.latitude,
          longitude: position.longitude,
          limit: 5,
        );

    return NearbyHospitalsResponse(
      latitude: position.latitude,
      longitude: position.longitude,
      results: results,
    );
  }

  Future<void> _loadHospitalDepartments(int hospitalId) async {
    setState(() {
      _loadingHospitalDepartments = true;
      _appointmentError = null;
    });
    try {
      final data = await _api!.fetchHospitalDepartments(hospitalId);
      final departments = <HospitalDepartment>[];
      for (final item in data) {
        try {
          final dept = HospitalDepartment.fromJson(
            item as Map<String, dynamic>,
          );
          if (dept.hospitalDepartmentID > 0) departments.add(dept);
        } catch (_) {}
      }
      setState(() {
        _hospitalDepartments = departments;
        _loadingHospitalDepartments = false;
      });
    } catch (e) {
      setState(() {
        _loadingHospitalDepartments = false;
        _appointmentError = 'Failed to load departments: $e';
      });
    }
  }

  Future<int> _fetchPatientId() async {
    String searchIdentifier = widget.patientIdentifier;
    final saved = widget.savedUserData;
    if (saved != null) {
      final cnic = saved['cnic'] as String? ?? saved['CNIC'] as String?;
      if (cnic != null && cnic.isNotEmpty) {
        searchIdentifier = cnic;
      } else {
        final phone = saved['phone'] as String?;
        if (phone != null && phone.isNotEmpty) searchIdentifier = phone;
      }
    }

    final patient = await _api!.fetchPatient(searchIdentifier);
    final patientId =
        patient['patientId'] as int? ?? patient['PatientID'] as int?;
    if (patientId == null) throw Exception('Patient ID not found');
    return patientId;
  }

  Future<void> _handleAppointmentSubmission() async {
    if (_selectedHospital == null || _selectedHospitalDepartment == null)
      return;

    setState(() {
      _submittingAppointment = true;
      _appointmentError = null;
    });

    try {
      final patientId = await _fetchPatientId();
      final saved = widget.savedUserData;
      final patientName =
          saved?['FullName'] as String? ??
          saved?['fullName'] as String? ??
          widget.patient['fullName'] as String? ??
          widget.patient['name'] as String? ??
          'Unknown';
      final patientMRN =
          saved?['MRN'] as String? ??
          saved?['mrn'] as String? ??
          widget.patient['mrn']?.toString() ??
          _patientCnic();

      final deptName = (_selectedHospitalDepartment!.departmentName)
          .toLowerCase();
      final queueResponse = await _api!.addPatientToQueue(
        patientId: patientId,
        hospitalId: _selectedHospital!.hospitalID,
        hospitalDepartmentId: _selectedHospitalDepartment!.hospitalDepartmentID,
        createdBy: 1,
        priority: 'Normal',
        queueType: deptName.contains('emergency') ? 'Emergency' : 'OPD',
        visitPurpose: 'Check-Up',
        patientSource: 'SELF_CHECKIN',
        patientComplaint: _complaintController.text,
        patientHistory: _historyController.text,
      );

      final queueId = QueueResponse.readInt(queueResponse['queueId']);
      final tokenNumber = queueResponse['tokenNumber']?.toString() ?? 'N/A';
      if (queueId == null || queueId <= 0) {
        throw Exception('Queue ID not returned');
      }

      Map<String, dynamic> receiptData = {};
      try {
        receiptData = await _api!.printQueueReceipt(queueId: queueId);
      } catch (_) {}

      final department = Department(
        departmentID: _selectedHospitalDepartment!.departmentID,
        name: _selectedHospitalDepartment!.departmentName,
        isActive: true,
        hospitalCount: 0,
      );

      final appointmentDetails = AppointmentDetails(
        queueResponse: QueueResponse(
          queueId: queueId,
          tokenNumber: tokenNumber,
        ),
        hospital: _selectedHospital!,
        department: department,
        patientName: patientName,
        patientMRN: patientMRN,
        appointmentDate: DateTime.now(),
        receiptData: receiptData.isNotEmpty ? receiptData : null,
      );

      await UserStorage.addKnownHospitalId(_selectedHospital!.hospitalID);
      PatientPortalService.notifyVisitsChanged();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AppointmentSuccessScreen(
            appointment: appointmentDetails,
            onGoHome: widget.onGoHome,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _selectedHospital = null;
          _selectedHospitalDepartment = null;
          _hospitalDepartments = null;
          _onConfirmStep = false;
          _submittingAppointment = false;
          _complaintController.clear();
          _historyController.clear();
        });
        await _loadRecentAppointments();
      }
    } catch (e) {
      setState(() {
        _submittingAppointment = false;
        _appointmentError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onHospitalSelected(Hospital? hospital) {
    setState(() {
      _selectedHospital = hospital;
      _selectedHospitalDepartment = null;
      _hospitalDepartments = null;
      _onConfirmStep = false;
    });
    if (hospital != null) _loadHospitalDepartments(hospital.hospitalID);
  }

  void _onDepartmentSelected(HospitalDepartment? dept) {
    setState(() {
      _selectedHospitalDepartment = dept;
      _onConfirmStep = false;
    });
  }

  Future<void> _openExistingBooking(Map<String, dynamic> visit) async {
    final saved = widget.savedUserData;
    final patientName =
        saved?['FullName'] as String? ??
        saved?['fullName'] as String? ??
        widget.patient['fullName'] as String? ??
        widget.patient['name'] as String? ??
        'Unknown';
    final patientMRN =
        saved?['MRN'] as String? ??
        saved?['mrn'] as String? ??
        widget.patient['mrn']?.toString() ??
        _patientCnic();
    final details = AppointmentDetails.tryFromVisit(
      visit,
      patientName: patientName,
      patientMRN: patientMRN,
    );
    if (details == null) {
      if (!mounted) return;
      setState(() => _appointmentError = context.l10n.couldNotBookVisit);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppointmentSuccessScreen(
          appointment: details,
          onGoHome: widget.onGoHome,
        ),
      ),
    );
  }

  void _goToConfirmStep() {
    if (_selectedHospital == null || _selectedHospitalDepartment == null)
      return;
    setState(() => _onConfirmStep = true);
  }

  int get _currentStep {
    if (_onConfirmStep) return 2;
    if (_selectedHospital != null) return 1;
    return 0;
  }

  bool get _canContinue =>
      _selectedHospital != null && _selectedHospitalDepartment != null;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottomNavSpace = PunjabBottomNav.navBarHeight;
    final departmentEnabled =
        _selectedHospital != null && !_loadingHospitalDepartments;

    return RefreshIndicator(
      color: PunjabColors.primary,
      onRefresh: _loadRecentAppointments,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              PunjabPageHeader.screenInsets.left,
              PunjabPageHeader.screenInsets.top,
              PunjabPageHeader.screenInsets.right,
              bottomNavSpace,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                PunjabPageHeader(
                  title: l.bookAppointment,
                  subtitle: l.bookVisitSubtitle,
                ),
                PunjabCard(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: PunjabBookingStepper(currentStep: _currentStep),
                ),
                const Gap(16),
                if (!_onConfirmStep) ...[
                  _BookingSectionHeader(
                    title: l.selectHospital,
                    subtitle: l.selectHospitalSubtitle,
                  ),
                  const Gap(14),
                  _BookingFieldCard(
                    title: l.hospital,
                    child: SearchableHospitalSelect(
                      selectedHospital: _selectedHospital,
                      onSearch: _searchHospitals,
                      loadNearbyHospitals: _loadNearbyHospitals,
                      showHeader: false,
                      placeholder: l.searchAndSelectHospital,
                      searchPlaceholder: l.searchHospitalByName,
                      onSelected: _onHospitalSelected,
                    ),
                  ),
                  const Gap(16),
                  _BookingSectionHeader(
                    title: l.selectDepartment,
                    subtitle: l.selectDepartmentSubtitle,
                  ),
                  const Gap(14),
                  _BookingFieldCard(
                    title: l.department,
                    child: _DepartmentField(
                      enabled: departmentEnabled,
                      loading: _loadingHospitalDepartments,
                      value: _selectedHospitalDepartment,
                      departments: _hospitalDepartments,
                      hintText: _selectedHospital == null
                          ? l.pickHospitalFirstHint
                          : l.selectDepartmentHint,
                      onChanged: departmentEnabled
                          ? _onDepartmentSelected
                          : null,
                    ),
                  ),
                ] else ...[
                  _BookingConfirmSummary(
                    hospitalName: _selectedHospital!.name,
                    departmentName: _selectedHospitalDepartment!.departmentName,
                  ),
                  const Gap(16),
                  _BookingSectionHeader(
                    title: l.patientComplaint,
                    subtitle: l.patientComplaintHint,
                  ),
                  const Gap(14),
                  _BookingNotesField(
                    controller: _complaintController,
                    hint: l.patientComplaintHint,
                    maxLength: 2000,
                  ),
                  const Gap(16),
                  _BookingSectionHeader(
                    title: l.patientHistory,
                    subtitle: l.patientHistoryHint,
                  ),
                  const Gap(14),
                  _BookingNotesField(
                    controller: _historyController,
                    hint: l.patientHistoryHint,
                    maxLength: 2000,
                  ),
                ],
                if (_appointmentError != null) ...[
                  const Gap(16),
                  _BookingErrorBanner(
                    title: l.couldNotBookVisit,
                    message: _appointmentError!,
                  ),
                ],
                const Gap(16),
                PunjabPrimaryButton(
                  label: _onConfirmStep ? l.bookMyVisit : l.next,
                  icon: Icons.arrow_forward_rounded,
                  loading: _submittingAppointment,
                  onPressed: _onConfirmStep
                      ? (_canContinue && !_submittingAppointment
                            ? _handleAppointmentSubmission
                            : null)
                      : (_canContinue ? _goToConfirmStep : null),
                ),
                if (_loadingRecentVisits) ...[
                  const Gap(20),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_recentAppointments != null &&
                    _recentAppointments!.isNotEmpty) ...[
                  const Gap(20),
                  PunjabSectionTitle(title: l.recentVisits),
                  const Gap(12),
                  ..._recentAppointments!.map(
                    (apt) => _RecentVisitCard(
                      appointment: apt,
                      onTap: () => _openExistingBooking(apt),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BookingSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: PunjabColors.textPrimary,
          ),
        ),
        const Gap(4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: PunjabColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BookingFieldCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _BookingFieldCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return PunjabCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: PunjabColors.textPrimary,
            ),
          ),
          const Gap(14),
          child,
        ],
      ),
    );
  }
}

class _DepartmentField extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final HospitalDepartment? value;
  final List<HospitalDepartment>? departments;
  final String hintText;
  final ValueChanged<HospitalDepartment?>? onChanged;

  const _DepartmentField({
    required this.enabled,
    required this.loading,
    required this.value,
    required this.departments,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final hasValue = value != null;
    final fillColor = !enabled
        ? const Color(0xFFF3F5F4)
        : hasValue
        ? PunjabColors.primary.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = !enabled
        ? const Color(0xFFE8ECE9)
        : hasValue
        ? PunjabColors.primary.withValues(alpha: 0.35)
        : PunjabColors.border;
    final textColor = !enabled
        ? const Color(0xFF8A968F)
        : hasValue
        ? PunjabColors.textPrimary
        : PunjabColors.textSecondary;
    final iconColor = !enabled
        ? const Color(0xFFB0BAB4)
        : PunjabColors.textSecondary;

    return DropdownButtonFormField<HospitalDepartment>(
      value: value,
      isExpanded: true,
      hint: Text(
        hintText,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: enabled ? PunjabColors.primary : borderColor,
            width: enabled ? 1.5 : 1,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      items: departments?.map((dept) {
        return DropdownMenuItem(
          value: dept,
          child: Text(dept.departmentName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _BookingConfirmSummary extends StatelessWidget {
  final String hospitalName;
  final String departmentName;

  const _BookingConfirmSummary({
    required this.hospitalName,
    required this.departmentName,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return PunjabCard(
      padding: const EdgeInsets.all(18),
      borderColor: PunjabColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: PunjabColors.primary,
                size: 22,
              ),
              const Gap(8),
              Text(
                l.readyToBook,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: PunjabColors.primary,
                ),
              ),
            ],
          ),
          const Gap(14),
          _SummaryRow(
            icon: Icons.local_hospital_rounded,
            label: l.hospital,
            value: hospitalName,
          ),
          const Gap(10),
          _SummaryRow(
            icon: Icons.medical_services_rounded,
            label: l.department,
            value: departmentName,
          ),
        ],
      ),
    );
  }
}

class _BookingNotesField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;

  const _BookingNotesField({
    required this.controller,
    required this.hint,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return PunjabCard(
      padding: const EdgeInsets.all(18),
      child: TextField(
        controller: controller,
        maxLines: 4,
        maxLength: maxLength,
        textInputAction: TextInputAction.newline,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: PunjabColors.textPrimary,
          height: 1.35,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: PunjabColors.textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PunjabColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: PunjabColors.primary,
              width: 1.5,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PunjabColors.border),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: PunjabColors.primary),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PunjabColors.textSecondary,
                ),
              ),
              const Gap(2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PunjabColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingErrorBanner extends StatelessWidget {
  final String title;
  final String message;

  const _BookingErrorBanner({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PunjabColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PunjabColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: PunjabColors.danger, size: 22),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PunjabColors.textPrimary,
                  ),
                ),
                const Gap(4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: PunjabColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentVisitCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;
  const _RecentVisitCard({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hospital = appointment['hospitalName']?.toString() ?? 'Hospital';
    final dept = appointment['departmentName']?.toString() ?? 'Department';
    final token = appointment['tokenNumber']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PunjabCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: ListTile(
          onTap: onTap,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.local_hospital_rounded,
            color: PunjabColors.primary,
          ),
          title: Text(
            hospital,
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$dept${token != null ? ' · Token $token' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: PunjabColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
