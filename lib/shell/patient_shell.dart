import 'package:flutter/material.dart';
import '../screens/booking/book_appointment_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/health/health_hub_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/records/encounters_screen.dart';
import '../screens/signin_screen.dart';
import '../services/auth_service.dart';
import '../services/patient_portal_service.dart';
import '../utils/user_storage.dart';
import '../utils/app_localizations_ext.dart';
import '../widgets/punjab_ui.dart';

class PatientShell extends StatefulWidget {
  final String patientIdentifier;

  const PatientShell({super.key, required this.patientIdentifier});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _currentIndex = PatientTabIndex.home;
  final _portal = PatientPortalService();

  Map<String, dynamic>? _patient;
  Map<String, dynamic>? _savedUserData;
  int? _patientId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final saved = await UserStorage.getUserData();
      final profile = await _portal.fetchPatientProfile(widget.patientIdentifier);
      final patientId = _portal.parsePatientId(profile);
      if (!mounted) return;
      setState(() {
        _savedUserData = saved;
        _patient = profile;
        _patientId = patientId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _switchTab(int index) => setState(() => _currentIndex = index);

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _patient == null || _patientId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.myHealth)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error ?? context.l10n.couldNotLoadProfile),
                const SizedBox(height: 16),
                PunjabPrimaryButton(label: context.l10n.tryAgain, onPressed: _loadPatient),
                TextButton(onPressed: _logout, child: Text(context.l10n.signOut)),
              ],
            ),
          ),
        ),
      );
    }

    final patient = _patient!;
    final patientId = _patientId!;
    final screens = [
      BookAppointmentScreen(
        patientId: patientId,
        patientIdentifier: widget.patientIdentifier,
        patient: patient,
        savedUserData: _savedUserData,
        onGoHome: () => _switchTab(PatientTabIndex.home),
      ),
      EncountersScreen(patient: patient),
      HomeScreen(
        patient: patient,
        patientId: patientId,
        patientIdentifier: widget.patientIdentifier,
        savedUserData: _savedUserData,
        onBookVisit: () => _switchTab(PatientTabIndex.book),
        onOpenVisits: () => _switchTab(PatientTabIndex.visits),
        onOpenHealth: () => _switchTab(PatientTabIndex.health),
        onOpenProfile: () => _switchTab(PatientTabIndex.profile),
      ),
      HealthHubScreen(
        patientId: patientId,
        patient: patient,
        savedUserData: _savedUserData,
      ),
      ProfileScreen(
        patientId: patientId,
        patient: patient,
        savedUserData: _savedUserData,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: screens),
      ),
      bottomNavigationBar: PunjabBottomNav(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}
