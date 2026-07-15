import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/pending_signup.dart';
import '../providers/settings_provider.dart';
import '../screens/otp_screen.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/textfield.dart';

class SignupScreen extends StatefulWidget {
  final String? initialRole;

  const SignupScreen({super.key, this.initialRole});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Driver-only controllers.
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _carMakeController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _carColorController = TextEditingController();

  String _selectedRole = 'Passenger';
  File? _licenseImage;
  File? _carImage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole == 'Driver' ? 'Driver' : 'Passenger';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>().settings;
      VoiceGuideService().describePage(
        pageKey: 'signup',
        language: settings.language,
        voiceEnabled: settings.voiceEnabled,
      );
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _licenseController.dispose();
    _carMakeController.dispose();
    _carModelController.dispose();
    _plateController.dispose();
    _carColorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLicense) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      if (isLicense) {
        _licenseImage = File(picked.path);
      } else {
        _carImage = File(picked.path);
      }
    });
  }

  bool get _isDriver => _selectedRole == 'Driver';

  void _submit() {
    final phone = _phoneController.text.trim();
    final firstName = _firstNameController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Phone number is required.');
      return;
    }
    if (firstName.isEmpty) {
      setState(() => _errorMessage = 'First name is required.');
      return;
    }

    if (_isDriver) {
      if (_licenseController.text.trim().isEmpty ||
          _carMakeController.text.trim().isEmpty ||
          _carModelController.text.trim().isEmpty ||
          _plateController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please fill in all driver and car details.');
        return;
      }
      if (_licenseImage == null || _carImage == null) {
        setState(() => _errorMessage = "Please add a photo of your driver's license and your car.");
        return;
      }
    }

    // Password is entirely optional — only validated if they've started
    // typing one.
    final password = _passwordController.text;
    if (password.isNotEmpty) {
      if (password.length < 6) {
        setState(() => _errorMessage = 'Password must be at least 6 characters.');
        return;
      }
      if (password != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Passwords do not match.');
        return;
      }
    }

    setState(() => _errorMessage = null);

    final pending = PendingSignup(
      role: _selectedRole,
      firstName: firstName,
      lastName: _lastNameController.text.trim().isNotEmpty ? _lastNameController.text.trim() : null,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      password: password.isNotEmpty ? password : null,
      licenseNumber: _isDriver ? _licenseController.text.trim() : null,
      carMake: _isDriver ? _carMakeController.text.trim() : null,
      carModel: _isDriver ? _carModelController.text.trim() : null,
      carPlateNumber: _isDriver ? _plateController.text.trim() : null,
      carColor: _isDriver && _carColorController.text.trim().isNotEmpty ? _carColorController.text.trim() : null,
      licenseImageFile: _licenseImage,
      carImageFile: _carImage,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneOTPVerification(
          phoneNumber: phone,
          userRole: _selectedRole,
          pendingSignup: pending,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create your account', style: AppTextStyles.displayLarge),
            const SizedBox(height: 16),
            // Role toggle
            Row(
              children: [
                Expanded(
                  child: _RoleChip(
                    label: 'Passenger',
                    selected: !_isDriver,
                    onTap: () => setState(() => _selectedRole = 'Passenger'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleChip(
                    label: 'Driver',
                    selected: _isDriver,
                    onTap: () => setState(() => _selectedRole = 'Driver'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone Number *',
              hint: 'e.g. +233241234567',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _firstNameController,
              label: 'First Name *',
              hint: 'e.g. Ama',
              prefixIcon: Icons.person,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _lastNameController,
              label: 'Last Name (optional)',
              hint: 'e.g. Owusu',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _emailController,
              label: 'Email (optional)',
              hint: 'e.g. ama@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 24),
            const Text('Password (optional)', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              "Set a password if you'd like to skip the OTP step next time you log in. Leave blank to keep using a code every time.",
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Password (optional)',
              hint: 'At least 6 characters',
              isPassword: true,
              prefixIcon: Icons.lock_outline,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              isPassword: true,
              prefixIcon: Icons.lock_outline,
            ),
            if (_isDriver) ...[
              const SizedBox(height: 24),
              const Text('Driver & vehicle details', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 4),
              const Text(
                'Required so we can verify you before you can accept rides.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _licenseController,
                label: "Driver's License Number *",
                hint: 'e.g. GHA-1234-20',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _carMakeController,
                label: 'Car Make *',
                hint: 'e.g. Toyota',
                prefixIcon: Icons.directions_car,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _carModelController,
                label: 'Car Model *',
                hint: 'e.g. Corolla',
                prefixIcon: Icons.directions_car_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _plateController,
                label: 'Car Plate Number *',
                hint: 'e.g. GR 1234-24',
                prefixIcon: Icons.confirmation_number_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _carColorController,
                label: 'Car Color (optional)',
                hint: 'e.g. Silver',
                prefixIcon: Icons.palette_outlined,
              ),
              const SizedBox(height: 20),
              _DocumentPicker(
                label: "Driver's License Photo *",
                file: _licenseImage,
                onTap: () => _pickImage(true),
              ),
              const SizedBox(height: 12),
              _DocumentPicker(
                label: 'Car Photo *',
                file: _carImage,
                onTap: () => _pickImage(false),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 24),
            AppButton(label: 'Send OTP', icon: Icons.arrow_forward, onPressed: _submit),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;

  const _DocumentPicker({required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? AppColors.success : AppColors.surfaceVariant,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              file != null ? Icons.check_circle : Icons.add_a_photo_outlined,
              color: file != null ? AppColors.success : AppColors.textHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file != null ? '$label — selected' : label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
