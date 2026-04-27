import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stego_snap/screens/profile_page.dart';
import 'package:stego_snap/services/firestore_service.dart';
import 'package:stego_snap/services/notification_service.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/widgets/buttom_sheet_container.dart';
import 'package:stego_snap/widgets/buttom_sheet_header.dart';
import 'package:stego_snap/widgets/custom_button.dart';
import 'package:stego_snap/widgets/custom_textfield.dart';
import 'package:stego_snap/widgets/profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  int _selectedTab = 0;
  String shareToUserID = '';
  String title = '';
  String _searchQuery = '';
  Map<String, dynamic>? _activeSnap;

  String _serverBaseUrl() {
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  String? _buildImageUrl(Map<String, dynamic> snap) {
    final serverPath = (snap['stegoServerPath'] as String?)?.trim();
    if (serverPath == null || serverPath.isEmpty) {
      return null;
    }
    if (serverPath.startsWith('http')) {
      return serverPath;
    }
    return '${_serverBaseUrl()}/$serverPath';
  }

  Future<void> _tryDownload() async {
    final snap = _activeSnap;
    if (snap == null) return;

    final imageUrl = _buildImageUrl(snap);
    if (imageUrl == null) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Download Failed',
        body: 'Encoded image URL is not available for this snap.',
      );
      return;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await NotificationService.createNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: 'Download Failed',
          body: 'Failed to fetch image (${response.statusCode}).',
        );
        return;
      }

      final fileName =
          (snap['stegoFileName'] as String?)?.trim().isNotEmpty == true
          ? snap['stegoFileName'] as String
          : 'encoded_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final outputFile = File('${Directory.systemTemp.path}/$fileName');
      await outputFile.writeAsBytes(response.bodyBytes);

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Download Success',
        body: 'File saved temporarily to ${outputFile.path}',
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Download Failed',
        body: e.toString(),
      );
    }
  }

  Future<void> _tryShare() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final snap = _activeSnap;
    if (snap == null) return;

    final targetUserId = shareToUserID.trim();
    if (targetUserId.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Failed',
        body: 'Please enter a valid user id.',
      );
      return;
    }

    try {
      await _firestoreService.shareSnapToUserId(
        snapId: (snap['snapsId'] ?? snap['id']).toString(),
        userId: targetUserId,
      );

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Success',
        body: 'Snap shared to user id $targetUserId.',
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Failed',
        body: e.toString(),
      );
    }
  }

  Future<void> _tryRename() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final snap = _activeSnap;
    if (snap == null) return;

    final newTitle = title.trim();
    if (newTitle.isEmpty) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Rename Failed',
        body: 'Please enter a new title.',
      );
      return;
    }

    try {
      await _firestoreService.renameSnapById(
        snapId: (snap['snapsId'] ?? snap['id']).toString(),
        newTitle: newTitle,
      );

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Rename Success',
        body: 'Snap title updated successfully.',
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Rename Failed',
        body: e.toString(),
      );
    }
  }

  Future<void> _tryDelete() async {
    final snap = _activeSnap;
    if (snap == null) return;

    try {
      await _firestoreService.deleteSnap(
        (snap['snapsId'] ?? snap['id']).toString(),
      );

      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Delete Success',
        body: 'Snap deleted successfully.',
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Delete Failed',
        body: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHomeHeader(context),
                  const SizedBox(height: 28),
                  _buildSearchField(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildSegmentedTab()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(25, 15, 25, 65),
            sliver: _buildSnapGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeHeader(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $displayName',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 30,
                color: Colors.white,
              ),
            ),
            const Text(
              'Welcome to StegoSnap',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfilePage()),
          ),
          child: _buildProfileAvatar(user),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar(User? user) {
    if (user == null) {
      return const ProfileWidget(size: 70, iconSize: 50);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final profileImageUrl = (data?['profileImage'] as String?)?.trim();

        return ProfileWidget(
          size: 70,
          iconSize: 50,
          profileImageUrl: profileImageUrl,
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextFormField(
      controller: _controller,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      },
      style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 16.0, right: 8.0),
          child: Icon(Icons.search, color: Colors.white, size: 28),
        ),
        suffixIcon: const Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: Icon(
            Icons.settings_input_component_outlined,
            color: Colors.white,
          ),
        ),
        hintText: 'Search image',
        hintStyle: GoogleFonts.poppins(fontSize: 15, color: Colors.white70),
        filled: true,
        fillColor: AppColors.purpleField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
      ),
    );
  }

  Widget _buildSegmentedTab() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.purpleField,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTabItem('[ENCODED]', 0),
          _buildTabItem('[DECODED]', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.purpleNavButton : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnapGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.getAllSnap(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Text(
              'Failed to load snaps: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          if (_searchQuery.isNotEmpty && !title.contains(_searchQuery)) {
            return false;
          }
          if (_selectedTab == 1) {
            return (data['decoded_text'] ?? '').toString().isNotEmpty;
          }
          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Text(
              'No snap data found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 5,
          childCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data();
            final snap = {...data, 'id': doc.id};
            return _buildCard(snap);
          },
        );
      },
    );
  }

  Widget _buildCard(Map<String, dynamic> snap) {
    final imageUrl = _buildImageUrl(snap);
    final title = (snap['title'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: GestureDetector(
            onTap: () => _showOptionImage(context, snap),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
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
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showOptionImage(context, snap),
                child: const Icon(Icons.more_horiz, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOptionImage(BuildContext context, Map<String, dynamic> snap) {
    _activeSnap = snap;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        int modalState = 0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 100),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: (_buildImageUrl(snap) != null)
                                ? Image.network(
                                    _buildImageUrl(snap)!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/images/rectangle1.png',
                                        fit: BoxFit.contain,
                                      );
                                    },
                                  )
                                : Image.asset(
                                    'assets/images/rectangle1.png',
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          (snap['title'] ?? '').toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildDynamicContent(
                  context,
                  modalState,
                  (val) => setModalState(() => modalState = val),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDynamicContent(
    BuildContext context,
    int modalState,
    Function(int) setModalState,
  ) {
    switch (modalState) {
      case 0:
        return _buildOptionMenu(setModalState);
      case 1:
        return _buildDownloadForm();
      case 2:
        return _buildShareForm();
      case 3:
        return _buildRenameForm();
      case 4:
        return _buildDeleteForm();
      default:
        return const SizedBox();
    }
  }

  Widget _buildOptionMenu(Function(int) setModalState) {
    return BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            iconSize: 32,
            title: 'Options Image',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          buildCreateOption(
            icon: Icons.file_download_outlined,
            label: 'Download',
            onTap: () => setModalState(1),
          ),
          buildCreateOption(
            icon: Icons.send_outlined,
            label: 'Share to User ID',
            onTap: () => setModalState(2),
          ),
          buildCreateOption(
            icon: Icons.edit_outlined,
            label: 'Rename title',
            onTap: () => setModalState(3),
          ),
          buildCreateOption(
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: () => setModalState(4),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget buildCreateOption({
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
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadForm() {
    return BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            prefixIcon: Icons.file_download_outlined,
            iconSize: 28,
            title: 'Download',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          _buildActionContainer(
            onTap: _tryDownload,
            notes: 'Do you want to download this photo?',
            action: 'Download',
          ),
        ],
      ),
    );
  }

  Widget _buildShareForm() {
    return BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            prefixIcon: Icons.send_outlined,
            iconSize: 28,
            title: 'Share to User ID',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          _buildActionContainer(
            hint: 'Enter User ID',
            icon: Icons.person_outlined,
            notes:
                'This image contain a secret data. Are you sure you want to share it?',
            action: 'Send',
            onTap: _tryShare,
            onChanged: (val) => shareToUserID = val,
          ),
        ],
      ),
    );
  }

  Widget _buildRenameForm() {
    return BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            prefixIcon: Icons.edit_outlined,
            iconSize: 28,
            title: 'Rename Title',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          _buildActionContainer(
            hint: 'Enter New Title',
            icon: Icons.folder_open_outlined,
            onTap: _tryRename,
            action: 'Save',
            notes: 'Do you want to rename this photo?',
            onChanged: (val) => title = val,
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteForm() {
    return BottomSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            prefixIcon: Icons.delete_outline,
            iconSize: 28,
            title: 'Delete',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          _buildActionContainer(
            onTap: _tryDelete,
            notes: 'Are you sure you want to delete it?',
            action: 'Delete',
          ),
        ],
      ),
    );
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
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        CustomButton(
          onTap: () async => onTap(),
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
