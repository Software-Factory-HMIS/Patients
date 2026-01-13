import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'otp_screen.dart';
import 'registration_phone_screen.dart';
import 'patient_selection_screen.dart';
import 'dashboard_screen.dart';
import 'set_password_phone_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Load saved user data to pre-fill form
    _loadSavedUserData();
  }

  Future<void> _loadSavedUserData() async {
    try {
      final userData = await UserStorage.getUserData();
      if (userData != null && mounted) {
        final cnic = userData['CNIC'] ?? userData['cnic'];
        if (cnic != null && cnic.toString().isNotEmpty) {
          _cnicController.text = cnic.toString();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved user data: $e');
    }
  }

  @override
  void dispose() {
    _cnicController.dispose();
    _passwordController.dispose();
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
                      'Enter your CNIC and password to continue',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Gap(48),
                    
                    // CNIC input field - larger and more touch-friendly
                    TextFormField(
                      controller: _cnicController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        _CnicInputFormatter(),
                      ],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'CNIC',
                        hintText: '12345-1234567-1 or 1234512345671',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        helperText: 'CNIC: 13 digits (with or without dashes)',
                        helperStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 100),
                      validator: (value) {
                        final String? requiredResult = _requiredValidator(value, fieldName: 'CNIC');
                        if (requiredResult != null) return requiredResult;
                        
                        // Validate CNIC format - accept with or without dashes
                        final cnic = value!.trim();
                        // Remove dashes and non-digits for validation
                        final digitsOnly = cnic.replaceAll(RegExp(r'[^0-9]'), '');
                        
                        if (digitsOnly.isEmpty) {
                          return 'CNIC must contain digits';
                        }
                        
                        if (digitsOnly.length != 13) {
                          return 'CNIC must be exactly 13 digits (format: 12345-1234567-1 or 1234512345671)';
                        }
                        
                        return null;
                      },
                    ),
                    
                    const Gap(16),
                    
                    // Password input field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 100),
                      validator: (value) {
                        final String? requiredResult = _requiredValidator(value, fieldName: 'Password');
                        if (requiredResult != null) return requiredResult;
                        return null;
                      },
                    ),
                    
                    const Gap(16),
                    
                    // Set Password button for existing users without password
                    OutlinedButton.icon(
                      onPressed: _handleSetPassword,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.blue.shade300),
                      ),
                      icon: Icon(Icons.lock_reset, color: Colors.blue.shade700),
                      label: Text(
                        'Set Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
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

  Future<void> _handleSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    // Get and clean CNIC and password
    // Remove dashes from CNIC before sending to API
    final cnic = _cnicController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final password = _passwordController.text;
    
    if (cnic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a CNIC'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _loading = true;
    });

    try {
      // Initialize API client
      final apiClient = EmrApiClient();
      
      print('🔍 [SignIn] Attempting login with CNIC: $cnic');
      
      // Call login by CNIC and password API
      final patients = await apiClient.loginByCnic(cnic, password: password);
      
      if (!mounted) return;
      
      setState(() {
        _loading = false;
      });

      print('✅ [SignIn] Found ${patients.length} patient(s)');

      // Handle different cases
      if (patients.isEmpty) {
        // No patients found - show error and suggest registration
        print('⚠️ [SignIn] No patients found');
        _showNoPatientsFoundDialog(cnic);
      } else if (patients.length == 1) {
        // Single patient found - save and navigate directly (no OTP required for sign in)
        print('✅ [SignIn] Single patient found, navigating to dashboard');
        await _handleSinglePatient(patients[0]);
      } else {
        // Multiple patients found - show selection screen
        print('✅ [SignIn] Multiple patients found, showing selection screen');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PatientSelectionScreen(
              patients: patients,
              phoneNumber: cnic, // Reusing phoneNumber parameter name for identifier
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      print('❌ [SignIn] Error during login: $e');
      
      setState(() {
        _loading = false;
      });
      
      // Extract error message
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.replaceAll('Exception: ', '');
      }
      if (errorMessage.contains('No patients found')) {
        // If it's a "not found" error, show the dialog instead
        _showNoPatientsFoundDialog(cnic);
        return;
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessage,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _handleSignIn(),
          ),
        ),
      );
    }
  }

  Future<void> _handleSinglePatient(
    Map<String, dynamic> patient,
  ) async {
    try {
      // Save patient data to both UserStorage and AuthService
      await UserStorage.saveUserData(patient);
      await AuthService.instance.saveLoginResponse(patient);
      
      // Get MRN or CNIC for navigation
      final mrn = patient['MRN'] ?? patient['mrn'] ?? '';
      final cnic = patient['CNIC'] ?? patient['cnic'] ?? '';
      final identifier = mrn.isNotEmpty ? mrn : cnic;
      
      if (!mounted) return;
      
      // Navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(cnic: identifier),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving patient data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showNoPatientsFoundDialog(String cnic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('No Account Found'),
          ],
        ),
        content: Text(
          'No patient account found with CNIC: $cnic\n\nWould you like to register a new account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleRegister();
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _handleRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegistrationPhoneScreen(),
      ),
    );
  }

  void _handleSetPassword() {
    // Get CNIC from the form
    final cnic = _cnicController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cnic.isEmpty || cnic.length != 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid CNIC first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Navigate to set password flow
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SetPasswordPhoneScreen(cnic: cnic),
      ),
    );
  }
}

// CNIC input formatter - formats as user types (12345-1234567-1)
class _CnicInputFormatter extends TextInputFormatter {
  static final RegExp _nonDigit = RegExp(r'[^0-9]');
  
  static String _formatCnic(String raw) {
    final String digits = raw.replaceAll(_nonDigit, '');
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length && i < 13; i++) {
      out.write(digits[i]);
      if (i == 4 || i == 11) {
        if (i != digits.length - 1) out.write('-');
      }
    }
    return out.toString();
  }
  
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final String formatted = _formatCnic(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

 
