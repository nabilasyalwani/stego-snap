import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/screens/nav_page.dart';
import 'package:stego_snap/services/firestore_service.dart';
import 'package:stego_snap/services/notification_service.dart';
import 'package:stego_snap/widgets/custom_button.dart';
import 'package:stego_snap/widgets/custom_iconbutton.dart';
import 'package:stego_snap/widgets/buttom_sheet_container.dart';
import 'package:stego_snap/widgets/buttom_sheet_header.dart';
import 'package:stego_snap/widgets/custom_textfield.dart';

class ResultEncodePage extends StatefulWidget {
  final String title;
  final String? encodedImageUrl;
  final String? encodedFileName;
  final String? stegoServerPath;
  final String? secretData;
  final String? snapId;

  const ResultEncodePage({
    super.key,
    this.title = "Title Image",
    this.encodedImageUrl,
    this.encodedFileName,
    this.stegoServerPath,
    this.secretData = "This is your secret data",
    this.snapId,
  });

  @override
  State<ResultEncodePage> createState() => _ResultEncodePageState();
}

class _ResultEncodePageState extends State<ResultEncodePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  static const int _downloadModalState = 1;
  static const int _shareModalState = 2;
  static const int _renameModalState = 3;

  String? shareToUserID;
  String? title;
  late String _currentTitle;
  final isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
  }

  Future<void> _downloadEncodedImage() async {
    final imageUrl = widget.encodedImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Download Failed',
        body: 'Encoded image URL is not available.',
      );
      return;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await NotificationService.createNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: 'Download Failed',
          body: 'Failed to fetch encoded image (${response.statusCode}).',
        );
        return;
      }

      final fileName =
          widget.encodedFileName ??
          'encoded_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFile = File('${Directory.systemTemp.path}/$fileName');
      await outputFile.writeAsBytes(response.bodyBytes);

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Download Success',
        body: 'Encoded image saved temporarily to ${outputFile.path}',
      );
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Download Failed',
        body: e.toString(),
      );
    }
  }

  Future<void> _renameSnapTitle() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final newTitle = (title ?? '').trim();
    if (newTitle.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Rename Failed',
        body: 'Please enter a new title first.',
      );
      return;
    }

    final snapId = widget.snapId;
    if (snapId == null || snapId.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Rename Failed',
        body: 'Snap id is not available.',
      );
      return;
    }

    try {
      await FirestoreService().renameSnapById(
        snapId: snapId,
        newTitle: newTitle,
      );

      if (!mounted) return;
      setState(() {
        _currentTitle = newTitle;
      });

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Rename Success',
        body: 'Snap title updated successfully.',
      );
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Rename Failed',
        body: e.toString(),
      );
    }
  }

  Future<void> _shareSnap() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final userId = (shareToUserID ?? '').trim();
    if (userId.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Failed',
        body: 'Please enter a User ID first.',
      );
      return;
    }

    final snapId = widget.snapId;
    if (snapId == null || snapId.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Failed',
        body: 'Snap id is not available.',
      );
      return;
    }

    try {
      await FirestoreService().shareSnapToUserId(
        snapId: snapId,
        userId: userId,
      );

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Success',
        body: 'Snap shared to user id $userId.',
      );
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Failed',
        body: e.toString(),
      );
    }
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
        child: isLoading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(
          'Succesfully Encode Data!',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 200,
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child:
                widget.encodedImageUrl != null &&
                    widget.encodedImageUrl!.isNotEmpty
                ? Image.network(
                    widget.encodedImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/images/rectangle1.png',
                        fit: BoxFit.cover,
                      );
                    },
                  )
                : Image.asset(
                    'assets/images/rectangle1.png',
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _currentTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: "Poppins",
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25.0),
            decoration: BoxDecoration(
              color: AppColors.purpleField,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildRichText(), const Spacer()],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButton(),
      ],
    );
  }

  Widget _buildRichText() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          fontFamily: "Poppins",
          color: Colors.white,
        ),
        children: [
          const TextSpan(
            text: "Secret data: ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: widget.secretData ?? 'This is your secret data'),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Row(
      children: [
        Expanded(
          child: _buildIconButton(Icons.folder_copy_outlined, () {
            _showActionModal(_renameModalState);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildIconButton(Icons.download_outlined, () {
            _showActionModal(_downloadModalState);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildIconButton(Icons.send_outlined, () {
            _showActionModal(_shareModalState);
          }),
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return CustomIconButton(
      onTap: onTap,
      height: 65,
      width: 112,
      backgroundColor: AppColors.transparentPurpleButton,
      borderRadius: 20,
      icon: icon,
      fontColor: Colors.white,
    );
  }

  void _showActionModal(int initialState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        int modalState = initialState;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return _buildDynamicContent(
              modalState,
              (value) => setModalState(() => modalState = value),
            );
          },
        );
      },
    );
  }

  Widget _buildDynamicContent(int modalState, Function(int) setModalState) {
    switch (modalState) {
      case _downloadModalState:
        return _buildDownloadForm();
      case _shareModalState:
        return _buildShareForm();
      case _renameModalState:
        return _buildRenameForm();
      default:
        return BottomSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomSheetHeader(
                iconSize: 32,
                title: "Options",
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
              _buildCreateOption(
                icon: Icons.file_download_outlined,
                label: "Download",
                onTap: () => setModalState(_downloadModalState),
              ),
              _buildCreateOption(
                icon: Icons.send_outlined,
                label: "Share to User ID",
                onTap: () => setModalState(_shareModalState),
              ),
              _buildCreateOption(
                icon: Icons.edit_outlined,
                label: "Rename title",
                onTap: () => setModalState(_renameModalState),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
    }
  }

  Widget _buildCreateOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: "Poppins",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadForm() {
    return (BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            prefixIcon: Icons.file_download_outlined,
            iconSize: 28,
            title: "Download",
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          _buildActionContainer(
            onTap: _downloadEncodedImage,
            notes: "Do you want to download this photo?",
            action: "Download",
          ),
        ],
      ),
    ));
  }

  Widget _buildShareForm() {
    return (BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            prefixIcon: Icons.send_outlined,
            iconSize: 28,
            title: "Share to User ID",
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          _buildActionContainer(
            hint: "Enter User ID",
            icon: Icons.person_outlined,
            notes:
                "This image contain a secret data. Are you sure you want to share it?",
            action: "Send",
            onTap: _shareSnap,
            onChanged: (val) => shareToUserID = val,
          ),
        ],
      ),
    ));
  }

  Widget _buildRenameForm() {
    return (BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            prefixIcon: Icons.edit_outlined,
            iconSize: 28,
            title: "Rename Title",
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          _buildActionContainer(
            hint: "Enter New Title",
            icon: Icons.folder_open_outlined,
            onTap: _renameSnapTitle,
            action: "Save",
            notes: "Do you want to rename this photo?",
            onChanged: (val) => title = val,
          ),
        ],
      ),
    ));
  }

  Widget _buildActionContainer({
    String? hint,
    String? notes,
    required String action,
    IconData? icon,
    required Future<void> Function() onTap,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hint != null) ...[
          Form(
            key: _formKey,
            child: CustomTextField(
              hint: hint,
              icon: icon ?? Icons.text_fields,
              onChanged: onChanged ?? (_) {},
              validator: (val) => val!.isEmpty ? 'Please $hint' : null,
            ),
          ),
          const SizedBox(height: 40),
        ],
        if (notes != null) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              notes,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: "Poppins",
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        CustomButton(
          onTap: () async {
            await onTap();
            if (mounted) {
              Navigator.pop(context);
            }
          },
          height: 65,
          width: double.infinity,
          borderRadius: 50.0,
          label: action,
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
}
