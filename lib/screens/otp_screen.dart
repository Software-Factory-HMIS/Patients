import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'dashboard_screen.dart';
import '../utils/keyboard_inset_padding.dart';

class OtpScreen extends StatefulWidget {
  final String cnic;
  
  const OtpScreen({super.key, required this.cnic});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();

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
      body: Row(
        children: <Widget>[
              Expanded(
                child: Container(
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: EdgeInsets.all(getResponsiveSize(32)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                        // Logo & heading
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: getResponsiveHeight(kIsWeb ? 315 * 0.7 : 315),
                            child: Image.asset(
                              'assets/images/punjab.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.local_hospital,
                                  size: getResponsiveSize(kIsWeb ? 189 * 0.7 : 189),
                                  color: Colors.white.withValues(alpha: 0.85),
                                );
                              },
                            ),
                          ),
                        ),
                        Gap(getResponsiveSize(16)),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Verify your identity',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: getResponsiveFontSize(22),
                            ),
                          ),
                        ),
                        Gap(getResponsiveSize(8)),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Enter the 4-digit OTP sent to your registered number',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Gap(getResponsiveSize(20)),
                        
                        // Feature highlights (match login/sign-in styling)
                        Container(
                          padding: EdgeInsets.all(getResponsiveSize(16)),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(getResponsiveSize(12)),
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
                                getResponsiveSize(12),
                              ),
                              Gap(getResponsiveSize(12)),
                              _buildFeatureItem(
                                Icons.sms,
                                'SMS Delivery',
                                'OTP sent to your registered mobile number',
                                Colors.white.withOpacity(0.9),
                                getResponsiveSize(12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxFormWidth = 800;
                 return Center(
                   child: ConstrainedBox(
                     constraints: BoxConstraints(maxWidth: maxFormWidth),
                     child: KeyboardInsetPadding(
                       child: Padding(
                         padding: EdgeInsets.all(getResponsiveSize(24)),
                         child: Form(
                           key: _formKey,
                           child: SingleChildScrollView(
                             keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.stretch,
                               children: <Widget>[
                                // OTP title
                                Text(
                                  'Enter OTP',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: getResponsiveFontSize(28),
                                  ),
                                ),
                                Gap(getResponsiveSize(12)),
                                Text(
                                  'We sent a 4-digit code to your registered number',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Gap(getResponsiveSize(32)),
                                
                                // OTP input field
                                TextFormField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  maxLength: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'OTP',
                                    hintText: '----',
                                    border: OutlineInputBorder(),
                                    counterText: '', // Hide character counter
                                  ),
                                  scrollPadding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).viewInsets.bottom + getResponsiveSize(120),
                                  ),
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
                                Gap(getResponsiveSize(24)),
                                
                                // Submit button (bypass OTP)
                                SizedBox(
                                  height: getResponsiveSize(56),
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _handleOtpSubmit,
                                    child: const Text('Continue'),
                                  ),
                                ),
                                Gap(getResponsiveSize(16)),
                                
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
                                Gap(getResponsiveSize(16)),
                                
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
                    ),
                  ),
                ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, Color color, double spacing) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(getResponsiveSize(8)),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(getResponsiveSize(8)),
          ),
          child: Icon(icon, color: color, size: getResponsiveSize(20)),
        ),
        Gap(getResponsiveSize(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: getResponsiveFontSize(14),
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: getResponsiveFontSize(12),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleOtpSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      // Navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(cnic: widget.cnic),
        ),
      );
    }
  }

  void _handleResendOtp() {
    // Handle resend OTP logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP resent to your registered number'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
