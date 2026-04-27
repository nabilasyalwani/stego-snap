import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double height;
  final double width;
  final Color? backgroundColor;
  final BoxShape shape;
  final Gradient? gradient;
  final double borderRadius;
  final String? label;
  final IconData icon;
  final double? fontSize;
  final Color? fontColor;
  final double? iconSize;
  final List<BoxShadow>? boxShadow;

  const CustomIconButton({
    super.key,
    required this.onTap,
    required this.height,
    required this.width,
    required this.icon,
    this.shape = BoxShape.rectangle,
    this.backgroundColor,
    this.label,
    this.gradient,
    this.borderRadius = 50.0,
    this.fontSize = 14,
    this.iconSize = 24,
    this.fontColor = Colors.white,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              shape: shape,
              color: gradient == null ? backgroundColor : null,
              gradient: gradient,
              borderRadius: shape == BoxShape.rectangle
                  ? BorderRadius.circular(borderRadius)
                  : null,
              boxShadow: boxShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: fontColor,
                size: iconSize,
              )
            ),
          ),
          if (label != null) ...[
            SizedBox(height: 8),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: "Poppins",
                color: fontColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}