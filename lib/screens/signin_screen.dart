import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'otp_screen.dart';
import 'registration_phone_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import '../utils/mock_user.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _mrnController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Test API connection when app launches
    _testApiConnection();
    // Initialize mock user if no user data exists
    _initializeMockUserIfNeeded();
    // Load saved user data to pre-fill form
    _loadSavedUserData();
  }

  Future<void> _initializeMockUserIfNeeded() async {
    try {
      final shouldUseMock = await MockUser.shouldUseMockUser();
      if (shouldUseMock) {
        await MockUser.initializeMockUser();
      }
    } catch (e) {
      debugPrint('Error initializing mock user: $e');
    }
  }

  Future<void> _loadSavedUserData() async {
    try {
      final phoneNumber = await UserStorage.getPhoneNumber();
      if (phoneNumber != null && mounted) {
        _mrnController.text = phoneNumber;
      }
    } catch (e) {
      debugPrint('Error loading saved user data: $e');
    }
  }

  @override
  void dispose() {
    _mrnController.dispose();
    super.dispose();
  }

  Future<void> _testApiConnection() async {
    try {
      // Wait a bit for the UI to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Create API client with fallback mechanism
      final apiClient = await EmrApiClient.create();
      
      // Test the connection
      final isConnected = await apiClient.testConnection();
      
      if (mounted && isConnected) {
        // Show success toast message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('API connection established'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Silently fail - don't show error toast on launch
      // Connection issues will be handled when API is actually used
      if (mounted) {
        debugPrint('API connection test failed: $e');
      }
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
      backgroundColor: Colors.grey.shade50,
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
                    
                    // Logo area
                    Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Image.asset(
                          'assets/images/punjab.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.local_hospital,
                              size: 60,
                              color: Colors.blue.shade600,
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const Gap(32),
                    
                    // Welcome text
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Gap(8),
                    
                    Text(
                      'Enter your mobile number to continue',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Gap(48),
                    
                    // Mobile number input field - larger and more touch-friendly
                    TextFormField(
                      controller: _mrnController,
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
                    
                    const Gap(16),
                    
                    // Registration option for new users
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New user? ',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          TextButton(
                            onPressed: _handleRegister,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Register',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Gap(16),
                    
                    // Continue button - larger and more touch-friendly
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _loading ? null : _handleSignIn,
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
                                'Continue',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const Gap(24),
                    
                    // Terms and Privacy
                    Center(
                      child: Text(
                        'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
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

  void _handleSignIn() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final mrn = _mrnController.text.trim();
    
    setState(() {
      _loading = true;
    });

    // Simulate a brief loading state for better UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtpScreen(cnic: mrn),
          ),
        );
      }
    });
  }

  void _handleRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegistrationPhoneScreen(),
      ),
    );
  }
}

 
