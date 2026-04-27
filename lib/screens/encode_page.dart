import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

  File? _tempImageFile;
  String? _selectedImageSource;
  bool _isEncoding = false;

  Uri _encodeApiUri() {
    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2:8000/encode');
    }
    return Uri.parse('http://127.0.0.1:8000/encode');
  }

  String _extractFilename(Map<String, String> headers) {
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition == null) {
      return 'stego_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }

    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(contentDisposition);
    return match?.group(1) ??
        'stego_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      request.fields['title'] = title;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await NotificationService.createNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: 'Encode Failed',
          body: 'API encode gagal (${response.statusCode}). ${response.body}',
        );
        return;
      }

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Encode Success',
        body: 'Image berhasil dikirim ke API encode.',
      );

      final encodedFileName = _extractFilename(response.headers);
      final stegoServerPath = 'stego-images/$encodedFileName';

      await _firestoreService.createSnap(
        title: title,
        localImagePath: _tempImageFile!.path,
        imageSource: _selectedImageSource ?? 'unknown',
        stegoServerPath: stegoServerPath,
        stegoFileName: encodedFileName,
      );

      final snapId = FirestoreService.lastSnapId;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultEncodePage(
            title: title,
            secretData: secretData,
            encodedImageUrl: _encodeApiUri()
                .replace(path: '/stego-images/$encodedFileName')
                .toString(),
            encodedFileName: encodedFileName,
            stegoServerPath: stegoServerPath,
            snapId: snapId,
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
