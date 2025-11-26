import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'otp_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/api_config.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _mrnController = TextEditingController();
  EmrApiClient? _api;
  bool _loading = false;
  String? _error;

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
    _mrnController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    print('🚀 Initializing API client for physical device...');
    try {
      _api = await EmrApiClient.create();
      print('✅ API client initialized successfully');
    } catch (e) {
      print('❌ API client initialization failed: $e');
      // Don't throw here, let _handleSignIn handle the fallback
    }
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
                        // Logo area
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
                        Gap(getResponsiveSize(24)),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Welcome back',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: getResponsiveFontSize(32),
                            ),
                          ),
                        ),
                        Gap(getResponsiveSize(12)),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Enter your MRN to continue',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        Gap(getResponsiveSize(10)),
                        
                        // Feature highlights (match login page styling)
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
                                'Secure Access',
                                'Your data is protected with enterprise-grade security',
                                Colors.white.withOpacity(0.9),
                                getResponsiveSize(12),
                              ),
                              Gap(getResponsiveSize(12)),
                              _buildFeatureItem(
                                Icons.medical_services_rounded,
                                'Healthcare Management',
                                'Comprehensive patient and family management system',
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
                                // Sign In title
                                Text(
                                  'Sign In',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: getResponsiveFontSize(28),
                                  ),
                                ),
                                Gap(getResponsiveSize(12)),
                                Text(
                                  'Enter your CNIC to access your account',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Gap(getResponsiveSize(32)),
                                
                                // MRN input field
                                TextFormField(
                                  controller: _mrnController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(14),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'MRN',
                                    hintText: 'Enter 13 or 14 digit MRN (numbers only)',
                                    border: OutlineInputBorder(),
                                    helperText: 'MRN must be 13 or 14 digits long',
                                  ),
                                  scrollPadding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).viewInsets.bottom + getResponsiveSize(120),
                                  ),
                                  validator: (value) {
                                    final String? requiredResult = _requiredValidator(value, fieldName: 'MRN');
                                    if (requiredResult != null) return requiredResult;
                                    
                                    // Validate MRN format (numbers only, 13 or 14 digits)
                                    final mrn = value!.trim();
                                    if (!RegExp(r'^\d+$').hasMatch(mrn)) {
                                      return 'MRN must contain only numbers';
                                    }
                                    
                                    if (mrn.length != 13 && mrn.length != 14) {
                                      return 'MRN must be exactly 13 or 14 digits';
                                    }
                                    
                                    return null;
                                  },
                                ),
                                Gap(getResponsiveSize(24)),
                                
                                // Continue button
                                SizedBox(
                                  height: getResponsiveSize(56),
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _loading ? null : _handleSignIn,
                                    child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Continue'),
                                  ),
                                ),
                                Gap(getResponsiveSize(16)),
                                
                                // Terms and Privacy
                                Center(
                                  child: Text(
                                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
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

  void _handleSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final mrn = _mrnController.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Ensure API client is initialized with fallback
      if (_api == null) {
        print('🔄 Initializing API client with fallback for physical device...');
        // Detect device network configuration first
        await detectDeviceNetwork();
        // Test all URLs for debugging
        await testAllUrls();
        _api = await EmrApiClient.create();
      }

      // Test connection first
      print('🔍 Testing API connection on physical device...');
      final isConnected = await _api!.testConnection();
      if (!isConnected) {
        print('❌ Connection failed on physical device');
        printNetworkInfo();
        throw Exception('Cannot connect to server. Please check your network connection.');
      }
      
      print('✅ Successfully connected to API server');

      // Fetch patient data
      final patient = await _api!.fetchPatient(mrn);
      
      // Proceed to placeholder OTP screen (bypass supported there)
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtpScreen(cnic: mrn),
          ),
        );
      }
    } catch (e) {
      print('❌ Sign-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('connect') 
                ? 'Connection failed. Please check your network and try again.'
                : 'No user found for provided MRN'),
            backgroundColor: Colors.red,
          ),
        );
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

 
