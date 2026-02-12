import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'otp_screen.dart';
import '../utils/emr_api_client.dart';

/// Screen that displays the masked phone number and allows user to request OTP.
/// This is the second step in the OTP-only authentication flow:
/// CNIC Input -> Phone Confirm -> OTP -> Dashboard
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Number'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.surface,
              colorScheme.surfaceContainerHighest,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(24),

                // Welcome icon
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone_android,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                ),

                const Gap(32),

                // Welcome message
                Text(
                  'Hello, ${widget.patientName}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Gap(12),

                Text(
                  'We found your account. To verify your identity, we\'ll send a verification code to your registered phone number.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Gap(32),

                // Phone number card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Your registered number',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Gap(8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                            const Gap(12),
                            Text(
                              widget.maskedPhone,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Gap(16),

                // Info text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.tertiary,
                        size: 20,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          'Not your number? Please visit hospital reception to update your contact details.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Send OTP button
                FilledButton.icon(
                  onPressed: _loading ? null : _requestOtp,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.sms_outlined, size: 20),
                  label: _loading
                      ? const Text('Sending OTP...')
                      : const Text(
                          'Send Verification Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const Gap(12),

                // Back button
                OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back'),
                ),

                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestOtp() async {
    setState(() {
      _loading = true;
    });

    try {
      final apiClient = EmrApiClient();
      
      // Request OTP for the CNIC
      final result = await apiClient.requestOtp(cnic: widget.cnic);
      
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      final success = result['success'] as bool? ?? true;
      final message = result['message'] as String?;
      final cooldown = result['cooldownSecondsRemaining'] as int? ?? 0;

      if (!success && cooldown > 0) {
        // Still in cooldown period
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Please wait $cooldown seconds before requesting another OTP'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Navigate to OTP screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            cnic: widget.cnic,
            maskedPhone: widget.maskedPhone,
            patientName: widget.patientName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      String errorMessage = e.toString();
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.replaceAll('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _requestOtp,
          ),
        ),
      );
    }
  }
}
