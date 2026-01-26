import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'signin_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/user_storage.dart';
import '../utils/emr_api_client.dart';
import '../services/app_settings.dart';

class RegistrationScreen extends StatefulWidget {
  final String? phoneNumber;
  final bool isAddOthers;
  final String? relationshipType; // 'Spouse', 'Parent', 'Child'
  final String? parentCnic; // For children registration
  final String? parentAddress; // For "Add Others" - pre-fill address from first user
  final Map<String, dynamic>? originalPatientData; // Original person's data for "Add Others"
  
  const RegistrationScreen({
    super.key,
    this.phoneNumber,
    this.isAddOthers = false,
    this.relationshipType,
    this.parentCnic,
    this.parentAddress,
    this.originalPatientData,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Language state - default to Urdu
  bool _isUrdu = true;
  
  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // State variables
  DateTime? _dateOfBirth;
  String? _gender; // 'Male' or 'Female'
  String? _bloodGroup; // dropdown
  String? _registrationType; // 'Self' or 'Others' - defaults to 'Self' for first registration
  String? _parentType; // 'Father' or 'Mother'
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showDetailsCard = false; // Show details card after successful registration
  Map<String, dynamic>? _registeredPatientData; // Store registered patient data (for self registration)
  Map<String, dynamic>? _newlyAddedPatientData; // Store newly added patient data (for "Add Others")
  EmrApiClient? _apiClient; // API client for patient registration
  
  // Translation maps
  Map<String, String> get _translations => _isUrdu ? _urduTranslations : _englishTranslations;
  
  static const Map<String, String> _englishTranslations = {
    'appBarTitle': 'Patient Registration',
    'registerAs': 'Register as:',
    'self': 'Self',
    'others': 'Others',
    'parentType': 'Parent Type',
    'selectParentType': 'Select parent type',
    'father': 'Father',
    'mother': 'Mother',
    'fullName': 'Full name',
    'cnic': 'CNIC',
    'fathersCnic': 'Father\'s CNIC',
    'mothersCnic': 'Mother\'s CNIC',
    'parentsCnic': 'Parent\'s CNIC',
    'dateOfBirth': 'Date of birth',
    'selectDate': 'Select date',
    'gender': 'Gender',
    'male': 'Male',
    'female': 'Female',
    'email': 'Email',
    'emailOptional': 'Email (Optional)',
    'phone': 'Phone',
    'address': 'Address',
    'addressOptional': 'Address (Optional)',
    'bloodGroup': 'Blood group',
    'bloodGroupOptional': 'Blood group (Optional)',
    'selectBloodGroup': 'Select blood group',
    'selectRelation': 'Select relation',
    'completeRegistration': 'Complete Registration',
    'required': 'is required',
    'optional': '(Optional)',
    'selectRegistrationType': 'Please select registration type (Self or Others)',
    'selectDateOfBirth': 'Please select date of birth',
    'selectGender': 'Please select gender',
    'enterValidEmail': 'Enter a valid email address',
    'enterValidPhone': 'Enter a valid phone number',
    'enterCnicFormat': 'Enter CNIC as 12345-1234567-1',
    'registrationSuccessful': 'Registration successful!',
    'languageToggle': 'English',
    'password': 'Password',
    'confirmPassword': 'Confirm Password',
    'passwordRequirements': 'Password must be at least 8 characters and contain uppercase, lowercase, number, and special character',
    'passwordsDoNotMatch': 'Passwords do not match',
  };
  
  static const Map<String, String> _urduTranslations = {
    'appBarTitle': 'Ù…Ø±ÛŒØ¶ Ú©ÛŒ Ø±Ø¬Ø³Ù¹Ø±ÛŒØ´Ù†',
    'registerAs': 'Ø±Ø¬Ø³Ù¹Ø± Ú©Ø±ÛŒÚº Ø¨Ø·ÙˆØ±:',
    'self': 'Ø®ÙˆØ¯',
    'others': 'Ø¯ÙˆØ³Ø±Û’',
    'parentType': 'ÙˆØ§Ù„Ø¯ÛŒÙ† Ú©ÛŒ Ù‚Ø³Ù…',
    'selectParentType': 'ÙˆØ§Ù„Ø¯ÛŒÙ† Ú©ÛŒ Ù‚Ø³Ù… Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº',
    'father': 'ÙˆØ§Ù„Ø¯',
    'mother': 'ÙˆØ§Ù„Ø¯Û',
    'fullName': 'Ù…Ú©Ù…Ù„ Ù†Ø§Ù…',
    'cnic': 'Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ',
    'fathersCnic': 'ÙˆØ§Ù„Ø¯ Ú©Ø§ Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ',
    'mothersCnic': 'ÙˆØ§Ù„Ø¯Û Ú©Ø§ Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ',
    'parentsCnic': 'ÙˆØ§Ù„Ø¯ÛŒÙ† Ú©Ø§ Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ',
    'dateOfBirth': 'ØªØ§Ø±ÛŒØ® Ù¾ÛŒØ¯Ø§Ø¦Ø´',
    'selectDate': 'ØªØ§Ø±ÛŒØ® Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº',
    'gender': 'Ø¬Ù†Ø³',
    'male': 'Ù…Ø±Ø¯',
    'female': 'Ø¹ÙˆØ±Øª',
    'email': 'Ø§ÛŒ Ù…ÛŒÙ„',
    'emailOptional': 'Ø§ÛŒ Ù…ÛŒÙ„ (Ø§Ø®ØªÛŒØ§Ø±ÛŒ)',
    'phone': 'ÙÙˆÙ†',
    'address': 'Ù¾ØªÛ',
    'addressOptional': 'Ù¾ØªÛ (Ø§Ø®ØªÛŒØ§Ø±ÛŒ)',
    'bloodGroup': 'Ø®ÙˆÙ† Ú©Ø§ Ú¯Ø±ÙˆÙ¾',
    'bloodGroupOptional': 'Ø®ÙˆÙ† Ú©Ø§ Ú¯Ø±ÙˆÙ¾ (Ø§Ø®ØªÛŒØ§Ø±ÛŒ)',
    'selectBloodGroup': 'Ø®ÙˆÙ† Ú©Ø§ Ú¯Ø±ÙˆÙ¾ Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº',
    'selectRelation': 'Ø±Ø´ØªÛ Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº',
    'completeRegistration': 'Ø±Ø¬Ø³Ù¹Ø±ÛŒØ´Ù† Ù…Ú©Ù…Ù„ Ú©Ø±ÛŒÚº',
    'required': 'Ø¯Ø±Ú©Ø§Ø± ÛÛ’',
    'optional': '(Ø§Ø®ØªÛŒØ§Ø±ÛŒ)',
    'selectRegistrationType': 'Ø¨Ø±Ø§Û Ú©Ø±Ù… Ø±Ø¬Ø³Ù¹Ø±ÛŒØ´Ù† Ú©ÛŒ Ù‚Ø³Ù… Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº (Ø®ÙˆØ¯ ÛŒØ§ Ø¯ÙˆØ³Ø±Û’)',
    'selectDateOfBirth': 'Ø¨Ø±Ø§Û Ú©Ø±Ù… ØªØ§Ø±ÛŒØ® Ù¾ÛŒØ¯Ø§Ø¦Ø´ Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº',
    'selectGender': 'Ø¨Ø±Ø§Û Ú©Ø±Ù… Ø¬Ù†Ø³ Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº',
    'enterValidEmail': 'Ø¯Ø±Ø³Øª Ø§ÛŒ Ù…ÛŒÙ„ Ø§ÛŒÚˆØ±ÛŒØ³ Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚº',
    'enterValidPhone': 'Ø¯Ø±Ø³Øª ÙÙˆÙ† Ù†Ù…Ø¨Ø± Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚº',
    'enterCnicFormat': 'Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ 12345-1234567-1 Ú©ÛŒ Ø´Ú©Ù„ Ù…ÛŒÚº Ø¯Ø±Ø¬ Ú©Ø±ÛŒÚº',
    'registrationSuccessful': 'Ø±Ø¬Ø³Ù¹Ø±ÛŒØ´Ù† Ú©Ø§Ù…ÛŒØ§Ø¨!',
    'languageToggle': 'Ø§Ø±Ø¯Ùˆ',
    'password': 'Ù¾Ø§Ø³ ÙˆØ±Úˆ',
    'confirmPassword': 'Ù¾Ø§Ø³ ÙˆØ±Úˆ Ú©ÛŒ ØªØµØ¯ÛŒÙ‚',
    'passwordRequirements': 'Ù¾Ø§Ø³ ÙˆØ±Úˆ Ú©Ù… Ø§Ø² Ú©Ù… 8 Ø­Ø±ÙˆÙ Ú©Ø§ ÛÙˆÙ†Ø§ Ú†Ø§ÛÛŒÛ’ Ø§ÙˆØ± Ø¨Ú‘Û’ Ø­Ø±ÙˆÙØŒ Ú†Ú¾ÙˆÙ¹Û’ Ø­Ø±ÙˆÙØŒ Ù†Ù…Ø¨Ø± Ø§ÙˆØ± Ø®Ø§Øµ Ø¹Ù„Ø§Ù…Øª Ø´Ø§Ù…Ù„ ÛÙˆÙ†ÛŒ Ú†Ø§ÛÛŒÛ’',
    'passwordsDoNotMatch': 'Ù¾Ø§Ø³ ÙˆØ±Úˆ Ù…ÛŒÙ„ Ù†ÛÛŒÚº Ú©Ú¾Ø§ØªÛ’',
  };
  
  // Dropdown options translations
  List<String> get _parentTypeOptions => _isUrdu 
      ? ['ÙˆØ§Ù„Ø¯', 'ÙˆØ§Ù„Ø¯Û']
      : ['Father', 'Mother'];
  
  List<String> get _genderOptions => _isUrdu
      ? ['Ù…Ø±Ø¯', 'Ø¹ÙˆØ±Øª']
      : ['Male', 'Female'];
  

  @override
  void initState() {
    super.initState();
    _isUrdu = AppSettings.instance.languageCode.value == 'ur';
    // Set default registration type to 'Self' for first registration
    if (!widget.isAddOthers) {
      _registrationType = 'Self';
    } else {
      _registrationType = 'Others';
    }
    
    // Set phone number if provided
    if (widget.phoneNumber != null) {
      _phoneController.text = widget.phoneNumber!;
    }
    
    // Set parent CNIC for children
    if (widget.isAddOthers && widget.relationshipType == 'Child' && widget.parentCnic != null) {
      _cnicController.text = widget.parentCnic!;
    }
    
    // Pre-fill address from parent for "Add Others"
    if (widget.isAddOthers && widget.parentAddress != null && widget.parentAddress!.isNotEmpty) {
      _addressController.text = widget.parentAddress!;
    }
    
    // Initialize API client
    _initializeApiClient();
  }
  
  Future<void> _initializeApiClient() async {
    try {
      _apiClient = EmrApiClient();
    } catch (e) {
      // Continue anyway - will show error when trying to register
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cnicController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName ${_translations['required']}';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '${_translations['password']} ${_translations['required']}';
    }
    
    if (value.length < 8) {
      return _translations['passwordRequirements'];
    }
    
    // Check for uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return _translations['passwordRequirements'];
    }
    
    // Check for lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return _translations['passwordRequirements'];
    }
    
    // Check for number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return _translations['passwordRequirements'];
    }
    
