import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'registration_phone_screen.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/user_storage.dart';

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
  
  // State variables
  DateTime? _dateOfBirth;
  String? _gender; // 'Male' or 'Female'
  String? _bloodGroup; // dropdown
  String? _registrationType; // 'Self' or 'Others' - defaults to 'Self' for first registration
  String? _parentType; // 'Father' or 'Mother'
  bool _isSubmitting = false;
  bool _showDetailsCard = false; // Show details card after successful registration
  Map<String, dynamic>? _registeredPatientData; // Store registered patient data (for self registration)
  Map<String, dynamic>? _newlyAddedPatientData; // Store newly added patient data (for "Add Others")
  
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
    'phone': 'Phone',
    'address': 'Address',
    'bloodGroup': 'Blood group',
    'selectBloodGroup': 'Select blood group',
    'selectRelation': 'Select relation',
    'completeRegistration': 'Complete Registration',
    'required': 'is required',
    'selectRegistrationType': 'Please select registration type (Self or Others)',
    'selectDateOfBirth': 'Please select date of birth',
    'selectGender': 'Please select gender',
    'enterValidEmail': 'Enter a valid email address',
    'enterValidPhone': 'Enter a valid phone number',
    'enterCnicFormat': 'Enter CNIC as 12345-1234567-1',
    'registrationSuccessful': 'Registration successful!',
    'languageToggle': 'English',
  };
  
  static const Map<String, String> _urduTranslations = {
    'appBarTitle': 'مریض کی رجسٹریشن',
    'registerAs': 'رجسٹر کریں بطور:',
    'self': 'خود',
    'others': 'دوسرے',
    'parentType': 'والدین کی قسم',
    'selectParentType': 'والدین کی قسم منتخب کریں',
    'father': 'والد',
    'mother': 'والدہ',
    'fullName': 'مکمل نام',
    'cnic': 'قومی شناختی کارڈ',
    'fathersCnic': 'والد کا قومی شناختی کارڈ',
    'mothersCnic': 'والدہ کا قومی شناختی کارڈ',
    'parentsCnic': 'والدین کا قومی شناختی کارڈ',
    'dateOfBirth': 'تاریخ پیدائش',
    'selectDate': 'تاریخ منتخب کریں',
    'gender': 'جنس',
    'male': 'مرد',
    'female': 'عورت',
    'email': 'ای میل',
    'phone': 'فون',
    'address': 'پتہ',
    'bloodGroup': 'خون کا گروپ',
    'selectBloodGroup': 'خون کا گروپ منتخب کریں',
    'selectRelation': 'رشتہ منتخب کریں',
    'completeRegistration': 'رجسٹریشن مکمل کریں',
    'required': 'درکار ہے',
    'selectRegistrationType': 'براہ کرم رجسٹریشن کی قسم منتخب کریں (خود یا دوسرے)',
    'selectDateOfBirth': 'براہ کرم تاریخ پیدائش منتخب کریں',
    'selectGender': 'براہ کرم جنس منتخب کریں',
    'enterValidEmail': 'درست ای میل ایڈریس درج کریں',
    'enterValidPhone': 'درست فون نمبر درج کریں',
    'enterCnicFormat': 'قومی شناختی کارڈ 12345-1234567-1 کی شکل میں درج کریں',
    'registrationSuccessful': 'رجسٹریشن کامیاب!',
    'languageToggle': 'اردو',
  };
  
  // Dropdown options translations
  List<String> get _parentTypeOptions => _isUrdu 
      ? ['والد', 'والدہ']
      : ['Father', 'Mother'];
  
  List<String> get _genderOptions => _isUrdu
      ? ['مرد', 'عورت']
      : ['Male', 'Female'];
  

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName ${_translations['required']}';
    }
    return null;
  }

  String _getCnicLabel() {
    if (widget.isAddOthers) {
      if (widget.relationshipType == 'Spouse') {
        return _isUrdu ? 'شریک حیات کا قومی شناختی کارڈ' : 'Spouse\'s CNIC';
      } else if (widget.relationshipType == 'Parent') {
        return _isUrdu ? 'والدین کا قومی شناختی کارڈ' : 'Parent\'s CNIC';
      } else if (widget.relationshipType == 'Child') {
        return _isUrdu ? 'والدین کا قومی شناختی کارڈ' : 'Parent\'s CNIC';
      }
    }
    if (_registrationType == 'Others') {
      if (_parentType == 'Father' || _parentType == 'والد') {
        return _translations['fathersCnic']!;
      } else if (_parentType == 'Mother' || _parentType == 'والدہ') {
        return _translations['mothersCnic']!;
      } else {
        return _translations['parentsCnic']!;
      }
    }
    return _translations['cnic']!;
  }
  
  String _getGenderValue(String displayText) {
    if (_isUrdu) {
      if (displayText == 'مرد') return 'Male';
      if (displayText == 'عورت') return 'Female';
    }
    return displayText;
  }
  
  String _getGenderDisplay(String? value) {
    if (value == null) return '';
    if (_isUrdu) {
      return value == 'Male' ? 'مرد' : 'عورت';
    }
    return value;
  }
  
  String _getParentTypeValue(String displayText) {
    if (_isUrdu) {
      if (displayText == 'والد') return 'Father';
      if (displayText == 'والدہ') return 'Mother';
    }
    return displayText;
  }
  
  String _getParentTypeDisplay(String? value) {
    if (value == null) return '';
    if (_isUrdu) {
      return value == 'Father' ? 'والد' : 'والدہ';
    }
    return value;
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

  void _handleSubmit() {
    if (_registrationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translations['selectRegistrationType']!),
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
    
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      // Simulate submission
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          if (widget.isAddOthers) {
            // For "Add Others" registration, store new patient data and show details card
            _newlyAddedPatientData = {
              'fullName': _fullNameController.text.trim(),
              'cnic': _cnicController.text.trim(),
              'phone': _phoneController.text.trim(),
              'email': _emailController.text.trim(),
              'dateOfBirth': _dateOfBirth,
              'gender': _gender,
              'address': _addressController.text.trim(),
              'bloodGroup': _bloodGroup,
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
            _registeredPatientData = {
              'fullName': _fullNameController.text.trim(),
              'cnic': _cnicController.text.trim(),
              'phone': _phoneController.text.trim(),
              'email': _emailController.text.trim(),
              'dateOfBirth': _dateOfBirth,
              'gender': _gender,
              'address': _addressController.text.trim(),
              'bloodGroup': _bloodGroup,
            };
            
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
      });
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
                _isUrdu ? 'زبان' : 'Language',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
              Switch(
                value: _isUrdu,
                onChanged: (value) {
                  setState(() {
                    _isUrdu = value;
                  });
                },
                activeColor: Colors.blue.shade700,
              ),
              Text(
                _isUrdu ? 'English' : 'اردو',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
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
          title: _isUrdu ? 'آپ کی تفصیلات' : 'Your Details',
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
              _isUrdu ? 'دوسرے شامل کریں' : 'Add Others',
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
              _isUrdu ? 'سائن ان پر واپس جائیں' : 'Back to Sign In',
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
          return 'شریک حیات کی تفصیلات';
        case 'Parent':
          return 'والدین کی تفصیلات';
        case 'Child':
          return 'اولاد کی تفصیلات';
        default:
          return 'مریض کی تفصیلات';
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
          return 'شریک حیات';
        case 'Parent':
          return 'والدین';
        case 'Child':
          return 'اولاد';
        default:
          return 'مریض';
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
                      _isUrdu ? 'خود' : 'Self',
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
            _buildDetailRow(_isUrdu ? 'مکمل نام' : 'Full Name', patientData['fullName'] ?? ''),
            _buildDetailRow(_isUrdu ? 'قومی شناختی کارڈ' : 'CNIC', patientData['cnic'] ?? ''),
            _buildDetailRow(_isUrdu ? 'فون' : 'Phone', patientData['phone'] ?? ''),
            _buildDetailRow(_isUrdu ? 'ای میل' : 'Email', patientData['email'] ?? ''),
            if (patientData['dateOfBirth'] != null)
              _buildDetailRow(
                _isUrdu ? 'تاریخ پیدائش' : 'Date of Birth',
                '${(patientData['dateOfBirth'] as DateTime).year}-${(patientData['dateOfBirth'] as DateTime).month.toString().padLeft(2, '0')}-${(patientData['dateOfBirth'] as DateTime).day.toString().padLeft(2, '0')}',
              ),
            if (patientData['gender'] != null)
              _buildDetailRow(
                _isUrdu ? 'جنس' : 'Gender',
                patientData['gender'] == 'Male' ? (_isUrdu ? 'مرد' : 'Male') : (_isUrdu ? 'عورت' : 'Female'),
              ),
            if (patientData['bloodGroup'] != null)
              _buildDetailRow(_isUrdu ? 'خون کا گروپ' : 'Blood Group', patientData['bloodGroup'] ?? ''),
            if (patientData['address'] != null && patientData['address'].toString().isNotEmpty)
              _buildDetailRow(_isUrdu ? 'پتہ' : 'Address', patientData['address'] ?? ''),
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
        title: Text(_isUrdu ? 'رشتہ کی قسم منتخب کریں' : 'Select Relationship Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(_isUrdu ? 'شریک حیات' : 'Spouse'),
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
              title: Text(_isUrdu ? 'والدین' : 'Parent'),
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
              title: Text(_isUrdu ? 'اولاد' : 'Child'),
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.isAddOthers 
            ? (_isUrdu ? 'دوسرے کی رجسٹریشن' : 'Add Others Registration')
            : _translations['appBarTitle']!),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: KeyboardInsetPadding(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _showDetailsCard
                  ? _buildDetailsCard()
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
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
                                  _isUrdu ? 'زبان' : 'Language',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                Switch(
                                  value: _isUrdu,
                                  onChanged: (value) {
                                    setState(() {
                                      _isUrdu = value;
                                    });
                                  },
                                  activeColor: Colors.blue.shade700,
                                ),
                                Text(
                                  _isUrdu ? 'English' : 'اردو',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(24),
                          // Registration type radio buttons - only show for "Add Others"
                          if (widget.isAddOthers) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    _isUrdu ? 'رشتہ کی قسم' : 'Relationship Type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Gap(12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: RadioListTile<String>(
                                          title: Text(_isUrdu ? 'شریک حیات' : 'Spouse'),
                                          value: 'Spouse',
                                          groupValue: widget.relationshipType,
                                          onChanged: null, // Disabled - set from parent
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<String>(
                                          title: Text(_isUrdu ? 'والدین' : 'Parent'),
                                          value: 'Parent',
                                          groupValue: widget.relationshipType,
                                          onChanged: null, // Disabled - set from parent
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<String>(
                                          title: Text(_isUrdu ? 'اولاد' : 'Child'),
                                          value: 'Child',
                                          groupValue: widget.relationshipType,
                                          onChanged: null, // Disabled - set from parent
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Gap(24),
                          ],
                    
                    // Full name and CNIC row
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: _translations['fullName'],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
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
                            style: const TextStyle(fontSize: 16),
                            readOnly: widget.isAddOthers && widget.relationshipType == 'Child' && widget.parentCnic != null,
                            decoration: InputDecoration(
                              labelText: _getCnicLabel(),
                              hintText: '12345-1234567-1',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
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
                    const Gap(16),
                    
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                _dateOfBirth == null
                                    ? _translations['selectDate']!
                                    : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 16),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const Gap(8),
                              Wrap(
                                spacing: 12,
                                children: <Widget>[
                                  ChoiceChip(
                                    label: Text(_translations['male']!),
                                    selected: _gender == 'Male',
                                    onSelected: (selected) {
                                      setState(() =>
                                          _gender = selected ? 'Male' : null);
                                    },
                                  ),
                                  ChoiceChip(
                                    label: Text(_translations['female']!),
                                    selected: _gender == 'Female',
                                    onSelected: (selected) {
                                      setState(() =>
                                          _gender = selected ? 'Female' : null);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    
                    // Email and Phone row
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: _translations['email'],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              final String? requiredResult =
                                  _requiredValidator(value, fieldName: _translations['email']!);
                              if (requiredResult != null) return requiredResult;
                              final String trimmed = value!.trim();
                              final bool looksValid = RegExp(
                                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(trimmed);
                              if (!looksValid) {
                                return _translations['enterValidEmail']!;
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
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: _translations['phone'],
                              hintText: '03001234567',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
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
                    const Gap(16),
                    
                    // Address field
                    TextFormField(
                      controller: _addressController,
                      keyboardType: TextInputType.streetAddress,
                      textInputAction: TextInputAction.next,
                      readOnly: widget.isAddOthers && widget.parentAddress != null && widget.parentAddress!.isNotEmpty,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: _translations['address'],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (v) =>
                          _requiredValidator(v, fieldName: _translations['address']!),
                    ),
                    const Gap(16),
                    
                    // Blood group field
                    DropdownButtonFormField<String>(
                      value: _bloodGroup,
                      decoration: InputDecoration(
                        labelText: _translations['bloodGroup'],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: const [
                        'A+',
                        'A-',
                        'B+',
                        'B-',
                        'AB+',
                        'AB-',
                        'O+',
                        'O-'
                      ]
                          .map((g) => DropdownMenuItem<String>(
                                value: g,
                                child: Text(g),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _bloodGroup = value),
                      validator: (v) =>
                          v == null || v.isEmpty ? _translations['selectBloodGroup'] : null,
                    ),
                    const Gap(32),
                    
                    // Submit button
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _translations['completeRegistration']!,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
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

