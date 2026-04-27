import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:stego_snap/screens/nav_page.dart';
import 'package:stego_snap/screens/result_decode_page.dart';
import 'package:stego_snap/services/firestore_service.dart';
import 'package:stego_snap/services/notification_service.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/widgets/custom_button.dart';
import 'package:stego_snap/widgets/custom_textfield.dart';

class DecodePage extends StatefulWidget {
  const DecodePage({super.key});

  @override
  State<DecodePage> createState() => _DecodePageState();
}

class _DecodePageState extends State<DecodePage> {
  final TextEditingController _stegoPathController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  File? _selectedImageFile;
  String? _selectedImageUrl;
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _stegoPathController.text = FirestoreService.lastStegoServerPath ?? '';
  }

  Uri _decodePathApiUri() {
    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2:8000/decode');
    }
    return Uri.parse('http://127.0.0.1:8000/decode');
  }

  Uri _decodeFileApiUri() {
    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2:8000/decode_file');
    }
    return Uri.parse('http://127.0.0.1:8000/decode_file');
  }

  Future<void> _selectImageFromGallery() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    if (!mounted) return;

    setState(() {
      _selectedImageFile = File(pickedFile.path);
      _selectedImageUrl = null;
      _stegoPathController.text = pickedFile.path;
    });

    await NotificationService.createNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Decode Image',
      body: 'Gallery image selected and ready for decode.',
    );
  }

  Future<void> _useLastEncodedPath() async {
    final latestSnap = await _firestoreService.getLatestSnapForCurrentUser();
    final path = (latestSnap?['stegoServerPath'] as String?)?.trim();

    if (path == null || path.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Decode Path',
        body: 'No latest snap found yet. Encode an image first.',
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _selectedPath = path;
      _stegoPathController.text = path;
      _selectedImageFile = null;
      _selectedImageUrl = null;
    });

    await NotificationService.createNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Select Latest Path',
      body: 'Latest encoded image path selected and ready for decode.',
    );
  }

  Future<void> _decodeImage() async {
    final stegoPath = _stegoPathController.text.trim();

    if (_selectedImageFile == null && stegoPath == null) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Decode Failed',
        body: 'Please choose an image first.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      late http.Response response;

      if (_selectedImageFile != null) {
        final request = http.MultipartRequest('POST', _decodeFileApiUri());
        request.files.add(
          await http.MultipartFile.fromPath('file', _selectedImageFile!.path),
        );
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await http.post(
          _decodePathApiUri(),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'stego_image_path': stegoPath}),
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await NotificationService.createNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: 'Decode Failed',
          body: 'API decode gagal (${response.statusCode}). ${response.body}',
        );
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final decodedText = (data['decoded_text'] ?? '').toString();

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Decode Success',
        body: 'Image berhasil didecode dari API server.',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultDecodePage(
            decodedText: decodedText,
            stegoImagePath: _selectedImageFile?.path ?? stegoPath,
          ),
        ),
      );
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Decode Failed',
        body: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stegoPathController.dispose();
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
        child: _isLoading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Text(
          'Reveal Secret Content',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        _buildLinkPreviewArea(),
        const SizedBox(height: 20),
        _buildImagePicker(),
        const Spacer(),
        CustomButton(
          onTap: _isLoading ? () {} : _decodeImage,
          height: 65,
          width: double.infinity,
          borderRadius: 50.0,
          label: 'Decode Image',
          fontSize: 18,
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

  Widget _buildImagePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.purpleField,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionItem(
                icon: Icons.photo_outlined,
                onTap: _selectImageFromGallery,
              ),
              _buildActionItem(
                icon: Icons.folder_copy_outlined,
                onTap: _useLastEncodedPath,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Choose image",
            style: TextStyle(
              fontSize: 16,
              fontFamily: "Poppins",
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPreviewArea() {
    if (_selectedImageFile == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.purpleField,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomTextField(
          hint: 'Enter stego image path, e.g. stego-images/filename.jpg',
          icon: Icons.link,
          controller: _stegoPathController,
          validator: (val) => val!.isEmpty ? 'Enter stego image path' : null,
          keyboardType: TextInputType.text,
          onChanged: (_) {
            if (_selectedImageFile != null || _selectedImageUrl != null) {
              setState(() {
                _selectedImageFile = null;
                _selectedImageUrl = null;
              });
            }
          },
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 180,
        color: AppColors.purpleField,
        child: _selectedImageUrl != null && _selectedImageUrl!.isNotEmpty
            ? Image.network(
                _selectedImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.file(_selectedImageFile!, fit: BoxFit.cover);
                },
              )
            : Image.file(_selectedImageFile!, fit: BoxFit.cover),
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
}
