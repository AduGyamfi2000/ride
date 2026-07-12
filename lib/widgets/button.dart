import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton(
      {super.key,
      required this.label,
      this.onPressed,
      required this.color});
  final String label;
  final void Function()? onPressed;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 180,
        height: 42,
        child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(
              label,
              style: const TextStyle(fontSize: 18),
            )));
  }
}
