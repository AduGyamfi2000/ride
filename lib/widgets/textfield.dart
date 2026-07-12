import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Labeled text field used across auth/booking forms. Kept the original
/// file name (textfield.dart) so existing imports don't need to change.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.hint,
    required this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
  });

  final String hint;
  final String label;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final IconData? prefixIcon;

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
        TextField(
          obscureText: isPassword,
          controller: controller,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.primary, size: 22) : null,
          ),
        ),
      ],
    );
  }
}
