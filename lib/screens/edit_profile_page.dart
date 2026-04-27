import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stego_snap/screens/profile_page.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/services/auth_service.dart';
import 'package:stego_snap/services/notification_service.dart';
import 'package:stego_snap/widgets/custom_textfield.dart';
import 'package:stego_snap/widgets/custom_button.dart';
import 'package:stego_snap/widgets/profile.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final firebase_auth.User? _currentUser =
      firebase_auth.FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _profileImageController = TextEditingController();
  bool _isLoading = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController.text = _currentUser?.displayName ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted || !doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      setState(() {
        _nameController.text = data['displayName'] ?? '';
        _idController.text = data['idStegoSnap'] ?? '';
        _profileImageController.text = data['profileImage'] ?? '';
        _profileImageUrl = data['profileImage'];
      });
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Load Profile Failed',
        body: 'ERROR LOAD PROFILE: $e',
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final isSuccess = await _authService.updateUserProfile(
      displayName: _nameController.text,
      idStegoSnap: _idController.text,
      profileImageUrl: _profileImageController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (isSuccess) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      setState(() => _isLoading = true);

      final uploadedUrl = await _uploadProfileImage(imageFile);
      await _currentUser?.updatePhotoURL(uploadedUrl);

      if (!mounted) return;

      setState(() {
        _profileImageUrl = uploadedUrl;
        _profileImageController.text = uploadedUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile picture updated successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image picker belum aktif. Lakukan full restart.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _uploadProfileImage(File file) async {
    if (_currentUser == null) {
      throw Exception('User is null');
    }

    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final fileBytes = await file.readAsBytes();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = file.path.split('.').last;
    final fileName = 'profile_${_currentUser.uid}_$timestamp.$extension';

    try {
      await Supabase.instance.client.storage
          .from('profile_images')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return Supabase.instance.client.storage
          .from('profile_images')
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Upload failed');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ProfilePage()),
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
              "Edit Profile",
              style: TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 30),
            _buildProfileSection(),
            Spacer(),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Stack(
          children: [
            ProfileWidget(
              size: 100,
              iconSize: 60,
              profileImageUrl: _profileImageController.text.trim().isNotEmpty
                  ? _profileImageController.text.trim()
                  : _profileImageUrl,
            ),
            Positioned(
              bottom: 0,
              right: 5,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.purpleButton,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 40),
        _buildItemTextField(
          icon: Icons.person,
          controller: _nameController,
          hint: _currentUser?.displayName ?? 'Enter your name',
        ),
        SizedBox(height: 20),
        _buildItemTextField(
          icon: Icons.badge_outlined,
          controller: _idController,
          hint: 'idStegoSnap',
        ),
      ],
    );
  }

  Widget _buildItemTextField({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool isRequired = true,
  }) {
    return CustomTextField(
      controller: controller,
      hint: hint,
      icon: icon,
      onChanged: (val) {
        if (controller == _profileImageController) {
          setState(() {
            _profileImageUrl = val.trim().isEmpty ? null : val.trim();
          });
        }
      },
      validator: (val) {
        if (!isRequired) {
          return null;
        }
        return val!.trim().isEmpty ? 'Required field' : null;
      },
      keyboardType: TextInputType.text,
      foregroundColor: Colors.white,
      backgroundColor: AppColors.purpleField,
    );
  }

  Widget _buildBottomButton() {
    return CustomButton(
      onTap: _saveProfile,
      width: double.infinity,
      height: 50,
      label: _isLoading ? 'Saving...' : 'Save Changes',
      fontSize: 16,
      fontColor: AppColors.darkPurpleText,
      gradient: const LinearGradient(
        colors: [Colors.white, AppColors.purpleButton],
      ),
    );
  }
}
