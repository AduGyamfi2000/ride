import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/car_data.dart';
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
  final TextEditingController _carMakeOtherController = TextEditingController();
  final TextEditingController _carModelOtherController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _carColorController = TextEditingController();

  // Car make/model are dropdowns fed by CarData, with 'Other' falling
  // through to the free-text controllers above for whatever isn't listed.
  String? _selectedMake;
  String? _selectedModel;

  String _selectedRole = 'Passenger';
  XFile? _licenseImage;
  XFile? _carImage;
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
    _carMakeOtherController.dispose();
    _carModelOtherController.dispose();
    _plateController.dispose();
    _carColorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLicense) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      if (isLicense) {
        _licenseImage = picked;
      } else {
        _carImage = picked;
      }
    });
  }

  bool get _isDriver => _selectedRole == 'Driver';

  // Resolves the dropdown selection down to the actual value to save —
  // the free-text field when 'Other' was picked, otherwise the picked
  // make/model itself.
  String get _resolvedMake =>
      _selectedMake == CarData.otherOption ? _carMakeOtherController.text.trim() : (_selectedMake ?? '');
  String get _resolvedModel =>
      _selectedModel == CarData.otherOption ? _carModelOtherController.text.trim() : (_selectedModel ?? '');

  void _onMakeChanged(String? make) {
    setState(() {
      _selectedMake = make;
      // A model chosen for the previous make may not apply to the new
      // one, so it resets rather than silently keeping a mismatched pick.
      _selectedModel = null;
      _carModelOtherController.clear();
    });
  }

  // The color for whichever role is currently active — used on the tab
  // indicator and the AppBar, so the whole page visibly reflects "you are
  // signing up as X" using the same color introduced on RoleSelectionScreen.
  Color get _activeColor => _isDriver ? AppColors.driverColor : AppColors.passengerColor;

  void _switchRole(String role) {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
    });
    final settings = context.read<SettingsProvider>().settings;
    VoiceGuideService().describePage(
      pageKey: role == 'Driver' ? 'signup_driver_selected' : 'signup_passenger_selected',
      language: settings.language,
      voiceEnabled: settings.voiceEnabled,
    );
  }

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
          _resolvedMake.isEmpty ||
          _resolvedModel.isEmpty ||
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
      carMake: _isDriver ? _resolvedMake : null,
      carModel: _isDriver ? _resolvedModel : null,
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
    final otherRole = _isDriver ? 'Passenger' : 'Driver';
    final otherRoleColor = _isDriver ? AppColors.passengerColor : AppColors.driverColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: _activeColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create your account', style: AppTextStyles.displayLarge),
            const SizedBox(height: 16),
            // Shows which role this form is currently for — the actual
            // way to switch roles is the colored tap-to-switch banner
            // further down, not a tab bar.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _activeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_isDriver ? Icons.drive_eta : Icons.emoji_people, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _isDriver ? 'Signing up as a Driver' : 'Signing up as a Passenger',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
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
              _CarDropdown(
                label: 'Car Make *',
                icon: Icons.directions_car,
                value: _selectedMake,
                options: CarData.makes,
                onChanged: _onMakeChanged,
              ),
              if (_selectedMake == CarData.otherOption) ...[
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _carMakeOtherController,
                  label: 'Car Make (type your own) *',
                  hint: 'e.g. Tata',
                  prefixIcon: Icons.edit_outlined,
                ),
              ],
              const SizedBox(height: 16),
              _CarDropdown(
                label: 'Car Model *',
                icon: Icons.directions_car_outlined,
                // Disabled until a make is picked — a model list without
                // a make selected doesn't mean anything.
                value: _selectedModel,
                options: _selectedMake == null ? [] : CarData.modelsFor(_selectedMake),
                onChanged: _selectedMake == null ? null : (value) => setState(() => _selectedModel = value),
                enabled: _selectedMake != null,
              ),
              if (_selectedModel == CarData.otherOption) ...[
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _carModelOtherController,
                  label: 'Car Model (type your own) *',
                  hint: 'e.g. Indica',
                  prefixIcon: Icons.edit_outlined,
                ),
              ],
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
            AppButton(
              label: 'Send OTP',
              icon: Icons.arrow_forward,
              onPressed: _submit,
              variant: _isDriver ? AppButtonVariant.secondary : AppButtonVariant.primary,
            ),
            const SizedBox(height: 16),
            // Colored prompt to switch to the other role's signup — same
            // color that role uses everywhere else, reinforcing "wrong
            // tab? here's the right color to look for."
            GestureDetector(
              onTap: () => _switchRole(otherRole),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: otherRoleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: otherRoleColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      otherRole == 'Driver' ? Icons.drive_eta : Icons.emoji_people,
                      color: otherRoleColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Meant to sign up as a $otherRole instead? Tap here.',
                        style: TextStyle(color: otherRoleColor, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

class _CarDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const _CarDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: options.contains(value) ? value : null,
          items: options
              .map((option) => DropdownMenuItem(value: option, child: Text(option, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: enabled ? AppColors.primary : AppColors.textHint, size: 22),
            hintText: enabled ? 'Select' : 'Choose a make first',
          ),
        ),
      ],
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  final String label;
  final XFile? file;
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
