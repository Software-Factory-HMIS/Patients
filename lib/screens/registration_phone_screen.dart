import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'registration_otp_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/api_config.dart';

class RegistrationPhoneScreen extends StatefulWidget {
  const RegistrationPhoneScreen({super.key});

  @override
  State<RegistrationPhoneScreen> createState() => _RegistrationPhoneScreenState();
}

class _RegistrationPhoneScreenState extends State<RegistrationPhoneScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;
  EmrApiClient? _apiClient;

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
    _phoneController.dispose();
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
        title: const Text('Phone Verification'),
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
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.phone_android,
                          size: 40,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    
                    const Gap(32),
                    
                    // Title
                    Text(
                      'Enter your mobile number',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Gap(8),
                    
                    Text(
                      'We will send you an OTP to verify your number',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Gap(48),
                    
                    // Phone number input field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter mobile number',
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
                        helperText: 'Mobile number must be 7-15 digits',
                        helperStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 100),
                      validator: (value) {
                        final String? requiredResult = _requiredValidator(value, fieldName: 'Mobile number');
                        if (requiredResult != null) return requiredResult;
                        
                        // Validate mobile number format (numbers only, 7-15 digits)
                        final mobileNumber = value!.trim();
                        if (mobileNumber.isEmpty) {
                          return 'Mobile number is required';
                        }
                        
                        if (!RegExp(r'^\d+$').hasMatch(mobileNumber)) {
                          return 'Mobile number must contain only digits';
                        }
                        
                        if (mobileNumber.length < 7 || mobileNumber.length > 15) {
                          return 'Mobile number must be 7-15 digits';
                        }
                        
                        return null;
                      },
                    ),
                    
                    const Gap(32),
                    
                    // Continue button
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _loading ? null : _handleContinue,
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
                    
                    // Debug info (only in debug mode)
                    if (kDebugMode) ...[
                      const Gap(16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Debug Info',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'API Base URL: ${resolveEmrBaseUrl()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
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

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final phoneNumber = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    
    // Additional validation
    if (phoneNumber.isEmpty || phoneNumber.length < 7 || phoneNumber.length > 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid mobile number (7-15 digits)'),
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
      _loading = true;
    });

    // First, test connection if we get a network error
    try {
      // Request OTP from server (server generates and sends via SMS)
      final response = await _apiClient!.requestRegistrationOtp(phoneNumber: phoneNumber);
      
      if (!mounted) return;
      
      // Check response for success
      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? 'OTP sent to your phone number';
      final cooldown = response['cooldownSecondsRemaining'] as int? ?? 0;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Navigate to OTP entry screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RegistrationOtpScreen(
              phoneNumber: phoneNumber,
            ),
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
      debugPrint('❌ Error requesting registration OTP: $e');
      if (mounted) {
        final errorStr = e.toString();
        String userMessage = 'Failed to send OTP';
        String? debugDetails;
        bool isNetworkError = errorStr.contains('Network error') || 
                             errorStr.contains('ClientException') ||
                             errorStr.contains('Connection failed');
        
        // If it's a network error, test the connection first
        if (isNetworkError && _apiClient != null) {
          try {
            debugPrint('🔍 Testing server connection...');
            final connectionTest = await _apiClient!.testConnection();
            debugPrint('📊 Connection test result: $connectionTest');
            
            if (connectionTest['connected'] == false) {
              // Build detailed connection diagnostics
              final buffer = StringBuffer();
              buffer.writeln('Connection Test Failed');
              buffer.writeln('====================');
              buffer.writeln('Base URL: ${connectionTest['baseUrl']}');
              buffer.writeln('Test Endpoint: ${connectionTest['testEndpoint']}');
              buffer.writeln('Message: ${connectionTest['message']}');
              
              if (connectionTest.containsKey('testEndpointError')) {
                buffer.writeln('\nTest Endpoint Error:');
                buffer.writeln('  ${connectionTest['testEndpointError']}');
              }
              if (connectionTest.containsKey('healthEndpointError')) {
                buffer.writeln('\nHealth Endpoint Error:');
                buffer.writeln('  ${connectionTest['healthEndpointError']}');
              }
              if (connectionTest.containsKey('timeout')) {
                buffer.writeln('\n⚠️ Connection timeout - server may be unreachable');
              }
              if (connectionTest.containsKey('networkError')) {
                buffer.writeln('\n⚠️ Network error - check internet connection');
              }
              
              debugDetails = buffer.toString();
              userMessage = 'Cannot connect to server. See diagnostics below.';
            } else {
              // Connection test passed, so the error is something else
              debugDetails = errorStr;
            }
          } catch (testError) {
            debugPrint('⚠️ Connection test also failed: $testError');
            debugDetails = 'Original Error:\n$errorStr\n\nConnection Test Error:\n$testError';
          }
        } else {
          // Extract user-friendly message and debug details
          if (errorStr.contains('Debug Info:')) {
            final parts = errorStr.split('Debug Info:');
            userMessage = parts[0].trim();
            debugDetails = parts.length > 1 ? parts[1].trim() : null;
          } else {
            // Check for specific error types
            if (errorStr.contains('wait') || errorStr.contains('cooldown')) {
              userMessage = 'Please wait before requesting another OTP.';
            } else if (errorStr.contains('Invalid phone') || errorStr.contains('Invalid request')) {
              userMessage = 'Invalid phone number format.';
            } else if (errorStr.contains('400') || errorStr.contains('Bad Request')) {
              userMessage = 'Invalid request. Please check your phone number.';
              debugDetails = errorStr;
            } else if (errorStr.contains('500') || errorStr.contains('Internal Server')) {
              userMessage = 'Server error occurred. See details below.';
              debugDetails = errorStr;
            } else if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
              userMessage = 'Request timed out. Please check your internet connection.';
              debugDetails = errorStr;
            } else {
              userMessage = 'Failed to send OTP. See error details below.';
              debugDetails = errorStr;
            }
          }
        }
        
        // Show detailed error dialog for debugging
        _showErrorDialog(context, userMessage, debugDetails ?? errorStr);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showErrorDialog(BuildContext context, String userMessage, String debugDetails) {
    final baseUrl = resolveEmrBaseUrl();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userMessage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Base URL: $baseUrl',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text(
                  'Debug Information',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                initiallyExpanded: true, // Expanded by default for easier debugging
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      debugDetails,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Copy to clipboard
              Clipboard.setData(ClipboardData(text: debugDetails));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error details copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy Details'),
          ),
        ],
      ),
    );
  }
}

