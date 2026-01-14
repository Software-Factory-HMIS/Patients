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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Gap(20),
                      
                      // Logo area with modern styling
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/images/punjab.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.local_hospital_rounded,
                                size: 100,
                                color: colorScheme.primary,
                              );
                            },
                          ),
                        ),
                      ),
                      
                      const Gap(11),
                      
                      // Welcome text with modern styling
                      Text(
                        'Welcome back',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const Gap(6),
                      
                      Text(
                        'Enter your CNIC and password to continue',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const Gap(28),
                      
                      // Modern card container for form
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.95),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                    
                              // CNIC input field with modern styling
                              TextFormField(
                                controller: _cnicController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  _CnicInputFormatter(),
                                ],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'CNIC',
                                  hintText: '12345-1234567-1',
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.badge_outlined,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.error,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                  helperText: '13 digits (with or without dashes)',
                                  helperStyle: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                scrollPadding: const EdgeInsets.only(bottom: 100),
                                validator: (value) {
                                  final String? requiredResult = _requiredValidator(value, fieldName: 'CNIC');
                                  if (requiredResult != null) return requiredResult;
                                  
                                  final cnic = value!.trim();
                                  final digitsOnly = cnic.replaceAll(RegExp(r'[^0-9]'), '');
                                  
                                  if (digitsOnly.isEmpty) {
                                    return 'CNIC must contain digits';
                                  }
                                  
                                  if (digitsOnly.length != 13) {
                                    return 'CNIC must be exactly 13 digits';
                                  }
                                  
                                  return null;
                                },
                              ),
                              
                              const Gap(20),
                              
                              // Password input field with modern styling
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.lock_outlined,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword 
                                          ? Icons.visibility_outlined 
                                          : Icons.visibility_off_outlined,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.error,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                scrollPadding: const EdgeInsets.only(bottom: 100),
                                validator: (value) {
                                  final String? requiredResult = _requiredValidator(value, fieldName: 'Password');
                                  if (requiredResult != null) return requiredResult;
                                  return null;
                                },
                                onFieldSubmitted: (_) => _handleSignIn(),
                              ),
                              
                              const Gap(20),
                              
                              // Set Password button with modern styling
                              OutlinedButton.icon(
                                onPressed: _handleSetPassword,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.primary.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.lock_reset_outlined,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                label: Text(
                                  'Set Password',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              
                              const Gap(24),
                              
                              // Continue button with modern styling
                              FilledButton.icon(
                                onPressed: _loading ? null : _handleSignIn,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                                icon: _loading
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
                                    : const Icon(Icons.arrow_forward, size: 20),
                                label: _loading
                                    ? const Text('Signing in...')
                                    : const Text(
                                        'Sign In',
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
                      
                      // Registration option with modern styling
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'New user? ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: _handleRegister,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Register Now',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Gap(24),
                      
                      // Terms and Privacy with modern styling
                      Center(
                        child: Text(
                          'By continuing, you agree to our\nTerms of Service and Privacy Policy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const Gap(20),
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
      
      
      // Call login by CNIC and password API
      final patients = await apiClient.loginByCnic(cnic, password: password);
      
      if (!mounted) return;
      
      setState(() {
        _loading = false;
      });


      // Handle different cases
      if (patients.isEmpty) {
        // No patients found - show error and suggest registration
        _showNoPatientsFoundDialog(cnic);
      } else if (patients.length == 1) {
        // Single patient found - save and navigate directly (no OTP required for sign in)
        await _handleSinglePatient(patients[0]);
      } else {
        // Multiple patients found - show selection screen
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

 
