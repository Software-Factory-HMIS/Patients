import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import '../shell/patient_shell.dart';
import '../utils/keyboard_inset_padding.dart';
import '../models/otp_delivery_channel.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import '../utils/api_message_localizer.dart';
import '../utils/app_localizations_ext.dart';
import '../utils/app_snackbar.dart';
import '../services/auth_service.dart';
import '../services/inactivity_service.dart';
import '../widgets/auth/signin_auth_layout.dart';
import '../widgets/auth/signin_auth_theme.dart';

class OtpScreen extends StatefulWidget {
  final String cnic;
  final String? maskedPhone;
  final String? patientName;
  final OtpDeliveryChannel deliveryChannel;

  const OtpScreen({
    super.key,
    required this.cnic,
    this.maskedPhone,
    this.patientName,
    this.deliveryChannel = OtpDeliveryChannel.sms,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  EmrApiClient? _apiClient;
  bool _isRequestingOtp = false;
  bool _isVerifyingOtp = false;

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
  }

  Future<void> _initializeApiClient() async {
    try {
      _apiClient = EmrApiClient();
    } catch (_) {}
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_apiClient == null) await _initializeApiClient();
    if (_apiClient == null) {
      if (mounted)
        AppSnackBar.showError(context, context.l10n.apiFailedInitClient);
      return;
    }

    setState(() => _isRequestingOtp = true);

    try {
      final result = await _apiClient!.requestOtp(
        cnic: widget.cnic,
        deliveryChannel: widget.deliveryChannel,
      );
      if (mounted) {
        final cooldown = result['cooldownSecondsRemaining'] as int? ?? 0;
        if (cooldown > 0) {
          AppSnackBar.showInfo(context, context.l10n.apiCooldown(cooldown));
        } else {
          AppSnackBar.showSuccess(
            context,
            context.l10n.otpSentVia(
              ApiMessageLocalizer.channelLabel(context, widget.deliveryChannel),
              widget.maskedPhone ?? context.l10n.registeredNumber,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          ApiMessageLocalizer.localize(context, e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequestingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: KeyboardInsetPadding(
        child: SignInAuthLayout(
          showBackButton: true,
          child: Form(
            key: _formKey,
            child: SignInAuthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          l.verifyYourPhone,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: SignInAuthTheme.labelTextColor(context),
                          ),
                        ),
                      ),
                      Text(
                        l.step3Of3,
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: SignInAuthTheme.mutedTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  Text(
                    widget.maskedPhone != null
                        ? l.otpSentToPhone(widget.maskedPhone!)
                        : l.otpSentToPhoneGeneric,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: SignInAuthTheme.bodyTextColor(context),
                      height: 1.4,
                    ),
                  ),
                  if (whatsappOtpEnabled) ...[
                    const Gap(20),
                    Row(
                      children: [
                        _DeliveryTile(
                          icon: Icons.sms_rounded,
                          label: l.channelSms,
                          selected:
                              widget.deliveryChannel == OtpDeliveryChannel.sms,
                        ),
                        const Gap(12),
                        _DeliveryTile(
                          icon: Icons.chat_rounded,
                          label: l.channelWhatsApp,
                          selected:
                              widget.deliveryChannel ==
                              OtpDeliveryChannel.whatsApp,
                        ),
                      ],
                    ),
                    const Gap(24),
                  ] else
                    const Gap(24),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ListenableBuilder(
                          listenable: _otpController,
                          builder: (_, __) =>
                              _OtpBoxes(text: _otpController.text),
                        ),
                        Opacity(
                          opacity: 0.01,
                          child: TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            autofocus: true,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(counterText: ''),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return l.enter6DigitCode;
                              if (value.length != 6) return l.otpMustBe6Digits;
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleOtpSubmit(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(14),
                  Text(
                    l.otpExpiresIn5Min,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SignInAuthTheme.textMuted,
                    ),
                  ),
                  const Gap(6),
                  TextButton(
                    onPressed: (_isRequestingOtp || _isVerifyingOtp)
                        ? null
                        : _requestOtp,
                    child: Text(
                      _isRequestingOtp ? l.sending : l.resendCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: SignInAuthTheme.linkBlue,
                      ),
                    ),
                  ),
                  const Gap(16),
                  SignInContinueButton(
                    label: l.signIn,
                    loading: _isVerifyingOtp,
                    onPressed: (_isVerifyingOtp || _isRequestingOtp)
                        ? null
                        : _handleOtpSubmit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleOtpSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_apiClient == null) await _initializeApiClient();
    if (_apiClient == null) {
      if (mounted)
        AppSnackBar.showError(context, context.l10n.apiFailedInitClient);
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final response = await _apiClient!.verifyOtp(
        cnic: widget.cnic,
        otpCode: _otpController.text.trim(),
      );

      if (!mounted) return;

      await AuthService.instance.saveLoginResponse(response);
      await UserStorage.saveUserData(AuthService.instance.patientData!);
      InactivityService.instance.resetActivity();

      final mrn = response['MRN'] ?? response['mrn'] ?? '';
      final cnic = response['CNIC'] ?? response['cnic'] ?? widget.cnic;
      final identifier = mrn.toString().isNotEmpty ? mrn.toString() : cnic;

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => PatientShell(patientIdentifier: identifier),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          ApiMessageLocalizer.localize(context, e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }
}

class _DeliveryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _DeliveryTile({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = SignInAuthTheme.isDark(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF232D28) : SignInAuthTheme.inputFill),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? scheme.primary
                  : SignInAuthTheme.mutedTextColor(context),
              size: 28,
            ),
            const Gap(8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? scheme.primary
                    : SignInAuthTheme.bodyTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  final String text;

  const _OtpBoxes({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final char = i < text.length ? text[i] : '';
        final focused = i == text.length;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 4,
              right: i == 5 ? 0 : 4,
            ),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SignInAuthTheme.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused
                      ? SignInAuthTheme.primary
                      : SignInAuthTheme.border,
                  width: focused ? 2 : 1,
                ),
              ),
              child: Text(
                char,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SignInAuthTheme.titleGreen,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
