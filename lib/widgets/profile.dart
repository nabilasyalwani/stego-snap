import 'package:flutter/material.dart';
import 'package:stego_snap/utils/colors.dart';

class ProfileWidget extends StatelessWidget {
  final String? profileImageUrl;
  final double iconSize;
  final double size;

  const ProfileWidget({
    super.key,
    required this.size,
    required this.iconSize,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.grayBackgroundProfile,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                profileImageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person, color: Colors.white, size: iconSize),
              )
            : Icon(Icons.person, color: Colors.white, size: iconSize),
      ),
    );
  }
}
