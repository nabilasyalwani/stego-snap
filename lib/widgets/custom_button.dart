import 'package:flutter/material.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback onTap;
  final double height;
  final double width;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double borderRadius;
  final String label;
  final IconData? icon;
  final double? fontSize;
  final Color? fontColor;

  const CustomButton({
    super.key,
    required this.onTap,
    required this.height,
    required this.width,
    required this.label,
    this.backgroundColor,
    this.gradient,
    this.borderRadius = 50.0,
    this.icon,
    this.fontSize = 16,
    this.fontColor = AppColors.darkPurpleText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: gradient == null ? backgroundColor : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fontColor),
                const SizedBox(width: 16),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}