import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/synthetic_email.dart';
import '../models/user_profile_model.dart';
import '../providers/settings_provider.dart';
import '../services/user_service.dart';
import '../services/voice_guide_service.dart';
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
  bool _saving = false;
  String? _loadError;
  String? _phone;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>().settings;
      VoiceGuideService().describePage(
        pageKey: 'profile',
        language: settings.language,
        voiceEnabled: settings.voiceEnabled,
      );
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone');
    if (phone == null) {
      setState(() => _loading = false);
      return;
    }
    try {
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
    } catch (e) {
      // Previously unguarded — any Firestore error here (undeployed
      // rules, no connection, etc.) left the screen stuck on a spinner
      // forever with no explanation. Now it fails visibly instead.
      if (!mounted) return;
      setState(() {
        _loadError = "Couldn't load your profile: $e";
        _loading = false;
      });
    }
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
    setState(() => _saving = true);
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
      hasPassword: _profile!.hasPassword,
      ratingSum: _profile!.ratingSum,
      ratingCount: _profile!.ratingCount,
    );
    try {
      await UserService.createOrUpdateUser(updated);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      // Previously unguarded — a failed write here (e.g. undeployed
      // rules) would throw unhandled, and the "Save" button gave no
      // indication anything went wrong.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't save your profile: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateHasPassword(bool value) async {
    if (_profile == null) return;
    final updated = UserProfile(
      phone: _profile!.phone,
      firstName: _profile!.firstName,
      lastName: _profile!.lastName,
      email: _profile!.email,
      role: _profile!.role,
      licenseNumber: _profile!.licenseNumber,
      carMake: _profile!.carMake,
      carModel: _profile!.carModel,
      carPlateNumber: _profile!.carPlateNumber,
      carColor: _profile!.carColor,
      licenseImageUrl: _profile!.licenseImageUrl,
      carImageUrl: _profile!.carImageUrl,
      verificationStatus: _profile!.verificationStatus,
      hasPassword: value,
      ratingSum: _profile!.ratingSum,
      ratingCount: _profile!.ratingCount,
    );
    await UserService.createOrUpdateUser(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
  }

  /// Set a password for the first time — links a new email/password
  /// credential to the current session, same mechanism used during
  /// signup (see lib/auth/synthetic_email.dart).
  Future<void> _showSetPasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set a Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Skip OTP next time you log in.', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (min 6 characters)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final pw = newPasswordController.text;
                if (pw.length < 6) {
                  setDialogState(() => error = 'Password must be at least 6 characters.');
                  return;
                }
                if (pw != confirmController.text) {
                  setDialogState(() => error = 'Passwords do not match.');
                  return;
                }
                try {
                  final credential = EmailAuthProvider.credential(
                    email: syntheticEmailForPhone(_profile!.phone),
                    password: pw,
                  );
                  await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
                  await _updateHasPassword(true);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Password set.')),
                  );
                } catch (e) {
                  setDialogState(() => error = 'Could not set password: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Changes an existing password. Firebase requires a recent sign-in to
  /// change a password, so this re-authenticates with the current
  /// password first rather than assuming the session is fresh enough.
  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (min 6 characters)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final newPw = newController.text;
                if (newPw.length < 6) {
                  setDialogState(() => error = 'Password must be at least 6 characters.');
                  return;
                }
                if (newPw != confirmController.text) {
                  setDialogState(() => error = 'Passwords do not match.');
                  return;
                }
                try {
                  final email = syntheticEmailForPhone(_profile!.phone);
                  final reauthCredential = EmailAuthProvider.credential(
                    email: email,
                    password: currentController.text,
                  );
                  await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(reauthCredential);
                  await FirebaseAuth.instance.currentUser!.updatePassword(newPw);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Password changed.')),
                  );
                } on FirebaseAuthException catch (e) {
                  setDialogState(() => error = e.code == 'invalid-credential' || e.code == 'wrong-password'
                      ? 'Current password is incorrect.'
                      : 'Could not change password: ${e.message}');
                } catch (e) {
                  setDialogState(() => error = 'Could not change password: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemovePassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Password'),
        content: const Text("You'll need to use a code (OTP) to log in from now on. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.currentUser!.unlink(EmailAuthProvider.PROVIDER_ID);
    } catch (e) {
      // If unlink fails for any reason, still flip the flag below — the
      // account will fall back to OTP either way from the user's
      // perspective, since LoginScreen only checks hasPassword.
    }
    await _updateHasPassword(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password removed.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 20),
              AppButton(
                label: 'Try Again',
                isLarge: false,
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _load();
                },
              ),
            ],
          ),
        ),
      );
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
            AppButton(label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Password', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              _profile!.hasPassword
                  ? 'A password is set — you can log in with it instead of a code.'
                  : "No password set — you'll always use a code (OTP) to log in.",
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_profile!.hasPassword) ...[
              AppButton(
                label: 'Change Password',
                variant: AppButtonVariant.outlined,
                isLarge: false,
                onPressed: _showChangePasswordDialog,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Remove Password',
                variant: AppButtonVariant.danger,
                isLarge: false,
                onPressed: _confirmRemovePassword,
              ),
            ] else
              AppButton(
                label: 'Set a Password',
                variant: AppButtonVariant.outlined,
                isLarge: false,
                onPressed: _showSetPasswordDialog,
              ),
          ],
        ),
      ),
    );
  }
}