    // Check for special character
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return _translations['passwordRequirements'];
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '${_translations['confirmPassword']} ${_translations['required']}';
    }
    
    if (value != _passwordController.text) {
      return _translations['passwordsDoNotMatch'];
    }
    
    return null;
  }

  String _getCnicLabel() {
    if (widget.isAddOthers) {
      if (widget.relationshipType == 'Spouse') {
        return _isUrdu ? 'Ø´Ø±ÛŒÚ© Ø­ÛŒØ§Øª Ú©Ø§ Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ' : 'Spouse\'s CNIC';
      } else if (widget.relationshipType == 'Parent') {
        return _isUrdu ? 'ÙˆØ§Ù„Ø¯ÛŒÙ† Ú©Ø§ Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ' : 'Parent\'s CNIC';
      } else if (widget.relationshipType == 'Child') {
        return _isUrdu ? 'ÙˆØ§Ù„Ø¯ÛŒÙ† Ú©Ø§ Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ' : 'Parent\'s CNIC';
      }
    }
    // For first registration, check registration type
    if (_registrationType == 'Others') {
      if (_parentType == 'Father' || _parentType == 'ÙˆØ§Ù„Ø¯') {
        return _translations['fathersCnic']!;
      } else if (_parentType == 'Mother' || _parentType == 'ÙˆØ§Ù„Ø¯Û') {
        return _translations['mothersCnic']!;
      } else {
        return _translations['parentsCnic']!;
      }
    }
    // Default to Self CNIC
    return _translations['cnic']!;
  }
  
  String _getGenderValue(String displayText) {
    if (_isUrdu) {
      if (displayText == 'Ù…Ø±Ø¯') return 'Male';
      if (displayText == 'Ø¹ÙˆØ±Øª') return 'Female';
    }
    return displayText;
  }
  
  String _getGenderDisplay(String? value) {
    if (value == null) return '';
    if (_isUrdu) {
      return value == 'Male' ? 'Ù…Ø±Ø¯' : 'Ø¹ÙˆØ±Øª';
    }
    return value;
  }
  
  String _getParentTypeValue(String displayText) {
    if (_isUrdu) {
      if (displayText == 'ÙˆØ§Ù„Ø¯') return 'Father';
      if (displayText == 'ÙˆØ§Ù„Ø¯Û') return 'Mother';
    }
    return displayText;
  }
  
  String _getParentTypeDisplay(String? value) {
    if (value == null) return '';
    if (_isUrdu) {
      return value == 'Father' ? 'ÙˆØ§Ù„Ø¯' : 'ÙˆØ§Ù„Ø¯Û';
    }
    return value;
  }
  
  Widget _buildRelationshipChip({
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    final isSelected = widget.relationshipType == value;
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
            ? colorScheme.primaryContainer 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? colorScheme.primary 
              : colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
  

  // Formats numeric input into 12345-1234567-1 as the user types.
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

  Future<void> _handleSubmit() async {
    // Validate registration type only for first registration (not "Add Others")
    if (!widget.isAddOthers && _registrationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translations['selectRegistrationType']!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate parent type when Others is selected
    if ((!widget.isAddOthers && _registrationType == 'Others') && 
        (_parentType == null || _parentType!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translations['selectParentType']!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translations['selectDateOfBirth']!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translations['selectGender']!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Additional validation: Ensure password is provided for Self registration
    if (_registrationType == 'Self' && !widget.isAddOthers) {
      final passwordText = _passwordController.text.trim();
      if (passwordText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_translations['password']} ${_translations['required']}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Validate password meets requirements
      final passwordError = _validatePassword(passwordText);
      if (passwordError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(passwordError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      
      // Validate confirm password matches
      final confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text.trim());
      if (confirmPasswordError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(confirmPasswordError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Ensure API client is initialized
        if (_apiClient == null) {
          await _initializeApiClient();
        }
        
        if (_apiClient == null) {
          throw Exception('Failed to initialize API client');
        }

        // Prepare patient data
        final patientData = {
          'fullName': _fullNameController.text.trim(),
          'cnic': _cnicController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          'dateOfBirth': _dateOfBirth!,
          'gender': _gender!,
          'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          'bloodGroup': _bloodGroup,
          'password': _passwordController.text, // Only for Self registration
        };

        // Register patient via API
        // For patient self-registration, use default system user ID (1)
        // In a real system, this would be a dedicated "Self-Registration" system user
        const int defaultSystemUserId = 1;
        
        
        // Determine password to send - only for Self registration
        String? passwordToSend;
        if (_registrationType == 'Self' && !widget.isAddOthers) {
          final passwordText = _passwordController.text.trim();
          
          if (passwordText.isEmpty) {
            if (mounted) {
              setState(() {
                _isSubmitting = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_translations['password']} ${_translations['required']}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          passwordToSend = passwordText;
        } else {
        }
        
        
        final registeredPatient = await _apiClient!.registerPatient(
          fullName: patientData['fullName'] as String,
          cnic: patientData['cnic'] as String,
          phone: patientData['phone'] as String,
          email: patientData['email'] as String?,
          dateOfBirth: patientData['dateOfBirth'] as DateTime,
          gender: patientData['gender'] as String,
          address: patientData['address'] as String?,
          bloodGroup: patientData['bloodGroup'] as String?,
          password: passwordToSend, // Only for Self registration
          registrationType: _registrationType,
          parentType: _parentType,
          createdBy: defaultSystemUserId, // Required by database - use system user for self-registration
        );

        
        // Merge API response with form data
        final completePatientData = {
          ...patientData,
          'patientId': registeredPatient['patientId'] ?? registeredPatient['PatientID'],
          'mrn': registeredPatient['mrn'] ?? registeredPatient['MRN'],
        };

        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          if (widget.isAddOthers) {
            // For "Add Others" registration, store new patient data and show details card
            _newlyAddedPatientData = {
              ...completePatientData,
              'relationshipType': widget.relationshipType,
            };
            
            // Use original patient data from widget parameter
            _registeredPatientData = widget.originalPatientData;
            
            setState(() {
              _showDetailsCard = true;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_translations['registrationSuccessful']!),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // For self registration, store data and show details card
            _registeredPatientData = completePatientData;
            
            // Save user data for demonstration purposes
            await UserStorage.saveUserData(_registeredPatientData!);
            
            if (mounted) {
              setState(() {
                _showDetailsCard = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_translations['registrationSuccessful']!),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      } catch (e) {
        
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          // Extract error message
          String errorMessage = e.toString().replaceFirst('Exception: ', '');
          
          // If it's a database trigger error, provide more helpful message
          if (errorMessage.toLowerCase().contains('trigger')) {
            errorMessage = 'Database error: $errorMessage\\n\\n'
                'This might be due to:\\n'
                '- Missing required fields\\n'
                '- Data validation issues\\n'
                '- Database constraint violations\\n\\n'
                'Please check the console for details.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Details',
                textColor: Colors.white,
                onPressed: () {
                  // Show detailed error in a dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Registration Error'),
                      content: SingleChildScrollView(
                        child: Text(
                          'Full error details:\\n\\n$e',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    }
  }

  Widget _buildDetailsCard() {
    if (_registeredPatientData == null) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Language Toggle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ø§Ø±Ø¯Ùˆ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isUrdu ? Colors.blue.shade900 : Colors.grey.shade600,
                ),
              ),
              Switch(
                value: _isUrdu,
                onChanged: (value) {
                  setState(() {
                    _isUrdu = value;
                    AppSettings.instance.setLanguageCode(value ? 'ur' : 'en');
                  });
                },
                activeColor: Colors.blue.shade700,
              ),
              Text(
                'English',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: !_isUrdu ? Colors.blue.shade900 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const Gap(24),
        
        // Success Message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const Gap(12),
              Expanded(
                child: Text(
                  _translations['registrationSuccessful']!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(24),
        
        // Original Patient Details Card (Self)
        _buildPatientCard(
          title: _isUrdu ? 'Ø¢Ù¾ Ú©ÛŒ ØªÙØµÛŒÙ„Ø§Øª' : 'Your Details',
          patientData: _registeredPatientData!,
          isSelf: true,
        ),
        
        // Newly Added Patient Card (if "Add Others" registration)
        if (widget.isAddOthers && _newlyAddedPatientData != null) ...[
          const Gap(24),
          _buildPatientCard(
            title: _getRelationshipTitle(_newlyAddedPatientData!['relationshipType']),
            patientData: _newlyAddedPatientData!,
            isSelf: false,
            relationshipType: _newlyAddedPatientData!['relationshipType'],
          ),
        ],
        
        const Gap(24),
        
        // Add Others Button
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => _showAddOthersDialog(),
            icon: const Icon(Icons.person_add),
            label: Text(
              _isUrdu ? 'Ø¯ÙˆØ³Ø±Û’ Ø´Ø§Ù…Ù„ Ú©Ø±ÛŒÚº' : 'Add Others',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.blue.shade700, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const Gap(16),
        
        // Book Appointment Button
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const SignInScreen(),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _isUrdu ? 'Ø§Ù¾Ø§Ø¦Ù†Ù¹Ù…Ù†Ù¹ Ø¨Ú© Ú©Ø±ÛŒÚº' : 'Book Appointment',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const Gap(16),
        
        // Back to Sign In Button
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isUrdu ? 'Ø³Ø§Ø¦Ù† Ø§Ù† Ù¾Ø± ÙˆØ§Ù¾Ø³ Ø¬Ø§Ø¦ÛŒÚº' : 'Back to Sign In',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  String _getRelationshipTitle(String? relationshipType) {
    if (_isUrdu) {
      switch (relationshipType) {
        case 'Spouse':
          return 'Ø´Ø±ÛŒÚ© Ø­ÛŒØ§Øª Ú©ÛŒ ØªÙØµÛŒÙ„Ø§Øª';
        case 'Parent':
          return 'ÙˆØ§Ù„Ø¯ÛŒÙ† Ú©ÛŒ ØªÙØµÛŒÙ„Ø§Øª';
        case 'Child':
          return 'Ø§ÙˆÙ„Ø§Ø¯ Ú©ÛŒ ØªÙØµÛŒÙ„Ø§Øª';
        default:
          return 'Ù…Ø±ÛŒØ¶ Ú©ÛŒ ØªÙØµÛŒÙ„Ø§Øª';
      }
    } else {
      switch (relationshipType) {
        case 'Spouse':
          return 'Spouse Details';
        case 'Parent':
          return 'Parent Details';
        case 'Child':
          return 'Child Details';
        default:
          return 'Patient Details';
      }
    }
  }
  
  String _getRelationshipLabel(String? relationshipType) {
    if (_isUrdu) {
      switch (relationshipType) {
        case 'Spouse':
          return 'Ø´Ø±ÛŒÚ© Ø­ÛŒØ§Øª';
        case 'Parent':
          return 'ÙˆØ§Ù„Ø¯ÛŒÙ†';
        case 'Child':
          return 'Ø§ÙˆÙ„Ø§Ø¯';
        default:
          return 'Ù…Ø±ÛŒØ¶';
      }
    } else {
      switch (relationshipType) {
        case 'Spouse':
          return 'Spouse';
        case 'Parent':
          return 'Parent';
        case 'Child':
          return 'Child';
        default:
          return 'Patient';
      }
    }
  }
  
  Widget _buildPatientCard({
    required String title,
    required Map<String, dynamic> patientData,
    required bool isSelf,
    String? relationshipType,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                if (isSelf)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isUrdu ? 'Ø®ÙˆØ¯' : 'Self',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                if (!isSelf && relationshipType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getRelationshipLabel(relationshipType),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const Gap(20),
            _buildDetailRow(_isUrdu ? 'Ù…Ú©Ù…Ù„ Ù†Ø§Ù…' : 'Full Name', patientData['fullName'] ?? ''),
            _buildDetailRow(_isUrdu ? 'Ù‚ÙˆÙ…ÛŒ Ø´Ù†Ø§Ø®ØªÛŒ Ú©Ø§Ø±Úˆ' : 'CNIC', patientData['cnic'] ?? ''),
            _buildDetailRow(_isUrdu ? 'ÙÙˆÙ†' : 'Phone', patientData['phone'] ?? ''),
            _buildDetailRow(_isUrdu ? 'Ø§ÛŒ Ù…ÛŒÙ„' : 'Email', patientData['email'] ?? ''),
            if (patientData['dateOfBirth'] != null)
              _buildDetailRow(
                _isUrdu ? 'ØªØ§Ø±ÛŒØ® Ù¾ÛŒØ¯Ø§Ø¦Ø´' : 'Date of Birth',
                '${(patientData['dateOfBirth'] as DateTime).year}-${(patientData['dateOfBirth'] as DateTime).month.toString().padLeft(2, '0')}-${(patientData['dateOfBirth'] as DateTime).day.toString().padLeft(2, '0')}',
              ),
            if (patientData['gender'] != null)
              _buildDetailRow(
                _isUrdu ? 'Ø¬Ù†Ø³' : 'Gender',
                patientData['gender'] == 'Male' ? (_isUrdu ? 'Ù…Ø±Ø¯' : 'Male') : (_isUrdu ? 'Ø¹ÙˆØ±Øª' : 'Female'),
              ),
            if (patientData['bloodGroup'] != null)
              _buildDetailRow(_isUrdu ? 'Ø®ÙˆÙ† Ú©Ø§ Ú¯Ø±ÙˆÙ¾' : 'Blood Group', patientData['bloodGroup'] ?? ''),
            if (patientData['address'] != null && patientData['address'].toString().isNotEmpty)
              _buildDetailRow(_isUrdu ? 'Ù¾ØªÛ' : 'Address', patientData['address'] ?? ''),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAddOthersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isUrdu ? 'Ø±Ø´ØªÛ Ú©ÛŒ Ù‚Ø³Ù… Ù…Ù†ØªØ®Ø¨ Ú©Ø±ÛŒÚº' : 'Select Relationship Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(_isUrdu ? 'Ø´Ø±ÛŒÚ© Ø­ÛŒØ§Øª' : 'Spouse'),
              onTap: () {
                Navigator.of(context).pop();
                 Navigator.of(context).push(
                   MaterialPageRoute(
                     builder: (context) => RegistrationScreen(
                       phoneNumber: _registeredPatientData!['phone'],
                       isAddOthers: true,
                       relationshipType: 'Spouse',
                       parentAddress: _registeredPatientData!['address'] as String?,
                       originalPatientData: _registeredPatientData,
                     ),
                   ),
                 );
              },
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom),
              title: Text(_isUrdu ? 'ÙˆØ§Ù„Ø¯ÛŒÙ†' : 'Parent'),
              onTap: () {
                Navigator.of(context).pop();
                 Navigator.of(context).push(
                   MaterialPageRoute(
                     builder: (context) => RegistrationScreen(
                       phoneNumber: _registeredPatientData!['phone'],
                       isAddOthers: true,
                       relationshipType: 'Parent',
                       parentAddress: _registeredPatientData!['address'] as String?,
                       originalPatientData: _registeredPatientData,
                     ),
                   ),
                 );
              },
            ),
            ListTile(
              leading: const Icon(Icons.child_care),
              title: Text(_isUrdu ? 'Ø§ÙˆÙ„Ø§Ø¯' : 'Child'),
              onTap: () {
                Navigator.of(context).pop();
                 Navigator.of(context).push(
                   MaterialPageRoute(
                     builder: (context) => RegistrationScreen(
                       phoneNumber: _registeredPatientData!['phone'],
                       isAddOthers: true,
                       relationshipType: 'Child',
                       parentCnic: _registeredPatientData!['cnic'],
                       parentAddress: _registeredPatientData!['address'] as String?,
                       originalPatientData: _registeredPatientData,
                     ),
                   ),
                 );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.isAddOthers 
            ? (_isUrdu ? 'Ø¯ÙˆØ³Ø±Û’ Ú©ÛŒ Ø±Ø¬Ø³Ù¹Ø±ÛŒØ´Ù†' : 'Add Others Registration')
              : _translations['appBarTitle']!,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
        child: KeyboardInsetPadding(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 16),
              child: _showDetailsCard
                  ? _buildDetailsCard()
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                            const Gap(8),
                            
                            // Language Toggle - Modern Card
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: colorScheme.outline.withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Container(
                            decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.95),
                                    ],
                                  ),
                            ),
                                padding: const EdgeInsets.all(15),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Ø§Ø±Ø¯Ùˆ',
                                  style: TextStyle(
                                        fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                        color: _isUrdu ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Switch(
                                  value: _isUrdu,
                                  onChanged: (value) {
                                    setState(() {
                                      _isUrdu = value;
                    AppSettings.instance.setLanguageCode(value ? 'ur' : 'en');
                  });
                                  },
                                      activeColor: colorScheme.primary,
                                ),
                                Text(
                                  'English',
                                  style: TextStyle(
                                        fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                        color: !_isUrdu ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                            ),
                            const Gap(7),
                          // Registration type radio buttons - only show for first registration (not "Add Others")
                          if (!widget.isAddOthers) ...[
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: colorScheme.outline.withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.95),
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.person_outline,
                                            color: colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                        const Gap(12),
                                  Text(
                                    _translations['registerAs']!,
                                    style: TextStyle(
                                            fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                    ),
                                        ),
                                      ],
                                  ),
                                    const Gap(16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                            decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                          color: colorScheme.primary,
                                                width: 2,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _translations['self']!,
                                                style: TextStyle(
                                            fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                                        ),
                                      ),
                            const Gap(7),
                            // Parent Type selection - only show when Others is selected
                            if (_registrationType == 'Others') ...[
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: colorScheme.outline.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        Colors.white.withOpacity(0.95),
                                      ],
                                              ),
                                            ),
                                  padding: const EdgeInsets.all(15),
                                  child: DropdownButtonFormField<String>(
                                    value: _parentType,
                                    decoration: InputDecoration(
                                      labelText: _translations['parentType'],
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(10),
                                              ),
                                        child: Icon(
                                          Icons.family_restroom_outlined,
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
                                  filled: true,
                                      fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                        vertical: 18,
                                  ),
                                ),
                                items: _parentTypeOptions.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: _getParentTypeValue(type),
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _parentType = value;
                                  });
                                },
                                validator: (v) => v == null || v.isEmpty 
                                    ? _translations['selectParentType'] 
                                    : null,
                              ),
                                ),
                              ),
                              const Gap(7),
                            ],
                          ],
                          // Registration type radio buttons - only show for "Add Others"
                          if (widget.isAddOthers) ...[
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: colorScheme.outline.withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.95),
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.people_outline,
                                            color: colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                        const Gap(12),
                                  Text(
                                    _isUrdu ? 'Ø±Ø´ØªÛ Ú©ÛŒ Ù‚Ø³Ù…' : 'Relationship Type',
                                    style: TextStyle(
                                            fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                    ),
                                        ),
                                      ],
                                  ),
                                    const Gap(16),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                    children: <Widget>[
                                        _buildRelationshipChip(
                                          label: _isUrdu ? 'Ø´Ø±ÛŒÚ© Ø­ÛŒØ§Øª' : 'Spouse',
                                          value: 'Spouse',
                                          icon: Icons.favorite_outline,
                                          colorScheme: colorScheme,
                                        ),
                                        _buildRelationshipChip(
                                          label: _isUrdu ? 'ÙˆØ§Ù„Ø¯ÛŒÙ†' : 'Parent',
                                          value: 'Parent',
                                          icon: Icons.family_restroom_outlined,
                                          colorScheme: colorScheme,
                                        ),
                                        _buildRelationshipChip(
                                          label: _isUrdu ? 'Ø§ÙˆÙ„Ø§Ø¯' : 'Child',
                                          value: 'Child',
                                          icon: Icons.child_care_outlined,
                                          colorScheme: colorScheme,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ),
                            const Gap(7),
                          ],
                    
                    // Form Fields Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.4),
                          width: 1.5,
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
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    // Full name and CNIC row
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                            decoration: InputDecoration(
                              labelText: _translations['fullName'],
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.person_outline,
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
                              filled: true,
                                      fillColor: colorScheme.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                        vertical: 18,
                              ),
                            ),
                            validator: (v) =>
                                _requiredValidator(v, fieldName: _translations['fullName']!),
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: TextFormField(
                            controller: _cnicController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                            readOnly: widget.isAddOthers && widget.relationshipType == 'Child' && widget.parentCnic != null,
                            decoration: InputDecoration(
                              labelText: _getCnicLabel(),
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
                              filled: true,
                                      fillColor: colorScheme.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                        vertical: 18,
                              ),
                            ),
                            inputFormatters: <TextInputFormatter>[
                              _CnicInputFormatter(),
                            ],
                            validator: (value) {
                              // Skip validation for children as CNIC is pre-filled
                              if (widget.isAddOthers && widget.relationshipType == 'Child') {
                                return null;
                              }
                              final String? requiredResult =
                                  _requiredValidator(value, fieldName: _translations['cnic']!);
                              if (requiredResult != null) return requiredResult;
                              final RegExp pattern =
                                  RegExp(r'^\d{5}-\d{7}-\d{1}$');
                              if (!pattern.hasMatch(value!.trim())) {
                                return _translations['enterCnicFormat']!;
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                            const Gap(20),
                    
                    // Date of birth and Gender row
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime now = DateTime.now();
                              final DateTime first = DateTime(now.year - 120);
                              final DateTime last = now;
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _dateOfBirth ?? DateTime(now.year - 30, 1, 1),
                                firstDate: first,
                                lastDate: last,
                              );
                              if (picked != null) {
                                setState(() {
                                  _dateOfBirth = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: _translations['dateOfBirth'],
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.calendar_today_outlined,
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
                                filled: true,
                                        fillColor: colorScheme.surfaceContainerHighest,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                          vertical: 18,
                                ),
                              ),
                              child: Text(
                                _dateOfBirth == null
                                    ? _translations['selectDate']!
                                    : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                        ),
                              ),
                            ),
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _translations['gender']!,
                                style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Gap(8),
                              Wrap(
                                spacing: 12,
                                children: <Widget>[
                                          FilterChip(
                                    label: Text(_translations['male']!),
                                    selected: _gender == 'Male',
                                    onSelected: (selected) {
                                      setState(() =>
                                          _gender = selected ? 'Male' : null);
                                    },
                                            selectedColor: colorScheme.primaryContainer,
                                            checkmarkColor: colorScheme.primary,
                                  ),
                                          FilterChip(
                                    label: Text(_translations['female']!),
                                    selected: _gender == 'Female',
                                    onSelected: (selected) {
                                      setState(() =>
                                          _gender = selected ? 'Female' : null);
                                    },
                                            selectedColor: colorScheme.primaryContainer,
                                            checkmarkColor: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                            const Gap(20),
                    
                    // Email and Phone row
                    Row(
                      children: <Widget>[
                        Expanded(
                                  child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                                decoration: InputDecoration(
                                  labelText: _translations['emailOptional'],
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.email_outlined,
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
                                  filled: true,
                                      fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                        vertical: 18,
                                  ),
                                ),
                                validator: (value) {
                                  // Only validate format if value is provided
                                  if (value != null && value.trim().isNotEmpty) {
                                    final String trimmed = value.trim();
                                    final bool looksValid = RegExp(
                                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(trimmed);
                                    if (!looksValid) {
                                      return _translations['enterValidEmail']!;
                                    }
                                  }
                                  return null;
                                },
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                            decoration: InputDecoration(
                              labelText: _translations['phone'],
                              hintText: '03001234567',
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.phone_outlined,
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
                              filled: true,
                                      fillColor: colorScheme.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                        vertical: 18,
                              ),
                            ),
                            validator: (value) {
                              final String? requiredResult =
                                  _requiredValidator(value, fieldName: _translations['phone']!);
                              if (requiredResult != null) return requiredResult;
                              final String digits =
                                  value!.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digits.length != 11) {
                                return _translations['enterValidPhone']!;
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                            const Gap(20),
                    
                    // Address field
                        TextFormField(
                          controller: _addressController,
                          keyboardType: TextInputType.streetAddress,
                          textInputAction: TextInputAction.next,
                          readOnly: widget.isAddOthers && widget.parentAddress != null && widget.parentAddress!.isNotEmpty,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                          decoration: InputDecoration(
                            labelText: _translations['addressOptional'],
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.location_on_outlined,
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
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                helperText: _translations['optional'],
                                helperStyle: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              // No validator - field is optional
                    ),
                            const Gap(20),
                    
                    // Blood group field
                        DropdownButtonFormField<String>(
                          value: _bloodGroup,
                          decoration: InputDecoration(
                            labelText: _translations['bloodGroupOptional'],
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.bloodtype_outlined,
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
                            filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                                  vertical: 18,
                                ),
                                helperText: _translations['optional'],
                                helperStyle: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          items: [
                            // Add a null option for "Not Selected"
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                _isUrdu ? 'Ù…Ù†ØªØ®Ø¨ Ù†ÛÛŒÚº Ú©ÛŒØ§' : 'Not Selected',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                            const DropdownMenuItem<String>(value: 'A+', child: Text('A+')),
                            const DropdownMenuItem<String>(value: 'A-', child: Text('A-')),
                            const DropdownMenuItem<String>(value: 'B+', child: Text('B+')),
                            const DropdownMenuItem<String>(value: 'B-', child: Text('B-')),
                            const DropdownMenuItem<String>(value: 'AB+', child: Text('AB+')),
                            const DropdownMenuItem<String>(value: 'AB-', child: Text('AB-')),
                            const DropdownMenuItem<String>(value: 'O+', child: Text('O+')),
                            const DropdownMenuItem<String>(value: 'O-', child: Text('O-')),
                          ],
                          onChanged: (value) => setState(() => _bloodGroup = value),
                          // No validator - field is optional
                              ),
                            ],
                          ),
                        ),
                    ),
                    const Gap(7),
                    
                    // Password fields - only show for Self registration (not for "Add Others")
                    if (!widget.isAddOthers && _registrationType == 'Self') ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.95),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                        decoration: InputDecoration(
                          labelText: _translations['password'],
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
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                        ),
                        validator: _validatePassword,
                      ),
                              const Gap(20),
                      
                      // Confirm Password field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                        decoration: InputDecoration(
                          labelText: _translations['confirmPassword'],
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
                                      _obscureConfirmPassword 
                                          ? Icons.visibility_outlined 
                                          : Icons.visibility_off_outlined,
                                      color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
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
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                        ),
                        validator: _validateConfirmPassword,
                      ),
                              const Gap(12),
                      
                      // Password requirements hint
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                                      size: 16,
                                      color: colorScheme.primary,
                            ),
                                    const Gap(8),
                            Expanded(
                              child: Text(
                                _translations['passwordRequirements']!,
                                style: TextStyle(
                                  fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(7),
                    ],
                    
                    // Submit button
                    FilledButton.icon(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          ),
                        minimumSize: const Size(double.infinity, 56),
                        ),
                      icon: _isSubmitting
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
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: _isSubmitting
                          ? const Text('Registering...')
                            : Text(
                                _translations['completeRegistration']!,
                              style: const TextStyle(
                                fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    const Gap(7),
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
}

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



