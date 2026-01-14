import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'dashboard_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../services/inactivity_service.dart';

class OtpScreen extends StatefulWidget {
  final String cnic;
  
  const OtpScreen({super.key, required this.cnic});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  EmrApiClient? _apiClient;
  bool _isRequestingOtp = false;
  bool _isVerifyingOtp = false;

  // Responsive sizing methods (aligned with login_page.dart)
  double getResponsiveSize(double baseSize) {
    final screenSize = MediaQuery.of(context).size;
    final scaleFactor = screenSize.width < 600 ? 0.315 : screenSize.width < 1200 ? 0.64 : 1.0;
    return baseSize * scaleFactor;
  }

  double getResponsiveHeight(double baseHeight) {
    final screenSize = MediaQuery.of(context).size;
    final scaleFactor = screenSize.height < 800 ? 0.3675 : screenSize.height < 1000 ? 0.72 : 1.0;
    return baseHeight * scaleFactor;
  }

  double getResponsiveFontSize(double baseFontSize) {
    final screenSize = MediaQuery.of(context).size;
    final scaleFactor = screenSize.width < 600 ? 0.3675 : screenSize.width < 1200 ? 0.72 : 1.0;
    return baseFontSize * scaleFactor;
  }

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
    _requestOtp();
  }

  Future<void> _initializeApiClient() async {
    try {
      _apiClient = EmrApiClient();
    } catch (e) {
      debugPrint('Error initializing API client: $e');
    }
  }

  Future<void> _requestOtp() async {
    final cnic = widget.cnic.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cnic.isEmpty || cnic.length != 13) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid CNIC format. CNIC must be exactly 13 digits.'),
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
      _isRequestingOtp = true;
    });

    try {
      final response = await _apiClient!.requestOtp(cnic: cnic);
      
      if (!mounted) return;
      
      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? 'OTP sent to your registered number';
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
      debugPrint('Error requesting OTP: $e');
      if (mounted) {
        String errorMessage = 'Failed to send OTP';
        final errorStr = e.toString();
        
        if (errorStr.contains('wait') || errorStr.contains('cooldown')) {
          errorMessage = 'Please wait before requesting another OTP.';
        } else if (errorStr.contains('Invalid CNIC') || errorStr.contains('Invalid request')) {
          errorMessage = 'Invalid CNIC format. CNIC must be exactly 13 digits.';
        } else if (errorStr.contains('400') || errorStr.contains('Bad Request')) {
          errorMessage = 'Invalid request. Please check your CNIC.';
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: KeyboardInsetPadding(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: <Widget>[
                // Row 1: Logo & Info Section
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0f172a),
                        Color(0xFF1e293b),
                        Color(0xFF334155),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Logo
                        SizedBox(
                          height: 120,
                          child: Image.asset(
                            'assets/images/punjab.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.local_hospital,
                                size: 80,
                                color: Colors.white.withValues(alpha: 0.85),
                              );
                            },
                          ),
                        ),
                        const Gap(16),
                        // Heading
                        Text(
                          'Verify your identity',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(8),
                        Text(
                          'Enter the OTP sent to your registered number',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(20),
                        // Feature highlights
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildFeatureItem(
                                Icons.security_rounded,
                                'Secure Verification',
                                'Your OTP is valid for 5 minutes only',
                                Colors.white.withOpacity(0.9),
                                12,
                              ),
                              const Gap(12),
                              _buildFeatureItem(
                                Icons.sms,
                                'SMS Delivery',
                                'OTP sent to your registered mobile number',
                                Colors.white.withOpacity(0.9),
                                12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Row 2: OTP Form Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // OTP title
                        Text(
                          'Enter OTP',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'We sent a code to your registered number',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Gap(32),
                        
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
                            onPressed: (_isVerifyingOtp || _isRequestingOtp) ? null : _handleOtpSubmit,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isVerifyingOtp
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Continue',
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
                        
                        // Back to sign in
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Back to Sign In',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, Color color, double spacing) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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
      final cnic = widget.cnic.replaceAll(RegExp(r'[^0-9]'), '');
      
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
      
      if (cnic.isEmpty || cnic.length != 13) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid CNIC format'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final response = await _apiClient!.verifyOtp(
        cnic: cnic,
        otpCode: otpCode,
      );

      if (!mounted) return;

      // Reset inactivity timer on successful OTP verification
      InactivityService.instance.resetActivity();

      // OTP verified successfully - navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(cnic: widget.cnic),
        ),
      );
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      if (mounted) {
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
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    final cnic = widget.cnic.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cnic.isEmpty || cnic.length != 13) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid CNIC format'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    await _requestOtp();
  }
}
