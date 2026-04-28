import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/screens/nav_page.dart';
import 'package:stego_snap/screens/result_encode_page.dart';
import 'package:stego_snap/services/firestore_service.dart';
import 'package:stego_snap/services/notification_service.dart';
import 'package:stego_snap/widgets/custom_button.dart';
import 'package:stego_snap/widgets/normal_textfield.dart';
import 'dart:io';

class EncodePage extends StatefulWidget {
  const EncodePage({super.key});

  @override
  State<EncodePage> createState() => _EncodePageState();
}

class _EncodePageState extends State<EncodePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dataController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  File? _tempImageFile;
  String? _selectedImageSource;
  bool _isEncoding = false;

  Uri _encodeApiUri() {
    if (Platform.isAndroid) {
      return Uri.parse('https://stego-snap.onrender.com/encode');
    }
    return Uri.parse('https://stego-snap.onrender.com/encode');
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile == null) return;
    if (!mounted) return;

    setState(() {
      _tempImageFile = File(pickedFile.path);
      _selectedImageSource = source == ImageSource.camera
          ? 'camera'
          : 'gallery';
    });

    await NotificationService.createNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Image Selected',
      body: 'Image selected from $_selectedImageSource.',
    );
  }

  Future<void> _encodeImage() async {
    final title = _titleController.text.trim();
    final secretData = _dataController.text.trim();

    if (_tempImageFile == null) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Encode Failed',
        body: 'Please choose image from camera or gallery first.',
      );
      return;
    }

    if (title.isEmpty || secretData.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Encode Failed',
        body: 'Title and secret message cannot be empty.',
      );
      return;
    }

    setState(() {
      _isEncoding = true;
    });

    try {
      final imagePath = _tempImageFile!.path;
      final request = http.MultipartRequest('POST', _encodeApiUri());
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      request.fields['secret_data'] = secretData;

      final streamedResponse = await request.send();
      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        final errorBody = await streamedResponse.stream.bytesToString();

        await NotificationService.createNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: 'Encode Failed',
          body: 'API encode gagal (${streamedResponse.statusCode}). $errorBody',
        );
        return;
      }

      final responseBytes = await streamedResponse.stream.toBytes();
      final serverFileName =
          streamedResponse.headers['x-filename'] ??
          'stego_${DateTime.now().millisecondsSinceEpoch}.png';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$serverFileName');
      await tempFile.writeAsBytes(responseBytes);

      final supabase = supabase_flutter.Supabase.instance.client;
      final storagePath = '${_currentUser!.uid}/$serverFileName';

      await supabase.storage
          .from('stego_images')
          .uploadBinary(
            storagePath,
            responseBytes,
            fileOptions: const supabase_flutter.FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = supabase.storage
          .from('stego_images')
          .getPublicUrl(storagePath);

      final snapId = await _firestoreService.createSnap(
        title: title,
        stegoImageUrl: publicUrl,
      );

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Encode Success',
        body: 'Image encoded and uploaded successfully.',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultEncodePage(
            title: title,
            secretData: secretData,
            encodedImageUrl: publicUrl,
            stegoFileId: snapId,
          ),
        ),
      );
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Encode Failed',
        body: 'Failed to save snap: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEncoding = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dataController.dispose();
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
            MaterialPageRoute(builder: (context) => const NavPage()),
          ),
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 25.0),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgroundCreate.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              'Create Secure Image',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _buildImagePicker(),
            const SizedBox(height: 15),
            _buildTitleInput(),
            const SizedBox(height: 15),
            _buildMessageInput(),
            const Spacer(),
            CustomButton(
              onTap: _isEncoding ? () {} : _encodeImage,
              height: 65,
              width: double.infinity,
              borderRadius: 50.0,
              label: _isEncoding ? 'Encoding...' : 'Encode Image',
              fontSize: 18,
              fontColor: AppColors.darkPurpleText,
              gradient: const LinearGradient(
                colors: [Colors.white, AppColors.purpleButton],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.purpleField,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionItem(
                      icon: Icons.camera_alt_outlined,
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 50),
                    _buildActionItem(
                      icon: Icons.photo_outlined,
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Choose Image",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: "Poppins",
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _tempImageFile != null
                  ? Image.file(_tempImageFile!, fit: BoxFit.cover)
                  : Image.asset(
                      "assets/images/rectangle1.png",
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 32, color: Colors.white),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.purpleField,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Text(
              "Title:",
              style: TextStyle(
                fontSize: 16,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Expanded(
              child: NormalTextField(
                controller: _titleController,
                hint: 'Enter your title',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purpleField,
        borderRadius: BorderRadius.circular(16),
      ),
      child: NormalTextField(
        controller: _dataController,
        hint: 'Write your secret message here...',
        maxLines: 20,
      ),
    );
  }
}
