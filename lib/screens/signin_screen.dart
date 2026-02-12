import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'phone_confirm_screen.dart';
import 'id_scanner_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';

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
                        'Welcome',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const Gap(6),
                      
                      Text(
                        'Enter your CNIC to continue',
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
                                textInputAction: TextInputAction.done,
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
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.camera_alt_outlined,
                                      color: colorScheme.primary,
                                    ),
                                    tooltip: 'Scan ID Card',
                                    onPressed: _openIDScanner,
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
                                onFieldSubmitted: (_) => _handleContinue(),
                              ),
                              
                              const Gap(24),
                              
                              // Continue button with modern styling
                              FilledButton.icon(
                                onPressed: _loading ? null : _handleContinue,
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
                                    ? const Text('Looking up...')
                                    : const Text(
                                        'Continue',
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
                      
                      // Help section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                            const Gap(8),
                            Text(
                              'Not registered yet?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const Gap(4),
                            Text(
                              'Please visit hospital reception for registration',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
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

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    // Get and clean CNIC
    final cnic = _cnicController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    
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
      final apiClient = EmrApiClient();
      
      // Call lookup endpoint
      final result = await apiClient.lookupPatient(cnic: cnic);
      
      if (!mounted) return;
      
      setState(() {
        _loading = false;
      });

      final found = result['found'] as bool? ?? false;
      final maskedPhone = result['maskedPhone'] as String?;
      final patientName = result['patientName'] as String?;
      final message = result['message'] as String?;

      if (!found) {
        // Patient not found - show dialog
        _showNotFoundDialog(cnic, message);
      } else if (maskedPhone == null || maskedPhone.isEmpty) {
        // Patient found but no phone number
        _showNoPhoneDialog(patientName);
      } else {
        // Patient found with phone - navigate to phone confirm screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PhoneConfirmScreen(
              cnic: cnic,
              maskedPhone: maskedPhone,
              patientName: patientName ?? 'Patient',
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
            onPressed: () => _handleContinue(),
          ),
        ),
      );
    }
  }

  void _showNotFoundDialog(String cnic, String? message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Account Not Found'),
          ],
        ),
        content: Text(
          message ?? 'No patient account found with CNIC: $cnic\n\nPlease visit hospital reception for registration.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNoPhoneDialog(String? patientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_disabled, color: Colors.orange),
            SizedBox(width: 8),
            Text('No Phone Number'),
          ],
        ),
        content: Text(
          'Hello ${patientName ?? 'Patient'},\n\nYour account does not have a phone number on record. Please visit hospital reception to update your contact information.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Opens the ID card scanner for fast CNIC capture
  Future<void> _openIDScanner() async {
    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const IDScannerScreen(),
      ),
    );
    
    if (imagePath != null && mounted) {
      // TODO: In future, OCR can be added here to extract CNIC from the image
      // For now, show success message that image was captured
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('ID card captured successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
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
