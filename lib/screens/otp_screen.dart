import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ride/auth/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/otp_generator.dart';
import '../models/pending_signup.dart';
import '../models/user_profile_model.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'driver_home_screen.dart';
import 'home_screen.dart';
import 'admin_screen.dart';

class PhoneOTPVerification extends StatefulWidget {
  final String phoneNumber;
  final String userRole; // '' when this is a plain login (role resolved after verify)
  final PendingSignup? pendingSignup; // non-null when this is a signup

  const PhoneOTPVerification({
    super.key,
    required this.phoneNumber,
    required this.userRole,
    this.pendingSignup,
  });

  @override
  State<PhoneOTPVerification> createState() => _PhoneOTPVerificationState();
}

class _PhoneOTPVerificationState extends State<PhoneOTPVerification> {
  final TextEditingController _otpController = TextEditingController();
  final OtpService _otpService = OtpService();

  bool _isSending = false;
  bool _isVerifying = false;
  String? _lastSentCode; // dev/demo convenience only — see otp_generator.dart
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      final code = await _otpService.generateAndStore(widget.phoneNumber);
      if (!mounted) return;
      setState(() {
        _lastSentCode = code;
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not generate a code: $e';
        _isSending = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final failure = await _otpService.verify(widget.phoneNumber, _otpController.text);
    if (failure != null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = failure;
        _isVerifying = false;
      });
      return;
    }

    try {
      // The OTP checked out — establish a Firebase Auth session so
      // Firestore's security rules (which require request.auth != null)
      // let us read/write. See otp_generator.dart for why this is
      // anonymous auth rather than real phone auth.
      await FirebaseAuth.instance.signInAnonymously();

      UserProfile profile;
      final pending = widget.pendingSignup;

      if (pending != null) {
        // Signup: upload driver documents (if any) and create the profile.
        String? licenseUrl;
        String? carUrl;
        if (pending.role == 'Driver') {
          if (pending.licenseImageFile != null) {
            licenseUrl = await UserService.uploadDriverDocument(
              phone: widget.phoneNumber,
              file: pending.licenseImageFile!,
              label: 'license',
            );
          }
          if (pending.carImageFile != null) {
            carUrl = await UserService.uploadDriverDocument(
              phone: widget.phoneNumber,
              file: pending.carImageFile!,
              label: 'car',
            );
          }
        }

        profile = UserProfile(
          phone: widget.phoneNumber,
          firstName: pending.firstName,
          lastName: pending.lastName,
          email: pending.email,
          role: pending.role,
          licenseNumber: pending.licenseNumber,
          carMake: pending.carMake,
          carModel: pending.carModel,
          carPlateNumber: pending.carPlateNumber,
          carColor: pending.carColor,
          licenseImageUrl: licenseUrl,
          carImageUrl: carUrl,
          verificationStatus: pending.role == 'Driver' ? 'Pending' : 'Verified',
        );
        await UserService.createOrUpdateUser(profile);
      } else {
        // Login: the profile should already exist for this phone number.
        final existing = await UserService.fetchByPhone(widget.phoneNumber);
        if (existing == null) {
          if (!mounted) return;
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("We couldn't find an account for that number — please sign up first.")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignupScreen()),
          );
          return;
        }
        // Admin phone number is tagged at login time (LoginScreen), so
        // trust that role here rather than whatever was last saved.
        profile = widget.userRole == 'Admin'
            ? UserProfile.fromJson({...existing.toJson(), 'role': 'Admin'})
            : existing;
      }

      if (!mounted) return;

      // Keep AuthGateScreen's locally-cached role in sync so relaunching
      // the app routes straight to the right home screen, and remember
      // the phone number so screens like ProfileScreen can look up "my"
      // profile (anonymous sessions carry no phone claim of their own).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedRole', profile.role);
      await prefs.setString('userPhone', widget.phoneNumber);

      switch (profile.role) {
        case 'Admin':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
          break;
        case 'Driver':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DriverHomeScreen()));
          break;
        default:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong finishing sign-in: $e';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your number')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Enter the code', style: AppTextStyles.displayLarge),
            const SizedBox(height: 8),
            Text(
              'We generated a code for ${widget.phoneNumber}.',
              style: AppTextStyles.bodyMedium,
            ),
            if (_lastSentCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Demo mode — no SMS gateway is configured yet, so here is your code: $_lastSentCode',
                  style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: OtpService.codeLength,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(counterText: ''),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: 'Verify',
              isLoading: _isVerifying,
              onPressed: _isVerifying ? null : _submit,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Resend Code',
              variant: AppButtonVariant.ghost,
              isLoading: _isSending,
              isLarge: false,
              onPressed: _isSending ? null : _sendOtp,
            ),
          ],
        ),
      ),
    );
  }
}
