import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'dashboard_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../models/otp_delivery_channel.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import '../services/auth_service.dart';
import '../services/inactivity_service.dart';

/// OTP verification screen for the OTP-only authentication flow.
/// This is the final step: CNIC Input -> Phone Confirm -> OTP -> Dashboard
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
    // Don't auto-request OTP here - it was already requested from PhoneConfirmScreen
  }

  Future<void> _initializeApiClient() async {
    try {
      _apiClient = EmrApiClient();
    } catch (e) {
      debugPrint('Error initializing API client: $e');
    }
  }

  Future<void> _requestOtp() async {
    if (_apiClient == null) {
      await _initializeApiClient();
    }
    
    if (_apiClient == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize API client'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRequestingOtp = true;
    });

    try {
      final result = await _apiClient!.requestOtp(
        cnic: widget.cnic,
        deliveryChannel: widget.deliveryChannel,
      );
      if (mounted) {
        final cooldown = result['cooldownSecondsRemaining'] as int? ?? 0;
        if (cooldown > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait $cooldown seconds before requesting another OTP'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'OTP sent via ${widget.deliveryChannel.label} to ${widget.maskedPhone ?? "your registered number"}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error requesting OTP: $e');
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception: ')) {
          errorMessage = errorMessage.replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingOtp = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Enter OTP'),
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
          child: KeyboardInsetPadding(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Gap(16),

                      // Lock icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),

                      const Gap(24),

                      // Heading
                      Text(
                        'Verification Code',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const Gap(8),

                      // Subheading
                      Text(
                        widget.maskedPhone != null
                            ? 'Enter the 6-digit code sent to ${widget.maskedPhone}'
                            : 'Enter the 6-digit code sent to your registered number',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const Gap(32),

                      // OTP input card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // OTP input field
                              TextFormField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                maxLength: 6,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 12,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '------',
                                  hintStyle: TextStyle(
                                    color: colorScheme.outline,
                                    letterSpacing: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 20,
                                  ),
                                  counterText: '', // Hide character counter
                                ),
                                scrollPadding: const EdgeInsets.only(bottom: 100),
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (value) {
                                  final String? requiredResult = _requiredValidator(value, fieldName: 'OTP');
                                  if (requiredResult != null) return requiredResult;
                                  if (value!.length != 6) {
                                    return 'OTP must be 6 digits';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _handleOtpSubmit(),
                              ),

                              const Gap(24),

                              // Verify button
                              FilledButton.icon(
                                onPressed: (_isVerifyingOtp || _isRequestingOtp) ? null : _handleOtpSubmit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                                icon: _isVerifyingOtp
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
                                    : const Icon(Icons.check, size: 20),
                                label: _isVerifyingOtp
                                    ? const Text('Verifying...')
                                    : const Text(
                                        'Verify & Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Gap(24),

                      // Resend OTP section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Didn\'t receive the code?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Gap(8),
                            TextButton.icon(
                              onPressed: (_isRequestingOtp || _isVerifyingOtp) ? null : _handleResendOtp,
                              icon: _isRequestingOtp
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.refresh,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                              label: Text(
                                _isRequestingOtp ? 'Sending...' : 'Resend OTP',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Gap(16),

                      // Info text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const Gap(4),
                          Text(
                            'OTP is valid for 5 minutes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const Gap(24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleOtpSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_apiClient == null) {
      await _initializeApiClient();
    }

    if (_apiClient == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize API client'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final otpCode = _otpController.text.trim();
      final response = await _apiClient!.verifyOtp(
        cnic: widget.cnic,
        otpCode: otpCode,
      );

      if (!mounted) return;

      // The response now contains full patient data and tokens
      // Save patient data and tokens
      await UserStorage.saveUserData(response);
      await AuthService.instance.saveLoginResponse(response);

      // Reset inactivity timer on successful OTP verification
      InactivityService.instance.resetActivity();

      // Get identifier for dashboard
      final mrn = response['MRN'] ?? response['mrn'] ?? '';
      final cnic = response['CNIC'] ?? response['cnic'] ?? widget.cnic;
      final identifier = mrn.toString().isNotEmpty ? mrn.toString() : cnic;

      // Navigate to dashboard, clearing the back stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(cnic: identifier),
        ),
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception: ')) {
          errorMessage = errorMessage.replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  void _handleResendOtp() {
    _requestOtp();
  }
}
