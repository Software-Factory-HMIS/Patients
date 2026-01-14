import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'registration_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';

class RegistrationOtpScreen extends StatefulWidget {
  final String phoneNumber;
  
  const RegistrationOtpScreen({
    super.key, 
    required this.phoneNumber,
  });

  @override
  State<RegistrationOtpScreen> createState() => _RegistrationOtpScreenState();
}

class _RegistrationOtpScreenState extends State<RegistrationOtpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;
  EmrApiClient? _apiClient;

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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('OTP Verification'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
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
                    
                    // Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    
                    const Gap(32),
                    
                    // Title
                    Text(
                      'Enter OTP',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Gap(8),
                    
                    Text(
                      'We sent a code to\n${widget.phoneNumber}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Gap(48),
                    
                    // OTP input field
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 8,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        hintText: '----',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                        
                        final otp = value!.trim();
                        if (!RegExp(r'^\d+$').hasMatch(otp)) {
                          return 'OTP must contain only digits';
                        }
                        
                        if (otp.length != 6) {
                          return 'OTP must be exactly 6 digits';
                        }
                        
                        return null;
                      },
                    ),
                    
                    const Gap(32),
                    
                    // Submit button
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _loading ? null : _handleVerifyOtp,
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
                                'Verify OTP',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const Gap(16),
                    
                    // Resend OTP
                    Center(
                      child: TextButton(
                        onPressed: _handleResendOtp,
                        child: Text(
                          'Didn\'t receive OTP? Resend',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    
                    const Gap(8),
                    
                    // Back button
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Back',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
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
    );
  }

  Future<void> _handleVerifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final otpCode = _otpController.text.trim();
    
    // Additional validation
    if (otpCode.isEmpty || !RegExp(r'^\d{6}$').hasMatch(otpCode)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid 6-digit OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    final phoneNumber = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneNumber.isEmpty || phoneNumber.length < 7 || phoneNumber.length > 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid phone number'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
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
      _loading = true;
    });

    try {
      // Verify OTP on server
      final response = await _apiClient!.verifyRegistrationOtp(
        phoneNumber: phoneNumber,
        otpCode: otpCode,
      );
      
      if (!mounted) return;
      
      // Check response for success
      final verified = response['verified'] as bool? ?? false;
      
      if (verified) {
        setState(() {
          _loading = false;
        });
        
        // Navigate to registration screen after OTP verification
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => RegistrationScreen(phoneNumber: widget.phoneNumber),
          ),
          (route) => false, // Remove all previous routes
        );
      } else {
        throw Exception('OTP verification failed');
      }
    } catch (e) {
      debugPrint('Error verifying registration OTP: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        
        String errorMessage = 'Invalid OTP';
        final errorStr = e.toString();
        
        if (errorStr.contains('expired') || errorStr.contains('not requested')) {
          errorMessage = 'OTP has expired. Please request a new one.';
        } else if (errorStr.contains('attempts') || errorStr.contains('Too many')) {
          errorMessage = 'Too many attempts. Please request a new OTP.';
        } else if (errorStr.contains('Invalid') || errorStr.contains('401') || errorStr.contains('Unauthorized')) {
          errorMessage = 'Invalid OTP. Please check and try again.';
        } else if (errorStr.contains('400') || errorStr.contains('Bad Request')) {
          errorMessage = 'Invalid request. Please check your input.';
        } else if (errorStr.contains('500') || errorStr.contains('Internal Server')) {
          errorMessage = 'Server error. Please try again later.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleResendOtp() async {
    final phoneNumber = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneNumber.isEmpty || phoneNumber.length < 7 || phoneNumber.length > 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid phone number'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
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

    try {
      final response = await _apiClient!.requestRegistrationOtp(phoneNumber: phoneNumber);
      
      if (!mounted) return;
      
      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? 'OTP resent to your phone number';
      final cooldown = response['cooldownSecondsRemaining'] as int? ?? 0;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        String errorMessage = message;
        if (cooldown > 0) {
          errorMessage = 'Please wait ${cooldown} seconds before requesting another OTP.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error resending OTP: $e');
      if (mounted) {
        String errorMessage = 'Failed to resend OTP';
        final errorStr = e.toString();
        
        if (errorStr.contains('wait') || errorStr.contains('cooldown')) {
          errorMessage = 'Please wait before requesting another OTP.';
        } else if (errorStr.contains('Invalid phone') || errorStr.contains('Invalid request')) {
          errorMessage = 'Invalid phone number format.';
        } else if (errorStr.contains('400') || errorStr.contains('Bad Request')) {
          errorMessage = 'Invalid request. Please check your phone number.';
        } else {
          errorMessage = 'Failed to resend OTP. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

