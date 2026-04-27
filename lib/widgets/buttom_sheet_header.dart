import 'package:flutter/material.dart';

class BottomSheetHeader extends StatelessWidget {
  final IconData? prefixIcon;
  final double? iconSize;
  final String title;
  final VoidCallback onClose;

  const BottomSheetHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.prefixIcon,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (prefixIcon != null) ...[
          Icon(
            prefixIcon,
            size: iconSize,
            color: Colors.white,
          ),
          SizedBox(width: 15),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Icon(
            Icons.close,
            color: Colors.white,
            size: 32,
          ), 
        )
      ],
    );
  }
}