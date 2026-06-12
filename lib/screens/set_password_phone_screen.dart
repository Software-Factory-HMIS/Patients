import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'set_password_otp_screen.dart';
import '../models/otp_delivery_channel.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/app_snackbar.dart';
import '../widgets/otp_delivery_selector.dart';

class SetPasswordPhoneScreen extends StatefulWidget {
  final String cnic;
  
  const SetPasswordPhoneScreen({
    super.key,
    required this.cnic,
  });

  @override
  State<SetPasswordPhoneScreen> createState() => _SetPasswordPhoneScreenState();
}

class _SetPasswordPhoneScreenState extends State<SetPasswordPhoneScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;
  EmrApiClient? _apiClient;
  OtpDeliveryChannel _otpDeliveryChannel = OtpDeliveryChannel.sms;

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
  }

  Future<void> _initializeApiClient() async {
    try {
      _apiClient = EmrApiClient();
    } catch (e) {
      debugPrint('Error initializing API client: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
        title: const Text('Set Password'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.25),
              colorScheme.surface,
            ],
            stops: const [0.0, 0.6],
          ),
        ),
        child: SafeArea(
        child: KeyboardInsetPadding(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Gap(40),
                    
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(Icons.phone_android, size: 44, color: colorScheme.primary),
                      ),
                    ),
                    
                    const Gap(32),
                    
                    Text(
                      'Enter your phone number',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(8),
                    Text(
                      'We will send you an OTP to verify your number',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(20),
                    Text(
                      'Receive code via',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(8),
                    Center(
                      child: OtpDeliverySelector(
                        value: _otpDeliveryChannel,
                        onChanged: (c) => setState(() => _otpDeliveryChannel = c),
                      ),
                    ),
                    const Gap(32),
                    
                    // Phone number input field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter 11 digit mobile number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        helperText: 'Mobile number must be exactly 11 digits',
                        helperStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 100),
                      validator: (value) {
                        final String? requiredResult = _requiredValidator(value, fieldName: 'Mobile number');
                        if (requiredResult != null) return requiredResult;
                        
                        // Validate mobile number format (numbers only, exactly 11 digits)
                        final mobileNumber = value!.trim();
                        if (!RegExp(r'^\d+$').hasMatch(mobileNumber)) {
                          return 'Mobile number must contain only digits';
                        }
                        
                        if (mobileNumber.length != 11) {
                          return 'Mobile number must be exactly 11 digits';
                        }
                        
                        return null;
                      },
                    ),
                    
                    const Gap(32),
                    
                    // Continue button
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _loading ? null : _handleContinue,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Send OTP',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const Gap(24),
                    
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Back',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    const Gap(40),
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

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final phoneNumber = _phoneController.text.trim();
    
    if (_apiClient == null) {
      await _initializeApiClient();
    }

    if (_apiClient == null) {
      if (mounted) AppSnackBar.showError(context, 'Failed to initialize API client');
      return;
    }

    setState(() => _loading = true);

    try {
      bool smsSentSuccessfully = false;
      try {
        await _apiClient!.requestRegistrationOtp(
          phoneNumber: phoneNumber,
          deliveryChannel: _otpDeliveryChannel,
        );
        smsSentSuccessfully = true;
        if (mounted) AppSnackBar.showSuccess(context, 'OTP sent via ${_otpDeliveryChannel.label}');
      } catch (smsError) {
        debugPrint('Failed to send OTP via SMS: $smsError');
        final errorMsg = smsError.toString();

        if (errorMsg.contains('OTP:') ||
            errorMsg.contains('proceed to enter') ||
            errorMsg.contains('CanProceed')) {
          smsSentSuccessfully = true;

          String warningMessage;
          if (errorMsg.contains('Timeout') || errorMsg.contains('timed out')) {
            warningMessage = 'SMS delivery timed out. You can still enter the OTP manually.';
          } else if (errorMsg.contains('Invalid sender IP')) {
            warningMessage = 'SMS service temporarily unavailable. Please enter the OTP manually.';
          } else {
            warningMessage = 'SMS delivery failed. Please enter the OTP manually.';
          }

          if (mounted) AppSnackBar.showInfo(context, warningMessage);
        } else {
          String errorMessage;
          if (errorMsg.contains('Timeout') || errorMsg.contains('timed out')) {
            errorMessage = 'SMS delivery timed out. Please try again.';
          } else {
            errorMessage =
                'Failed to send OTP via ${_otpDeliveryChannel.label}. Please check your phone number and try again.';
          }
          if (mounted) AppSnackBar.showError(context, errorMessage);
          return;
        }
      }

      if (smsSentSuccessfully && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SetPasswordOtpScreen(
              cnic: widget.cnic,
              phoneNumber: phoneNumber,
              expectedOtp: null,
              deliveryChannel: _otpDeliveryChannel,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error requesting OTP: $e');
      if (mounted) {
        setState(() => _loading = false);
        AppSnackBar.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

}


