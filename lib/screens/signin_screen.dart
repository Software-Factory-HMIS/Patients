import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'otp_screen.dart';
import 'registration_phone_screen.dart';
import 'patient_selection_screen.dart';
import 'dashboard_screen.dart';
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
  final TextEditingController _cnicController = TextEditingController();
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
                      'Enter your CNIC to continue',
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
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'CNIC',
                        hintText: 'Enter 13 digit CNIC number',
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
                        helperText: 'CNIC must be exactly 13 digits',
                        helperStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 100),
                      validator: (value) {
                        final String? requiredResult = _requiredValidator(value, fieldName: 'CNIC');
                        if (requiredResult != null) return requiredResult;
                        
                        // Validate CNIC format (numbers only, exactly 13 digits)
                        final cnic = value!.trim();
                        if (!RegExp(r'^\d+$').hasMatch(cnic)) {
                          return 'CNIC must contain only digits';
                        }
                        
                        if (cnic.length != 13) {
                          return 'CNIC must be exactly 13 digits';
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

  Future<void> _handleSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    // Get and clean CNIC
    final cnic = _cnicController.text.trim();
    
    if (cnic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a CNIC'),
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
      final apiClient = await EmrApiClient.create();
      
      print('🔍 [SignIn] Attempting login with CNIC: $cnic');
      
      // Call login by CNIC API
      final patients = await apiClient.loginByCnic(cnic);
      
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
        // Single patient found - save and navigate directly
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
      // Save patient data
      await UserStorage.saveUserData(patient);
      
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
}

 
