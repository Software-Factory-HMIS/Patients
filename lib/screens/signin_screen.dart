import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import '../l10n/app_localizations.dart';
import 'phone_confirm_screen.dart';
import 'id_scanner_screen.dart';
import 'settings_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import '../utils/app_snackbar.dart';
import '../utils/api_message_localizer.dart';
import '../services/nearest_hospital_service.dart';
import '../services/patient_location_service.dart';
import '../utils/app_localizations_ext.dart';
import '../widgets/auth/signin_auth_layout.dart';
import '../widgets/auth/signin_auth_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cnicController = TextEditingController();
  final FocusNode _cnicFocus = FocusNode();
  bool _loading = false;
  bool _supportLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUserData();
    PatientLocationService.instance.warmUp();
  }

  Future<void> _loadSavedUserData() async {
    try {
      final userData = await UserStorage.getUserData();
      if (userData != null && mounted) {
        final cnic = userData['CNIC'] ?? userData['cnic'];
        if (cnic != null && cnic.toString().isNotEmpty) {
          _cnicController.text = CnicInputFormatter.format(cnic.toString());
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cnicController.dispose();
    _cnicFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            decoration: SignInAuthTheme.pageDecorationFor(context),
            child: KeyboardInsetPadding(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = SignInMetrics.of(context, constraints);

                    return Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, bodyConstraints) {
                              return SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.symmetric(
                                  horizontal: metrics.horizontalPadding,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: bodyConstraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: metrics.cardMaxWidth,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          SignInAuthHeader(metrics: metrics),
                                          Gap(metrics.mediumGap),
                                          _buildSignInContent(
                                            context,
                                            metrics,
                                            l,
                                          ),
                                          Gap(metrics.mediumGap),
                                          SignInHospitalSupportButton(
                                            compact: metrics.isShortHeight,
                                            loading: _supportLoading,
                                            onPressed:
                                                _showNearestHospitalSupport,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            metrics.horizontalPadding,
                            metrics.smallGap,
                            metrics.horizontalPadding,
                            metrics.mediumGap,
                          ),
                          child: const SignInAuthFooter(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: SignInAuthTheme.textMuted,
                  size: 22,
                ),
                tooltip: l.settings,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInContent(
    BuildContext context,
    SignInMetrics metrics,
    AppLocalizations l,
  ) {
    return Form(
      key: _formKey,
      child: SignInAuthCard(
        padding: EdgeInsets.all(metrics.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.cnicNumber,
              style: TextStyle(
                fontSize: metrics.labelFontSize,
                fontWeight: FontWeight.w800,
                color: SignInAuthTheme.labelTextColor(context),
              ),
            ),
            Gap(metrics.mediumGap),
            _CnicInputField(
              controller: _cnicController,
              focusNode: _cnicFocus,
              onCameraTap: _openIDScanner,
              onSubmitted: (_) => _handleContinue(),
              compact: metrics.isCompactWidth || metrics.isShortHeight,
            ),
            Gap(metrics.mediumGap),
            SignInInfoBox(
              message: l.signInInfoMessage,
              compact: metrics.isShortHeight,
            ),
            Gap(metrics.largeGap),
            SignInContinueButton(
              loading: _loading,
              height: metrics.buttonHeight,
              onPressed: _handleContinue,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNearestHospitalSupport() async {
    if (_supportLoading) return;
    final l = context.l10n;

    setState(() => _supportLoading = true);

    try {
      final position = await PatientLocationService.instance
          .requestCurrentPosition();
      if (!mounted) return;

      if (position == null) {
        AppSnackBar.showError(context, l.locationPermissionRequired);
        return;
      }

      final nearest = await NearestHospitalService().findNearest(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;

      if (nearest == null) {
        AppSnackBar.showError(context, l.noHospitalFoundNearby);
        return;
      }

      final distance = nearest.distanceKm < 10
          ? nearest.distanceKm.toStringAsFixed(1)
          : nearest.distanceKm.round().toString();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.local_hospital_rounded,
            color: SignInAuthTheme.primary,
            size: 36,
          ),
          title: Text(l.nearestHospital),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nearest.hospital.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Gap(8),
              if (nearest.hospital.location != 'Location not specified')
                Text(
                  nearest.hospital.location,
                  style: TextStyle(
                    color: SignInAuthTheme.mutedTextColor(dialogContext),
                  ),
                ),
              const Gap(8),
              Text(
                l.distanceAwayKm(distance),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (nearest.usedApproximateLocation) ...[
                const Gap(8),
                Text(
                  l.approximateHospitalDistance,
                  style: TextStyle(
                    fontSize: 12,
                    color: SignInAuthTheme.mutedTextColor(dialogContext),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.ok),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        ApiMessageLocalizer.localize(context, e.toString()),
      );
    } finally {
      if (mounted) setState(() => _supportLoading = false);
    }
  }

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cnic = _cnicController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (cnic.isEmpty) {
      AppSnackBar.showError(context, context.l10n.enterCnic);
      return;
    }

    setState(() => _loading = true);

    try {
      final apiClient = EmrApiClient();
      final result = await apiClient.lookupPatient(cnic: cnic);

      if (!mounted) return;
      setState(() => _loading = false);

      final found = result['found'] as bool? ?? false;
      final maskedPhone = result['maskedPhone'] as String?;
      final patientName = result['patientName'] as String?;
      final message = result['message'] as String?;

      if (!found) {
        _showNotFoundDialog(cnic, message);
      } else if (maskedPhone == null || maskedPhone.isEmpty) {
        _showNoPhoneDialog(patientName);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PhoneConfirmScreen(
              cnic: cnic,
              maskedPhone: maskedPhone,
              patientName: patientName ?? context.l10n.patient,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      AppSnackBar.showError(
        context,
        ApiMessageLocalizer.localize(context, e.toString()),
        onRetry: _handleContinue,
      );
    }
  }

  void _showNotFoundDialog(String cnic, String? message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_off_outlined, size: 36),
        title: Text(context.l10n.accountNotFound),
        content: Text(
          message != null
              ? ApiMessageLocalizer.localize(context, message)
              : context.l10n.accountNotFoundMessage(cnic),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showNoPhoneDialog(String? patientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.phone_disabled_outlined, size: 36),
        title: Text(context.l10n.phoneMissing),
        content: Text(
          context.l10n.phoneMissingMessage(patientName ?? context.l10n.there),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _openIDScanner() async {
    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const IDScannerScreen()),
    );

    if (imagePath != null && mounted) {
      AppSnackBar.showSuccess(context, context.l10n.cnicPhotoCaptured);
    }
  }
}

class _CnicInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCameraTap;
  final ValueChanged<String>? onSubmitted;
  final bool compact;

  const _CnicInputField({
    required this.controller,
    required this.focusNode,
    required this.onCameraTap,
    this.onSubmitted,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isDark = SignInAuthTheme.isDark(context);
    final iconSize = compact ? 20.0 : 22.0;
    final iconBox = compact ? 44.0 : 48.0;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [CnicInputFormatter()],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l.enterCnicRequired;
        }
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length != 13) {
          return l.cnicMustBe13Digits;
        }
        return null;
      },
      style: TextStyle(
        fontSize: compact ? 15 : 16,
        fontWeight: FontWeight.w600,
        color: SignInAuthTheme.labelTextColor(context),
        letterSpacing: 0.4,
        height: 1.2,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF232D28) : SignInAuthTheme.inputFill,
        hintText: l.cnicHint,
        hintStyle: TextStyle(
          fontFamily: 'serif',
          fontSize: compact ? 15 : 17,
          fontWeight: FontWeight.w700,
          color: isDark ? scheme.onSurfaceVariant : SignInAuthTheme.titleGreen,
          letterSpacing: 0.8,
        ),
        prefixIcon: Icon(
          Icons.badge_outlined,
          size: iconSize,
          color: SignInAuthTheme.mutedTextColor(context),
        ),
        prefixIconConstraints: BoxConstraints(
          minWidth: iconBox,
          minHeight: iconBox,
        ),
        suffixIcon: IconButton(
          onPressed: onCameraTap,
          icon: Icon(
            Icons.photo_camera_outlined,
            size: iconSize,
            color: scheme.primary,
          ),
          tooltip: l.scanCnic,
        ),
        suffixIconConstraints: BoxConstraints(
          minWidth: iconBox,
          minHeight: iconBox,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: compact ? 13 : 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignInAuthTheme.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: SignInAuthTheme.danger,
            width: 1.5,
          ),
        ),
      ),
      onFieldSubmitted: onSubmitted,
    );
  }
}

class CnicInputFormatter extends TextInputFormatter {
  static final RegExp _nonDigit = RegExp(r'[^0-9]');

  static String format(String raw) {
    final digits = raw.replaceAll(_nonDigit, '');
    final out = StringBuffer();
    for (var i = 0; i < digits.length && i < 13; i++) {
      out.write(digits[i]);
      if (i == 4 || i == 11) {
        if (i != digits.length - 1) out.write('-');
      }
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
