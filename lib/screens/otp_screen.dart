import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'dashboard_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../services/inactivity_service.dart';
import '../widgets/otp_input.dart';

class OtpScreen extends StatefulWidget {
  final String cnic;

  const OtpScreen({super.key, required this.cnic});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  EmrApiClient? _apiClient;
  String _otpValue = '';

  bool _isRequestingOtp = false;
  bool _isVerifyingOtp = false;

  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
    _requestOtp(isResend: false);
  }

  Future<void> _initializeApiClient() async {
    try {
      _apiClient = EmrApiClient();
    } catch (e) {
      debugPrint('Error initializing API client: $e');
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _requestOtp({required bool isResend}) async {
    if (_apiClient == null) {
      await _initializeApiClient();
    }

    if (_apiClient == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize API client'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isRequestingOtp = true;
    });

    try {
      await _apiClient!.requestOtp(cnic: widget.cnic);
      _startResendCooldown();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isResend ? 'OTP resent to your registered number' : 'OTP sent to your registered number'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error requesting OTP: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleOtpSubmit() async {
    final otpCode = _otpValue.trim();
    if (otpCode.length != 4 || !RegExp(r'^\d{4}$').hasMatch(otpCode)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 4-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_apiClient == null) {
      await _initializeApiClient();
    }

    if (_apiClient == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize API client'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      await _apiClient!.verifyOtp(
        cnic: widget.cnic,
        otpCode: otpCode,
      );

      if (!mounted) return;
      InactivityService.instance.resetActivity();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(cnic: widget.cnic)),
      );
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid OTP: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: cs.surface,
      body: SafeArea(
        child: KeyboardInsetPadding(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: <Widget>[
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
                      children: <Widget>[
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
                          'Enter the 4-digit OTP sent to your registered number',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Enter OTP',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                      ),
                      const Gap(8),
                      Text(
                        'We sent a 4-digit code to your registered number',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const Gap(24),
                      OtpInput(
                        onChanged: (v) => _otpValue = v,
                        onCompleted: (_) => _handleOtpSubmit(),
                      ),
                      const Gap(24),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: (_isVerifyingOtp || _isRequestingOtp) ? null : _handleOtpSubmit,
                          child: _isVerifyingOtp
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const Gap(12),
                      Center(
                        child: TextButton(
                          onPressed: (_resendSeconds > 0 || _isRequestingOtp || _isVerifyingOtp)
                              ? null
                              : () => _requestOtp(isResend: true),
                          child: Text(
                            _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Didn\'t receive OTP? Resend',
                          ),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Sign In'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
