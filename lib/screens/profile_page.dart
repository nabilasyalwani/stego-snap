import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/screens/landing_page.dart';
import 'package:stego_snap/screens/nav_page.dart';
import 'package:stego_snap/screens/edit_profile_page.dart';
import 'package:stego_snap/services/auth_service.dart';
import 'package:stego_snap/widgets/custom_button.dart';
import 'package:stego_snap/widgets/profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return (Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => NavPage()),
          ),
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(32.0),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgroundCreate.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 40),
            Text(
              "Profile",
              style: TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32),
            _buildProfileSection(),
            const Spacer(),
            _buildBottomButtons(context),
          ],
        ),
      ),
    ));
  }

  Widget _buildProfileInfo(
    BuildContext context,
    User user,
    Map<String, dynamic>? profileData,
  ) {
    final displayName =
        (profileData?['displayName'] as String?)?.trim().isNotEmpty == true
        ? profileData!['displayName'] as String
        : (user.displayName ?? 'User');
    final profileImageUrl = (profileData?['profileImage'] as String?)?.trim();
    final idStegoSnap =
        (profileData?['idStegoSnap'] as String?)?.trim().isNotEmpty == true
        ? profileData!['idStegoSnap'] as String
        : 'No ID';

    return Column(
      children: [
        ProfileWidget(
          size: 100,
          iconSize: 60,
          profileImageUrl: profileImageUrl,
        ),
        SizedBox(height: 20),
        Text(
          displayName,
          style: TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 30),
        _buildInfoItem(Icons.email, user.email ?? 'No Email'),
        _buildInfoItem(Icons.pin, idStegoSnap),
      ],
    );
  }

  Widget _buildProfileSection() {
    final user = _currentUser;
    if (user == null) {
      return _buildInfoItem(Icons.info_outline, 'No active user');
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.data();
        return _buildProfileInfo(context, user, profileData);
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.purpleField,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 20),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Column(
      children: [
        CustomButton(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => EditProfilePage()),
          ),
          icon: Icons.edit_outlined,
          width: double.infinity,
          height: 50,
          label: 'Edit Profile',
          fontSize: 16,
          fontColor: Colors.white,
          backgroundColor: AppColors.transparentPurpleButton,
        ),
        SizedBox(height: 20),
        CustomButton(
          onTap: () async {
            await _authService.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LandingPage()),
            );
          },
          width: double.infinity,
          height: 50,
          label: 'Log Out',
          fontSize: 16,
          fontColor: AppColors.darkPurpleText,
          gradient: const LinearGradient(
            colors: [Colors.white, AppColors.purpleButton],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ],
    );
  }
}
