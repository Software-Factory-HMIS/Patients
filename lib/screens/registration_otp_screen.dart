import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'registration_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';

class RegistrationOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String? expectedOtp; // OTP to verify against
  final String? errorMessage; // Error message to display if SMS failed
  
  const RegistrationOtpScreen({
    super.key, 
    required this.phoneNumber,
    this.expectedOtp,
    this.errorMessage,
  });

  @override
  State<RegistrationOtpScreen> createState() => _RegistrationOtpScreenState();
}

class _RegistrationOtpScreenState extends State<RegistrationOtpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  EmrApiClient? _apiClient;
  bool _loading = false;

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
                      'We sent a 4-digit code to\n${widget.phoneNumber}',
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
                      maxLength: 4,
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
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (value) {
                        final String? requiredResult = _requiredValidator(value, fieldName: 'OTP');
                        if (requiredResult != null) return requiredResult;
                        if (value!.length != 4) {
                          return 'OTP must be 4 digits';
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
    
    // Basic validation - OTP must be 4 digits
    if (otpCode.length != 4 || !RegExp(r'^\d{4}$').hasMatch(otpCode)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid 4-digit OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // If expectedOtp is provided (legacy support), verify locally first
    if (widget.expectedOtp != null && otpCode != widget.expectedOtp) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid OTP. Please check and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() {
      _loading = true;
    });

    // Verify OTP via backend API
    if (_apiClient == null) {
      await _initializeApiClient();
    }

    if (_apiClient != null) {
      try {
        await _apiClient!.verifyRegistrationOtp(
          phoneNumber: widget.phoneNumber,
          otpCode: otpCode,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid OTP: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      // Fallback: if API client failed to initialize and expectedOtp is null, show error
      if (widget.expectedOtp == null) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to verify OTP. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    if (mounted) {
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
    }
  }

  Future<void> _handleResendOtp() async {
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
      await _apiClient!.requestRegistrationOtp(
        phoneNumber: widget.phoneNumber,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent to your registered number'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

