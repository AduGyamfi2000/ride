import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../screens/admin_screen.dart';
import '../screens/driver_home_screen.dart';
import '../screens/home_screen.dart';
import '../screens/otp_screen.dart';
import '../services/user_service.dart';
import '../services/voice_guide_service.dart';
import '../models/user_profile_model.dart';
import 'signup_screen.dart';
import 'synthetic_email.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/textfield.dart';

class LoginScreen extends StatefulWidget {
  final String userRole;

  const LoginScreen({super.key, this.userRole = ''});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Define the admin phone number
  final String adminPhoneNumber =
      "+233123456789"; // Change this to your actual admin number

  // 'phone' = entering phone number; 'password' = this account has a
  // password set, so we ask for it instead of sending an OTP.
  String _mode = 'phone';
  bool _isChecking = false;
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>().settings;
      VoiceGuideService().describePage(
        pageKey: 'login',
        language: settings.language,
        voiceEnabled: settings.voiceEnabled,
      );
    });
  }

  bool get _isAdminNumber => _phoneController.text.trim() == adminPhoneNumber;

  /// Checks whether this phone number already has a password set. If so,
  /// switches to password entry instead of sending an OTP. Otherwise (or
  /// if the account doesn't exist yet — a new number) falls back to the
  /// existing OTP flow, same as before this feature existed.
  Future<void> _continue() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number.');
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    UserProfile? profile;
    try {
      // Reading a profile requires a signed-in session (see
      // firestore.rules) — anonymous sign-in is free/instant and reuses
      // any existing session, so this is safe to call every time.
      await FirebaseAuth.instance.signInAnonymously();
      profile = await UserService.fetchByPhone(phoneNumber);
    } catch (e) {
      // If this lookup fails for any reason, fail open to the OTP flow
      // rather than blocking login entirely — OTP doesn't depend on this
      // check succeeding.
      profile = null;
    }

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (profile?.hasPassword == true) {
      setState(() => _mode = 'password');
      return;
    }

    _goToOtp(phoneNumber);
  }

  void _goToOtp(String phoneNumber) {
    // The admin number goes through the same OTP flow as everyone else —
    // it just gets tagged with the 'Admin' role. Previously this skipped
    // Firebase Auth entirely, which meant request.auth was null and the
    // admin dashboard's own Firestore security rules would reject every
    // read.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneOTPVerification(
          phoneNumber: phoneNumber,
          userRole: _isAdminNumber ? 'Admin' : (widget.userRole.isNotEmpty ? widget.userRole : ''),
        ),
      ),
    );
  }

  Future<void> _loginWithPassword() async {
    final phoneNumber = _phoneController.text.trim();
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    try {
      // This replaces the current anonymous session with the real
      // password-linked one — exactly what we want for login.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: syntheticEmailForPhone(phoneNumber),
        password: password,
      );

      final profile = await UserService.fetchByPhone(phoneNumber);
      if (profile == null) {
        throw Exception('Signed in, but no profile was found for this number.');
      }

      final resolvedProfile = _isAdminNumber
          ? UserProfile.fromJson({...profile.toJson(), 'role': 'Admin'})
          : profile;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedRole', resolvedProfile.role);
      await prefs.setString('userPhone', phoneNumber);

      if (!mounted) return;
      switch (resolvedProfile.role) {
        case 'Admin':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
          break;
        case 'Driver':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DriverHomeScreen()));
          break;
        default:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = (e.code == 'wrong-password' || e.code == 'invalid-credential')
            ? 'Incorrect password.'
            : 'Could not log in: ${e.message}';
        _isLoggingIn = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not log in: $e';
        _isLoggingIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordMode = _mode == 'password';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        leading: isPasswordMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _mode = 'phone';
                  _errorMessage = null;
                }),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome back', style: AppTextStyles.displayLarge),
            const SizedBox(height: 8),
            Text(
              isPasswordMode ? 'Enter your password to continue' : 'Enter your phone number to continue',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'e.g. +233241234567',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone,
            ),
            if (isPasswordMode) ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                isPassword: true,
                prefixIcon: Icons.lock_outline,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 24),
            if (isPasswordMode) ...[
              AppButton(
                label: 'Login',
                icon: Icons.arrow_forward,
                isLoading: _isLoggingIn,
                onPressed: _isLoggingIn ? null : _loginWithPassword,
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _isLoggingIn ? null : () => _goToOtp(_phoneController.text.trim()),
                  child: const Text('Forgot password? Use a code instead'),
                ),
              ),
            ] else ...[
              AppButton(
                label: 'Continue',
                icon: Icons.arrow_forward,
                isLoading: _isChecking,
                onPressed: _isChecking ? null : _continue,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignupScreen(initialRole: widget.userRole.isNotEmpty ? widget.userRole : null),
                      ),
                    );
                  },
                  child: const Text("Don't have an account? Sign up"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
