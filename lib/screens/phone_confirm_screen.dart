import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'otp_screen.dart';
import '../models/otp_delivery_channel.dart';
import '../utils/api_message_localizer.dart';
import '../utils/app_localizations_ext.dart';
import '../utils/emr_api_client.dart';
import '../utils/app_snackbar.dart';
import '../widgets/auth/signin_auth_layout.dart';
import '../widgets/auth/signin_auth_theme.dart';

class PhoneConfirmScreen extends StatefulWidget {
  final String cnic;
  final String maskedPhone;
  final String patientName;

  const PhoneConfirmScreen({
    super.key,
    required this.cnic,
    required this.maskedPhone,
    required this.patientName,
  });

  @override
  State<PhoneConfirmScreen> createState() => _PhoneConfirmScreenState();
}

class _PhoneConfirmScreenState extends State<PhoneConfirmScreen> {
  bool _loading = false;
  OtpDeliveryChannel _otpDeliveryChannel = OtpDeliveryChannel.sms;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SignInAuthLayout(
        showBackButton: true,
        child: SignInAuthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l.verifyPhone,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SignInAuthTheme.labelTextColor(context),
                      ),
                    ),
                  ),
                  Text(
                    l.step2Of3,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: SignInAuthTheme.mutedTextColor(context),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              Text(
                l.helloName(widget.patientName),
                style: SignInAuthTheme.titleStyleFor(
                  context,
                ).copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const Gap(8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const Gap(8),
                  LtrText(
                    widget.maskedPhone,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: SignInAuthTheme.labelTextColor(context),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              SignInInfoBox(message: l.phoneVerifyInfo),
              if (whatsappOtpEnabled) ...[
                const Gap(20),
                Text(
                  l.howToSendCode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SignInAuthTheme.bodyTextColor(context),
                  ),
                ),
                const Gap(12),
                Row(
                  children: [
                    _DeliveryTile(
                      icon: Icons.sms_rounded,
                      label: l.channelSms,
                      selected: _otpDeliveryChannel == OtpDeliveryChannel.sms,
                      onTap: () => setState(
                        () => _otpDeliveryChannel = OtpDeliveryChannel.sms,
                      ),
                    ),
                    const Gap(12),
                    _DeliveryTile(
                      icon: Icons.chat_rounded,
                      label: l.channelWhatsApp,
                      selected:
                          _otpDeliveryChannel == OtpDeliveryChannel.whatsApp,
                      onTap: () => setState(
                        () => _otpDeliveryChannel = OtpDeliveryChannel.whatsApp,
                      ),
                    ),
                  ],
                ),
                const Gap(22),
              ] else
                const Gap(22),
              SignInContinueButton(
                label: l.sendCode,
                loading: _loading,
                onPressed: _requestOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestOtp() async {
    setState(() => _loading = true);

    try {
      final apiClient = EmrApiClient();
      final result = await apiClient.requestOtp(
        cnic: widget.cnic,
        deliveryChannel: _otpDeliveryChannel,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      final success = result['success'] as bool? ?? true;
      final message = result['message'] as String?;
      final cooldown = result['cooldownSecondsRemaining'] as int? ?? 0;

      if (!success && cooldown > 0) {
        AppSnackBar.showInfo(
          context,
          message != null
              ? ApiMessageLocalizer.localize(context, message)
              : context.l10n.apiCooldown(cooldown),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            cnic: widget.cnic,
            maskedPhone: widget.maskedPhone,
            patientName: widget.patientName,
            deliveryChannel: _otpDeliveryChannel,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.showError(
        context,
        ApiMessageLocalizer.localize(context, e.toString()),
        onRetry: _requestOtp,
      );
    }
  }
}

class _DeliveryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            final isDark = SignInAuthTheme.isDark(context);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : (isDark
                          ? const Color(0xFF232D28)
                          : SignInAuthTheme.inputFill),
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
            );
          },
        ),
      ),
    );
  }
}
