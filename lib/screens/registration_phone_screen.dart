import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'registration_otp_screen.dart';
import '../utils/keyboard_inset_padding.dart';

class RegistrationPhoneScreen extends StatefulWidget {
  const RegistrationPhoneScreen({super.key});

  @override
  State<RegistrationPhoneScreen> createState() => _RegistrationPhoneScreenState();
}

class _RegistrationPhoneScreenState extends State<RegistrationPhoneScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;

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

  void _handleContinue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final phoneNumber = _phoneController.text.trim();
    
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
            builder: (context) => RegistrationOtpScreen(phoneNumber: phoneNumber),
          ),
        );
      }
    });
  }
}

