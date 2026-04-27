import 'package:flutter/material.dart';
import 'package:stego_snap/utils/colors.dart';

class BottomSheetContainer extends StatelessWidget {
  final Widget child;

  const BottomSheetContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: AppColors.navBottom,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: child,
      ),
    );
  }
}