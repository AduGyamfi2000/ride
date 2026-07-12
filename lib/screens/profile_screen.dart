import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile_model.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/textfield.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _loading = true;
  String? _phone;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone');
    if (phone == null) {
      setState(() => _loading = false);
      return;
    }
    final profile = await UserService.fetchByPhone(phone);
    if (!mounted) return;
    setState(() {
      _phone = phone;
      _profile = profile;
      _firstNameController.text = profile?.firstName ?? '';
      _lastNameController.text = profile?.lastName ?? '';
      _emailController.text = profile?.email ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_phone == null || _profile == null) return;
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name cannot be empty.')),
      );
      return;
    }
    setState(() => _loading = true);
    final updated = UserProfile(
      phone: _profile!.phone,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim().isNotEmpty ? _lastNameController.text.trim() : null,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      role: _profile!.role,
      licenseNumber: _profile!.licenseNumber,
      carMake: _profile!.carMake,
      carModel: _profile!.carModel,
      carPlateNumber: _profile!.carPlateNumber,
      carColor: _profile!.carColor,
      licenseImageUrl: _profile!.licenseImageUrl,
      carImageUrl: _profile!.carImageUrl,
      verificationStatus: _profile!.verificationStatus,
    );
    await UserService.createOrUpdateUser(updated);
    if (!mounted) return;
    setState(() {
      _profile = updated;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userPhone');
    await prefs.remove('selectedRole');
    await FirebaseAuth.instance.signOut();
    // AuthGateScreen listens to auth state live, so it will show
    // LoginScreen on its own once we pop back to it.
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('No profile found for this device.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            CustomTextField(
              controller: _firstNameController,
              label: 'First Name',
              hint: 'e.g. Ama',
              prefixIcon: Icons.person,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _lastNameController,
              label: 'Last Name (optional)',
              hint: 'e.g. Owusu',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _emailController,
              label: 'Email (optional)',
              hint: 'e.g. ama@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 12),
            Text('Phone: ${_profile!.phone}', style: AppTextStyles.bodyMedium),
            Text('Role: ${_profile!.role}', style: AppTextStyles.bodyMedium),
            if (_profile!.isDriver) ...[
              const SizedBox(height: 8),
              Text('Verification: ${_profile!.verificationStatus}', style: AppTextStyles.bodyMedium),
            ],
            const SizedBox(height: 24),
            AppButton(label: 'Save', onPressed: _save),
            const SizedBox(height: 12),
            AppButton(label: 'Sign Out', variant: AppButtonVariant.outlined, onPressed: _signOut),
          ],
        ),
      ),
    );
  }
}
