import 'package:flutter/material.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final Function(String) onChanged;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final double? fontSize;
  final Color backgroundColor;
  final Color foregroundColor;

  const CustomTextField({
    super.key,
    this.controller,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.obscureText = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.fontSize = 16,
    this.backgroundColor = AppColors.whiteField,
    this.foregroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: fontSize, color: foregroundColor),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 16.0, right: 8.0),
          child: Icon(icon, color: foregroundColor),
        ),
        errorStyle: TextStyle(color: Colors.white),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: fontSize,
          color: foregroundColor.withAlpha(179),
        ),
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
      ),
    );
  }
}
